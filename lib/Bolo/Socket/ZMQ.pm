package Bolo::Socket::ZMQ;

use strict;
use warnings;

use ZMQ::LibZMQ3;
use ZMQ::Constants qw/
	ZMQ_PUB ZMQ_SUB ZMQ_DEALER ZMQ_ROUTER
	ZMQ_SNDMORE ZMQ_RCVMORE
	ZMQ_SUBSCRIBE
	ZMQ_LINGER
	ZMQ_POLLIN ZMQ_POLLOUT
/;

sub new
{
	my ($class, %opts) = @_;
	my $ctx = zmq_ctx_new()
		or return undef;

	bless({
		_context   => $ctx,
		_timeout   => $opts{timeout} || 5,
		_endpoints => [],
		_binds     => [],
		_socket    => undef,
	}, $class);
}

sub timeout
{
	my ($self, $val) = @_;
	return $self->{_timeout} unless defined $val;

	my $old = $self->{_timeout};
	$self->{_timeout} = $val;
	return $old;
}

sub timeout_us
{
	my ($self) = @_;
	my $timeout = $self->timeout;
	return -1 if $timeout <= 0;

	$timeout * 1000; # s -> us
}

sub _socket
{
	my ($self, $type) = @_;
	die "Socket type already set\n" if $self->{_socket};

	$self->{_socket} = zmq_socket($self->{_context}, $type)
		or die "Failed to create a socket: $!\n";
	$self->{type} = $type;

	zmq_setsockopt($self->{_socket}, ZMQ_LINGER, 0) == 0
		or die "Failed to set 0MQ linger timeout to 0\n";

	$self;
}

sub router { $_[0]->_socket(ZMQ_ROUTER); }
sub dealer { $_[0]->_socket(ZMQ_DEALER); }

sub publisher { $_[0]->_socket(ZMQ_PUB); }
sub subscriber
{
	my ($self, $filter) = @_;
	$self->_socket(ZMQ_SUB);

	zmq_setsockopt($self->{_socket}, ZMQ_SUBSCRIBE, $filter || "") == 0
		or die "Failed to set 0MQ subscriber filter\n";
	$self;
}

sub bound
{
	my ($self) = @_;
	return scalar(@{ $self->{_binds} }) > 0;
}

sub bind
{
	my ($self, @listen) = @_;
	die "bind() before setting up socket type (by ->publisher or ->router)\n"
		if !$self->{_socket};

	for (@listen) {
		zmq_bind($self->{_socket}, $_) == 0
			or die "Failed to bind to $_: $!\n";

		push @{ $self->{_binds} }, $_;
	}
	$self;
}

sub connected
{
	my ($self) = @_;
	return scalar(@{ $self->{_endpoints} }) > 0;
}

sub connect
{
	my ($self, @endpoints) = @_;
	die "connect() before setting up socket type (by ->subscriber or ->dealer)\n"
		if !$self->{_socket};

	for (@endpoints) {
		zmq_connect($self->{_socket}, $_) == 0
			or die "Failed to connect to $_: $!\n";
		push @{ $self->{_endpoints} }, $_;
	}
	$self;
}

sub disconnect
{
	my ($self, @endpoints) = @_;
	return $self unless $self->{_socket};

	if (!@endpoints) {
		@endpoints = @{ $self->{_endpoints} };
	}
	for (@endpoints) {
		zmq_disconnect($self->{_socket}, $_);
	}
	$self;
}

sub receive
{
	my ($self) = @_;
	return undef unless $self->{_socket};

	my ($buf, @frames);
	my @ready = zmq_poll([
			{ socket   => $self->{_socket},
			  events   => ZMQ_POLLIN,
			  callback => sub {}   # dummy callback, required by ZMQ::LibZMQ3 impl.
			},
		], $self->timeout_us);
	return undef unless $ready[0];

	do {
		zmq_recv($self->{_socket}, $buf, 4096);
		$buf =~ s/\0*$//;
		push @frames, "$buf";
	} while (zmq_getsockopt($self->{_socket}, ZMQ_RCVMORE));

	if ($self->{type} == ZMQ_ROUTER) {
		my $id = shift @frames;
		shift @frames;
		unshift @frames, $id;
	}

	print STDERR "received ZMQ frames:\n".Dumper(\@frames)
		if $ENV{BOLO_WEB_DEBUG};

	return \@frames;
}

sub send
{
	my ($self, $frames) = @_;
	return undef unless $self->{_socket};

	print STDERR "sending ZMQ frames:\n".Dumper($frames)
		if $ENV{BOLO_WEB_DEBUG};

	my @ready = zmq_poll([
			{ socket   => $self->{_socket},
			  events   => ZMQ_POLLOUT,
			  callback => sub {}   # dummy callback, required by ZMQ::LibZMQ3 impl.
			},
		], $self->timeout_us);
	return undef unless $ready[0];

	if ($self->{type} == ZMQ_DEALER) {
		zmq_send($self->{_socket}, "", 0, ZMQ_SNDMORE) > -1
			or return 0;
	}

	$frames = [map { $_ ? $_ : '' } @$frames];
	my $last = pop @$frames;
	for (@$frames) {
		zmq_send($self->{_socket}, $_, -1, ZMQ_SNDMORE) > -1
			or return 0;
	}
	zmq_send($self->{_socket}, $last, -1) > -1
		or return 0;
	return 1;
}

sub shutdown
{
	my ($self) = @_;
	return unless $self->{_socket};

	if ($self->bound) {
		zmq_unbind($self->{_socket}, $_)
			for @{ $self->{_binds} };
		$self->{_binds} = [];
	}
	if ($self->connected) {
		zmq_disconnect($self->{_socket}, $_)
			for @{ $self->{_endpoints} };
		$self->{_endpoints} = [];
	}

	zmq_close($self->{_socket}) == 0
		or die "Failed to close socket: $!\n";
	$self->{_socket} = undef;
}

sub DESTROY
{
	my ($self) = @_;
	$self->shutdown;
	zmq_ctx_destroy($self->{_context});
}

1;

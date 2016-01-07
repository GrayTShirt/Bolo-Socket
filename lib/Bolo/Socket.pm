package Bolo::Socket;

use strict;
use warnings;

use IPC::Open3;
use Fcntl;
use Bolo::Dashboard::ZMQ;
use Bolo::Dashboard::Logger;

my %CLIENTS;
my %SUBSCRIBERS = ();
my $SERVER = {};

sub subscriber
{
	my ($filter, $endpoints) = @_;
	pipe my $reader, my $writer;

	defined (my $pid = fork) or die "fork failed: $!\n";

	if (!$pid) { # child process
		close $reader;
		nonblocking($writer);
		open STDOUT, ">&", $writer
			or die "Failed to reopen STDOUT\n";
		close STDIN;
		close STDERR;

		my $subscriber = Bolo::Dashboard::ZMQ->new->subscriber($filter);
		$subscriber->connect(@$endpoints);
		$subscriber->timeout(0); # block forever!

		do {
			my $pdu = $subscriber->receive;
			print JSON->new->utf8->encode($pdu)."\n";
		} while 1;
		exit 0;
	}

	close $writer;
	nonblocking($reader);

	$SUBSCRIBERS{$reader} = {
		buffer => '',
		io     => $reader,
		pid    => $pid,
	};
}

sub _drain
{
	my ($io) = @_;

	my (@block, $buf, $n);
	while (1) {
		defined($n = sysread($io, $buf, 4096))
			and $n > 0 or last;
		push @block, "$buf";
	}
	join('', @block);
}

sub nonblocking
{
	my ($fd) = @_;
	my $flags = fcntl($fd, F_GETFL, 0)
		or die "Failed to get flags from pipe\n";
	$flags = fcntl($fd, F_SETFL, $flags | O_NONBLOCK)
		or die "Failed to set flags on pipe\n";
}

sub on_zmq
{
	my ($server, $io) = @_;
	my $S = $SUBSCRIBERS{$io};
	$S->{buffer} .= _drain($io);
	my $n = scalar(values %CLIENTS);
	while ($S->{buffer} =~ s/^(.*)\n//) {
		my $now = time;
		last unless values %CLIENTS;
		logger info => 'broadcasting %s to all %i connected client(s)', $1, $n;
		$_->send_utf8($1) for values %CLIENTS;
	}
}

1;

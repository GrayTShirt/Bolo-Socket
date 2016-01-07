#!/usr/bin/perl

use strict;
use warnings;

use ExtUtils::MakeMaker;

WriteMakefile(
	NAME               => 'Bolo::Socket',
	AUTHOR             => q{Dan Molik <dan@d3fy.net>},
	VERSION_FROM       => 'lib/Bolo/Socket.pm',
	ABSTRACT_FROM      => 'lib/Bolo/Socket.pm',
	LICENSE            => 'private',
	PL_FILES           => {},
	MIN_PERL_VERSION   => 5.006,
	CONFIGURE_REQUIRES => {
		'ExtUtils::MakeMaker' => 0,
	},
	BUILD_REQUIRES     => {
		'Test::More' => 0,
	},
	PREREQ_PM          => {
		'ZMQ::LibZMQ3'   => 0,
		'ZMQ::Constants' => 0,
	},
	dist               => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
	clean              => { FILES => 'Bolo-Socket-*' },
);

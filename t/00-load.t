#!/usr/bin/perl -T

use strict;
use warnings;

use Test::More;

plan tests => 1;

BEGIN {
    use_ok( 'Bolo::Socket' ) || print "Bail out!\n";
}

diag( "Testing Bolo::Socket $Bolo::Socket::VERSION, Perl $], $^X" );

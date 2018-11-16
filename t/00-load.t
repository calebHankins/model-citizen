#!/usr/bin/perl -w
use strict;
use warnings FATAL => 'all';
use Test::More;

plan tests => 1;

# Make sure we could load the module
BEGIN {
  use_ok('ModelCitizen') || print "Could not load module\n";
}

diag("Testing ModelCitizen $ModelCitizen::VERSION, Perl $], $^X");


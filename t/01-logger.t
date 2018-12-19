#!/usr/bin/perl -w
use strict;
use warnings;
use Test::More;

use ModelCitizen;

plan tests => 8;

testLogger();

sub testLogger {

  # Let's make sure logger has all the functions we expect and store values as expected
  my $died          = 0;
  my $checkErrCnt   = 0;
  my $checkFatalCnt = 0;

  # Debug / Info
  $ModelCitizen::logger->trace("trace");
  $ModelCitizen::logger->debug("debug");
  $ModelCitizen::logger->info("info");

  # Warning
  $ModelCitizen::logger->warn("warn");
  $ModelCitizen::logger->carp("carp");
  $ModelCitizen::logger->cluck("cluck");

  # Error
  $ModelCitizen::logger->error("error");
  $checkErrCnt = $ModelCitizen::logger->get_count("ERROR");
  ok($checkErrCnt == 1);

  # Error and die
  $died = 0;
  eval { $ModelCitizen::logger->error_die("error_die"); };
  $died = 1 if $@;
  ok($died);
  $checkErrCnt = $ModelCitizen::logger->get_count("ERROR");
  ok($checkErrCnt == 2);

  $died = 0;
  eval { $ModelCitizen::logger->croak("croak"); };
  $died = 1 if $@;
  ok($died);
  $checkErrCnt = $ModelCitizen::logger->get_count("ERROR");
  ok($checkErrCnt == 3);

  $died = 0;
  eval { $ModelCitizen::logger->confess("confess"); };
  $died = 1 if $@;
  ok($died);
  $checkErrCnt = $ModelCitizen::logger->get_count("ERROR");
  ok($checkErrCnt == 4);

  # Fatal
  $ModelCitizen::logger->fatal("fatal");
  $checkFatalCnt = $ModelCitizen::logger->get_count("FATAL");
  ok($checkFatalCnt == 1);

} ## end sub testLogger

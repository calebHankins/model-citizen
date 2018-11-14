#!/usr/bin/perl -w
use strict;
use warnings FATAL => 'all';
use File::Spec;
use Test::More;
use English qw(-no_match_vars);

# Make sure we adhere to the supplied style guidelines
eval { require Test::Code::TidyAll; };
if ($EVAL_ERROR) {
  my $msg = 'Test::Code::TidyAll required to criticize code';
  plan(skip_all => $msg);
}

Test::Code::TidyAll::tidyall_ok();

#!/usr/bin/perl -w
use strict;
use warnings FATAL => 'all';
use Test::More;
no if $] >= 5.017011, warnings => 'experimental::smartmatch';    # Suppress smartmatch warnings

use ModelCitizen;

plan tests => 8;

checkRequiredParm();
objConversionErrorMsgGenerator();
signOff();
getUniqArray();
logFileInformation();

sub getUniqArray {
  my @uniqLUE = ModelCitizen::getUniqArray((42, 42, 42, 42, 42));
  my @oneLUE  = (42);
  is_deeply(@oneLUE, @uniqLUE);

  return;
} ## end sub getUniqArray

sub checkRequiredParm {
  my $checkRequiredParmErrCnt = 0;

  # Populated
  my $populatedValue = 42;
  ModelCitizen::checkRequiredParm($populatedValue);
  $checkRequiredParmErrCnt = $ModelCitizen::logger->get_count("ERROR");
  ok($checkRequiredParmErrCnt == 0);

  # Unpopulated
  my $unpopulatedValue = '';
  ModelCitizen::checkRequiredParm($unpopulatedValue);
  $checkRequiredParmErrCnt = $ModelCitizen::logger->get_count("ERROR");
  ok($checkRequiredParmErrCnt == 1);

  # Undefined
  my $undefinedValue;
  ModelCitizen::checkRequiredParm($undefinedValue);
  $checkRequiredParmErrCnt = $ModelCitizen::logger->get_count("ERROR");
  ok($checkRequiredParmErrCnt == 2);

  return;
} ## end sub checkRequiredParm

sub objConversionErrorMsgGenerator {
  my $errorMessage          = 'I_AM_AN_ERROR_MSG';
  my $errorMessageConverted = ModelCitizen::objConversionErrorMsgGenerator($errorMessage);
  ok($errorMessageConverted =~ /$errorMessage/i);

  return;
} ## end sub objConversionErrorMsgGenerator

sub signOff {
  ok(ModelCitizen::signOff(42) == 42);
  ok(ModelCitizen::signOff(256) == 1);

  return;
} ## end sub signOff

sub logFileInformation {
  ok(!defined(ModelCitizen::logFileInformation(['testFile1.txt'], 'testFiles', './scratch')));
}

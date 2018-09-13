#!/usr/bin/perl
#/*#########################################################################################
#                       (C) Copyright Acxiom Corporation 2017
#                               All Rights Reserved.
############################################################################################
#
# Script: partnerApps_generify.pl
# Author: Caleb Hankins - chanki
# Date:   2017-09-07
#
# Purpose: Make environment specific files generic or vice versa
#
############################################################################################
# MODIFICATION HISTORY
##-----------------------------------------------------------------------------------------
# DATE        PROGRAMMER                   DESCRIPTION
##-----------------------------------------------------------------------------------------
# 2017-09-07  Caleb Hankins - chanki       Initial Copy
###########################################################################################*/

use strict;
use warnings;
use IO::Handle;                # Supply object methods for I/O handles
use Getopt::Long;              # Extended processing of command line options
use Pod::Usage;                # Print a usage message from embedded pod documentation
use Cwd qw( cwd abs_path );    # Get current working directory and absolute file paths
use partnerApps;               # partnerApps helper code for acxiom integration

# turn on auto-flush / hot pipes
STDOUT->autoflush(1);
STDERR->autoflush(1);

# User options that we'll set using GetOptions()
my $packageFilepath   = cwd();    # Default dir to current working dir if no path is specified
my $outputRuleList    = '';
my $globalFindReplace = '';
my $preserveQuotes    = '';       # Default to stripping quotes from find/replace strings
my $utfDisabled       = '';       # Default to creating files with encoding(UTF-8)
my $fuseLogSafeOutput = 1;        # Default to make log output 'Fuse safe'
my $testMode          = '';
my $verbose           = '';

my $rc = GetOptions(
  'f|packageFilepath=s'   => \$packageFilepath,
  'o|outputRuleList=s'    => \$outputRuleList,
  'g|globalFindReplace=s' => \$globalFindReplace,
  'p|preserveQuotes'      => \$preserveQuotes,
  'utfDisabled'           => \$utfDisabled,
  'fuseLogSafeOutput=s'   => \$fuseLogSafeOutput,

  't|testMode' => \$testMode,
  'v|verbose'  => \$verbose,

  #pod2usage variables
  'help' => sub { pod2usage(1); },
  'man'  => sub { pod2usage(-exitstatus => 0, -verbose => 2); }
);

# Give script options the ol' sanity check
sanityCheckOptions();

# Print script config info to log
logScriptConfig();

# Construct a list of files to munge and log file details
my @inputFiles = partnerApps::buildPackageFileList($packageFilepath, '.*');
logFileInformation(\@inputFiles, 'Input');

# Construct a list of RedPoint system files and log file details. These have some extended functionality
# my @redpointSystemFiles = partnerApps::buildPackageFileList($packageFilepath, '.rpf');
# if (@redpointSystemFiles) { logFileInformation(\@redpointSystemFiles, 'Redpoint System'); }

# Global find/replace
# globalFindReplace();

loadModel(\@inputFiles);

# Log out warning if we couldn't find any files to load
if (!@inputFiles > 0) {
  $partnerApps::logger->warn("No files were found to work on. You might want to check that out.");
}

##---------------------------------------------------------------------------
END {
  exit(partnerApps::signOff($?));
}
##---------------------------------------------------------------------------

##---------------------------------------------------------------------------
# Give script options the ol' sanity check
sub sanityCheckOptions {
  my $subName = (caller(0))[3];

  # Shell style filename expansions for things in the path like tilde or wildcards
  $packageFilepath = glob($packageFilepath);
  partnerApps::checkRequiredParm($packageFilepath, 'packageFilepath');

  $partnerApps::verbose           = $verbose;            # Set partnerApps' verbose flag to the user supplied option
  $partnerApps::fuseLogSafeOutput = $fuseLogSafeOutput;  # Set the Fuse log-safe output flag to the user supplied option

  # Check for errors before starting processing
  if ($partnerApps::logger->get_count("ERROR") > 0) {

    # Print informational message to standard output
    $partnerApps::logger->info(  "$subName There were ["
                               . $partnerApps::logger->get_count("ERROR")
                               . "] error messages detected while sanity checking options. Script is halting.");

    # Exit with a non-zero code and print usage
    pod2usage(10);
  } ## end if ($partnerApps::logger...)

  return;
} ## end sub sanityCheckOptions
##---------------------------------------------------------------------------

##---------------------------------------------------------------------------
# Print [Script Config Information] to log
sub logScriptConfig {
  $partnerApps::logger->info("[Script Config Information]");
  $partnerApps::logger->info("  script path:             [$0]");
  $partnerApps::logger->info("  packageFilepath:         [$packageFilepath]");
  $partnerApps::logger->info("  globalFindReplace:       [$globalFindReplace]");
  $partnerApps::logger->info("  outputRuleList:          [$outputRuleList]");
  $utfDisabled
    ? $partnerApps::logger->info("  utf Encoding:            [Disabled]")
    : $partnerApps::logger->info("  utf Encoding:            [Enabled]");
  $fuseLogSafeOutput
    ? $partnerApps::logger->info("  fuseLogSafeOutput:       [Enabled]")
    : $partnerApps::logger->info("  fuseLogSafeOutput:       [Disabled]");
  $testMode
    ? $partnerApps::logger->info("  testMode:                [Enabled]")
    : $partnerApps::logger->info("  testMode:                [Disabled]");
  $verbose
    ? $partnerApps::logger->info("  verbose:                 [Enabled]")
    : $partnerApps::logger->info("  verbose:                 [Disabled]");
  $partnerApps::logger->info("");

  return;
} ## end sub logScriptConfig
##---------------------------------------------------------------------------

##---------------------------------------------------------------------------
# Print [File Information] to log
sub logFileInformation {
  my ($files, $fileType) = @_;
  $partnerApps::logger->info("[$fileType File Information]");
  $partnerApps::logger->info("  filepath: [$packageFilepath]");
  for (my $i = 0; $i < @{$files}; $i++) {
    my $formattedIndex = sprintf '%4s', $i;    # Left pad index with spaces for prettier logging
    $partnerApps::logger->info("$formattedIndex:  [$files->[$i]]");
  }
  $partnerApps::logger->info("");

  return;
} ## end sub logFileInformation
##---------------------------------------------------------------------------

# ##---------------------------------------------------------------------------
# # Global find/replace of values in files
# sub globalFindReplace {
#   my $subName = (caller(0))[3];

#   if ($globalFindReplace) {
#     my $findReplaceLookup = parseFindReplaceList($globalFindReplace);

#     for my $currentFilename (@inputFiles) {
#       my $fileUpdateCount = 0;
#       if ($verbose) { $partnerApps::logger->info("$subName Processing file: [$currentFilename]") }

#       my $currentPackage = partnerApps::openAndLoadFile($currentFilename);

#       for my $currentFindReplace (@{$findReplaceLookup}) {
#         if ($verbose) {
#           $partnerApps::logger->info(  "$subName Processing find:replace: ["
#                                      . $currentFindReplace->{'find'} . ":"
#                                      . $currentFindReplace->{'replace'}
#                                      . "]");
#         } ## end if ($verbose)
#         $currentPackage =~ s/($currentFindReplace->{'find'})/$currentFindReplace->{'replace'}/g;
#         if ($1) {    # If we made changes
#           if ($verbose) {
#             $partnerApps::logger->info(  "$subName Update made for find:replace: ["
#                                        . $currentFindReplace->{'find'} . ":"
#                                        . $currentFindReplace->{'replace'}
#                                        . "]");
#           } ## end if ($verbose)
#           $fileUpdateCount++;    # Note that we made a file update
#         } ## end if ($1)
#       } ## end for my $currentFindReplace...

#       # Update the source file with the new contents if we had changes and not in testMode
#       if ($fileUpdateCount > 0) {
#         if (!$testMode) {
#           $partnerApps::logger->info("$subName Changes detected, updating [$currentFilename]");
#           partnerApps::createExportFile($currentPackage, $currentFilename, undef, $utfDisabled);
#         }
#         else {
#           $partnerApps::logger->info("$subName Running in testMode, skipping file update [$currentFilename]");
#         }
#       } ## end if ($fileUpdateCount >...)
#     } ## end for my $currentFilename...
#   } ## end if ($globalFindReplace)

#   return;
# } ## end sub globalFindReplace
# ##---------------------------------------------------------------------------

# ##---------------------------------------------------------------------------
# # Parse scalar find/replace list and return an array ref of hash refs with find/replace keys
# sub parseFindReplaceList {
#   my ($globalFindReplace) = @_;
#   my $findReplaceLookup   = [];               # Array ref of hashrefs with find/replace keys
#   my $subName             = (caller(0))[3];

#   # Parse scalar list of find/replace pairs into an array
#   my @globalFindReplace;
#   eval { @globalFindReplace = Text::ParseWords::parse_line(',', $preserveQuotes, $globalFindReplace); };    # Split list on comma
#   $partnerApps::logger->error_die(
#        "$subName Could not ParseWords globalFindReplace: '$globalFindReplace'." . "Error message from ParseWords: '$@'")
#     if $@;

#   # For each of the find/replace pairs, build a hash with find/replace key/value pair
#   for my $findReplacePair (@globalFindReplace) {
#     my ($find, $replace);
#     eval { ($find, $replace) = Text::ParseWords::parse_line(':', $preserveQuotes, $findReplacePair); };     # Split list on colon
#     $partnerApps::logger->error_die(
#                "$subName Could not ParseWords findReplace: '$findReplacePair'." . "Error message from ParseWords: '$@'")
#       if $@;

#     # Make sure we had a pair and load to our list
#     if ($find and $replace) { push @{$findReplaceLookup}, {'find' => $find, 'replace' => $replace}; }
#   } ## end for my $findReplacePair...

#   if ($verbose) {
#     $partnerApps::logger->info(
#                       "$subName List of global find:replace pairs:\n" . $partnerApps::json->encode($findReplaceLookup));
#   }

#   return $findReplaceLookup;
# } ## end sub parseFindReplaceList
# ##---------------------------------------------------------------------------

##---------------------------------------------------------------------------
# Loop over list of package files and load model info
sub loadModel {
  my ($fileList) = @_;
  my $subName = (caller(0))[3];

  # if ($outputRuleList) {

  # Parse scalar list of output rules into an array
  # my @outputRules;
  # eval { @outputRules = Text::ParseWords::parse_line(',', 0, $outputRuleList); };    # Split list on comma
  # $partnerApps::logger->error_die(
  #  "$subName Could not ParseWords outputRuleList: '$outputRuleList'." . "Error message from ParseWords: '$@'")
  # if $@;

  # Process the list of packages, one file at a time
  for my $currentFilename (@$fileList) { loadModelFile($currentFilename); }

  # } ## end if ($outputRuleList)

  return;
} ## end sub loadModel
##---------------------------------------------------------------------------

##---------------------------------------------------------------------------
# Update output rules in a package
sub loadModelFile {
  my ($currentFilename) = @_;
  my $subName = (caller(0))[3];
  my $XMLObj;    # Our XML Twig containing the package file contents
  my $fileUpdateCount = 0;    # Count of changes made to the package by this sub

  if ($verbose) { $partnerApps::logger->info("$subName Processing: [$currentFilename]") }

  # Convert plain XML text to a twig object
  eval { $XMLObj = $partnerApps::twig->parsefile($currentFilename); };
  $partnerApps::logger->error(partnerApps::objConversionErrorMsgGenerator($@)) if $@;

  # Table name
  # $partnerApps::logger->info("$XMLObj: " . partnerApps::Dumper($XMLObj));
  # my $xmlRoot   = $XMLObj->root; # this will actually be Table I think
  # my $table = $xmlRoot->first_child('Table');
  my $table     = $XMLObj->root;
  my $tableName = $table->att("name");
  $partnerApps::logger->info("tableName" . partnerApps::Dumper($tableName));

  # really only care about the table names, guids and the index info for now
  # as a stretch, grab everything so the full DDL can be generated

  # my $tableName = $XMLObj->root->first_child('Table');
  # $partnerApps::logger->info("tableName" . partnerApps::Dumper($tableName));

  # # Climb down our XML tree and hunt for output rule lists to update
  # my $rpiFile = $XMLObj->root;
  # my $details = $rpiFile->first_child('details');
  # for my $fileStorageItem ($details->children('FileStorageItem')) {
  #   my $innerDetails    = $fileStorageItem->first_child('Details');
  #   my $innerDetailsObj = $innerDetails->first_child('obj');
  #   for my $shr ($innerDetailsObj->children('shr')) {
  #     for my $shrObj ($shr->children('obj')) {
  #       my $shrObjID   = $shrObj->att("id");
  #       my $shrObjName = $shrObj->att("name");

  #       # The output rules should live here if they exist
  #       if ($shrObjID and lc($shrObjName) eq 'output_rule') {
  #         if ($verbose) {
  #           $partnerApps::logger->info("$subName Found output rule definition in [$currentFilename]");
  #         }
  #         my $shrObjP = $shrObj->first_child('p');

#         # Cleanup any old rules coming in except for the default rule
#         my $defaultOutputRuleValue = $shrObjP->att("dv");
#         for my $shrObjPcVL ($shrObjP->children('cVL')) {
#           if ($shrObjPcVL->att("cV") ne $defaultOutputRuleValue) {    # If the current value is not the default value
#             if ($verbose) {
#               $partnerApps::logger->info(
#                                        "$subName Deleting non-default output rule: [" . $shrObjPcVL->att("cV") . "]");
#             }
#             $shrObjPcVL->delete;                                      # Remove the output rule element
#             $fileUpdateCount++;                                       # Note that we made a file update
#           } ## end if ($shrObjPcVL->att("cV"...))
#         } ## end for my $shrObjPcVL ($shrObjP...)

  #         # After deleting the old rules, install the ones we got from outputRuleList
  #         for my $newOutputRule (@outputRules) {
  #           if ($verbose) { $partnerApps::logger->info("$subName Adding output rule: [" . $newOutputRule . "]"); }
  #           $shrObjP->insert_new_elt(qq(cVL cV="$newOutputRule" cVdt="System.String"));
  #           $fileUpdateCount++;                                         # Note that we made a file update
  #         }
  #       } ## end if ($shrObjID and lc($shrObjName...))
  #     } ## end for my $shrObj ($shr->children...)
  #   } ## end for my $shr ($innerDetailsObj...)
  # } ## end for my $fileStorageItem...

  # # Update the source file with the new contents if we had changes and not in testMode
  # if ($fileUpdateCount > 0) {
  #   if (!$testMode) {
  #     $partnerApps::logger->info("$subName Changes detected, updating [$currentFilename]");
  #     partnerApps::createExportFile($XMLObj->sprint, $currentFilename, undef, $utfDisabled);
  #   }
  #   else {
  #     $partnerApps::logger->info("$subName Running in testMode, skipping file update [$currentFilename]");
  #   }
  # } ## end if ($fileUpdateCount >...)

  if ($verbose) { $partnerApps::logger->info("$subName Complete: [$currentFilename]") }

  return;
} ## end sub loadModelFile
##---------------------------------------------------------------------------

##---------------------------------------------------------------------------
# Podusage

__END__

=head1 AUTHOR

Caleb Hankins - chanki

=head1 NAME

partnerApps_generify.pl

=head1 SYNOPSIS

partnerApps_generify.pl - Make environment specific files generic or vice versa

 #NOTE# Script must be ran inside of fuse or after the fuse client env has been sourced. Ex: . $HOME/fuse_local/client.env

 Options:
    f|packageFilepath           String. Directory path where package file(s) live. Defaults to current working directory.
    g|globalFindReplace         String. Global Find and Replace. If any left hand side entry in this colon separated, comma delimited find/replace list is found, replace it with the right side colon entry.
    o|outputRuleList            String. Comma delimited list of Output Rules to install into relevant packages.
    p|preserveQuotes            Flag. If set, quotes and backslashes are not removed from find/replace strings.
    utfDisabled                 Flag. If set, disables creating files with encoding(UTF-8).
    fuseLogSafeOutput           0 or 1. If 1, encodes HTML entities in logs so they can be displayed in the fuse web log viewer properly. Defaults to 1.
    t|testMode                  Flag. Skip call to create package file but print all of the other information.
    v|verbose                   Flag. Print more verbose output.
    help                        Print brief help information.
    man                         Read the manual, includes examples.

=head1 EXAMPLES

  partnerApps_generify.pl  --packageFilepath '~/partnerAppsPackages/generify/' --outputRuleList 'ACXIOM_INTERNAL,PRINT_SHOP' --globalFindReplace '#DB_HOST#:SCHEMA_GOES_HERE,\/redpoint_output_dev:DETECT_LOCATION_SOURCE_PATH_GOES_HERE'

=cut
##---------------------------------------------------------------------------

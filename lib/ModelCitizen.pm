############################################################################################
#                       (C) Copyright Acxiom Corporation 2018
#                               All Rights Reserved.
############################################################################################
#
# Script: ModelCitizen.pm
# Author: Caleb Hankins - chanki
# Date:   2018-10-17
#
# Purpose: Export Oracle Data Modeler files as json and or SQL DDL for easier consumption by other processes
#
############################################################################################
# MODIFICATION HISTORY
##----------------------------------------------------------------------------------------
# DATE        PROGRAMMER                   DESCRIPTION
##----------------------------------------------------------------------------------------
# 2018-10-17  Caleb Hankins - chanki       Initial Copy
############################################################################################

package ModelCitizen;

use warnings;
use strict;
use JSON;                         # JSON (JavaScript Object Notation) encoder/decoder
use XML::Twig;                    # A perl module for processing huge XML documents in tree mode
use Data::Dumper;                 # Stringified perl data structures, suitable for both printing and eval
use HTML::Entities;               # Encode or decode strings with HTML entities
use URI::Escape;                  # Percent-encode and percent-decode unsafe characters
use File::Path qw(make_path);     # Create directory trees
use File::Basename;               # Parse file paths into directory, filename and suffix
use Text::ParseWords;             # Parse text into an array of tokens or array of arrays
use Exporter qw(import);          # Implements default import method for modules
use experimental 'smartmatch';    # Gimme those ~~ y'all

##--------------------------------------------------------------------------
# Version info
our $VERSION = '0.0.1';           # Todo, pull this from git tag
##--------------------------------------------------------------------------

##--------------------------------------------------------------------------
# Create logger object
use Logger;
our $logger = Logger->new() or die "Cannot retrieve Logger object\n";
##--------------------------------------------------------------------------

##--------------------------------------------------------------------------
# Setup xml twig object
our $twig = XML::Twig->new('pretty_print' => 'record');
##--------------------------------------------------------------------------

##--------------------------------------------------------------------------
# Setup json object
our $json = JSON->new->pretty->allow_nonref->allow_blessed->convert_blessed->allow_unknown;
##--------------------------------------------------------------------------

##--------------------------------------------------------------------------
# Verbosity
our $verbose = 0;    # Default to not verbose
##--------------------------------------------------------------------------

##--------------------------------------------------------------------------
# Generate an error string for failed object conversions
sub objConversionErrorMsgGenerator {
  my ($errorInformation) = @_;
  my $parentName = (caller(1))[3];

  my $errMsg = "$parentName Could not create the expected obj from input. Error information: $errorInformation";

  return $errMsg;
} ## end sub objConversionErrorMsgGenerator
##--------------------------------------------------------------------------

##--------------------------------------------------------------------------
# Make sure required parm is populated
sub checkRequiredParm {
  my ($requiredParmVal, $requiredParmValName, $errMsg) = @_;
  my $parentName = (caller(1))[3];
  $requiredParmValName //= "Missing a parameter that";
  $errMsg              //= "$requiredParmValName is required.";

  # Make sure value is populated
  unless (defined($requiredParmVal) and length($requiredParmVal) > 0) { $logger->error("$parentName $errMsg"); }

  return;
} ## end sub checkRequiredParm
##--------------------------------------------------------------------------

##--------------------------------------------------------------------------
sub openAndLoadFile {
  my ($filename)   = @_;
  my $subName      = (caller(0))[3];
  my $fileContents = '';

  # Try to open our file
  open my $fileHandle, "<", $filename or $logger->croak("$subName Could not open file '$filename' $!");

  # Read file handle data stream into our file variable
  while (defined(my $line = <$fileHandle>)) {
    $fileContents .= $line;
  }

  close($fileHandle);

  if (length($fileContents) <= 0) {
    $logger->carp(
             "$subName It appears that nothing was in [$filename] Please check file and see if it meets expectations.");
  }

  return $fileContents;
} ## end sub openAndLoadFile
##--------------------------------------------------------------------------

##--------------------------------------------------------------------------
# Build and return a sorted list of package filenames
sub buildPackageFileList {
  my ($packageFilepath, $validPackageExts, $emptyFilesOk) = @_;
  my @packageFiles;        # Array of package files to import that we will build and return
  my @validPackageExts;    # Array of valid file ext patterns we will populate from $validPackageExts scalar argument
  my $subName = (caller(0))[3];

  # Convert scalar list of valid ext patterns into an array
  eval { @validPackageExts = Text::ParseWords::shellwords($validPackageExts); };
  $logger->confess(
                "$subName Could not ParseWords file ext list: '$validPackageExts'. Error message from ParseWords: '$@'")
    if $@;

  # If we just have the one file as a parm, add that to our array (if it checks out) and keep trucking
  if (-f $packageFilepath and -r $packageFilepath and (-s $packageFilepath or $emptyFilesOk))
  {                        # If this was a plain file, readable and has a non-zero size
    pushPackageFile(\@packageFiles, $packageFilepath, \@validPackageExts, $emptyFilesOk);
  }
  elsif (-d $packageFilepath and -r $packageFilepath)
  {    # Else if we got a directory as our input, fetch all valid files and add them to our package file import list
    my $dh;    # Directory Handle
    opendir($dh, $packageFilepath)
      or
      $logger->confess("$subName Could not open dir '$packageFilepath', exiting in error state. Error Message: '$!'");

    # Open the directory and recursively loop through all the entries looking for valid package files
    while (my $file = readdir($dh)) {
      chomp $file;
      if ($file ~~ /^\.{1,2}$/) { next; }    # Skip . and ..
      my $fullFile = $packageFilepath . '/' . $file;    # Construct full filepath
      push(@packageFiles, buildPackageFileList($fullFile, $validPackageExts, $emptyFilesOk));
    } ## end while (my $file = readdir...)
    closedir($dh);
  } ## end elsif (-d $packageFilepath...)
  else {    # Else we don't have anything we can work with, raise error and quit
    $logger->confess(
      "$subName Unsupported or unreadable file or directory encountered, exiting in error state. packageFilepath: '$packageFilepath'"
    );
  }

  @packageFiles = sort @packageFiles
    ; # Sort our list of files alphabetically. Dependencies between packages could be handled through alphabetic prefixes.

  return @packageFiles;
} ## end sub buildPackageFileList
##--------------------------------------------------------------------------

##--------------------------------------------------------------------------
# Vet and add package filename to array by ref if it checks out
sub pushPackageFile {
  my ($packageFiles, $packageFilepath, $validPackageExts, $emptyFilesOk)
    = @_;    # packageFiles and validPackageExts are array refs
  my $subName = (caller(0))[3];

  my $filepathParts = getFilepathParts($packageFilepath, @{$validPackageExts});

  if (    $filepathParts->{'ext'}
      and -f $packageFilepath
      and -r $packageFilepath
      and (-s $packageFilepath or $emptyFilesOk))
  {          # File has an approved extension and is actually a plain file, readable, and has a non-zero size
    push @{$packageFiles}, $packageFilepath;    # Add file to package import list by reference
  } ## end if ($filepathParts->{'ext'...})

  return;
} ## end sub pushPackageFile
##--------------------------------------------------------------------------

##--------------------------------------------------------------------------
# Take our file data and use it to create a file on the filesystem
sub createExportFile {
  my (
      $fileData,                                  # File contents to write out
      $exportFilepath,                            # Might be full file path or just dir
      $exportFilename,                            # Might be undef or just the filename
      $utfDisabled                                # Optional indicator to avoid utf-8 encoding
  ) = @_;
  my $subName            = (caller(0))[3];
  my $exportFileFullName = $exportFilename ? "${exportFilepath}/${exportFilename}" : $exportFilepath;
  my $filepathParts      = getFilepathParts($exportFileFullName);

  # Create the dir if it doesn't already exist
  eval { make_path($filepathParts->{'dirname'}) };
  $logger->confess("$subName Could not make directory: $filepathParts->{'dirname'}: $@") if $@;

  $logger->info("$subName Attempting creation of file [$exportFileFullName]");
  open my $exportFile, q{>}, $exportFileFullName
    or $logger->confess("$subName Could not open file: $exportFileFullName: $!")
    ;    # Open file, overwrite if exists, raise error if we run into trouble
  if (!$utfDisabled) { binmode($exportFile, ":encoding(UTF-8)") }
  print $exportFile $fileData;
  close($exportFile);
  $logger->info("$subName Success!");

  return;
} ## end sub createExportFile
##--------------------------------------------------------------------------

##--------------------------------------------------------------------------
# Get and return a hash ref of file name parts
sub getFilepathParts {
  my ($filename, @extList) = @_;
  my $subName = (caller(0))[3];

  my ($name, $dirname, $ext);
  eval { ($name, $dirname, $ext) = File::Basename::fileparse($filename, @extList); };
  $logger->confess("$subName Could not fileparse '$filename'. Error message from fileparse: '$@'") if $@;

  return {
          'dirname'  => $dirname,
          'name'     => $name,
          'ext'      => $ext,
          'basename' => $name . $ext,
          'fullpath' => $dirname . $name . $ext
  };
} ## end sub getFilepathParts
##--------------------------------------------------------------------------

##--------------------------------------------------------------------------
# Get unique array curtesy of perlfaq4
sub getUniqArray {
  my (@array) = @_;
  my %seen = ();
  my @unique = grep { !$seen{$_}++ } @array;
  return @unique;
} ## end sub getUniqArray
##--------------------------------------------------------------------------

##--------------------------------------------------------------------------
# Print sign off message and return a status code
sub signOff {
  my (
      $statusCode,      # Optional $? (statusCode)
      $inErrorCount,    # Optional supplemental error count if not using logger
      $inWarnCount      # Optional supplemental warning count if not using logger
  ) = @_;
  $statusCode   //= 0;    # Default to 0 if not supplied
  $inErrorCount //= 0;    # Default to 0 if not supplied
  $inWarnCount  //= 0;    # Default to 0 if not supplied
  my $parentName = (caller(1))[3];    # Calling sub name
  $parentName //= 'main::main';       # Default parentName if we couldn't find one

  my $errorCount   = $logger->get_count("ERROR") + $inErrorCount;    # Combine logger's count and the supplied count
  my $warningCount = $logger->get_count("WARN") + $inWarnCount;      # Combine logger's count and the supplied count

  if (!$statusCode && $errorCount) { $statusCode += $errorCount; }   # Set non-zero rc if we detected logger errors
  if ($statusCode && !$errorCount) { $errorCount++; }                # Increment error counter if logger didn't catch it

  # If we got a value >255, assume we were passed a wait call exit status and right shift by 8 to get the return code
  my $statusCodeSmall = $statusCode;
  if ($statusCode > 255) { $statusCodeSmall = $statusCode >> 8; }
  if ($statusCode > 0 && ($statusCodeSmall % 256) == 0) { $statusCodeSmall = 1; }

  # Generate an informative sign off message for the log
  my $signOffMsg = "$parentName Exiting with return code of $statusCodeSmall";
  $signOffMsg .= ($statusCode != $statusCodeSmall) ? ", wait return code of $statusCode. " : ". ";
  $signOffMsg .= "$errorCount error(s), ";
  $signOffMsg .= "$warningCount warning(s) reported.";

  if   ($statusCode) { $logger->error($signOffMsg); }    # If we had a bad return code, log an error
  else               { $logger->info($signOffMsg); }     # Else log the sign off message as info

  return $statusCodeSmall;
} ## end sub signOff
##--------------------------------------------------------------------------

1;

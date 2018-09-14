############################################################################################
#                       (C) Copyright Acxiom Corporation 2017
#                               All Rights Reserved.
############################################################################################
#
# Script: partnerApps.pm
# Author: Caleb Hankins - chanki
# Date:   2017-07-24
#
# Purpose: partnerApps helper code for acxiom integration
#
############################################################################################
# MODIFICATION HISTORY
##----------------------------------------------------------------------------------------
# DATE        PROGRAMMER                   DESCRIPTION
##----------------------------------------------------------------------------------------
# 2017-07-24  Caleb Hankins - chanki       Initial Copy
############################################################################################

package partnerApps;

use warnings;
use strict;
use JSON;                        # JSON (JavaScript Object Notation) encoder/decoder
use XML::Simple;                 # An API for simple XML files
use XML::Twig;                   # A perl module for processing huge XML documents in tree mode
use LWP::UserAgent;              # Web user agent class
use Data::Dumper;                # Stringified perl data structures, suitable for both printing and eval
use HTML::Entities;              # Encode or decode strings with HTML entities
use URI::Escape;                 # Percent-encode and percent-decode unsafe characters
use File::Path qw(make_path);    # Create directory trees
use File::Basename;              # Parse file paths into directory, filename and suffix
use Text::ParseWords;            # Parse text into an array of tokens or array of arrays
use Exporter qw(import);         # Implements default import method for modules

our @EXPORT_OK = qw(
  Dumper import
  $logger 
  $ua $xml $twig $json $verbose $fuseLogSafeOutput
  getFuseLogSafeOutput apiRespErrorMsgGenerator objConversionErrorMsgGenerator
  checkRequiredParm setLoginCredentials signOff
  openAndLoadFile pushPackageFile buildPackageFileList createExportFile getFilepathParts
  getUniqArray runSQL deriveWithDBConnect
);

# ##--------------------------------------------------------------------------
# # Access the ASC standard library
# eval { require ASC::ASC; ASC::ASC->import(); 1; }
#   or die "$0 [FATAL] Could not access the ASC perl modules.\n"
#   . "This script was designed to be ran from fuse or after the fuse client env has been sourced.\n"
#   . "Please check this out:\n$@";
# ##--------------------------------------------------------------------------

##--------------------------------------------------------------------------
# Create logger object
# our $logger = ASC::Logger->new() or die "Cannot retrieve Logger object\n";
use  Logger;
our $logger = Logger->new() or die "Cannot retrieve Logger object\n";
##--------------------------------------------------------------------------

##--------------------------------------------------------------------------
# Create ASC object
# our $asc = ASC::ASC->new() or $logger->error_die("Cannot retrieve ASC object.");
##--------------------------------------------------------------------------

##--------------------------------------------------------------------------
# Setup user agent object
our $ua = LWP::UserAgent->new;
if (LWP::UserAgent->VERSION >= 6.00) {
  $ua->ssl_opts(verify_hostname => 0);
}   # Workaround for Error: Can't connect to <host>:443 (certificate verify failed). LWP < 6.0 does not support ssl_opts
##--------------------------------------------------------------------------

##--------------------------------------------------------------------------
# Setup xml simple object
our $xml = XML::Simple->new;
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
# Log output in a way that it will be viewable in fuse web logs
our $fuseLogSafeOutput = 1;    # Default to make logs 'fuse safe'
##--------------------------------------------------------------------------

##--------------------------------------------------------------------------
# Generate a fuseLogSafeOutput string if the fuseLogSafeOutput variable is set. Else return the original string
sub getFuseLogSafeOutput {
  my ($input) = @_;
  return (($fuseLogSafeOutput) ? HTML::Entities::encode_entities($input) : $input);
}
##--------------------------------------------------------------------------

##--------------------------------------------------------------------------
# Generate an error string using a LWP::UserAgent request response
sub apiRespErrorMsgGenerator {
  my ($APIResp) = @_;
  my $parentName = (caller(1))[3];

  # If fuseLogSafeOutput option is set, sanitize strings so they can be viewed in fuse web logs
  my $respStrFull        = getFuseLogSafeOutput($json->encode($APIResp));
  my $respDecodedContent = getFuseLogSafeOutput($APIResp->decoded_content);
  my $APIResponseCode    = $APIResp->code;
  my $APIResponseMessage = $APIResp->message;

  my $errMsg = "An error has been detected in $parentName!\n";
  if ($verbose) { $errMsg .= "$parentName full request response: [" . $respStrFull . "]\n"; }
  $errMsg .= "$parentName error code:            [$APIResponseCode]\n";
  $errMsg .= "$parentName error message:         [$APIResponseMessage]\n";
  $errMsg .= "$parentName decoded_content:       [$respDecodedContent]\n";
  return $errMsg;
} ## end sub apiRespErrorMsgGenerator
##--------------------------------------------------------------------------

##--------------------------------------------------------------------------
# Generate an error string for failed object conversions
sub objConversionErrorMsgGenerator {
  my ($errorInformation) = @_;
  my $parentName = (caller(1))[3];

  # If fuseLogSafeOutput option is set, sanitize strings so they can be viewed in fuse web logs
  $errorInformation = getFuseLogSafeOutput($errorInformation);

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
# Check and munge login credentials. If fuseConnect is specified, glean login details from fuse and ship back to caller by reference
# sub setLoginCredentials {
#   my ($baseURL, $username, $password, $clientName, $fuseConnect)
#     = @_;    # These should all be passed by ref so we can update them if we need to.
#   my $credNotPopulatedErrorMsg = "is a required parameter.";
#   my $subName                  = (caller(0))[3];

#   # If we got a fuse style connect string as an input option, try to retrieve login info from fuse
#   if (defined($$fuseConnect) and length($$fuseConnect) > 0) {
#     $credNotPopulatedErrorMsg = "was not populated after resolving fuseConnect. Please check fuseConnect config.";
#     my $schemaASC;
#     eval { $schemaASC = $asc->schema($$fuseConnect); };
#     $logger->error(
#       "$subName Could not create ASC Schema object for fuseConnect Alias '$$fuseConnect' due to the following error:\n$@\n"
#     ) if $@;

#     # If we were able to create an ASC schema object, try to glean login details from it
#     if ($schemaASC) {
#       my $db_user = $schemaASC->{db_user};
#       my $db_pw   = ASC::Fuse::DecryptPw($schemaASC->{db_pw});
#       my $db_name = $schemaASC->{db_name};
#       my $db_host = $schemaASC->{db_host};
#       my $db_port = $schemaASC->{db_port};

#       # If the fuse db connect specified a port, append that to the URL
#       if ((defined($db_port) and length($db_port) > 0)) { $db_host .= ":" . $db_port; }

#       # Use fuseConnect values unless they were overridden by another command line option
#       $$username   = (defined $$username   and length($$username))   ? $$username   : $db_user;
#       $$password   = (defined $$password   and length($$password))   ? $$password   : $db_pw;
#       $$clientName = (defined $$clientName and length($$clientName)) ? $$clientName : $db_name;
#       $$baseURL    = (defined $$baseURL    and length($$baseURL))    ? $$baseURL    : $db_host;
#     } ## end if ($schemaASC)
#   } ## end if (defined($$fuseConnect...))

#   # Sanity check login details after munging
#   checkRequiredParm($$username,   'username',   'username ' . $credNotPopulatedErrorMsg);
#   checkRequiredParm($$password,   'password',   'password ' . $credNotPopulatedErrorMsg);
#   checkRequiredParm($$clientName, 'clientName', 'clientName ' . $credNotPopulatedErrorMsg);
#   checkRequiredParm($$baseURL,    'baseURL',    'baseURL ' . $credNotPopulatedErrorMsg);

#   # Munge the baseURL and prepend transport protocol if missing
#   if (index($$baseURL, 'http') == -1) {
#     $$baseURL = "https://" . $$baseURL;
#   }    # Check for transport protocol and default to https if not specified

#   return;
# } ## end sub setLoginCredentials
# ##--------------------------------------------------------------------------

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
    while (my $file = readdir($dh))
    {          # Open the directory and loop through all the entries looking for valid package files
      chomp $file;
      if ($file ~~ /^\.{1,2}$/) {next;} # Skip . and ..
      my $fullFile = $packageFilepath . '/' . $file;    # Construct full filepath
      $logger->info("$subName $fullFile"); # todo, debug remove

      # If this is a file, push it
      # pushPackageFile(\@packageFiles, $fullFile, \@validPackageExts, $emptyFilesOk);

      # Recurse
      my @subDirFiles = buildPackageFileList($fullFile, $validPackageExts, $emptyFilesOk);
      my $cntSubDir = @subDirFiles;
      $logger->info("$subName cntSubDir count is now $cntSubDir"); # todo, debug remove
      # @packageFiles = splice (@packageFiles, buildPackageFileList($fullFile, $validPackageExts, $emptyFilesOk));
      push (@packageFiles,@subDirFiles); 
      my $cnt = @packageFiles;
      $logger->info("$subName packageFiles count is now $cnt"); # todo, debug remove

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

# ##--------------------------------------------------------------------------
# # Run sql for a specified fuse connect and return the results in an array ref
# sub runSQL {
#   my ($fuseConnect, $inputSQL) = @_;
#   my $dbh = $asc->dbh($fuseConnect)
#     or $logger->confess("Unable to generate dbh from asc object targeting $fuseConnect");
#   return $dbh->selectall_arrayref($inputSQL);
# } ## end sub runSQL
# ##--------------------------------------------------------------------------

# ##--------------------------------------------------------------------------
# # Run sql for a specified fuse connect and return the first result in the first row
# # This should be like fuse's derive with db connect but you can specifiy the connect at runtime
# sub deriveWithDBConnect {
#   my ($fuseConnect, $inputSQL) = @_;
#   my @results = @{runSQL($fuseConnect, $inputSQL)};
#   return scalar(${$results[0]}[0]);
# }
# ##--------------------------------------------------------------------------

1;

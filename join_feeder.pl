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
my $outputFile        = '';
my $outputFileJSON    = '';
my $globalFindReplace = '';
my $preserveQuotes    = '';       # Default to stripping quotes from find/replace strings
my $utfDisabled       = '';       # Default to creating files with encoding(UTF-8)
my $fuseLogSafeOutput = 1;        # Default to make log output 'Fuse safe'
my $testMode          = '';
my $verbose           = '';

my $rc = GetOptions(
  'f|packageFilepath=s'   => \$packageFilepath,
  'o|outputFile=s'        => \$outputFile,
  'outputFileJSON=s'      => \$outputFileJSON,
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
my @inputFiles = partnerApps::buildPackageFileList($packageFilepath, '.xml');
logFileInformation(\@inputFiles, 'Input');

my $model = loadModel(\@inputFiles);
if ($outputFileJSON) { partnerApps::createExportFile($partnerApps::json->encode($model), $outputFileJSON); }

my $sql = getSQL($model);
if ($outputFile) { partnerApps::createExportFile($sql, $outputFile); }

# $partnerApps::logger->info($partnerApps::json->encode($info)); # todo, debugging

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
  $partnerApps::logger->info("  outputFile:          [$outputFile]");
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

##---------------------------------------------------------------------------
# Loop over list of model files and load model info
sub loadModel {
  my ($fileList) = @_;
  my $subName = (caller(0))[3];

  # Process the list of packages, one file at a time
  my $tablesInfo = [];
  for my $currentFilename (@$fileList) {
    my $modelFile = loadModelFile($currentFilename);
    if ($modelFile) { push(@$tablesInfo, loadModelFile($currentFilename)); }
  }
  return $tablesInfo;
} ## end sub loadModel
##---------------------------------------------------------------------------

##---------------------------------------------------------------------------
# load a model file
sub loadModelFile {
  my ($currentFilename) = @_;
  my $subName = (caller(0))[3];
  my $XMLObj;    # Our XML Twig containing the package file contents
  my $modelFile;

  if ($verbose) { $partnerApps::logger->info("$subName Processing: [$currentFilename]") }

  # Convert plain XML text to a twig object
  eval { $XMLObj = $partnerApps::twig->parsefile($currentFilename); };
  $partnerApps::logger->error(partnerApps::objConversionErrorMsgGenerator($@)) if $@;

  # Handle files based on type. Could also do this based on internal metadata in the file instead of the path
  my $fileType = '';
  if    ($currentFilename ~~ /table/)      { $fileType = 'table'; }
  elsif ($currentFilename ~~ /foreignkey/) { $fileType = 'foreignkey'; }
  else                                     { $fileType = 'unknown'; }
  $partnerApps::logger->info("$subName detected as a $fileType fileType: [$currentFilename]");

  if ($fileType eq 'table')      { $modelFile = loadModelFileTable($XMLObj); }
  if ($fileType eq 'foreignkey') { $modelFile = loadModelFileForeignKey($XMLObj); }

  if ($verbose) { $partnerApps::logger->info("$subName Complete: [$currentFilename]") }

  return $modelFile;
} ## end sub loadModelFile
##---------------------------------------------------------------------------

##---------------------------------------------------------------------------
# Load table info from an XML object and return a hash ref of handy info
sub loadModelFileTable () {
  my ($XMLObj) = @_;
  my $subName = (caller(0))[3];

  # Table info
  my $tableInfo   = {};
  my $tableXMLObj = $XMLObj->root;
  $tableInfo->{type}        = 'table';
  $tableInfo->{name}        = $tableXMLObj->att("name");
  $tableInfo->{id}          = $tableXMLObj->att("id");
  $tableInfo->{createdBy}   = $tableXMLObj->first_child("createdBy")->inner_xml;
  $tableInfo->{createdTime} = $tableXMLObj->first_child("createdTime")->inner_xml;

  # Column info
  my $columns = $tableXMLObj->first_child("columns");
  $tableInfo->{columns} = [];
  for my $column ($columns->children('Column')) {

    my $colInfo = {name => $column->att('name'), id => $column->att('id')};

    if (defined $column->first_child('associations')) {
      my $colAssociations = [];
      for my $colAssociation ($column->first_child('associations')->children('colAssociation')) {
        push(
             @{$colAssociations},
             {
              fkAssociation  => $colAssociation->att('fkAssociation'),
              referredColumn => $colAssociation->att('referredColumn')
             }
        );
      } ## end for my $colAssociation ...
      $colInfo->{associations} = $colAssociations;
    } ## end if (defined $column->first_child...)

    if (defined $column->first_child('logicalDatatype')) {
      $colInfo->{"logicalDatatype"} = $column->first_child("logicalDatatype")->inner_xml;
    }
    if (defined $column->first_child('ownDataTypeParameters')) {
      $colInfo->{"ownDataTypeParameters"} = $column->first_child("ownDataTypeParameters")->inner_xml;
    }
    if (defined $column->first_child('autoIncrementCycle')) {
      $colInfo->{"autoIncrementCycle"} = $column->first_child("autoIncrementCycle")->inner_xml;
    }
    if (defined $column->first_child('createdTime')) {
      $colInfo->{"createdTime"} = $column->first_child("createdTime")->inner_xml;
    }
    if (defined $column->first_child('createdBy')) {
      $colInfo->{"createdBy"} = $column->first_child("createdBy")->inner_xml;
    }
    if (defined $column->first_child('useDomainConstraints')) {
      $colInfo->{"useDomainConstraints"} = $column->first_child("useDomainConstraints")->inner_xml;
    }
    if (defined $column->first_child('nullsAllowed')) {
      $colInfo->{"nullsAllowed"} = $column->first_child("nullsAllowed")->inner_xml;
    }
    if (defined $column->first_child('dataTypeSize')) {
      $colInfo->{"dataTypeSize"} = $column->first_child("dataTypeSize")->inner_xml;
    }

    push(@{$tableInfo->{columns}}, $colInfo);
  } ## end for my $column ($columns...)

  # Index info
  my $indexes = $tableXMLObj->first_child("indexes");
  if (defined $indexes) {

    $tableInfo->{indexes} = [];
    for my $index ($indexes->children('ind_PK_UK')) {
      $partnerApps::logger->info("index name:" . $index->att("name"));

      my $indexInfo = {name => $index->att("name"), id => $index->att("id")};

      # looks like FKs don't have indexColumnUsage
      if (defined $index->first_child("indexState")) {
        $indexInfo->{indexState} = $index->first_child("indexState")->inner_xml;
      }
      if (defined $index->first_child("pk")) { $indexInfo->{pk} = $index->first_child("pk")->inner_xml; }
      if (defined $index->first_child("indexColumnUsage")) {
        my $indexColumnUsage = [];
        for my $colUsage ($index->first_child("indexColumnUsage")->children('colUsage')) {
          push(@$indexColumnUsage, $colUsage->att("columnID"));
        }
        $indexInfo->{indexColumnUsage} = $indexColumnUsage;
      } ## end if (defined $index->first_child...)
      push(@{$tableInfo->{indexes}}, $indexInfo);
    } ## end for my $index ($indexes...)
  } ## end if (defined $indexes)

  if ($verbose) { $partnerApps::logger->info("tableInfo:\n" . partnerApps::Dumper($tableInfo)); }

  return $tableInfo;
} ## end sub loadModelFileTable
##---------------------------------------------------------------------------

##---------------------------------------------------------------------------
# Load Foreign Key info from an XML object and return a hash ref of handy info
sub loadModelFileForeignKey () {
  my ($XMLObj) = @_;
  my $subName = (caller(0))[3];

  my $fkInfo   = {};
  my $fkXMLObj = $XMLObj->root;
  $fkInfo->{type}      = 'foreignkey';
  $fkInfo->{name}      = $fkXMLObj->att("name");
  $fkInfo->{id}        = $fkXMLObj->att("id");
  $fkInfo->{keyObject} = $fkXMLObj->first_child("keyObject")->inner_xml;

  if (defined $fkXMLObj->first_child("containerWithKeyObject")) {
    $fkInfo->{containerWithKeyObject} = $fkXMLObj->first_child("containerWithKeyObject")->inner_xml;
  }
  if (defined $fkXMLObj->first_child("localFKIndex")) {
    $fkInfo->{localFKIndex} = $fkXMLObj->first_child("localFKIndex")->inner_xml;
  }
  if (defined $fkXMLObj->first_child("referredTableID")) {
    $fkInfo->{referredTableID} = $fkXMLObj->first_child("referredTableID")->inner_xml;
  }
  if (defined $fkXMLObj->first_child("referredKeyID")) {
    $fkInfo->{referredKeyID} = $fkXMLObj->first_child("referredKeyID")->inner_xml;
  }

  if ($verbose) { $partnerApps::logger->info("fkName\n" . partnerApps::Dumper($fkInfo)); }

  return $fkInfo;
} ## end sub loadModelFileForeignKey
##---------------------------------------------------------------------------

##---------------------------------------------------------------------------
# Generate sql from modelFile info
sub getSQL {
  my ($modelFiles) = @_;
  my $subName      = (caller(0))[3];
  my $sql          = '';

  for my $modelFile (@$modelFiles) {
    $partnerApps::logger->info("modelFile name: [$modelFile->{name}] type: [$modelFile->{type}]");
    if ($modelFile->{type} eq 'table') {
      for my $index (@{$modelFile->{indexes}}) {
        $partnerApps::logger->info("index name:" . $index->{name});
        if (defined $index->{pk}) { $sql .= getSQLPrimaryKey($index, $modelFile, $modelFiles); }
      }
    } ## end if ($modelFile->{type}...)
    elsif ($modelFile->{type} eq "foreignkey") {
      if (defined $modelFile->{containerWithKeyObject}) { $sql .= getSQLForeignKey($modelFile, $modelFiles); }
    }
  } ## end for my $modelFile (@$modelFiles)

  return $sql;

} ## end sub getSQL
##---------------------------------------------------------------------------

##---------------------------------------------------------------------------
sub getSQLPrimaryKey {
  my ($index, $modelFile, $modelFiles) = @_;
  my $subName     = (caller(0))[3];
  my $sql         = '';
  my $columnNames = [];

  $partnerApps::logger->info("index:" . $index->{name} . " detected as a pk");

  # look up this index's column names using the guids in indexColumnUsage
  for my $columnID (@{$index->{indexColumnUsage}}) {
    $partnerApps::logger->info("  columnID:" . $columnID);
    push(@$columnNames, getColumnNameFromID($modelFiles, $columnID));
  }
  $partnerApps::logger->info("  column names for index:" . $partnerApps::json->encode($columnNames));
  my $fieldList = join ',', @$columnNames;
  $sql .= qq{ ALTER TABLE $modelFile->{name} ADD CONSTRAINT $index->{name} PRIMARY KEY ( $fieldList ); \n};

  return $sql;
} ## end sub getSQLPrimaryKey
##---------------------------------------------------------------------------

##---------------------------------------------------------------------------
sub getSQLForeignKey {
  my ($modelFile, $modelFiles) = @_;
  my $subName     = (caller(0))[3];
  my $sql         = '';
  my $columnNames = [];

  my $hostTableID   = $modelFile->{containerWithKeyObject};
  my $referredTableID = $modelFile->{referredTableID};

  return $sql;
} ## end sub getSQLForeignKey
##---------------------------------------------------------------------------

##---------------------------------------------------------------------------
# Generate human readable column name using guid lookup and an array ref pointed to the table hashes
sub getColumnNameFromID {
  my ($tables, $columnID) = @_;
  my $subName = (caller(0))[3];

  for my $table (@$tables) {
    for my $column (@{$table->{columns}}) {
      if ($column->{id} eq $columnID) { return $column->{name}; }
    }
  }

  my $error = "ERR_COULD_NOT_RESOLVE_FIELD_NAME_FOR_ID_${columnID}";
  $partnerApps::logger->error("$subName $error");
  return "ERR_COULD_NOT_RESOLVE_FIELD_NAME_FOR_ID_${columnID}";
} ## end sub getColumnNameFromID
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
    o|outputFile            String. Comma delimited list of Output Rules to install into relevant packages.
    p|preserveQuotes            Flag. If set, quotes and backslashes are not removed from find/replace strings.
    utfDisabled                 Flag. If set, disables creating files with encoding(UTF-8).
    fuseLogSafeOutput           0 or 1. If 1, encodes HTML entities in logs so they can be displayed in the fuse web log viewer properly. Defaults to 1.
    t|testMode                  Flag. Skip call to create package file but print all of the other information.
    v|verbose                   Flag. Print more verbose output.
    help                        Print brief help information.
    man                         Read the manual, includes examples.

=head1 EXAMPLES

  partnerApps_generify.pl  --packageFilepath '~/partnerAppsPackages/generify/' --outputFile 'ACXIOM_INTERNAL,PRINT_SHOP' --globalFindReplace '#DB_HOST#:SCHEMA_GOES_HERE,\/redpoint_output_dev:DETECT_LOCATION_SOURCE_PATH_GOES_HERE'

=cut
##---------------------------------------------------------------------------

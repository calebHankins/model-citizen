#!/usr/bin/perl
#/*#########################################################################################
#                       (C) Copyright Acxiom Corporation 2018
#                               All Rights Reserved.
############################################################################################
#
# Script: model_citizen.pl
# Author: Caleb Hankins - chanki
# Date:   2018-09-13
#
# Purpose: Export Oracle Data Modeler files as json and or SQL DDL for easier consumption by other processes
#
############################################################################################
# MODIFICATION HISTORY
##-----------------------------------------------------------------------------------------
# DATE        PROGRAMMER                   DESCRIPTION
##-----------------------------------------------------------------------------------------
# 2018-09-13  Caleb Hankins - chanki       Initial Copy
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
my $modelFilepath     = cwd();    # Default dir to current working dir if no path is specified
my $outputFileSQL     = '';
my $outputFileJSON    = '';
my $globalFindReplace = '';
my $preserveQuotes    = '';       # Default to stripping quotes from find/replace strings
my $utfDisabled       = '';       # Default to creating files with encoding(UTF-8)
my $webLogSafeOutput  = 0;        # Default to not escape html entities when printing logs
my $testMode          = '';
my $verbose           = '';

my $rc = GetOptions(
  'f|modelFilepath=s'            => \$modelFilepath,
  'o|outputFile|outputFileSQL=s' => \$outputFileSQL,
  'outputFileJSON=s'             => \$outputFileJSON,
  'g|globalFindReplace=s'        => \$globalFindReplace,
  'p|preserveQuotes'             => \$preserveQuotes,
  'utfDisabled'                  => \$utfDisabled,
  'webLogSafeOutput=s'           => \$webLogSafeOutput,

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
$partnerApps::logger->info("Opening data model from [$modelFilepath]...");
my @inputFiles = partnerApps::buildPackageFileList($modelFilepath, '.xml');
if ($verbose) { logFileInformation(\@inputFiles, 'Input'); }
my $inputFileCnt = @inputFiles;
$partnerApps::logger->info("[$inputFileCnt] files have been identified for analysis.");

$partnerApps::logger->info("Parsing data model files loaded from from [$modelFilepath]...");
my $model = loadModel(\@inputFiles);

if ($outputFileJSON) {
  $partnerApps::logger->info("Exporting data model as json to [$outputFileJSON]...");
  partnerApps::createExportFile($partnerApps::json->encode($model), $outputFileJSON);
}

if ($outputFileSQL) {
  $partnerApps::logger->info("Exporting data model as sql to [$outputFileSQL]...");
  my $sql = getSQL($model);
  partnerApps::createExportFile($sql, $outputFileSQL);
}

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
  $modelFilepath = glob($modelFilepath);
  partnerApps::checkRequiredParm($modelFilepath, 'modelFilepath');

  $partnerApps::verbose           = $verbose;             # Set partnerApps' verbose flag to the user supplied option
  $partnerApps::fuseLogSafeOutput = $webLogSafeOutput;    # Set the web log-safe output flag to the user supplied option

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
  $partnerApps::logger->info("  modelFilepath:           [$modelFilepath]");
  $partnerApps::logger->info("  outputFileSQL:           [$outputFileSQL]");
  $partnerApps::logger->info("  outputFileJSON:          [$outputFileJSON]");

  $webLogSafeOutput
    ? $partnerApps::logger->info("  webLogSafeOutput:        [Enabled]")
    : $partnerApps::logger->info("  webLogSafeOutput:        [Disabled]");
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
  $partnerApps::logger->info("  filepath: [$modelFilepath]");
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
    if ($modelFile) { push(@$tablesInfo, $modelFile); }
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
  if ($verbose) { $partnerApps::logger->info("$subName detected as a $fileType fileType: [$currentFilename]"); }

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
      if ($verbose) { $partnerApps::logger->info("$subName index name:" . $index->att("name")); }

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

  if ($verbose) { $partnerApps::logger->info("$subName tableInfo:\n" . partnerApps::Dumper($tableInfo)); }

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
  $fkInfo->{type}                   = 'foreignkey';
  $fkInfo->{name}                   = $fkXMLObj->att("name");
  $fkInfo->{id}                     = $fkXMLObj->att("id");
  $fkInfo->{containerWithKeyObject} = $fkXMLObj->att("containerWithKeyObject");
  $fkInfo->{localFKIndex}           = $fkXMLObj->att("localFKIndex");
  $fkInfo->{keyObject}              = $fkXMLObj->first_child("keyObject")->inner_xml;

  if (defined $fkXMLObj->first_child("referredTableID")) {
    $fkInfo->{referredTableID} = $fkXMLObj->first_child("referredTableID")->inner_xml;
  }
  if (defined $fkXMLObj->first_child("referredKeyID")) {
    $fkInfo->{referredKeyID} = $fkXMLObj->first_child("referredKeyID")->inner_xml;
  }

  if ($verbose) { $partnerApps::logger->info("$subName fkName\n" . partnerApps::Dumper($fkInfo)); }

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
    if ($verbose) {
      $partnerApps::logger->info("$subName modelFile name: [$modelFile->{name}] type: [$modelFile->{type}]");
    }
    if ($modelFile->{type} eq 'table') {
      for my $index (@{$modelFile->{indexes}}) {
        if ($verbose) { $partnerApps::logger->info("$subName index name:" . $index->{name}); }
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
  my $subName = (caller(0))[3];

  if ($verbose) { $partnerApps::logger->info("$subName index:" . $index->{name} . " detected as a pk"); }
  my $fieldList = getFieldListFromIndex($index, $modelFile, $modelFiles);
  return qq{ ALTER TABLE $modelFile->{name} ADD CONSTRAINT $index->{name} PRIMARY KEY ( $fieldList ); \n};
} ## end sub getSQLPrimaryKey
##---------------------------------------------------------------------------

##---------------------------------------------------------------------------
# Return index based on ID
sub getIndexFromID {
  my ($tables, $indexID) = @_;
  my $subName = (caller(0))[3];

  for my $table (@$tables) {
    for my $index (@{$table->{indexes}}) {
      if ($index->{id} eq $indexID) { return $index; }
    }
  }

  my $error = "ERR_COULD_NOT_RESOLVE_INDEX_FOR_ID_${indexID}";
  $partnerApps::logger->error("$subName $error");
  return "ERR_COULD_NOT_RESOLVE_INDEX_FOR_ID_${indexID}";
} ## end sub getIndexFromID
##---------------------------------------------------------------------------

##---------------------------------------------------------------------------
sub getFieldListFromIndex {
  my ($index, $modelFile, $modelFiles) = @_;
  my $columnNames = getColumnNamesFromIndex($index, $modelFile, $modelFiles);
  return join ',', @$columnNames;
}
##---------------------------------------------------------------------------

##---------------------------------------------------------------------------
sub getColumnNamesFromIndex {
  my ($index, $modelFile, $modelFiles) = @_;
  my $subName     = (caller(0))[3];
  my $columnNames = [];
  for my $columnID (@{$index->{indexColumnUsage}}) { push(@$columnNames, getColumnNameFromID($modelFiles, $columnID)); }
  return $columnNames;
} ## end sub getColumnNamesFromIndex
##---------------------------------------------------------------------------

##---------------------------------------------------------------------------
sub getSQLForeignKey {
  my ($modelFile, $modelFiles) = @_;
  my $subName     = (caller(0))[3];
  my $sql         = '';
  my $columnNames = [];

  my $hostTableID     = $modelFile->{containerWithKeyObject};
  my $hostKeyID       = $modelFile->{keyObject};
  my $referredTableID = $modelFile->{referredTableID};
  my $referredKeyID   = $modelFile->{referredKeyID};

  # Need to convert these index IDs to index objects
  my $hostKeyIndex     = getIndexFromID($modelFiles, $hostKeyID);
  my $referredKeyIndex = getIndexFromID($modelFiles, $referredKeyID);

  # Convert host table id to human name
  my $hostTableName = getTableNameFromID($modelFiles, $hostTableID);

  # Convert host key to human key field list
  my $hostKeyFieldList = getFieldListFromIndex($hostKeyIndex, $modelFile, $modelFiles);

  # Convert referred table id to human name
  my $referredTableName = getTableNameFromID($modelFiles, $referredTableID);

  # Convert referred key to human key field list
  my $referredKeyFieldList = getFieldListFromIndex($referredKeyIndex, $modelFile, $modelFiles);

  $sql = qq{
            ALTER TABLE $hostTableName ADD CONSTRAINT $modelFile->{name} FOREIGN KEY ( $hostKeyFieldList )
                    REFERENCES $referredTableName ( $referredKeyFieldList );  
  };

  if ($verbose) { $partnerApps::logger->info("$subName \$sql:\n $sql"); }

  return $sql;
} ## end sub getSQLForeignKey
##---------------------------------------------------------------------------

##---------------------------------------------------------------------------
# Generate human readable column name using guid lookup
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
# Generate human readable table name using guid lookup
sub getTableNameFromID {
  my ($tables, $tableID) = @_;
  my $subName = (caller(0))[3];

  for my $table (@$tables) {
    if ($table->{id} eq $tableID) { return $table->{name}; }
  }

  my $error = "ERR_COULD_NOT_RESOLVE_TABLE_NAME_FOR_ID_${tableID}";
  $partnerApps::logger->error("$subName $error");
  return "ERR_COULD_NOT_RESOLVE_TABLE_NAME_FOR_ID_${tableID}";
} ## end sub getTableNameFromID
##---------------------------------------------------------------------------

##---------------------------------------------------------------------------
# Podusage

__END__

=head1 AUTHOR

Caleb Hankins - chanki

=head1 NAME

model_citizen.pl

=head1 SYNOPSIS

Export Oracle Data Modeler files as json and or SQL DDL for easier consumption by other processes 

 Options:
    f|modelFilepath             String. Directory path where data model lives. Defaults to current working directory.
    o|outputFile|outputFileSQL  String. Output file path for SQL DDL file built off the model.
    outputFileJSON              String. Output file path for json file built off the model.
    webLogSafeOutput            0 or 1. If 1, encodes HTML entities in logs so they can be displayed in a web log viewer properly. Defaults to 0.
    t|testMode                  Flag. Skip call to create output file(s) but print all of the other information.
    v|verbose                   Flag. Print more verbose output.
    help                        Print brief help information.
    man                         Read the manual, includes examples.

=head1 EXAMPLES

  perl model_citizen.pl  --outputFileSQL ./scratch/ddl.sql --outputFileJSON ./scratch/model.json --modelFilepath C:\git\datamodels\MY_AWESOME_DATA_MODEL\

=cut
##---------------------------------------------------------------------------

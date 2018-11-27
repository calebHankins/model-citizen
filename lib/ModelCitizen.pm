############################################################################################
#                       (C) Copyright 2018 Acxiom LLC
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
use JSON;                        # JSON (JavaScript Object Notation) encoder/decoder
use XML::Twig;                   # A perl module for processing huge XML documents in tree mode
use Data::Dumper;                # Stringified perl data structures, suitable for both printing and eval
use HTML::Entities;              # Encode or decode strings with HTML entities
use URI::Escape;                 # Percent-encode and percent-decode unsafe characters
use File::Path qw(make_path);    # Create directory trees
use File::Basename;              # Parse file paths into directory, filename and suffix
use Text::ParseWords;            # Parse text into an array of tokens or array of arrays
use Exporter qw(import);         # Implements default import method for modules
use Time::Piece;                 # Object Oriented time objects
no if $] >= 5.017011, warnings => 'experimental::smartmatch';    # Suppress smartmatch warnings

##--------------------------------------------------------------------------
# Version info
our $VERSION = '0.1.3';                                          # Todo, pull this from git tag
##--------------------------------------------------------------------------

##--------------------------------------------------------------------------
# Create logger object
use ModelCitizen::Logger;
our $logger = ModelCitizen::Logger->new() or die "Cannot retrieve Logger object\n";
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

##---------------------------------------------------------------------------
# Print [File Information] to log
sub logFileInformation {
  my ($files, $fileType, $filepath) = @_;
  $logger->info("[$fileType File Information]");
  if (defined $filepath) { $logger->info("  filepath: [$filepath]"); }
  for (my $i = 0; $i < @{$files}; $i++) {
    my $formattedIndex = sprintf '%4s', $i;    # Left pad index with spaces for prettier logging
    $logger->info("$formattedIndex:  [$files->[$i]]");
  }
  $logger->info("");

  return;
} ## end sub logFileInformation
##---------------------------------------------------------------------------

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

##---------------------------------------------------------------------------
# Loop over list of model files and load model info
sub loadModel {
  my ($fileList)  = @_;
  my $subName     = (caller(0))[3];
  my $modelFiles  = [];
  my $objectsInfo = [];

  # Process the list of model files, one file at a time
  for my $currentFilename (@$fileList) {
    my $modelFile = loadModelFile($currentFilename);
    if (defined $modelFile->{type}) {
      if   ($modelFile->{type} eq 'Objects.local') { push(@$objectsInfo, $modelFile); }
      else                                         { push(@$modelFiles,  $modelFile); }
    }
  } ## end for my $currentFilename...

  # If we loaded Objects.local info, enrich our other model files with it
  if (@{$objectsInfo} > 0) {
    $logger->info("$subName Found additional object info, enriching model...");
    enrichModelFiles($modelFiles, $objectsInfo);
  }

  # Sort model by name
  $logger->info("$subName Sorting model files by name...");
  @$modelFiles = sort { uc(stripQuotes($a->{name})) cmp uc(stripQuotes($b->{name})) } @$modelFiles;

  return $modelFiles;
} ## end sub loadModel
##---------------------------------------------------------------------------

##---------------------------------------------------------------------------
# Load a model file
sub loadModelFile {
  my ($currentFilename) = @_;
  my $subName = (caller(0))[3];
  my $XMLObj;    # Our XML Twig containing the file contents
  my $modelFile;

  if ($verbose) { $logger->info("$subName Processing: [$currentFilename]") }

  # Convert plain XML text to a twig object
  eval { $XMLObj = $twig->parsefile($currentFilename); };
  $logger->error(objConversionErrorMsgGenerator($@)) if $@;

  # Handle files based on type. Could also do this based on internal metadata in the file instead of the path
  my $fileType = '';
  if    ($currentFilename ~~ /table/)          { $fileType = 'table'; }
  elsif ($currentFilename ~~ /foreignkey/)     { $fileType = 'foreignkey'; }
  elsif ($currentFilename ~~ /schema/)         { $fileType = 'schema'; }
  elsif ($currentFilename ~~ /Objects\.local/) { $fileType = 'Objects.local'; }
  else                                         { $fileType = 'unknown'; }
  if ($verbose) { $logger->info("$subName detected as a $fileType fileType: [$currentFilename]"); }

  if    ($fileType eq 'table')         { $modelFile = loadModelFileTable($XMLObj); }
  elsif ($fileType eq 'foreignkey')    { $modelFile = loadModelFileForeignKey($XMLObj); }
  elsif ($fileType eq 'schema')        { $modelFile = loadModelFileSchema($XMLObj); }
  elsif ($fileType eq 'Objects.local') { $modelFile = loadModelFileObjectsLocal($XMLObj); }

  if ($verbose) { $logger->info("$subName Complete: [$currentFilename]"); }

  return $modelFile;
} ## end sub loadModelFile
##---------------------------------------------------------------------------

##---------------------------------------------------------------------------
# Load schema info from an XML object and return a hash ref of handy info
sub loadModelFileSchema {
  my ($XMLObj) = @_;
  my $subName = (caller(0))[3];

  # schema info
  my $schemaInfo   = {};
  my $schemaXMLObj = $XMLObj->root;
  $schemaInfo->{type}            = 'schema';
  $schemaInfo->{name}            = getSanitizedObjectName($schemaXMLObj->att("name"));
  $schemaInfo->{id}              = $schemaXMLObj->att("id");
  $schemaInfo->{createdBy}       = $schemaXMLObj->first_child("createdBy")->inner_xml;
  $schemaInfo->{createdTime}     = $schemaXMLObj->first_child("createdTime")->inner_xml;
  $schemaInfo->{ownerDesignName} = $schemaXMLObj->first_child("ownerDesignName")->inner_xml;

  if ($verbose) { $logger->info("$subName schemaInfo:\n" . Dumper($schemaInfo)); }

  return $schemaInfo;
} ## end sub loadModelFileSchema
##---------------------------------------------------------------------------

##---------------------------------------------------------------------------
# Load table info from an XML object and return a hash ref of handy info
sub loadModelFileTable {
  my ($XMLObj) = @_;
  my $subName = (caller(0))[3];

  # Table info
  my $tableInfo   = {};
  my $tableXMLObj = $XMLObj->root;
  $tableInfo->{type}        = 'table';
  $tableInfo->{name}        = getSanitizedObjectName($tableXMLObj->att("name"));
  $tableInfo->{id}          = $tableXMLObj->att("id");
  $tableInfo->{createdBy}   = $tableXMLObj->first_child("createdBy")->inner_xml;
  $tableInfo->{createdTime} = $tableXMLObj->first_child("createdTime")->inner_xml;
  if (defined $tableXMLObj->first_child("schemaObject")) {
    $tableInfo->{schemaObject} = $tableXMLObj->first_child("schemaObject")->inner_xml;
  }

  # Column info
  my $columns = $tableXMLObj->first_child("columns");
  $tableInfo->{columns} = [];
  for my $column ($columns->children('Column')) {

    my $colInfo = {name => getSanitizedObjectName($column->att('name')), id => $column->att('id')};

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
    if (defined $column->first_child('domain')) {
      $colInfo->{"domain"} = $column->first_child("domain")->inner_xml;
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
    if (defined $column->first_child('dataTypePrecision')) {
      $colInfo->{"dataTypePrecision"} = $column->first_child("dataTypePrecision")->inner_xml;
    }
    if (defined $column->first_child('dataTypeScale')) {
      $colInfo->{"dataTypeScale"} = $column->first_child("dataTypeScale")->inner_xml;
    }
    if (defined $column->first_child('commentInRDBMS')) {

      # These comments might have encoded new lines, replace the encoded version with \n
      my $comment = $column->first_child("commentInRDBMS")->inner_xml;
      $comment =~ s/&lt;br\/>/\n/g;
      $colInfo->{"commentInRDBMS"} = $comment;
    } ## end if (defined $column->first_child...)

    push(@{$tableInfo->{columns}}, $colInfo);
  } ## end for my $column ($columns...)

  # Index info
  my $indexes = $tableXMLObj->first_child("indexes");
  if (defined $indexes) {

    $tableInfo->{indexes} = [];
    for my $index ($indexes->children('ind_PK_UK')) {
      if ($verbose) { $logger->info("$subName index name:" . $index->att("name")); }

      my $indexInfo = {name => getSanitizedObjectName($index->att("name")), id => $index->att("id")};

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

  if ($verbose) { $logger->info("$subName tableInfo:\n" . Dumper($tableInfo)); }

  return $tableInfo;
} ## end sub loadModelFileTable
##---------------------------------------------------------------------------

##---------------------------------------------------------------------------
# Load Foreign Key info from an XML object and return a hash ref of handy info
sub loadModelFileForeignKey {
  my ($XMLObj) = @_;
  my $subName = (caller(0))[3];

  my $fkInfo   = {};
  my $fkXMLObj = $XMLObj->root;
  $fkInfo->{type}                   = 'foreignkey';
  $fkInfo->{name}                   = getSanitizedObjectName($fkXMLObj->att("name"));
  $fkInfo->{id}                     = $fkXMLObj->att("id");
  $fkInfo->{containerWithKeyObject} = $fkXMLObj->att("containerWithKeyObject");
  $fkInfo->{localFKIndex}           = $fkXMLObj->att("localFKIndex");
  $fkInfo->{keyObject}              = $fkXMLObj->first_child("keyObject")->inner_xml;
  $fkInfo->{createdTime}            = $fkXMLObj->first_child("createdTime")->inner_xml;
  $fkInfo->{createdBy}              = $fkXMLObj->first_child("createdBy")->inner_xml;

  # Sometimes localFKIndex is down here instead
  if (defined $fkXMLObj->first_child("localFKIndex")) {
    $fkInfo->{localFKIndex} = $fkXMLObj->first_child("localFKIndex")->inner_xml;
  }

  # Sometimes containerWithKeyObject is down here instead
  if (defined $fkXMLObj->first_child("containerWithKeyObject")) {
    $fkInfo->{containerWithKeyObject} = $fkXMLObj->first_child("containerWithKeyObject")->inner_xml;
  }

  if (defined $fkXMLObj->first_child("referredTableID")) {
    $fkInfo->{referredTableID} = $fkXMLObj->first_child("referredTableID")->inner_xml;
  }
  if (defined $fkXMLObj->first_child("referredKeyID")) {
    $fkInfo->{referredKeyID} = $fkXMLObj->first_child("referredKeyID")->inner_xml;
  }

  if ($verbose) { $logger->info("$subName fkName\n" . Dumper($fkInfo)); }

  return $fkInfo;
} ## end sub loadModelFileForeignKey
##---------------------------------------------------------------------------

##---------------------------------------------------------------------------
# Load Foreign Key info from an XML object and return a hash ref of handy info
sub loadModelFileObjectsLocal {
  my ($XMLObj) = @_;
  my $subName = (caller(0))[3];

  my $objectsInfoXMLObj = $XMLObj->root;
  my $objects           = [];

  # Object info
  for my $object ($objectsInfoXMLObj->children('object')) {
    my $objectInfo = {};

    if (defined $object->att('objectType')) {
      if ($object->att('objectType') eq 'FKIndexAssociation') {    # Store FKIndexAssociation metadata
        $objectInfo->{objectType}        = $object->att('objectType');
        $objectInfo->{objectID}          = $object->att('objectID');
        $objectInfo->{name}              = $object->att('name');
        $objectInfo->{seqName}           = $object->att('seqName');
        $objectInfo->{propertyClassName} = $object->att('propertyClassName');
        $objectInfo->{propertyParentId}  = $object->att('propertyParentId');
        $objectInfo->{propertySourceId}  = $object->att('propertySourceId');
        $objectInfo->{containerID}       = $object->att('containerID');
        $objectInfo->{refContainerID}    = $object->att('refContainerID');
        $objectInfo->{propertyTargetId}  = $object->att('propertyTargetId');

        push(@{$objects}, $objectInfo);
      } ## end if ($object->att('objectType'...))
    } ## end if (defined $object->att...)
  } ## end for my $object ($objectsInfoXMLObj...)

  my $objectsInfo;
  if (@{$objects} > 0) {    # If we found info, construct a populated object to return
    $objectsInfo->{type}    = 'Objects.local';
    $objectsInfo->{name}    = 'Objects.local';
    $objectsInfo->{objects} = $objects;

    if ($verbose) {
      $logger->info("$subName objectsInfo:\n" . Dumper($objectsInfo));
    }
  } ## end if (@{$objects} > 0)

  return $objectsInfo;
} ## end sub loadModelFileObjectsLocal
##---------------------------------------------------------------------------

##---------------------------------------------------------------------------
# Load type lookup information
sub loadTypes {
  my ($typeFilepath) = @_;
  my $subName = (caller(0))[3];
  my $types;

  # Sanity test and default types file path, then load the types information
  $typeFilepath = $typeFilepath ? $typeFilepath : dirname(__FILE__) . '/ModelCitizen/types/types.json';
  my $typeFilepathParts = getFilepathParts($typeFilepath, ('.json', '.xml'));
  if ($typeFilepathParts->{ext} eq '.json') {
    $types = loadJSONTypes($typeFilepath);
  }
  elsif ($typeFilepathParts->{ext} eq '.xml') {
    $types = loadXMLTypes($typeFilepath);
  }

  if (!defined($types)) {
    $logger->confess("$subName Unable to load types information from $typeFilepath");
  }

  return $types;
} ## end sub loadTypes
##---------------------------------------------------------------------------

##---------------------------------------------------------------------------
# Load type lookup information from a json file and return as a hash ref
sub loadJSONTypes {
  my ($typeFilepath) = @_;
  my $subName = (caller(0))[3];

  my $types = {};
  eval { $types = $json->decode(openAndLoadFile($typeFilepath)) };
  $logger->confess(objConversionErrorMsgGenerator($@)) if $@;

  return $types;
} ## end sub loadJSONTypes
##---------------------------------------------------------------------------

##---------------------------------------------------------------------------
# Load type lookup information from an XML file and return as a hash ref
sub loadXMLTypes {
  my ($typeFilepath) = @_;
  my $subName = (caller(0))[3];

  # Convert plain XML text to a twig object
  my $XMLObj;    # Our XML Twig containing the file contents
  eval { $XMLObj = $twig->parsefile($typeFilepath); };
  $logger->confess(objConversionErrorMsgGenerator($@)) if $@;

  my $types       = {};
  my $typesXMLObj = $XMLObj->root;

  my $logicalTypes = [];
  $types->{logicalTypes} = $logicalTypes;
  for my $logicalType ($typesXMLObj->children('logicaltype')) {
    my $logicalTypeInfo = {};
    $logicalTypeInfo->{name}     = $logicalType->att('name');
    $logicalTypeInfo->{objectid} = $logicalType->att('objectid');

    my $mappings = [];
    $logicalTypeInfo->{mappings} = $mappings;
    for my $mapping ($logicalType->children('mapping')) {
      my $mappingInfo = {};
      $mappingInfo->{rdbms}   = $mapping->att('rdbms');
      $mappingInfo->{mapping} = $mapping->inner_xml;
      push(@{$mappings}, $mappingInfo);
    } ## end for my $mapping ($logicalType...)

    push(@{$logicalTypes}, $logicalTypeInfo);

    # my $colInfo = {name => $column->att('name'), id => $column->att('id')};
  } ## end for my $logicalType ($typesXMLObj...)

  return $types;
} ## end sub loadXMLTypes
##---------------------------------------------------------------------------

##---------------------------------------------------------------------------
# Given the type lookup hash ref, logical type id, and the target RDBMS, return a hash ref of type info
sub getTypeInfo {
  my ($types, $logicalDataType, $RDBMS) = @_;
  my $subName  = (caller(0))[3];
  my $typeInfo = {};

  if (defined($logicalDataType) and defined($types) and defined($RDBMS)) {
    for my $type (@{$types->{logicalTypes}}) {
      if ($type->{objectid} eq $logicalDataType) {
        $typeInfo->{name} = $type->{name};
        for my $mapping (@{$type->{mappings}}) {
          if ($mapping->{rdbms} eq $RDBMS) {
            $typeInfo->{mapping} = $mapping->{mapping};
            last;
          }
        } ## end for my $mapping (@{$type...})
        last;
      } ## end if ($type->{objectid} ...)
    } ## end for my $type (@{$types->...})
  } ## end if (defined($logicalDataType...))

  return $typeInfo;
} ## end sub getTypeInfo

##---------------------------------------------------------------------------

##---------------------------------------------------------------------------
# Enrich Model Files using supplemental metadata
sub enrichModelFiles {
  my ($modelFiles, $objectsInfo) = @_;
  my $subName = (caller(0))[3];

  # If we have loaded Objects.local types, use them to enrich the other model files
  for my $objectInfo (@{$objectsInfo}) {
    for my $object (@{$objectInfo->{objects}}) {
      if ($object->{objectType} eq "FKIndexAssociation") {    # Foreign Key enrichment
        for my $enrichTarget (@{$modelFiles}) {
          if (defined $enrichTarget->{type} && defined $enrichTarget->{id} && defined $object->{objectID}) {
            if ($enrichTarget->{type} eq 'foreignkey' && $enrichTarget->{id} eq $object->{objectID}) {
              if ($verbose) {
                $logger->info("$subName enriching $enrichTarget->{name} using $object->{objectType} $object->{name} .");
              }
              $enrichTarget->{enrichment} = $object;          # Save our enriched fields into this matched object
            } ## end if ($enrichTarget->{type...})
          } ## end if (defined $enrichTarget...)
        } ## end for my $enrichTarget (@...)
      } ## end if ($object->{objectType...})
    } ## end for my $object (@{$objectInfo...})
  } ## end for my $objectInfo (@{$objectsInfo...})

  return;
} ## end sub enrichModelFiles
##---------------------------------------------------------------------------

##---------------------------------------------------------------------------
# Generate sql from modelFile info
sub getSQL {
  my ($modelFiles, $types, $RDBMS) = @_;
  my $subName      = (caller(0))[3];
  my $sql          = '';
  my $tableSQL     = '';
  my $fkSQL        = '';
  my $headerSQL    = '';
  my $startTime    = localtime;
  my $startTimeSQL = $startTime->datetime;

  # Header for SQL output
  $headerSQL .= qq{-- Generated by ModelCitizen $VERSION\n};
  $headerSQL .= qq{--   at:        $startTimeSQL\n};
  $headerSQL .= qq{--   site:      $RDBMS\n};
  $headerSQL .= qq{--   type:      $RDBMS\n};

  # Generate SQL for table files
  for my $modelFile (@$modelFiles) {
    if ($modelFile->{type} eq 'table') {
      $tableSQL .= getSQLTable($modelFile, $modelFiles, $types, $RDBMS);
    }
  }

  # Need to have all the tables and indexes set first, then we can construct the FKs
  for my $modelFile (@$modelFiles) {
    if ($modelFile->{type} eq "foreignkey") {
      $fkSQL .= getSQLForeignKey($modelFile, $modelFiles);
    }
  }

  # Assemble final SQL. Write fk after all table objects to avoid dependency issues
  $sql = qq{$headerSQL\n\n$tableSQL\n$fkSQL\n};

  return $sql;
} ## end sub getSQL
##---------------------------------------------------------------------------

##---------------------------------------------------------------------------
# Get SQL for a table
sub getSQLTable {
  my ($modelFile, $modelFiles, $types, $RDBMS) = @_;
  my $subName  = (caller(0))[3];
  my $tableSQL = '';

  if ($verbose) { $logger->info("$subName modelFile name: [$modelFile->{name}] type: [$modelFile->{type}]"); }

  # Create table SQL
  $tableSQL .= getSQLCreateTable($modelFile, $modelFiles, $types, $RDBMS);

  # Create index SQL
  for my $index (@{$modelFile->{indexes}}) {
    $tableSQL .= getSQLIndex($index, $modelFile, $modelFiles);
  }

  return $tableSQL;
} ## end sub getSQLTable
##---------------------------------------------------------------------------

##---------------------------------------------------------------------------
sub getSQLCreateTable {
  my ($modelFile, $modelFiles, $types, $RDBMS) = @_;
  my $subName        = (caller(0))[3];
  my $createTableSQL = '';

  # Schema
  my $schema = getSchemaFromID($modelFiles, $modelFile->{schemaObject});
  $modelFile->{schema} = $schema->{name};
  $modelFile->{schemaPrefixSQL} = $schema->{name} ? "$schema->{name}." : '';

  $createTableSQL .= qq{\nCREATE TABLE $modelFile->{schemaPrefixSQL}$modelFile->{name} (\n};

  # Field list
  my $fieldList          = [];
  my $commentInRDBMSList = [];
  for my $column (@{$modelFile->{columns}}) {

    # Lookup type info using logical type
    my $typeInfo = getTypeInfo($types, $column->{logicalDatatype}, $RDBMS);
    ## this will give us something like "NUMBER, precision, scale" in $typeInfo->{mapping}
    ## need to use this info along with the column info to generate the rest of the SQL

    my $fieldSQL = getFieldSQL($column, $typeInfo, $RDBMS);

    # Save off any comments so we can add the DDL for them later
    if (defined $column->{commentInRDBMS}) {
      push(@{$commentInRDBMSList}, {name => $column->{name}, commentInRDBMS => $column->{commentInRDBMS}});
    }
    push(@{$fieldList}, qq{    $fieldSQL});
  } ## end for my $column (@{$modelFile...})

  # Add field list to SQL statement
  $createTableSQL .= join ",\n", @$fieldList;

  # Close field list
  $createTableSQL .= qq{\n);\n\n};

  # Add SQL for column comments
  for my $commentInRDBMS (@{$commentInRDBMSList}) {
    my $commentText = $commentInRDBMS->{commentInRDBMS};
    $commentText =~ s/'/''/g;    # Escape single quotes inside the text
    $createTableSQL
      .= qq{COMMENT ON COLUMN $modelFile->{schemaPrefixSQL}$modelFile->{name}.$commentInRDBMS->{name} IS '$commentText';\n\n};
  } ## end for my $commentInRDBMS ...

  $modelFile->{sql} = $createTableSQL;    # todo, review saving this SQL to the model

  return $createTableSQL;
} ## end sub getSQLCreateTable
##---------------------------------------------------------------------------

##---------------------------------------------------------------------------
# Use the type information to generate RDBMS specific SQL for a field
sub getFieldSQL {
  my ($column, $typeInfo, $RDBMS) = @_;
  my $subName         = (caller(0))[3];
  my $fieldDetailsSQL = '';
  my @mapping;
  my $fieldDatatype = 'unknown';    # Default value for unknown values

  # Split ownDataTypeParameters, then need to know what datatype we're working with to apply the rules (?)
  if (defined($typeInfo->{mapping})) {
    @mapping                 = split(/,/, $typeInfo->{mapping});    # These are the rules to use when subbing values in
    $fieldDatatype           = $mapping[0];
    $column->{fieldDatatype} = $fieldDatatype;                      # Save in model
  }

  # Use mapping and ownDataTypeParameters to generate the RDBMS specific info
  if (defined($typeInfo->{mapping})) {
    my @ownDataTypeParameters;
    if (defined($column->{ownDataTypeParameters})) {
      @ownDataTypeParameters = split(/,/, $column->{ownDataTypeParameters}, 3); # These are the values we need to sub in
    }

    # Look for defined size/precision/scale information
    # It appears that ownDataTypeParameters is a 3 part array
    # map is a rdbms specific mapping of ownDataTypeParameters
    # 0 == size (might also include the datatype in the case of strings)
    # 1 == precision
    # 2 == scale
    for my $map (@mapping) {
      $map =~ s/^\s+|\s+$//g;    # Trim whitespace
      if ($map eq 'size') {

        # Populate with the dedicated attribute if it exists and is populated
        if (defined($column->{dataTypeSize})) {
          $column->{size} = $column->{dataTypeSize};
        }

        # This version of size is more specific than dataTypeSize sometimes, so use it if we have it
        if ($ownDataTypeParameters[0]) {
          my $size = $ownDataTypeParameters[0];
          $size =~ s/^\s+|\s+$//g;    # Trim whitespace
          if (defined($size)) { $column->{size} = $size; }    # Only overwrite if we got something here
        }
      } ## end if ($map eq 'size')
      if ($map eq 'precision') {

        # Populate with the dedicated attribute if it exists and is populated
        if (defined($column->{dataTypePrecision})) {
          $column->{precision} = $column->{dataTypePrecision};
        }

        if ($ownDataTypeParameters[1]) {
          my $precision = $ownDataTypeParameters[1];
          $precision =~ s/^\s+|\s+$//g;                       # Trim whitespace
          $column->{precision} = $precision;                  # Save in model
        }
      } ## end if ($map eq 'precision')
      if ($map eq 'scale') {

        # Populate with the dedicated attribute if it exists and is populated
        if (defined($column->{dataTypeScale})) {
          $column->{scale} = $column->{dataTypeScale};
        }
        if ($ownDataTypeParameters[2]) {
          my $scale = $ownDataTypeParameters[2];
          $scale =~ s/^\s+|\s+$//g;                           # Trim whitespace
          $column->{scale} = $scale;                          # Save in model
        }
      } ## end if ($map eq 'scale')
    } ## end for my $map (@mapping)
  } ## end if (defined($typeInfo->...))

  # Add size/precision/scale information if we have any
  my $fieldDetails = [];
  if (defined($column->{size}))      { push(@$fieldDetails, $column->{size}); }
  if (defined($column->{precision})) { push(@$fieldDetails, $column->{precision}); }
  if (defined($column->{scale}))     { push(@$fieldDetails, $column->{scale}); }
  if (@$fieldDetails) {
    $fieldDetailsSQL .= '(';
    $fieldDetailsSQL .= join ',', @$fieldDetails;
    $fieldDetailsSQL .= ') ';
  }

  if (!defined($column->{nullsAllowed})) { $fieldDetailsSQL .= 'NOT NULL'; }

  # Assemble field components into SQL
  my $fieldSQL = qq{$column->{name} $fieldDatatype $fieldDetailsSQL};
  $fieldSQL =~ s/^\s+|\s+$//g;    # Trim whitespace

  # Update the model with the derived values # Todo, make RDBMS specific (subdocument?)
  $column->{fieldSQL} = $fieldSQL;    # Save in model

  return $fieldSQL;
} ## end sub getFieldSQL
##---------------------------------------------------------------------------

##---------------------------------------------------------------------------
# Get SQL for indexes (Primary Key, Unique key)
sub getSQLIndex {
  my ($index, $modelFile, $modelFiles) = @_;
  my $subName = (caller(0))[3];
  my $sql     = '';

  if ($verbose) { $logger->info("$subName index name:" . $index->{name}); }

  # Try to suss out what type of key we got
  my $keyTypeSQL = 'DEFAULT INDEX';
  if (defined $index->{indexState}) {
    if (defined $index->{pk}) {
      $keyTypeSQL = 'PRIMARY KEY';
    }
    elsif ($index->{indexState} eq 'Unique Plain Index' or $index->{indexState} eq 'Unique Constraint') {
      $keyTypeSQL = 'UNIQUE';
    }
    elsif ($index->{indexState} eq 'Foreign Key') {
      $keyTypeSQL = 'FOREIGN KEY';
    }
  } ## end if (defined $index->{indexState...})

  # Sometimes indexState is not set, need to check against the list of FKs and make sure we're not in there
  if ($keyTypeSQL eq 'DEFAULT INDEX') {
    my $isFK = isIndexFK($index, $modelFiles);
    if ($isFK) { $keyTypeSQL = 'FOREIGN KEY'; }
  }

  if ($verbose) { $logger->info("$subName index:" . $index->{name} . " detected as $keyTypeSQL"); }

  if ($keyTypeSQL eq 'FOREIGN KEY') { return $sql; }    # Leave early, FKs are handled separately

  my $fieldList = getFieldListFromIndex($index, $modelFile, $modelFiles);
  if ($keyTypeSQL ne 'DEFAULT INDEX') {
    $sql
      = qq{ALTER TABLE $modelFile->{schemaPrefixSQL}$modelFile->{name} ADD CONSTRAINT $index->{name} $keyTypeSQL ( $fieldList );\n\n};
  }
  else {
    $sql
      = qq{CREATE INDEX $modelFile->{schemaPrefixSQL}$index->{name} ON $modelFile->{schemaPrefixSQL}$modelFile->{name} ( $fieldList );\n\n};
  }
  $index->{sql} = $sql;                                 # todo, revisit sql storage in model

  return $sql;
} ## end sub getSQLIndex
##---------------------------------------------------------------------------

##---------------------------------------------------------------------------
# Is the supplied index a FK?
sub isIndexFK {
  my ($index, $modelFiles) = @_;
  my $subName = (caller(0))[3];
  my $isFK    = 0;

  for my $modelFile (@$modelFiles) {
    if ($modelFile->{type} eq 'foreignkey') {
      my ($hostKeyID, $referredKeyID) = getKeyIndexIDsFromFK($modelFile, $modelFiles);
      if ($index->{id} eq $hostKeyID)     { $isFK = 1; last; }
      if ($index->{id} eq $referredKeyID) { $isFK = 1; last; }
    }
  } ## end for my $modelFile (@$modelFiles)

  return $isFK;
} ## end sub isIndexFK
##---------------------------------------------------------------------------

##---------------------------------------------------------------------------
# Return key index ids from a foreign key object
sub getKeyIndexIDsFromFK {
  my ($modelFile, $modelFiles) = @_;
  my $subName = (caller(0))[3];

  # Set out first guesses for IDs. Some of these will not be populated and we'll have to fall back
  my $hostKeyID     = $modelFile->{localFKIndex};
  my $referredKeyID = $modelFile->{referredKeyID};

  # Sometimes these refereed fields aren't set, try to look them up in the enrichment object
  if (!defined $referredKeyID) {
    if (defined $modelFile->{keyObject}) {
      $referredKeyID = $modelFile->{keyObject};
    }
    elsif (defined $modelFile->{enrichment}->{propertyTargetId}) {
      $referredKeyID = $modelFile->{enrichment}->{propertyTargetId};
    }
  } ## end if (!defined $referredKeyID)

  return ($hostKeyID, $referredKeyID);
} ## end sub getKeyIndexIDsFromFK
##---------------------------------------------------------------------------

##---------------------------------------------------------------------------
# Return index based on id
sub getIndexFromID {
  my ($tables, $indexID) = @_;
  my $subName = (caller(0))[3];

  for my $table (@$tables) {
    for my $index (@{$table->{indexes}}) {
      if ($index->{id} eq $indexID) {
        $index->{parentTableID} = $table->{id};
        return $index;
      }
    } ## end for my $index (@{$table...})
  } ## end for my $table (@$tables)

  my $error = "ERR_COULD_NOT_RESOLVE_INDEX_FOR_ID_${indexID}";
  $logger->warn("$subName $error");
  return {error => $error};
} ## end sub getIndexFromID
##---------------------------------------------------------------------------

##---------------------------------------------------------------------------
# Return schema from id
sub getSchemaFromID {
  my ($schemas, $schemaID) = @_;
  my $subName = (caller(0))[3];

  if (!defined $schemaID) {
    return {name => ''};
  }

  for my $schemaCandidate (@$schemas) {
    if ($schemaCandidate->{id} eq $schemaID) { return $schemaCandidate; }
  }

  my $error = "ERR_COULD_NOT_RESOLVE_SCHEMA_FOR_ID_${schemaID}";
  $logger->warn("$subName $error");
  return {error => $error, name => ''};
} ## end sub getSchemaFromID
##---------------------------------------------------------------------------

##---------------------------------------------------------------------------
# Generate a field list from an index
sub getFieldListFromIndex {
  my ($index, $modelFile, $modelFiles) = @_;
  my $columnNames = getColumnNamesFromIndex($index, $modelFiles);
  return join ',', @$columnNames;
}
##---------------------------------------------------------------------------

##---------------------------------------------------------------------------
# Generate a field names for an index
sub getColumnNamesFromIndex {
  my ($index, $modelFiles) = @_;
  my $subName     = (caller(0))[3];
  my $columnNames = [];
  for my $columnID (@{$index->{indexColumnUsage}}) { push(@$columnNames, getColumnNameFromID($modelFiles, $columnID)); }
  return $columnNames;
} ## end sub getColumnNamesFromIndex
##---------------------------------------------------------------------------

##---------------------------------------------------------------------------
# Generate DDL SQL for foreign keys
sub getSQLForeignKey {
  my ($modelFile, $modelFiles) = @_;
  my $subName = (caller(0))[3];
  my $sql     = '';

  if ($verbose) { $logger->info("$subName modelFile name: [$modelFile->{name}] type: [$modelFile->{type}]"); }

  my ($hostKeyID, $referredKeyID) = getKeyIndexIDsFromFK($modelFile, $modelFiles);

  # Proceed if we have the minimum required info to continue
  if (defined $hostKeyID && defined $referredKeyID) {

    # Need to convert these index IDs to index objects
    my $hostKeyIndex     = getIndexFromID($modelFiles, $hostKeyID);
    my $referredKeyIndex = getIndexFromID($modelFiles, $referredKeyID);

    # Convert host table id to human name
    my $hostTable = getModelFileByID($modelFiles, $hostKeyIndex->{parentTableID});

    # Convert host key to human key field list
    my $hostKeyFieldList = getFieldListFromIndex($hostKeyIndex, $modelFile, $modelFiles);

    # Convert referred table id to human name
    my $referredTable = getModelFileByID($modelFiles, $referredKeyIndex->{parentTableID});

    # Convert referred key to human key field list
    my $referredKeyFieldList = getFieldListFromIndex($referredKeyIndex, $modelFile, $modelFiles);

    # If we could find all the objects we needed, construct the SQL
    if (defined($hostKeyIndex->{error}) || defined($referredKeyIndex->{error})) {
      $logger->warn("$subName Foreign Key $modelFile->{name} has no columns.");
      $sql = "-- Error - Foreign Key $modelFile->{name} has no columns\n\n";
      if (defined($hostKeyIndex->{error})) {
        $logger->warn("$subName Foreign Key $modelFile->{name} host has no columns: $hostKeyIndex->{error}");
      }
      if (defined($referredKeyIndex->{error})) {
        $logger->warn("$subName Foreign Key $modelFile->{name} target has no columns: $referredKeyIndex->{error}");
      }
    } ## end if (defined($hostKeyIndex...))
    else {
      $sql = qq{ALTER TABLE $hostTable->{schemaPrefixSQL}$hostTable->{name}
    ADD CONSTRAINT $modelFile->{name} FOREIGN KEY ( $hostKeyFieldList )
      REFERENCES $referredTable->{schemaPrefixSQL}$referredTable->{name} ( $referredKeyFieldList );\n\n};
    }

    # Update the model file with our findings # todo, review mutating the model
    $modelFile->{hostTableName}        = $hostTable->{name};
    $modelFile->{referredTableName}    = $referredTable->{name};
    $modelFile->{hostKeyID}            = $hostKeyID;
    $modelFile->{referredKeyID}        = $referredKeyID;
    $modelFile->{hostKeyFieldList}     = $hostKeyFieldList;
    $modelFile->{referredKeyFieldList} = $referredKeyFieldList;
    $modelFile->{sql}                  = $sql;

    if ($verbose) { $logger->info("$subName \$sql:\n $sql"); }
  } ## end if (defined $hostKeyID...)
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
  $logger->warn("$subName $error");
  return $error;
} ## end sub getColumnNameFromID
##---------------------------------------------------------------------------

##---------------------------------------------------------------------------
# Get a model file from the modelFiles array ref using guid lookup
sub getModelFileByID {
  my ($modelFiles, $ID) = @_;
  my $subName = (caller(0))[3];
  my $error;

  if (defined $ID) {
    for my $modelFile (@$modelFiles) {
      if ($modelFile->{id} eq $ID) { return $modelFile; }
    }
    $error = "ERR_COULD_NOT_FIND_MODEL_FILE_BY_ID_$ID";
  } ## end if (defined $ID)
  else {
    $error = "ERR_COULD_NOT_FIND_MODEL_FILE_BY_ID_UNDEFINED_ID";
  }

  $logger->warn("$subName $error");
  return {error => $error, name => ' ', schemaPrefixSQL => ' ', id => $ID};
} ## end sub getModelFileByID
##---------------------------------------------------------------------------

##---------------------------------------------------------------------------
# Generate human readable table name using guid lookup
sub getTableNameFromID {
  my ($tables, $tableID) = @_;
  my $subName = (caller(0))[3];
  my $tableName;

  my $table = getModelFileByID($tables, $tableID);

  if (defined $table->{error}) {
    $tableName = "ERR_COULD_NOT_RESOLVE_TABLE_NAME_FOR_ID_${tableID}";
    $logger->warn("$subName $tableName");
  }
  return $tableName;
} ## end sub getTableNameFromID
##---------------------------------------------------------------------------

##--------------------------------------------------------------------------
# Derive and return a valid object name
sub getSanitizedObjectName {
  my ($objectName)        = @_;
  my $subName             = (caller(0))[3];
  my $sanitizedObjectName = $objectName;

  # Check if this object name matches a valid object pattern, if not wrap it in double quotes
  my $validObjectNameRegEx = '^[a-z?A-Z0-9_#\$@]+$';
  unless ($sanitizedObjectName =~ /$validObjectNameRegEx/gm) {    # Unless a valid object named without wrapping
    $sanitizedObjectName = stripQuotes($sanitizedObjectName);     # Strip any existing quotes
    $sanitizedObjectName = qq{"$sanitizedObjectName"};            # Wrap in double quotes
    $logger->warn("$subName $objectName detected as an invalid name, wrapping in quotes: $sanitizedObjectName.");
  }

  return $sanitizedObjectName;
} ## end sub getSanitizedObjectName
##--------------------------------------------------------------------------

##--------------------------------------------------------------------------
# Return a version of the supplied string, but without any double quote characters
sub stripQuotes {
  my ($string) = @_;
  my $stripped = $string;
  $stripped =~ s/"//gm;
  return $stripped;
} ## end sub stripQuotes
##-------------------------------------------------------------------------

1;

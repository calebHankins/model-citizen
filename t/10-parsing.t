#!/usr/bin/perl -w
use strict;
use warnings FATAL => 'all';
use Test::More;
use File::Basename;        # Parse file paths into directory, filename and suffix
use List::Util 'first';    # A selection of general-utility list subroutines

use ModelCitizen;

plan tests => 37;

$ModelCitizen::logger->info("Testing Model Parsing for ModelCitizen $ModelCitizen::VERSION, Perl $], $^X");

# Filepath to our sample model
my $modelFilepath = 'samples/JJJ';

# Construct a list of files to munge and log file details
$ModelCitizen::logger->debug("Opening data model from [$modelFilepath]...");
my @inputFiles   = ModelCitizen::buildPackageFileList($modelFilepath, '.xml .local');
my $inputFileCnt = @inputFiles;
$ModelCitizen::logger->debug("$inputFileCnt model files in list.");
ok($inputFileCnt >= 5);    # Number of relevant files in our sample model

# Let's test loading the sample model
my $loaded;
eval { $loaded = ModelCitizen::loadModel(\@inputFiles); };
my $loadModelErrCnt = $ModelCitizen::logger->get_count("ERROR");
my $loadedCnt       = @$loaded;                                    # Count of files we loaded
ok($loadedCnt >= 5);                                               # Make sure we loaded what we expected
ok($loadModelErrCnt == 0);                                         # Should have 0 errors so far

# Let's test the STORES table sample file
my $storesTablePath = first {/STORES.xml/} @inputFiles;
$ModelCitizen::logger->debug("Loading STORES table from file: [$storesTablePath].");
my $storesTableLoaded = ModelCitizen::loadModelFile($storesTablePath);
ok($storesTableLoaded->{name} eq "STORES");
ok($storesTableLoaded->{id} eq "8FEE201F-26AF-7AD0-6178-284577B5FA55");
ok($storesTableLoaded->{schemaObject} eq "B28EB275-E427-1CB2-7F30-0676E8AF18B1");
ok($storesTableLoaded->{type} eq "table");
ok($storesTableLoaded->{createdBy} eq "chanki");
ok($storesTableLoaded->{createdTime} eq "2018-12-18 19:23:03 UTC");
my $storesTableLoadedColumns    = $storesTableLoaded->{columns};
my $storesTableLoadedColumnsCnt = @$storesTableLoadedColumns;
ok($storesTableLoadedColumnsCnt == 4);
ok(ModelCitizen::getTableNameFromID($loaded, $storesTableLoaded->{id}) eq "STORES");

# Let's test the S_SL_FK foreignkey sample file
my $S_SL_FKPath = first {/S_SL_FK.xml/} @inputFiles;
$ModelCitizen::logger->debug("Loading S_SL_FK foreign key from file: [$S_SL_FKPath].");
my $S_SL_FKLoaded = ModelCitizen::loadModelFile($S_SL_FKPath);
ok($S_SL_FKLoaded->{name} eq "S_SL_FK");
ok($S_SL_FKLoaded->{id} eq "B1B52256-E143-3043-8698-6740ABD3BD2A");
ok($S_SL_FKLoaded->{type} eq "foreignkey");
ok($S_SL_FKLoaded->{createdBy} eq "chanki");
ok($S_SL_FKLoaded->{createdTime} eq "2018-12-18 19:23:03 UTC");
ok($S_SL_FKLoaded->{"keyObject"} eq "D37D734C-0AD4-76BE-3CD4-960574860D5F");
ok($S_SL_FKLoaded->{"referredKeyID"} eq "D37D734C-0AD4-76BE-3CD4-960574860D5F");
ok($S_SL_FKLoaded->{"referredTableID"} eq "DB1113D3-668A-6A60-95A6-C12E0DCB1720");
ok($S_SL_FKLoaded->{"containerWithKeyObject"} eq "8FEE201F-26AF-7AD0-6178-284577B5FA55");
ok($S_SL_FKLoaded->{"localFKIndex"} eq "8A6DAF78-83AE-C5AA-77F4-FDAB6A6FBC6A");

# Let's test the SQL Generation
ModelCitizen::getSQL($loaded);

# Let's test the SQL for the STORES table
my $storesTableWithSQL = first { $_->{name} eq "STORES" and $_->{type} eq "table" } @$loaded;
ok($storesTableWithSQL->{schema} eq "JJJ");
my $storesTablePK = first { $_->{pk} eq "true" } @{$storesTableWithSQL->{indexes}};
ok($storesTablePK->{name} eq "STORES_PK");
ok($storesTablePK->{indexState} eq "Primary Constraint");
ok($storesTablePK->{indexColumnUsage}[0] eq "32618D00-0A74-BA3C-BE21-126C0318D70A");
ok($storesTablePK->{sql} eq "ALTER TABLE JJJ.STORES ADD CONSTRAINT STORES_PK PRIMARY KEY ( STORE_ID );\n\n");
ok(ModelCitizen::isIndexFK($storesTablePK, $loaded) == 0);

# Let's test the SQL for the S_SL_FK FK
my $S_SL_FKWithSQL = first { $_->{name} eq "S_SL_FK" } @$loaded;
ok($S_SL_FKWithSQL->{type} eq "foreignkey");
ok($S_SL_FKWithSQL->{"hostTableName"} eq "STORES");
ok($S_SL_FKWithSQL->{"referredTableName"} eq "STORE_LOCATIONS");
ok($S_SL_FKWithSQL->{"hostKeyFieldList"} eq "LOCATION_ID");
ok($S_SL_FKWithSQL->{"referredKeyFieldList"} eq "LOCATION_ID");

# Let's test the STORES_W_LOCATION_NAMES view
my $STORES_W_LOCATION_NAMESLoaded = first { $_->{name} eq "STORES_W_LOCATION_NAMES" and $_->{type} eq 'view' } @$loaded;
ok($STORES_W_LOCATION_NAMESLoaded->{name} eq "STORES_W_LOCATION_NAMES");
ok($STORES_W_LOCATION_NAMESLoaded->{createdBy} eq "chanki");
ok($STORES_W_LOCATION_NAMESLoaded->{createdTime} eq "2018-12-19 18:26:56 UTC");
ok($STORES_W_LOCATION_NAMESLoaded->{userDefinedSQL} eq
  q{select t1.*, t2.location_name from jjj.stores t1&lt;br/>join jjj.store_locations t2&lt;br/>on t1.location_id = t2.location_id}
);
ok($STORES_W_LOCATION_NAMESLoaded->{sql} eq
   qq{select t1.*, t2.location_name from jjj.stores t1\njoin jjj.store_locations t2\non t1.location_id = t2.location_id;}
);


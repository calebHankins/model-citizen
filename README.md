# MODEL-CITIZEN

_I am the very model of modern meta generable_

Export Oracle Data Modeler files as json and or SQL DDL for easier consumption by other processes 

- [MODEL-CITIZEN](#model-citizen)
  - [Installation](#installation)
    - [Example commands to install Log::Log4perl on various platforms](#example-commands-to-install-loglog4perl-on-various-platforms)
  - [Usage](#usage)

## Installation

Install dependent perl libraries via your favorite management system

Requires the following perl modules and their dependencies:

```perl
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
use Log::Log4perl;               # Log4j implementation for Perl
```

### Example commands to install Log::Log4perl on various platforms
- `cpan install Log::Log4perl (cpan)`
- `ppm install Log-Log4perl (ActivePerl)`
- `sudo apt install liblog-log4perl-perl (Ubuntu/Debian)`
- `sudo yum install perl-Log-Log4perl (CentOS/RedHat)`

## Usage

Print usage info
```powershell
perl model_citizen.pl --help

```


Load up data modeler files and generate a DDL SQL output file and a json output file
```powershell
perl model_citizen.pl  --outputFileSQL ./scratch/ddl.sql --outputFileJSON ./scratch/model.json --modelFilepath C:\git\datamodels\MY_AWESOME_DATA_MODEL\

```

The json output is an array of documents describing the data model. These can be fed directly into mongoDB using a tool such as mongoimport using the --jsonArray option.
```powershell
mongoimport.exe --db join-hero --collection model --file "C:\git\model-citizen\scratch\model.json"
 --host localhost:27017 -v --stopOnError --jsonArray --mode upsert --upsertFields "name,type";
```


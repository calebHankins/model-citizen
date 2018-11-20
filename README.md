# MODEL-CITIZEN

_I am the very model of modern meta generable_

Export Oracle Data Modeler files as json and or SQL DDL for easier consumption by other processes 

- [MODEL-CITIZEN](#model-citizen)
    - [Note for Windows Users](#note-for-windows-users)
    - [Installation](#installation)
        - [Install using cpan](#install-using-cpan)
        - [Install using cpanm](#install-using-cpanm)
        - [Install using Module::Build](#install-using-modulebuild)
        - [Install using Make](#install-using-make)
        - [Manual Dependency Install](#manual-dependency-install)
            - [Example Commands To Install Log Log4perl On Various Platforms](#example-commands-to-install-log-log4perl-on-various-platforms)
        - [Troubleshooting](#troubleshooting)
    - [Run Without Installing](#run-without-installing)
    - [Usage](#usage)
        - [Help](#help)
        - [Export Model as SQL and or JSON array](#export-model-as-sql-and-or-json-array)
        - [Load JSON output to MongoDB](#load-json-output-to-mongodb)
    - [Sample Models](#sample-models)
    - [Contributing](#contributing)

## Note for Windows Users
This application requires Perl to be installed and on your path. [Active Perl](https://en.wikipedia.org/wiki/ActivePerl) is one alternative for installing a Perl interpreter.

If you have *chocolatey* installed, you can use the following command to install Active Perl.

```powershell
choco install activeperl
```

## Installation
**Installing may require elevated privileges.** If you want to run without installing, see [Run Without Installing](#run-without-installing)

### Install using cpan

```powershell
cpan install .
```

### Install using cpanm

```powershell
cpanm install .
```

### Install using Module::Build

```powershell
perl Build.PL
./Build clean         # Clean up build files
./Build installdeps   # Install any missing dependencies. May require superuser privs
./Build               # After this step, you should have entry point(s) in .\blib\script
./Build test          # Run tests for cromulency 
./Build install       # Add entry point(s) to your path. May require superuser privs
```

See https://metacpan.org/pod/Module::Build for more info on Module::Build

### Install using Make

```bash
# *nix
perl Makefile.PL
make
make test
make install

```

```powershell
# Activeperl
perl Makefile.PL
dmake.exe
dmake.exe test
dmake.exe install

```

### Manual Dependency Install
If you don't want to or can't install dependencies via `Build installdeps`, you can install them manually via your favorite management system.

[The dependency list can be reviewed here](MYMETA.json).

#### Example Commands To Install Log Log4perl On Various Platforms
- `cpan install Log::Log4perl (cpan)`
- `ppm install Log-Log4perl (ActivePerl)`
- `sudo apt install liblog-log4perl-perl (Ubuntu/Debian)`
- `sudo yum install perl-Log-Log4perl (CentOS/RedHat)`

### Troubleshooting
Users have reporting issues installing certain modules on Windows platforms. If one or more libraries fail to load due to failing tests on Windows, consider installing with the force flag turned on:
```powershell
cpan install -f Log::Log4perl
```
## Run Without Installing

You can run the model-citizen app without installing by invoking it in the `./script` directory. 

Note, you will have to [install any missing dependencies manually](#manual-dependency-install). If you have locally downloaded libraries, you can add them to `@INC` via the `-I` flag when invoking the Perl interpreter. [See the official perlrun documentation for more info](http://perldoc.perl.org/perlrun.html). 
 
```powershell
perl -I '.\vendor' .\script\model-citizen --help
```

## Usage

### Help
Print usage info
```powershell
model-citizen --help
```
### Export Model as SQL and or JSON array
Load up data modeler files and generate a DDL SQL output file and a json output file
```powershell
model-citizen  --outputFileSQL ./scratch/model.sql --outputFileJSON ./scratch/model.json --modelFilepath C:\git\datamodels\MY_AWESOME_DATA_MODEL\
```

### Load JSON output to MongoDB
The json output is an array of documents describing the data model. These can be fed directly into mongoDB using a tool such as mongoimport using the --jsonArray option.
```powershell
mongoimport.exe --db model-citizen --collection model --file "C:\git\model-citizen\scratch\model.json"
 --host localhost:27017 -v --stopOnError --jsonArray;
```

## Sample Models
Sample data models can be [found here](https://www.oracle.com/technetwork/developer-tools/datamodeler/sample-models-scripts-224531.html).

## Contributing
If you are interested in contributing to the project, please check out our [Contributor's Guide](CONTRIBUTING.md).

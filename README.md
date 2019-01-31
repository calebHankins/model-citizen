# MODEL-CITIZEN

_I am the very model of modern meta generable_



[![Master Build](https://img.shields.io/travis/Acxiom/model-citizen/master.svg?label=Master&nbsp;Build)](https://travis-ci.org/Acxiom/model-citizen?branch=master)
[![Master Coverage](https://img.shields.io/coveralls/github/Acxiom/model-citizen/master.svg?label=Master&nbsp;Coverage)](https://coveralls.io/github/Acxiom/model-citizen/?branch=master)
[![Develop Build](https://img.shields.io/travis/Acxiom/model-citizen/develop.svg?label=Develop&nbsp;Build)](https://travis-ci.org/Acxiom/model-citizen?branch=develop)
[![Develop Coverage](https://img.shields.io/coveralls/github/Acxiom/model-citizen/develop.svg?label=Develop&nbsp;Coverage)](https://coveralls.io/github/Acxiom/model-citizen/?branch=develop)

<img src="logo/logo.png" width="200">


Export Oracle Data Modeler files as json and or SQL DDL for easier consumption by other processes.

----

- [MODEL-CITIZEN](#model-citizen)
  - [Description](#description)
  - [Installation](#installation)
    - [Docker](#docker)
      - [Build](#build)
      - [Run](#run)
    - [Native](#native)
      - [Note for Windows Users](#note-for-windows-users)
      - [Install using cpanm](#install-using-cpanm)
        - [Using git repository directly](#using-git-repository-directly)
          - [Github](#github)
          - [Generic Repository](#generic-repository)
        - [Using local files](#using-local-files)
        - [Installing cpanm (App::cpanminus)](#installing-cpanm-appcpanminus)
      - [Install using cpan](#install-using-cpan)
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

## Description
This tool was developed to feed downstream continuous integration processes (like [join-hero](https://github.com/Acxiom/join-hero)) using objects modeled by the graphical tool [Oracle SQL Developer Data Modeler](https://www.oracle.com/database/technologies/appdev/datamodeler.html). It was created to support version 18.2 of Oracle SQL Developer Data Modeler and Oracle Database 12c export type, primarily focused on tables, indexes and foreign keys. Your milage may vary for other targets and Data Modeler versions.



## Installation
**Installing may require elevated privileges.** If you want to run without installing, see [Run Without Installing](#run-without-installing). The following commands that reference '.' should be executed from the same folder in which this README file can be found.

### Docker
#### Build
```powershell
docker build -t model-citizen .
```

#### Run
```powershell
# Print version info
docker run model-citizen --version
```

See the [official Docker documentation](https://docs.docker.com/engine) for more details. In particular, using [volumes](https://docs.docker.com/storage/volumes/) will be handy so the container can interact with the native filesystem.

```powershell
# Mount local filesystem and use in the container
docker run -it -v 'Z:\MY_COOL_MODELS\JJJ_DataModel\JJJ:/mnt/mydatamodel' model-citizen -i /mnt/mydatamodel/ -o /mnt/mydatamodel/model-citizen-out.ddl
```

### Native

#### Note for Windows Users
This application requires Perl to be installed and on your path. [Active Perl](https://en.wikipedia.org/wiki/ActivePerl) is one alternative for installing a Perl interpreter.

If you have *chocolatey* installed, you can use the following command to install Active Perl.

```powershell
choco install activeperl
```

#### Install using cpanm
cpanm is the easiest and most modern way to install. If you don't have cpanm on your path, check out [Installing cpanm](#installing-cpanm-appcpanminus)

##### Using git repository directly

###### Github
Install directly from a github repository.
```powershell
cpanm git://github.com/Acxiom/model-citizen.git
```

By default it will install the Master branch version. If you want another version, you can specify with the `@` symbol after the URL.

```powershell
# Install the current development build
cpanm git://github.com/Acxiom/model-citizen.git@develop
```

[Video showing cpanm github install example](https://www.youtube.com/watch?feature=player_embedded&v=6Vglyf7X2S8#t=5m).

###### Generic Repository
If this code repo is in BitBucket / Stash / Gitlab etc, you can use the checkout url that you would normally use for git.
```powershell
cpanm https://<YOUR_USER_HERE>@<REPO_HOST_HERE>/<PATH_TO_GIT_HERE>.git@<BRANCH_HERE / COMMIT_HASH_HERE>
```
##### Using local files
If you've checkout out the repository or unpacked the release tarball, you can run the following from the folder containing this README:
```powershell
# Install from the directory the README file is in after unpacking the tar.gz
cpanm .
```


##### Installing cpanm (App::cpanminus)
https://metacpan.org/pod/App::cpanminus#INSTALLATION


#### Install using cpan

```powershell
cpan .
```

#### Install using Module::Build

```powershell
perl Build.PL
./Build clean         # Clean up build files
./Build installdeps   # Install any missing dependencies. May require superuser privs
./Build               # After this step, you should have entry point(s) in .\blib\script
./Build test          # Run tests for cromulency 
./Build install       # Add entry point(s) to your path. May require superuser privs
```

See https://metacpan.org/pod/Module::Build for more info on Module::Build

#### Install using Make

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

#### Manual Dependency Install
If you don't want to or can't install dependencies via `Build installdeps`, you can install them manually via your favorite management system.

[The dependency list can be reviewed here](META.yml).

##### Example Commands To Install Log Log4perl On Various Platforms
- `cpan install Log::Log4perl (cpan)`
- `ppm install Log-Log4perl (ActivePerl)`
- `sudo apt install liblog-log4perl-perl (Ubuntu/Debian)`
- `sudo yum install perl-Log-Log4perl (CentOS/RedHat)`

#### Troubleshooting
Users have reporting issues installing certain modules on Windows platforms. If one or more libraries fail to load due to failing tests on Windows, consider installing with the force flag turned on:
```powershell
cpan install -f Log::Log4perl
```
### Run Without Installing

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

*Note: These models may be an older format (v2.x or v3.x) and will yield better results if upgraded using a more recent version of the Data Modeler utility.*

## Contributing
If you are interested in contributing to the project, please check out our [Contributor's Guide](CONTRIBUTING.md).

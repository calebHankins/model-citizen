# MODEL-CITIZEN

_I am the very model of modern meta generable_

Export Oracle Data Modeler files as json and or SQL DDL for easier consumption by other processes 

- [MODEL-CITIZEN](#model-citizen)
  - [Note for Windows Users](#note-for-windows-users)
- [chocolatey](#chocolatey)
  - [Installation](#installation)
  - [Usage](#usage)
    - [Help](#help)
    - [Export Model as SQL and or JSON array](#export-model-as-sql-and-or-json-array)
    - [Load JSO output to MongoDB](#load-jso-output-to-mongodb)

## Note for Windows Users
This application requires Perl to be installed and on your path. [Active Perl](https://en.wikipedia.org/wiki/ActivePerl) is one alternative for installing a Perl interpreter. 

If you have *chocolatey* installed, you can use the following command to install Active Perl.
```powershell
# chocolatey
choco install activeperl
```

## Installation

```powershell
perl Build.PL
./Build installdeps   # Install any missing dependencies. May require superuser privs
./Build               # After this step, you should have entry point(s) in .\blib\script
./Build test          # Run tests for cromulency 
./Build install       # Add entry point(s) to your path. May require superuser privs
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
model-citizen  --outputFileSQL ./scratch/ddl.sql --outputFileJSON ./scratch/model.json --modelFilepath C:\git\datamodels\MY_AWESOME_DATA_MODEL\
```

### Load JSO output to MongoDB
The json output is an array of documents describing the data model. These can be fed directly into mongoDB using a tool such as mongoimport using the --jsonArray option.
```powershell
mongoimport.exe --db join-hero --collection model --file "C:\git\model-citizen\scratch\model.json"
 --host localhost:27017 -v --stopOnError --jsonArray --mode upsert --upsertFields "name,type";
```


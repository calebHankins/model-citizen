# MODEL-CITIZEN

_I am the very model of modern meta generable_

Export Oracle Data Modeler files as json and or SQL DDL for easier consumption by other processes 

- [MODEL-CITIZEN](#model-citizen)
  - [Installation](#installation)
  - [Usage](#usage)

## Installation

 ```powershell
perl Build.PL
./Build installdeps  # this step may require superuser privs
./Build
./Build test
./Build install  # this step may require superuser privs
```

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


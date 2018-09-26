# MODEL-CITIZEN

Export Oracle Data Modeler files as json and or SQL DDL for easier consumption by other processes 

- [MODEL-CITIZEN](#model-citizen)
  - [Installation](#installation)
    - [Example commands to install Log::Log4perl on various platforms](#example-commands-to-install-loglog4perl-on-various-platforms)
  - [Usage](#usage)


## Installation

Install dependent perl libraries via your favorite management system

### Example commands to install Log::Log4perl on various platforms
- `cpan install Log::Log4perl (cpan)`
- `ppm install Log-Log4perl (ActivePerl)`
- `sudo apt install liblog-log4perl-perl (Ubuntu/Debian)`
- `sudo yum install perl-Log-Log4perl (CentOS/RedHat)`

## Usage

```powershell
# Print usage info
perl model_citizen.pl --help

```


```powershell
# Load up data modeler files and generate a DDL SQL output file and a json output file
perl model_citizen.pl  --outputFileSQL ./scratch/ddl.sql --outputFileJSON ./scratch/model.json -f C:\git\datamodels\MY_AWESOME_DATA_MODEL\

```


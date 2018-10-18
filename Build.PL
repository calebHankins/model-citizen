package ModelCitizen;

use 5.0101;
use strict;
use warnings;

use Module::Build;

#todo, need to install types file as well

my $build = Module::Build->new(
  module_name   => 'ModelCitizen',
  license       => 'apache',
  dist_abstract => 'Export Oracle Data Modeler files as json and or SQL DDL for easier consumption by other processes ',
  dist_author   => 'Caleb Hankins (caleb.hankins at acxiom.com)',
  script_files       => 'script/model-citizen',
  requires           => {
               'perl'             => '5.10.1',
               'JSON'             => '0',
               'XML::Twig'        => '0',
               'LWP::UserAgent'   => '0',
               'Data::Dumper'     => '0',
               'HTML::Entities'   => '0',
               'URI::Escape'      => '0',
               'File::Path'       => '0',
               'File::Basename'   => '0',
               'Text::ParseWords' => '0',
               'Log::Log4perl'    => '0',
               'IO::Handle'       => '0',
               'Getopt::Long'     => '0',
               'Pod::Usage'       => '0',
               'Cwd'              => '0',
               'experimental'     => '0',
  },
);
$build->create_build_script;

1;

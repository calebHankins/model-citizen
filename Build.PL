package ModelCitizen;

use 5.0100;
use strict;
use warnings;

use Module::Build;

my $build = Module::Build->new(
  module_name   => 'ModelCitizen',
  license       => 'apache',
  dist_abstract => 'Export Oracle Data Modeler files as json and or SQL DDL for easier consumption by other processes ',
  dist_author   => 'Caleb Hankins (caleb.hankins at acxiom.com)',
  script_files  => 'script/model-citizen',
  release_status => 'unstable',
  requires       => {
               'perl'             => '5.10.1',
               'JSON'             => '0',
               'XML::Twig'        => '0',
               'Data::Dumper'     => '0',
               'File::Path'       => '0',
               'File::Basename'   => '0',
               'File::Glob'       => '0',
               'Text::ParseWords' => '0',
               'Log::Log4perl'    => '0',
               'IO::Handle'       => '0',
               'Getopt::Long'     => '0',
               'Pod::Usage'       => '0',
               'Cwd'              => '0',
  },
  recommended_requires =>
    {'English' => '0', 'Test::Perl::Critic' => '0', 'Test::Code::TidyAll' => '0', 'Perl::Tidy' => '0',},
  configure_requires => {'Module::Build' => '0'},
  create_makefile_pl => 'traditional',
);

# Install any data files in /lib
$build->add_build_element('xml');
$build->add_build_element('json');
$build->add_build_element('dat');

$build->create_build_script;

1;

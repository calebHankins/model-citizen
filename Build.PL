use 5.0101;

use strict;
use warnings;

use Module::Build;
my $build = Module::Build->new(
  module_name   => 'modelCitizen',
  license       => 'Apache',
  dist_abstract => 'Export Oracle Data Modeler files as json and or SQL DDL for easier consumption by other processes ',
  dist_author   => 'Caleb Hankins (caleb.hankins at acxiom.com)',
  requires      => {
               'perl'               => '5.10.1',
               'JSON'               => '0',
               'XML::Simple'        => '0',
               'XML::Twig'          => '0',
               'LWP::UserAgent'     => '0',
               'Data::Dumper'       => '0',
               'HTML::Entities'     => '0',
               'URI::Escape'        => '0',
               'File::Path'         => '0',
               'File::Basename'     => '0',
               'Text::ParseWords'   => '0',
               'Log::Log4perl'      => '0',
               'local::lib'         => '0',
               'Astro::SpaceTrack ' => '0'
  },
);
$build->create_build_script;

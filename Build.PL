use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name       => 'App::PortDistances',
    license           => 'gpl3',
    dist_author       => 'Pedro Silva <pedros@berkeley.edu>',
    dist_version      => '0.0.1',
    dist_abstract     => 'App::PortDistances',
    requires          => {
        'Cache::File'          => 0,
        'Carp'                 => 0,
        'constant'             => 0,
        'Cwd'                  => 0,
        'Digest::MD5'          => 0,
        'File::Spec'           => 0,
        'FindBin'              => 0,
        'GIS::Distance'        => 0,
        'Graph'                => 0,
        'JSON'                 => 0,
        'lib'                  => 0,
        'MooseX::Declare'      => 0,
        'MooseX::Types'        => 0,
        'MooseX::Types::Moose' => 0,
        'MooseX::Getopt'       => 0,
        'String::Approx'       => 0,
        'Test::More'           => 0,
        'Carp'                 => 0,
    },
    add_to_cleanup     => ['App::PortDistances-*'],
    create_makefile_pl => 'traditional',
    script_files       => ['script/gpd'],
    sign               => 1,
    create_readme      => 1,
    create_license     => 1,
);

$builder->create_build_script();

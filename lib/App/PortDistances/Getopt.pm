use MooseX::Declare;

class App::PortDistances::Getopt {
    
    use FindBin;
    use lib File::Spec->catdir( $FindBin::Bin, ('..') x 3, 'lib' );
    
    with 'MooseX::Getopt';
    use MooseX::Types::Moose qw/HashRef/;

    use App::PortDistances::Types qw/File StrArray/;
    use App::PortDistances::DB;
    use App::PortDistances::Cache;
    
    # MooseX::Getopt::OptionTypeMap->add_option_type_to_map('File' => '=s');
    # MooseX::Getopt::OptionTypeMap->add_option_type_to_map('DB'   => '=s');

    has [qw/source target/] => (
        is       => 'ro',
        isa      => StrArray,
        coerce   => 1,
        required => 0,
        documentation =>
            'list of port names to be used as in/out-bound vertices',
    );

    has 'db' => (
        is            => 'ro',
        isa           => File,
        required      => 0,
        lazy          => 1,
        default       => sub { App::PortDistances::DB->DB_FILE },
        documentation => 'source database in JSON format',
    );

    has 'cache' => (
        is            => 'ro',
        isa           => File,
        default       => sub { App::PortDistances::Cache->CACHE_ROOT },
        documentation => 'Cache directory',
    );

    has 'filter' => (
        is => 'ro',
        isa => HashRef,
    );
};

use Data::Dumper;
my $o = App::PortDistances::Getopt->new_with_options;
print Dumper $o->db, $o->cache, $o->filter;

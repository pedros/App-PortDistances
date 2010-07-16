use MooseX::Declare;

class App::PortDistances::Getopt {

    use Data::Dumper;
    use FindBin;
    use lib File::Spec->catdir( $FindBin::Bin, ('..') x 3, 'lib' );

    with 'MooseX::Getopt';
    use MooseX::Types::Moose qw/HashRef/;

    use App::PortDistances::Types qw/File StrArray/;
    use App::PortDistances::DB;
    use App::PortDistances::Cache;

    has [qw/source target/] => (
        is       => 'rw',
        isa      => StrArray,
        coerce   => 1,
        required => 0,
        documentation =>
            'list of port names to be used as in/out-bound vertices',
    );

    has 'db' => (
        is            => 'ro',
        isa           => File,
        required      => 1,
        lazy          => 1,
        default       => sub { App::PortDistances::DB->DB_FILE },
        documentation => 'source database in JSON format',
    );

    has '_db' => (
        is       => 'rw',
        isa      => 'App::PortDistances::DB',
        required => 1,
        lazy     => 1,
        default =>
            sub { App::PortDistances::DB->new( db_file => shift->db ) },
    );

    has 'cache' => (
        is            => 'ro',
        isa           => File,
        required      => 0,
        default       => sub { App::PortDistances::Cache->CACHE_ROOT },
        documentation => 'Cache directory',
    );

    has '_cache' => (
        is       => 'ro',
        isa      => 'App::PortDistances::Cache',
        required => 0,
        lazy     => 1,
        default  => sub {
            App::PortDistances::Cache->new( cache_root => shift->cache );
        },
    );

    has 'filter-db' => (
        is      => 'ro',
        isa     => HashRef,
        trigger => sub {
            my $self = shift;
            my $db = App::PortDistances::DB->new( db_file => $self->db );
            $db->db;
            $self->_db( $db->find( %{ shift @_ } ) );
        },
    );

    has 'filter-source' => (
        is      => 'ro',
        isa     => HashRef,
        trigger => sub {
            my $self = shift;
            my $db = App::PortDistances::DB->new( db_file => $self->db );
            $db->db;
            $self->source( $db->find( %{ shift @_ } ) );
        },
    );

    has 'filter-target' => (
        is      => 'ro',
        isa     => HashRef,
        trigger => sub {
            my $self = shift;
            my $db = App::PortDistances::DB->new( db_file => $self->db );
            $db->db;
            $self->target( $db->find( %{ shift @_ } ) );
        },
    );
};

use Data::Dumper;
my $o = App::PortDistances::Getopt->new_with_options;
$o->_db->db;
print Dumper $o;

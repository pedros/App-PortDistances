use MooseX::Declare;

class App::PortDistances::Getopt {

    with 'MooseX::Getopt';
    use MooseX::Types::Moose qw/HashRef/;

    use App::PortDistances::Types qw/File StrArray/;
    use App::PortDistances::DB;
    use App::PortDistances::Cache;

    has [qw/sources targets/] => (
        is     => 'rw',
        isa    => StrArray,
        coerce => 1,
        documentation =>
            'list of port names to be used as in/out-bound vertices',
    );

    has 'db' => (
        is            => 'rw',
        isa           => File,
        default       => App::PortDistances::DB::DB_FILE,
        documentation => 'source database in JSON format',
    );

    has 'cache' => (
        is            => 'ro',
        isa           => 'Str',
        default       => App::PortDistances::Cache::CACHE_ROOT,
        documentation => 'cache directory',
    );

    has 'filter-db' => (
        reader        => 'filter_db',
        is            => 'ro',
        isa           => HashRef,
        documentation => 'filter list of ports that compose the graph',
    );

    has 'filter-sources' => (
        reader        => 'filter_sources',
        is            => 'ro',
        isa           => HashRef,
        documentation => 'filter list of source ports',
    );

    has 'filter-targets' => (
        reader        => 'filter_targets',
        is            => 'ro',
        isa           => HashRef,
        documentation => 'filter list of target ports',
    );

    has 'distance-matrix' => (
        reader        => 'distance_matrix',
        is            => 'ro',
        isa           => 'Bool',
        documentation => 'print the all-pairs shortest path distance matrix',
    );

    has 'details' => (
        is  => 'ro',
        isa => 'Bool',
        documentation => 'print graph details',
    );

    has 'help' => ( is => 'ro', documentation => 'this document' );
};

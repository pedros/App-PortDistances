package App::PortDistances;

use Moose;
use Moose::Util::TypeConstraints;
with 'MooseX::Getopt';

#use Graph::Directed;
use Cache::File;
use JSON;

subtype 'File'
    => as 'ArrayRef[Str]';
subtype 'DB'
    => as 'HashRef[HashRef]';

coerce 'File'
    => from 'Str'
    => via {
        open my $IN, q{<}, $_ or return [$_];
        chomp (my @Strs = <$IN>);
        [@Strs];
    };
coerce 'DB'
    => from 'Str'
    => via {
        local $/;
        open my $IN, q{<}, $_ or die $!;
        decode_json( <$IN> );
    };
MooseX::Getopt::OptionTypeMap->add_option_type_to_map('File' => '=s');
MooseX::Getopt::OptionTypeMap->add_option_type_to_map('DB'   => '=s');

has [qw/source target/] => (
    is  => 'ro',
    isa => 'File',
    coerce => 1,
    required => 1,
    documentation => 'list of port names to be used as in/out-bound vertices',
);
has 'db' => (
    is => 'rw',
    isa => 'DB',
    coerce => 1,
    required => 1,
    documentation => 'source database in JSON format',
);
has 'clear-cache' => (
    is => 'ro',
    isa => 'Bool',
    default => 0,
    lazy => 1,
    trigger => sub { $_[0]->_cache->clear },
    documentation => 'avoid using stale data for new computations',
);
has '_graph' => (
    is => 'rw',
    isa => 'Graph',
    default => \&_build_graph,
    lazy => 1,
);
has '_cache' => (
    is => 'ro',
    isa => 'Cache::File',
    default => \&_build_cache,
    lazy => 1,
);




sub _build_graph {
    my ($self) = @_;

    return unless $self->db;
    my $graph = Graph->new;
    
 SOURCE:
    while ( my ( undef, $source ) = each %{$self->db} ) {
    TARGET:
        for my $target ( @{ $source->{ports} } ) {
            $graph->add_weighted_path( $source->{name}, $target->{distance}, $target->{name} );
        }
    }
    return $graph;
}

sub _build_cache {
    my ($self) = @_;
    
    my $home_dir   = $ENV{HOME} || $ENV{HOMEPATH} || File::Spec->curdir;
    my $cache_dir  = '.port';
    my $cache_root = File::Spec->catdir( $home_dir, $cache_dir );
    my $cache = Cache::File->new(
        cache_root      => $cache_root,
        default_expires => 60 * 60 * 24 * 7 * 31,
    );
    return $cache;
}

1;



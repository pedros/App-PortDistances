package App::PortDistances::Graph;

use Graph::Directed;
use FindBin qw//;

use Moose;
use MooseX::Method::Signatures;

use Data::Dumper;
use lib File::Spec->catdir( $FindBin::Bin, ('..') x 3, 'lib' );

use App::PortDistances::DB;

has '_db' => (
    is       => 'ro',
    isa      => 'App::PortDistances::DB',
    default  => sub { App::PortDistances::DB->new },
    lazy     => 1,
    required => 1,
    clearer  => '_clear__db',
);

has 'graph' => (
    is       => 'ro',
    isa      => 'Graph',
    builder  => '_build_graph',
    lazy     => 1,
    handles => {
        SPT_Dijkstra => 'SPT_Dijkstra',
        APSP_Floyd_Warshall => 'APSP_Floyd_Warshall', 
    }
);

sub _build_graph {
    my ($self) = @_;

    my $graph = Graph->new;

SOURCE:
    for my $source ( $self->_db->ports ) {
        $graph->set_vertex_attribute( $source->name, 'latitude',  $source->latitude  );
        $graph->set_vertex_attribute( $source->name, 'longitude', $source->longitude );

    TARGET:
        for my $target ( $self->_db->details($source->targets) ) {
            next TARGET unless defined $target;
            
            $graph->set_vertex_attribute( $target->name, 'latitude',  $target->latitude  );
            $graph->set_vertex_attribute( $target->name, 'longitude', $target->longitude );
            $graph->add_weighted_path( $source->name, $source->distance($target), $target->name );
        }
    }
    
    $self->_clear__db;
    return $graph;
}

sub graph_details {
    my ($self) = @_;

    my @density_limits = $self->density_limits;

    return density => $self->density,
        edges      => scalar $self->edges,
        vertices   => scalar $self->vertices,
        sparse     => $density_limits[0],
        dense      => $density_limits[1],
        complete   => $density_limits[2];
}

method shortest_paths (ArrayRef[Str] :$sources? = [], ArrayRef[Str] :$targets? = [], Bool :$apsp? = 0) {
    my ($SP, %paths);

    $SP = $self->APSP_Floyd_Warshall if $apsp;
 SOURCE:
    for my $source (@$sources ? @$sources : $self->vertices) {
        my $SP = $self->SPT_Dijkstra($source) unless $apsp;

    TARGET:
        for my $target (@$targets ? @$targets : $SP->vertices) {

            my $current = $target;
        CURRENT:
            while ( defined $current ) {
                my $predecessor
                    = $SP->get_vertex_attribute( $current, q{p} );

                next TARGET unless $predecessor;

                my $weight
                    = $SP->get_edge_attribute( $predecessor, $current,
                    'weight' );

                unshift @{ $paths{$source}{$target} }, [ $current, $weight ];
                $current = $predecessor;
            }
        }
    }

    return \%paths;
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;

__END__
my $o = App::PortDistances::Graph->new;
$o->graph;
print Dumper $o->shortest_paths( apsp => 1, sources => ['Setubal, Portugal'] );exit;


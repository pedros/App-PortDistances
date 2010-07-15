use MooseX::Declare;

class App::PortDistances::Graph {

    use Graph;
    use FindBin;

    use lib File::Spec->catdir( $FindBin::Bin, ('..') x 3, 'lib' );

    use App::PortDistances::DB;

    has '_db' => (
        is       => 'rw',
        isa      => 'App::PortDistances::DB',
        default  => sub { App::PortDistances::DB->new },
        lazy     => 1,
        required => 1,
        clearer  => '_clear__db',
        handles  => { 'find' => 'find' },
    );

    has 'graph' => (
        is       => 'ro',
        isa      => 'Graph',
        builder  => '_build_graph',
        lazy     => 1,
        required => 1,
        handles  => {
            SPT_Dijkstra        => 'SPT_Dijkstra',
            APSP_Floyd_Warshall => 'APSP_Floyd_Warshall', 
            vertices            => 'vertices',
            density_limits      => 'density_limits',
        }
    );

    has 'apsp' => (
        is      => 'ro',
        isa     => 'Graph',
        default => sub { shift->APSP_Floyd_Warshall },
        lazy    => 1,
    );

    has 'sssp' => (
        is      => 'ro',
        isa     => 'Graph',
        default => sub { shift->SPT_Dijkstra },
        lazy    => 1,
    );

    method _build_graph {
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
                $graph->add_weighted_path( $source->name, $source->distance($target->name), $target->name );
            }
        }
        #$self->_clear__db;
        return $graph;
    };
    
    method graph_details {
        my @density_limits = $self->density_limits;

        return (density    => $self->density,
                edges      => scalar $self->edges,
                vertices   => scalar $self->vertices,
                sparse     => $density_limits[0],
                dense      => $density_limits[1],
                complete   => $density_limits[2]);
    };

    method _apsp_to_graph {
        my $graph = Graph->new;
        $self->apsp->for_shortest_paths(
            sub {
                my ($apsp, $source, $target, $i) = @_;
                my $weight = $apsp->path_length( $source, $target );
                $graph->add_weighted_path(
                    $source,
                    $weight,
                    $target
                );
            }
        );
        return $graph;
    }
 
    method _graph_to_matrix ( $graph! ) {
        my $matrix = Graph::Matrix->new( $graph );
    SOURCE:
        for my $source ( $graph->vertices ) {

        TARGET:
            for my $target ( $graph->vertices ) {
                $matrix->set(
                    $source,
                    $target,
                    $graph->get_edge_attribute( $source, $target, 'weight' )
                );
            }
        }
        return $matrix;
    }

    method _format_matrix ( $matrix! ) {
        my @sources
            = map  { $_->[0] }
              sort { $a->[3] <=> $b->[3] || $a->[2] <=> $b->[2] || $a->[1] cmp $b->[1] || $a->[0] cmp $b->[0] }
              map  { [ $_->name, $_->country, $_->latitude, $_->longitude ] }
                  $self->_db->details( $self->vertices );
        
        my @matrix = [undef, @sources];

        for my $source ( @sources ) {
            my @row = ($source);
            for my $target ( @sources ) {
                push @row, $matrix->get( $source, $target );
            }
            push @matrix, \@row;
        }
        return \@matrix;
    }
    
    method shortest_paths (ArrayRef[Str] :$sources? = [], ArrayRef[Str] :$targets? = [], Bool :$apsp? = 0) {
        my $graph  = Graph->new;
        my $SP = $self->APSP_Floyd_Warshall if $apsp;

        return $SP;
    SOURCE:
        for my $source (@$sources ? @$sources : $self->vertices) {
            $SP = $self->SPT_Dijkstra( $source ) unless $apsp;

        TARGET:
            for my $target (@$targets ? @$targets : $self->vertices) {

                my $predecessor
                    = $SP->get_vertex_attribute( $target, q{p} )
                        || next TARGET;
                
                my $weight
                    = $SP->get_edge_attribute( $predecessor, $target, 'weight' );

                $graph->add_weighted_path(
                    $source,
                    $weight,
                    $target
                );
            }
        }
        return $graph;
    }
};

use Data::Dumper;
my $o = App::PortDistances::Graph->new;
$o->_db($o->find( quadrant => 'SW' ));
my $m = $o->_format_matrix( $o->_graph_to_matrix( $o->_apsp_to_graph ) );

for my $row ( @$m ) {

    print join( "\t", map { defined $_ ? $_ : q{} } @$row ), "\n";

}

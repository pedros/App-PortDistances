use MooseX::Declare;

class App::PortDistances::Graph {

    use Graph;
    use FindBin;

    use lib File::Spec->catdir( $FindBin::Bin, ('..') x 3, 'lib' );

    use App::PortDistances::DB;
    use App::PortDistances::Cache;

    has '_db' => (
        is       => 'rw',
        isa      => 'App::PortDistances::DB',
        lazy     => 1,
        required => 1,
        clearer  => '_clear__db',
        handles  => { 'find' => 'find' },
        default  => sub { App::PortDistances::DB->new },
    );

    has '_cache' => (
        is       => 'rw',
        isa      => 'App::PortDistances::Cache',
        required => 1,
        lazy     => 1,
        default  => sub { App::PortDistances::Cache->new },
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
        is      => 'rw',
        isa     => 'Graph',
        default => sub { shift->APSP_Floyd_Warshall },
        lazy    => 1,
    );

    has 'sssp' => (
        is      => 'rw',
        isa     => 'Graph',
        default => sub { shift->SPT_Dijkstra( shift ) },
        lazy    => 1,
    );
    
    around apsp {
        my $key = join q{:}, 'apsp', sort $self->_db->port_names;

        print STDERR "Got apsp from cache\n" and return $self->_cache->get( $key )
            if $self->_cache->in( $key );

        print STDERR "Computing apsp into cache\n";
        my $struct = $self->$orig;
        $self->_cache->set( $key, $struct );
        return $struct;
    };

    around sssp ( $source! ) {
        my $key = join q{:}, $source, sort $self->_db->port_names;
        
        print STDERR "Got sssp for $source from cache\n" and return $self->_cache->get( $key )
            if $self->_cache->in( $key );

        print STDERR "Computing sssp into cache\n";
        my $struct = $self->$orig( $source );
        $self->_cache->set( $key, $struct );
        return $struct;
    };

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
    };

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

    method _sssp_to_paths ( Str $source!, ArrayRef[Str] $targets! = [] ) {
        my %paths;
        my $sssp = $self->sssp( $source );
        
    TARGET:
        for my $target (@$targets ? @$targets : $self->vertices) {

            my $current = $target;
        CURRENT:
            while ( defined $current ) {
                my $predecessor = $sssp->get_vertex_attribute( $current, 'p' )
                    || next TARGET;
                my $weight = $sssp->get_edge_attribute( $predecessor, $current, 'weight' );                
                unshift @{ $paths{$target} }, [ $current, $weight ];
                $current = $predecessor;
            }
        }
        return \%paths
    };
    
    method shortest_paths (ArrayRef[Str] :$sources? = [], ArrayRef[Str] :$targets? = [], Bool :$distance_matrix? = 0 ) {

        return $self->_format_matrix( $self->_graph_to_matrix( $self->_apsp_to_graph ) )
            if @$sources > 1 or $distance_matrix;

        my %paths;
    SOURCE:
        for my $source (@$sources ? @$sources : $self->vertices) {
            $paths{$source} = $self->_sssp_to_paths( $source, $targets );
        }
        return \%paths;
    }
};

use Data::Dumper;
my $o = App::PortDistances::Graph->new;
print Dumper $o->shortest_paths( sources => ['Setubal, Portugal', 'Lisboa, Portugal'] );

__END__
for my $row ( @$m ) {
    print join( "\t", map { defined $_ ? $_ : q{} } @$row ), "\n";
}

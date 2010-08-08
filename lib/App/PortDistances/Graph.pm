use MooseX::Declare;

class App::PortDistances::Graph {

    use Graph;
    use App::PortDistances::DB;
    use App::PortDistances::Cache;

    has 'db' => (
        is       => 'rw',
        isa      => 'App::PortDistances::DB',
        lazy     => 1,
        required => 1,
        clearer  => '_clear_db',
        handles  => { 'find' => 'find' },
        default  => sub { App::PortDistances::DB->new },
    );

    has 'cache' => (
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

    method apsp {
        my $key = join q{:}, 'apsp', sort $self->db->port_names;

        print STDERR "Got apsp from cache\n" and return $self->cache->get( $key )
        if $self->cache->in( $key );

        print STDERR "Computing apsp into cache\n";

        my $apsp = $self->APSP_Floyd_Warshall;

        $self->cache->set( $key, $apsp );
        return $apsp;
    }

    method sssp ( Str $source!, ArrayRef[Str] $targets? = [] ) {
        my $key = join q{:}, $source, sort $self->db->port_names;

        print STDERR "Got sssp for $source from cache\n"
        if $self->cache->in( $key );
        
        print STDERR "Computing sssp into cache\n"
        unless $self->cache->in( $key );
        
        my $sssp = $self->cache->in( $key ) ? $self->cache->get( $key ) : $self->SPT_Dijkstra( $source );

        if ($targets and @$targets) {
            my %targets = map { $_ => 1 } @$targets;

            TARGET:
            for my $target (@$targets ? @$targets : $self->vertices) {
                $sssp->delete_vertex( $target ) unless exists $targets{$target};
            }
        }

        $self->cache->set( $key, $sssp );
        return $sssp;
    }

    method _build_graph {
        my $graph = Graph->new;

        SOURCE:
        for my $source ( $self->db->ports ) {
            $graph->set_vertex_attribute( $source->name, 'latitude',  $source->latitude  );
            $graph->set_vertex_attribute( $source->name, 'longitude', $source->longitude );

            TARGET:
            for my $target ( $self->db->details($source->targets) ) {
                next TARGET unless defined $target;
                
                $graph->set_vertex_attribute( $target->name, 'latitude',  $target->latitude  );
                $graph->set_vertex_attribute( $target->name, 'longitude', $target->longitude );
                $graph->add_weighted_path( $source->name, $source->distance($target->name), $target->name );
            }
        }
        return $graph;
    }
    
    method graph_details {
        my @density_limits = $self->density_limits;

        return (density    => $self->density,
                edges      => scalar $self->edges,
                vertices   => scalar $self->vertices,
                sparse     => $density_limits[0],
                dense      => $density_limits[1],
                complete   => $density_limits[2]);
    }

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

    method _graph_to_matrix ( 
        $graph!,
        ArrayRef[Str] $sources? = [],
        ArrayRef[Str] $targets? = [] 
    ) {

        print STDERR "_graph_to_matrix ", `date`, "\n";
        my $matrix = Graph::Matrix->new( $graph );

        SOURCE:
        for my $source ( @$sources ?  @$sources : $graph->vertices) {

            TARGET:
            for my $target ( @$targets ? @$targets : $graph->vertices ) {
                $matrix->set(
                    $source,
                    $target,
                    $graph->get_edge_attribute( $source, $target, 'weight' )
                );
            }
        }
        return $matrix;
    }

    method _format_matrix (
        $matrix!,
        ArrayRef[Str] $sources? = [],
        ArrayRef[Str] $targets? = [] 
    ) {

        print STDERR "_format_matrix: ", `date`, "\n";

        my @sources
        = map  { $_->[0] }
        sort { $a->[3] <=> $b->[3] || $a->[2] <=> $b->[2] || $a->[1] cmp $b->[1] || $a->[0] cmp $b->[0] }
        map  { [ $_->name, $_->country, $_->latitude, $_->longitude ] }
        $self->db->details( @$sources ? @$sources : $self->vertices );
        
        my @targets
        = map  { $_->[0] }
        sort { $a->[3] <=> $b->[3] || $a->[2] <=> $b->[2] || $a->[1] cmp $b->[1] || $a->[0] cmp $b->[0] }
        map  { [ $_->name, $_->country, $_->latitude, $_->longitude ] }
        $self->db->details( @$targets ? @$targets : $self->vertices );

        my @matrix = [undef, @sources];

        for my $target ( @targets ) {
            my @row = ($target);

            for my $source ( @sources ) {
                push @row, $matrix->get( $source, $target );
            }
            push @matrix, \@row;
        }
        return \@matrix;
    }

    method _print_matrix ( ArrayRef[ArrayRef] $matrix! ) {
        for my $row ( @$matrix ) {
            print join( "\t", map { defined $_ ? $_ : q{} } @$row ), "\n";
        }
    }

    method _sssp_to_paths ( Str $source!, ArrayRef[Str] $targets! = [] ) {
        my %paths;
        my $sssp = $self->sssp( $source, $targets );

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
    }
    
    method _sssp_to_graph ( Str $source!, ArrayRef[Str] $targets? = [] ) {
        my $graph = Graph->new;
        my $sssp  = $self->sssp( $source, $targets );

        TARGET:
        for my $target (@$targets ? @$targets : $self->vertices) {

            my $current = $target;
            CURRENT:
            while ( defined $current ) {
                my $predecessor = $sssp->get_vertex_attribute( $current, 'p' )
                || next TARGET;
                my $weight = $sssp->get_edge_attribute( $predecessor, $current, 'weight' );                
                $graph->add_weighted_path(
                    $source,
                    $weight,
                    $current
                );
                $current = $predecessor;
            }
        }
        return $graph;
    }

    method shortest_paths (
        ArrayRef[Str] :$sources? = [],
        ArrayRef[Str] :$targets? = [], 
        Bool :$distance_matrix?  = 0
    ) {

        if ($distance_matrix) {
            if (@$sources > 1) {
                return $self->_print_matrix(
                    $self->_format_matrix(
                        $self->_graph_to_matrix(
                            $self->_apsp_to_graph
                        )
                    )
                );
            }
            else {
                return
                $self->_print_matrix(
                    $self->_format_matrix(
                        $self->_graph_to_matrix( 
                            $self->_sssp_to_graph(
                                $sources->[0],
                                $targets
                            ),
                            $sources,
                            $targets,
                        ),
                        $sources,
                        $targets,
                    ),
                );
            }
        }
        else {
            my %paths;
            SOURCE:
            for my $source (@$sources ? @$sources : $self->vertices) {
                $paths{$source} = $self->_sssp_to_paths( $source, $targets );
            }
            return \%paths;
        }
    }
}

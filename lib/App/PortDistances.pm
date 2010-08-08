use MooseX::Declare;

class App::PortDistances {

    use App::PortDistances::Getopt;
    use App::PortDistances::DB;
    use App::PortDistances::Cache;
    use App::PortDistances::Graph;

    sub run {
        my $opt = App::PortDistances::Getopt->new_with_options;

        my $cache = App::PortDistances::Cache->new(
            $opt->cache ? ( cache_root => $opt->cache ) : () );

        my $db = App::PortDistances::DB->new(
            $opt->db ? ( db_file => $opt->db ) : () );

        $db = $db->find( %{ $opt->filter_db } ) if $opt->filter_db;

        $opt->sources( [$db->find( %{ $opt->filter_sources } )->port_names] )
            if $opt->filter_sources;

        $opt->targets( [$db->find( %{ $opt->filter_targets } )->port_names] )
            if $opt->filter_targets;

        my $graph
            = App::PortDistances::Graph->new( db => $db, cache => $cache );

        $graph->shortest_paths(
            sources         => $opt->sources || [$db->port_names],
            targets         => $opt->targets || [$db->port_names],
            distance_matrix => $opt->distance_matrix
        );
    }
};

use MooseX::Declare;

class App::PortDistances::Cache {

    use File::Spec;
    use Cache::File;
    use Digest::MD5;

    has 'cache_root' => (
        is       => 'ro',
        isa      => File,
        required => 1,
        lazy     => 1,
        builder  => '_build_cache_root',
    );

    has 'cache' => (
        is      => 'ro',
        isa     => 'Cache::File' required => 1,
        lazy    => 1,
        builder => '_build_cache',
        clearer => '_clear_cache',
        handles => [qw/freeze thaw/]
    );

    method _build_cache_root {
        my $home_dir  = $ENV{HOME} || $ENV{HOMEPATH} || File::Spec->curdir;
        my $conf_dir  = '.port_distances';
        my $conf_path = File::Spec->catdir( $home_dir, $conf_dir );
    };

    method _build_cache {
        return Cache::File->new(
            cache_root      => $self->cache_root,
            default_expires => 60 * 60 * 24 * 7,
        );
    };

    method _clear_cache {
        $self->cache->clear;
    };

    before [qw/freeze thaw/] {
        $_[0] = Digest::MD5->new->add( $_[0] )->hexdigest;
    };

}

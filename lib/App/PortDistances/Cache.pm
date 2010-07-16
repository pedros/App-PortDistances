use MooseX::Declare;

class App::PortDistances::Cache {

    use File::Spec;
    use FindBin;
    use lib File::Spec->catdir( $FindBin::Bin, ('..') x 3, 'lib' );
    use Cwd;
    use constant CACHE_ROOT => File::Spec->catdir( $ENV{HOME}
            || $ENV{HOMEPATH}
            || File::Spec->curdir,
        '.port_distances' );

    use Cache::File;
    use Digest::MD5;

    use App::PortDistances::Types qw/File/;

    has 'cache_root' => (
        is       => 'ro',
        isa      => File,
        required => 1,
        lazy     => 1,
        default  => CACHE_ROOT,
    );

    has 'cache' => (
        is              => 'ro',
        isa             => 'Cache::File',
        required        => 1,
        lazy            => 1,
        builder         => '_build_cache',
        clearer         => '_clear_cache',
    );

    method _build_cache {
        Cache::File->new(
            cache_root => $self->cache_root,
        );
    };

    method _clear_cache {
        $self->cache->clear;
    };

    method freeze ( $key!, $value! ) {
        $self->cache->freeze( Digest::MD5->new->add($key)->hexdigest, $value );
    }

    method thaw ( $key! ) {
        $self->cache->thaw( Digest::MD5->new->add($key)->hexdigest );
    }
}

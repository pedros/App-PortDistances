use MooseX::Declare;

class App::PortDistances::Cache {

    use FindBin;
    use lib File::Spec->catdir( $FindBin::Bin, ('..') x 3, 'lib' );

    use File::Spec;
    use Cwd;
    use Cache::File;
    use Digest::MD5;
    use constant CACHE_ROOT => File::Spec->catdir( $ENV{HOME}
                                                || $ENV{HOMEPATH}
                                                || File::Spec->curdir,
                                                   '.port_distances' );

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
        default         => sub { Cache::File->new( cache_root=> shift->cache_root ) },
        handles         => [qw/clear/],
    );

    has 'use' => ( is => 'ro', isa => 'Bool', required => 1, lazy => 1, default => 1 );

    method set ( $key!, $value! ) {
        return unless $self->use;
        $self->cache->freeze( Digest::MD5->new->add($key)->hexdigest, $value );
    };

    method get ( $key! ) {
        return unless $self->use;
        $self->cache->thaw( Digest::MD5->new->add($key)->hexdigest );
    };

    method in ( $key! ) {
        return unless $self->use;
        $self->cache->exists( Digest::MD5->new->add($key)->hexdigest );
    };
};

    

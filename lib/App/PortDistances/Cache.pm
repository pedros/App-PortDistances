use MooseX::Declare;

class App::PortDistances::Cache {

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
        isa      => 'Str',
        required => 1,
        lazy     => 1,
        default  => CACHE_ROOT,
        trigger  => sub { shift->_use( 1 ) },
    );

    has '_cache' => (
        is              => 'ro',
        isa             => 'Cache::File',
        required        => 1,
        lazy            => 1,
        default         => sub { Cache::File->new( cache_root=> shift->cache_root ) },
        handles         => [qw/clear/],
    );

    has '_use' => (
        is       => 'rw',
        isa      => 'Bool',
        required => 1,
        lazy     => 1,
        default  => 1
    );

    method set ( $key!, $value! ) {
        return unless $self->_use;
        $self->_cache->freeze( Digest::MD5->new->add($key)->hexdigest, $value );
    };

    method get ( $key! ) {
        return unless $self->_use;
        $self->_cache->thaw( Digest::MD5->new->add($key)->hexdigest );
    };

    method in ( $key! ) {
        return unless $self->_use;
        $self->_cache->exists( Digest::MD5->new->add($key)->hexdigest );
    };
};

    

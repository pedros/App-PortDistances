package App::PortDistances::DB;

use File::Spec qw//;
use FindBin qw//;
use Cwd qw//;

use Moose;
use MooseX::Method::Signatures;

use lib File::Spec->catdir( $FindBin::Bin, ('..') x 3, 'lib' );
use Data::Dumper;

use App::PortDistances::Types qw/
                                    File HoH Coord
                                    Quadrant Hemisphere
                                /;

use App::PortDistances::DB::Port;

use constant DB_FILE => Cwd::abs_path(
    File::Spec->catfile(
        $FindBin::Bin, qw/.. .. ../, 'data', 'db.json'
    )
);

has 'db_file' => (
    is       => 'ro',
    isa      => File,
    required => 1,
    lazy     => 1,
    default  => DB_FILE,
);

has '_db' => (
    is       => 'ro',
    isa      => HoH,
    traits   => ['Hash'],
    coerce   => 1,
    required => 1,
    lazy     => 1,
    default  => sub { shift->db_file },
    clearer  => '_clear__db',
);

has '_regions' => (
    is       => 'ro',
    isa      => 'HashRef[CodeRef]',
    traits   => ['Hash'],
    required => 1,
    lazy     => 1,
    builder  => '_build__regions',
    handles  => {  _in_region => 'get' },
);

has 'db' => (
    is       => 'ro',
    isa      => 'HashRef[App::PortDistances::DB::Port]',
    traits   => ['Hash'],
    required => 1,
    lazy     => 1,
    builder  => '_build_db',
    handles  => {
        port_names => 'keys',
        ports      => 'values',
        size       => 'count',
        in         => 'exists',
        details    => 'get',
    },
);

method find ( Str      :$aname?,            Str        :$name?,
              Str      :$country?,          Num        :$radius?,
              Coord    :$latitude?,         Coord      :$longitude?,
              Quadrant :$quadrant?,         Hemisphere :$hemisphere?,
              Bool     :$intersection? = 0, Bool       :$union? = 0 ) {

    my @ports;
    
    push @ports, [$self->_find_by_approx( $aname )]
        if $aname;

    push @ports, [$self->_find_by_country( $country )]
        if $country;

    push @ports, [
        $self->_find_by_region(
            $quadrant
            ? (quadrant => $quadrant)
            : (hemisphere => $hemisphere)
        )
    ]
        if $quadrant or $hemisphere;

    push @ports, [
        $self->_find_by_prox(
            radius => $radius,
            $name
            ? (name => $name)
            : (latitude => $latitude, longitude => $longitude )
        )
    ]
        if $radius and ($name xor ($latitude and $longitude));

    if ( $intersection or $union ) {
        my @combined = $self->_set_combine( \@ports, intersection => $intersection );
        @ports = map { $self->details($_) } @combined;
    }

    return wantarray ? @ports : \@ports;
}

method _set_combine ( ArrayRef[ArrayRef] $lists!, Bool :$intersection? = 0 ) {
    my %counts;
    
    for my $list ( @$lists ) {
        $counts{$_->name}++ for @$list;
    }

    return $intersection
        ? grep { $counts{$_} == @$lists } keys %counts
        : keys %counts;
}

method _find_by_approx ( Str $aname! ) {
    eval { require String::Approx } or return;
    my @ports = $self->details( String::Approx::amatch( $aname, ['i'], $self->port_names ) );
    return @ports;
}

method _find_by_prox ( Str :$name?, Coord :$latitude?, Coord :$longitude?, Num :$radius! ) {
    eval { require GIS::Distance }
        and ($name or (defined $latitude and defined $longitude)) or return;    
    
    my $gis = GIS::Distance->new;

    if ($name and my $source = $self->details($name)) {    
        $latitude  ||= $source->latitude;
        $longitude ||= $source->longitude;
    }
    
    my @ports;

    for ($self->port_names) {
        my $port     = $self->details($_);
        my $distance = $gis->distance(
            $latitude, $longitude => $port->latitude, $port->longitude
        )->miles;
        push @ports, $port, $distance if
            $distance <= $radius;
    }

    return @ports;
}

method _find_by_country ( Str $country! ) {
    my @ports;

    for ($self->port_names) {
        my $port = $self->details($_);        
        push @ports, $port
            if $port->country eq $country;
    }
    
    return @ports;
}

method _find_by_region ( Quadrant|Hemisphere $region! ) {
    my @ports;

    for ($self->port_names) {

        my $port = $self->details($_);        
        push @ports, $port
            if $self->_in_region(lc $region)->($port->latitude, $port->longitude);
    }

    return @ports;
}

sub _build_db {
    my ($self) = @_;

    my %ports;
 PORT:
    while ( my ($k, $v) = each %{$self->_db} ) {
        my $port = App::PortDistances::DB::Port->new(
            name      => $k,
            ports     => {
                map { $_->{name} => $_->{distance} }
                    @{ $v->{ports} }
                },
            map { $_ => $v->{$_ } }
                qw/country latitude longitude names notes note junction/,
        );

        $ports{$k} = $port;
    }

    $self->_clear__db;    
    return \%ports;
}

sub _build__regions {
    return {
        n  => sub { $_[0] > 0 },
        s  => sub { $_[0] < 0 },
        e  => sub { $_[1] > 0 },
        w  => sub { $_[1] < 0 },
        ne => sub { $_[0] > 0 && $_[1] > 0 },
        se => sub { $_[0] < 0 && $_[1] > 0 },
        sw => sub { $_[0] < 0 && $_[1] < 0 },
        nw => sub { $_[0] > 0 && $_[1] < 0 }
    }
};

no Moose;
__PACKAGE__->meta->make_immutable;
1;

__END__
my $o = App::PortDistances::DB->new;
$o->db;
print Dumper ($o->_find_by_country( 'Japan' ));exit;
print Dumper $o;exit;
print Dumper ($o->find( aname => 'setb', country => 'Portugal', intersection => 1 ));exit;
print Dumper ($o->_find_by_prox( latitude => 0, longitude => 0, radius => 500 ));exit;
print Dumper ($o->_find_by_approx( 'span' ));exit;

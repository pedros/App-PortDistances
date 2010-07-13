use MooseX::Declare;

class App::PortDistances::DB {

    use lib File::Spec->catdir( $FindBin::Bin, ('..') x 3, 'lib' );
    use Data::Dumper;

    use File::Spec;
    use FindBin;
    use Cwd;
    use constant DB_FILE => Cwd::abs_path(
        File::Spec->catfile( $FindBin::Bin, qw/.. .. ../, 'data', 'db.json' )
    );
    
    use App::PortDistances::DB::Port;
    use App::PortDistances::Types
        qw/
              File HoH Coord
              Quadrant Hemisphere
          /;

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

    has 'db_file' => (
        is       => 'ro',
        isa      => File,
        required => 1,
        lazy     => 1,
        default  => DB_FILE,
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

=head2 find( %args )

Takes any number of the named parameters below.

Optionally applies set operations on the result set.

Returns flattened list in list context or an array reference in scalar context.

=over

=item name => $name

Find port by exact name match.

=item aname => $aname

Find port(s) by approximate name match using L<String::Approx|GIS::Distance>.

=item country => $country

Find port by exact country match.

=item quadrant   => NE|NW|SW|SE

=item hemisphere => N|S

Find port(s) by broad region.

=item latitude  => $lat

=item longitude => $lon

=item radius    => $radius

Find port(s) by proximity within given radius, in miles, using L<GIS::Distance|GIS::Distance>.

=item intersection => $intersection

=item union        => $union

Return intersection or union of results in case of more than one search criteria is specified.

=back

=cut

    method find ( Str      :$aname?,            Str        :$name?,
                  Str      :$country?,          Num        :$radius?,
                  Coord    :$latitude?,         Coord      :$longitude?,
                  Quadrant :$quadrant?,         Hemisphere :$hemisphere?,
                  Bool     :$intersection? = 0, Bool       :$union? = 0 ) {

        push my @ports, [ $self->_find_by_approx(  $aname )   ]
            if $aname;
        push    @ports, [ $self->_find_by_country( $country ) ]
            if $country;
        push    @ports, [ $self->_find_by_region(  $quadrant || $hemisphere ) ]
            if $quadrant or $hemisphere;

        push    @ports, [ $self->_find_by_prox( radius => $radius,
                                                $name
                                                ? (name => $name)
                                                : (latitude => $latitude, longitude => $longitude )) ]
            if $radius and ($name xor ($latitude and $longitude));

        @ports = map { $self->details($_) } $self->_set_combine( \@ports, intersection => $intersection )
            if $intersection or $union;

        return wantarray ? map { @$_ } @ports : \@ports;
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

    method _find_by_prox ( Str :$name?, Coord :$latitude?, Coord :$longitude?, Num :$radius = 0 ) {
        eval { require GIS::Distance }
            and ($name or (defined $latitude and defined $longitude)) or return;    
    
        if ($name and my $source = $self->details($name)) {    
            $latitude  ||= $source->latitude;
            $longitude ||= $source->longitude;
        }
    
        my @ports;
        my $gis = GIS::Distance->new;
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
            my $port = $self->details( $_ );        
            push @ports, $port
                if $self->_in_region(lc $region)->($port->latitude, $port->longitude);
        }
        return @ports;
    }

    method _build_db {
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

    method _build__regions {
        return {
            n  => sub { $_[0] > 0 },
            s  => sub { $_[0] < 0 },
            e  => sub { $_[1] > 0 },
            w  => sub { $_[1] < 0 },
            ne => sub { $_[0] > 0 && $_[1] > 0 },
            se => sub { $_[0] < 0 && $_[1] > 0 },
            sw => sub { $_[0] < 0 && $_[1] < 0 },
            nw => sub { $_[0] > 0 && $_[1] < 0 },
        }
    }
};

__END__
my $o = App::PortDistances::DB->new;
print Dumper $o;
$o->_db;
print Dumper $o;
$o->_db;

exit;
print Dumper $o;
print Dumper ($o->_find_by_country( 'Japan' ));exit;
print Dumper $o;exit;
print Dumper ($o->find( aname => 'setb', country => 'Portugal', intersection => 1 ));exit;
print Dumper ($o->_find_by_prox( latitude => 0, longitude => 0, radius => 500 ));exit;
print Dumper ($o->_find_by_approx( 'span' ));exit;

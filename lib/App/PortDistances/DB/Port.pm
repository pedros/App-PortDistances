package App::PortDistances::DB::Port;

use Moose;

use App::PortDistances::Types qw/Coord/;

has [qw/name country/]       => ( is => 'ro', isa => 'Str', required => 1, lazy => 1, default => sub { shift->names->[-1] } );
has [qw/latitude longitude/] => ( is => 'ro', isa => Coord, required => 1 );
has [qw/names notes/]        => ( is => 'ro', isa => 'ArrayRef[Str]' );
has 'note' => ( is => 'ro', isa => 'Str' );

has 'ports' => (
    is      => 'ro',
    isa     => 'HashRef[Num]',
    traits  => ['Hash'],
    handles => {
        targets  => 'keys',
        size     => 'count',
        connects => 'exists',
        distance => 'get',
    }
);

has 'junction' => ( is => 'ro', isa => 'Bool' );

no Moose;
__PACKAGE__->meta->make_immutable;
1;

use MooseX::Declare;

class App::PortDistances::DB::Port {

    use App::PortDistances::Types qw/Coord/;

    has 'note'                   => ( is => 'ro', isa => 'Str'                );
    has 'junction'               => ( is => 'ro', isa => 'Bool'               );
    has [qw/latitude longitude/] => ( is => 'ro', isa => Coord, required => 1 );
    has [qw/names notes/]        => ( is => 'ro', isa => 'ArrayRef[Str]'      );

    has [qw/name country/] => (
        is       => 'ro',
        isa      => 'Str',
        required => 1,
        lazy     => 1,
        default  => sub { shift->names->[-1] }
    );
    
    has 'ports' => (
        is      => 'ro',
        isa     => 'HashRef[Num]',
        traits  => ['Hash'],
        handles => {
            targets     => 'keys',
            connections => 'count',
            connects    => 'exists',
            distance    => 'get',
            delete      => 'delete',
        }
    );
};

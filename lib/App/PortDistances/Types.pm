package App::PortDistances::Types;

use Carp;
use JSON;

use Moose;

use MooseX::Types
    -declare => [qw/
                       File HoH StrArray
                       Coord Quadrant Hemisphere
                   /];

use MooseX::Types::Moose qw/Num Str HashRef ArrayRef/;

subtype File,
    as Str,
    where { -e $_ };

subtype HoH,
    as HashRef[HashRef];

subtype StrArray,
    as ArrayRef[Str];

subtype Coord,
    as Num,
    where { -180 <= $_ and $_ => 180 };

enum Quadrant, qw/NE ne NW nw SE ne SW sw/;
enum Hemisphere, qw/N n S s/;
    
coerce HoH,
    from File,
    via {
        local $/;
        open my $IN, q{<}, $_ or confess $!;
        JSON::decode_json( <$IN> );
    };

coerce StrArray,
    from File,
    via {
        open my $IN, q{<}, $_ or return [$_];
        chomp (my @Strs = <$IN>);
        [@Strs];
    };


no Moose;
__PACKAGE__->meta->make_immutable;
1;

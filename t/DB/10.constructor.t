#!/usr/bin/env perl -T

use strict;
use warnings;
use constant TESTS   => 5;
use Test::More tests => TESTS;

use_ok( 'App::PortDistances::DB' );
my $db = new_ok( 'App::PortDistances::DB' );
can_ok( $db, qw/db_file _db db _regions/ ); # attributes
can_ok( $db, qw/_build_db _build__regions _clear__db  _in__region port_names ports size in details/ ); # builders, clearers, handlers, predicates
can_ok( $db, qw/find _set_combine _find_by_approx _find_by_country _find_by_region _find_by_prox/ ); # methods

done_testing(TESTS);

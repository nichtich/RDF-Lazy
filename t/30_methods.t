use strict;
use warnings;

use Test::More;
use RDF::Trine::Parser;
use RDF::Lazy;

my $model = RDF::Trine::Model->new;
my $parser = RDF::Trine::Parser->new('turtle');
$parser->parse_into_model( 'http://example.org/', join('',<DATA>), $model );

my $g = RDF::Lazy->new( 
	namespaces => { 
		foaf => 'http://xmlns.com/foaf/0.1/',
		rdf  => 'http://www.w3.org/1999/02/22-rdf-syntax-ns#',
		x    => 'http://example.org/',
	},
	model => $model,
);

my $a = $g->resource('http://example.org/alice');
my $b = $g->resource('http://example.org/bob');
my $c = $g->resource('http://example.org/claire');
my $d = $g->resource('http://example.org/dave');
my $t = $g->uri('rdf:type');
my $p = $g->uri('foaf:Person');
my $o = $g->uri('foaf:Organization');

my $x = $g->blank;
ok( $x->id, 'blank node' );
$x = $g->blank('foo');
is( $x->id, 'foo', 'blank node' );

# type
is( $a->type, $g->foaf_Person, 'type eq' );
is( $a->type, $g->foaf_Person->str, 'type eq' );
ok( $a->type('foaf:Person'), 'a faof:Person' );
ok( $a->type('foaf:Organization','foaf:Person'), 'a faof:Person' );
ok( $a->type('foaf:Person','foaf:Organization'), 'a faof:Person' );

# TODO: ->types / ->type_

is( $a->foaf_knows, $b, 'a knows b' );
is( $b->rev('foaf:knows'), $a, 'b is known by a' );

is( $d->rel, $t, 'd rdf:type _' );
is( $d->rev, $g->foaf_knows, '_ foaf:knows d' );

list_is( $b->rels('rdf:type'), [qw(foaf:Organization foaf:Person)], 'rels (rdf:type): 2' );
list_is( $c->rels('rdf:type'), [], 'rels (rdf:type): 0' );

list_is( $p->revs('rdf:type'), [qw(x:alice x:bob x:dave)], 'revs (rdf:type): 2' );
list_is( $o->revs('rdf:type'), [qw(x:bob)], 'revs (rdf:type): 1' );

list_is( $p->rels, [ ], 'rels (empty)' );
list_is( $a->rels, [qw(rdf:type foaf:knows)], 'rels (2)' );

list_is( $a->revs, [], 'rels (empty)' );
list_is( $p->revs, [qw(rdf:type)], 'revs (1)' );
list_is( $d->revs, [qw(foaf:knows)], 'revs (1)' );

# TODO: test ->rev_ and rev(foaf_knows_)

done_testing;

sub list_is {
	my ($x,$y,$msg)  = @_;
    $x = [ sort map { "$_" } @$x ];
    $y = [ sort map { $g->uri($_)->str } @$y ];
	is_deeply( $x, $y, $msg );
}

__DATA__
@prefix foaf: <http://xmlns.com/foaf/0.1/> .
@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
<http://example.org/alice> rdf:type foaf:Person .
<http://example.org/bob>   a foaf:Person, foaf:Organization .
<http://example.org/claire> foaf:knows <http://example.org/dave> .
<http://example.org/dave>  a foaf:Person .
<http://example.org/alice> foaf:knows <http://example.org/bob> .

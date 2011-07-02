use strict;
use warnings;

use Test::More;
use RDF::Trine::Parser;
use RDF::Lazy;

my $model = RDF::Trine::Model->new;
my $parser = RDF::Trine::Parser->new('turtle');
$parser->parse_into_model( 'http://example.org/', join('',<DATA>), $model );

my $g = RDF::Lazy->new( 
	namespaces => { foaf => 'http://xmlns.com/foaf/0.1/' },
	model => $model,
);

my $a = $g->resource('http://example.org/alice');
my $b = $g->resource('http://example.org/bob');

# type
is( $a->type, $g->foaf_Person, 'type eq' );
is( $a->type, $g->foaf_Person->str, 'type eq' );
ok( $a->type('foaf:Person'), 'a faof:Person' );
ok( $a->type('foaf:Organization','foaf:Person'), 'a faof:Person' );
ok( $a->type('foaf:Person','foaf:Organization'), 'a faof:Person' );

# TODO: ->types / ->type_

ok( $a->foaf_knows );
# ok( $b->rel('foaf:knows') ); # $a

done_testing;

__DATA__
@prefix foaf: <http://xmlns.com/foaf/0.1/> .
@prefix rdfs: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
<http://example.org/alice> rdfs:type foaf:Person .
<http://example.org/bob>   a foaf:Person, foaf:Organization .
<http://example.org/alice> foaf:knows <http://example.org/bob> .

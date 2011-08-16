use strict;
use warnings;

use Test::More;
use RDF::Lazy;

my $data = join('',<DATA>);

my $rdf = RDF::Lazy->new($data);
is( $rdf->size, 4, 'rdf data as first parameter' );

$rdf = RDF::Lazy->new( rdf => $data );
is( $rdf->str, "4 triples", 'rdf data with named parameter' );

my $s = $rdf->uri('"hello"');
is( $s->str, "hello", 'parse plain literal' );

$s = $rdf->uri('"hello"@en');
is( $s->lang, "en", 'parse literal with language' );

$s = $rdf->uri('true');
is( $s->str, "true", 'parse plain true' );

# ...


# Turtle
like ( $rdf->ttlpre, qr/^<pre.*alice&gt;.*knows&gt;/s, 'RDF::Lazy->ttlpre' );
like ( $rdf->resource('http://example.org/bob')->ttlpre, qr/^<pre.*4 triples.*bob&gt;.*knows&gt;/s, 'RDF::Lazy::Node->ttlpre' );

done_testing;

__DATA__
@prefix foaf: <http://xmlns.com/foaf/0.1/> .
@prefix dc:   <http://purl.org/dc/elements/1.1/> .
<http://example.org/alice> foaf:knows <http://example.org/bob> .
<http://example.org/bob>   foaf:knows <http://example.org/alice> .
<http://example.org/alice> foaf:name "Alice" .
<http://example.org/bob>   foaf:name "Bob" .

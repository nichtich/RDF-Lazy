use strict;
use warnings;

use Test::More;
use RDF::Lazy;

my $rdf = RDF::Lazy->new(join('',<DATA>));

is( $rdf->size, 4 );

done_testing;

__DATA__
@prefix foaf: <http://xmlns.com/foaf/0.1/> .
@prefix dc:   <http://purl.org/dc/elements/1.1/> .
<http://example.org/alice> foaf:knows <http://example.org/bob> .
<http://example.org/bob>   foaf:knows <http://example.org/alice> .
<http://example.org/alice> foaf:name "Alice" .
<http://example.org/bob>   foaf:name "Bob" .

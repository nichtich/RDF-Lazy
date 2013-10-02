use strict;
use warnings;

use Test::More;
use RDF::Lazy;

my $g = RDF::Lazy->new; # TODO: explicitly set namespaces

is $g->ns('dc'), 'http://purl.org/dc/elements/1.1/', 'ns namespace lookup';
is $g->ns('http://purl.org/dc/elements/1.1/'), 'dc', 'ns prefix lookup';
is $g->ns('rdfs:seeAlso'),'http://www.w3.org/2000/01/rdf-schema#seeAlso', 'qname lookup';

#ok  TODO
    $g->ns( dc => 'http://example.org/' );
is $g->ns('dc'), 'http://example.org/', 'ns namespace lookup';
#is $g->ns('http://example.org/'), 'dc', 'ns prefix lookup';

done_testing;

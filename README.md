# NAME

RDF::Lazy - Lazy typing access to RDF data

# SYNOPSIS

    ### How to create a graph

    $g = RDF::Lazy->new(
       rdf        => $data,    # RDF::Trine::Model or ::Store (by reference)
       namespaces => {         # namespace prefix, RDF::NS or RDF::Trine::NamespaceMap
           foaf => 'http://xmlns.com/foaf/0.1/',
           rdf  => "http://www.w3.org/1999/02/22-rdf-syntax-ns#",
           xsd  => "http://www.w3.org/2001/XMLSchema#",
       }
    );

    $g = RDF::Lazy->new( $data, format => 'turtle' );  # parse RDF/Turtle
    $g = RDF::Lazy->new( $data, format => 'rdfxml' );  # parse RDF/XML
    $g = RDF::Lazy->new( "http://example.org/" );      # retrieve LOD

    ### How to get nodes

    $p = $g->resource('http://xmlns.com/foaf/0.1/Person'); # get node
    $p = $g->uri('<http://xmlns.com/foaf/0.1/Person>');    # alternatively
    $p = $g->uri('foaf:Person);                            # same but lazier
    $p = $g->foaf_Person;                                  # same but laziest

    $l = $g->literal('Alice');              # get literal node
    $l = $g->literal('Alice','en');         # get literal node with language
    $l = $g->literal('123','xsd:integer');  # get literal node with datatype

    $b = $g->blank('x123');   # get blank node
    $b = $g->blank;           # get blank node with random id

    ### How to retrieve RDF

    $x->rel('foaf:knows');    # retrieve a person that $x knows
    $x->rev('foaf:knows');    # retrieve a person known by $x

    $x->rels('foaf:knows');   # retrieve all people that $x knows
    $x->revs('foaf:knows');   # retrieve all people known by $x

    $x->foaf_knows;           # short form of $x->rel('foaf:knows')
    $x->foaf_knows_;          # short form of $x->rels('foaf:knows')

    $x->rels;                 # array reference with a list of properties
    $x->revs;                 # same as rels, but other direction

    $x->type;                 # same as $x->rel('rdf:type')
    $x->types;                # same as $x->rels('rdf:type')

    $g->subjects( 'rdf:type', 'foaf:Person' );  # retrieve subjects
    $g->predicates( $subject, $object );        # list predicates
    $g->objects( $subject, 'foaf:knows' );      # list objects

    ### How to add RDF

    $g->add( $rdfdata, format => 'rdfxml' );    # parse and add
    $g->add( $subject, $predicate, $object );   # add single triple

    ### How to show RDF

    $g->turtle;  # dump in RDF/Turtle syntax
    $g->ttlpre;  # dump in RDF/Turtle, wrapped in a HTML <pre> tag
    $g->rdfxml;  # dump in RDF/XML
    $g->rdfjson; # dump in RDF/JSON

# DESCRIPTION

This module wraps [RDF::Trine::Node](https://metacpan.org/pod/RDF::Trine::Node) to provide simple node-centric access to
RDF data. It was designed to access RDF within [Template](https://metacpan.org/pod/Template) Toolkit but the
module does not depend on or and can be used independently. Basically, an
instance of RDF::Lazy contains an unlabeled RDF graph and a set of namespace
prefixes. For lazy access and graph traversal, each RDF node
([RDF::Lazy::Node](https://metacpan.org/pod/RDF::Lazy::Node)) is tied to the graph.

# METHODS

## cache( \[ $cache \] )

Get and/or set a cache for loading RDF from URIs or URLs. A `$cache` can be
any blessed object that supports method `get($uri)` and `set($uri,$value)`.
For instance one can enable a simple file cache with [CHI](https://metacpan.org/pod/CHI) like this:

    my $rdf = RDF::Lazy->new(
        cache => CHI->new(
            driver => 'File', root_dir => '/tmp/cache',
            expires_in => '1 day'
        )
    );

By default, RDF is stored in Turtle syntax for easy inspection.

## load( $uri )

Load RDF from an URI or URL. RDF data is optionally retrieved from a cache.
Returns the number of triples that have been added (which could be zero if
all loaded triples are duplicates).

## new ( \[ \[ rdf => \] $rdf \] \[, namespaces => $namespaces \] \[ %options \])

Return new RDF graph. Namespaces can be provided as hash reference or as
[RDF::Trine::NamespaceMap](https://metacpan.org/pod/RDF::Trine::NamespaceMap) or [RDF::NS](https://metacpan.org/pod/RDF::NS). By default, the current local
version of RDF::NS is used.  RDF data can be [RDF:Trine::Model](RDF:Trine::Model) or
[RDF::Trine::Store](https://metacpan.org/pod/RDF::Trine::Store), which are used by reference, or many other forms, as
supported by [add](#add).

## resource ( $uri )

Return [RDF::Lazy::Resource](https://metacpan.org/pod/RDF::Lazy::Resource) node. The following statements are equivalent:

    $graph->resource('http://example.org');
    $graph->uri('<http://example.org>');

## literal ( $string , $language\_or\_datatype, $datatype )

Return [RDF::Lazy::Literal](https://metacpan.org/pod/RDF::Lazy::Literal) node.

## blank ( \[ $identifier \] )

Return [RDF::Lazy::Blank](https://metacpan.org/pod/RDF::Lazy::Blank) node. A random identifier is generated unless you
provide an identifier as parameter.

## uri ( $name | $node )

Returns a node that is connected to the graph. Note that every valid RDF node
is part of any RDF graph: this method does not check whether the graph actually
contains a triple with the given node. You can either pass a name or an
instance of [RDF::Trine::Node](https://metacpan.org/pod/RDF::Trine::Node). This method is also called for any undefined
method, so the following statements are equivalent:

    $graph->true;
    $graph->uri('true');

## rel / rels / rev / revs

Can be used to traverse the graph. See [RDF::Lazy::Node](https://metacpan.org/pod/RDF::Lazy::Node):

    $node->rel( ... )           # where $node is located in $graph
    $graph->rel( $node, ... )   # equivalent

## add

Add RDF data. _Sorry, not documented yet!_

## ttl ( \[ $node \] )

Returns a RDF/Turtle representation of a node's bounded description.

## ttlpre ( \[ $node \] )

Returns an HTML escaped RDF/Turtle representation of a node's bounded
description, wrapped in a HTML `<pre class="turtle">` element.

## ns ( $prefix | $namespace | $prefix => $namespace )

Gets or sets a namespace mapping for the entire graph. By default, RDF::Lazy
makes use of popular namespaces defined in [RDF::NS](https://metacpan.org/pod/RDF::NS).

    $g->ns('dc');   # returns 'http://purl.org/dc/elements/1.1/'
    $g->ns('http://purl.org/dc/elements/1.1/');  # returns 'dc'
    $g->ns( dc => 'http://example.org/' );       # modify mapping

# SEE ALSO

[RDF::Helper](https://metacpan.org/pod/RDF::Helper) and [RDF::TrineShortcuts](https://metacpan.org/pod/RDF::TrineShortcuts) provide similar APIs. Another similar framework
for PHP and Python is Graphite: http://graphite.ecs.soton.ac.uk/,
http://code.google.com/p/python-graphite/.

# AUTHOR

Jakob Voß <voss@gbv.de>

# COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by Jakob Voß.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

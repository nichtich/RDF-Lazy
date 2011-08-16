use strict;
use warnings;
package RDF::Lazy;
#ABSTRACT: Lazy typing access to RDF data

use RDF::Trine::Model;
use RDF::Trine::NamespaceMap;
use CGI qw(escapeHTML);

use RDF::Lazy::Node;
use Scalar::Util qw(blessed refaddr);
use Carp qw(carp croak);

our $AUTOLOAD;

#use overload '""' => \&str;

sub str {
    shift->size . " triples";
}

sub new {
    my $class = shift;
    my ($rdf, %args) = (@_ % 2) ? @_ : (undef,@_);

    if (defined $args{rdf}) {
        croak 'Either use first argument or ref => $rdf' if $rdf;
        $rdf = $args{rdf};
    }

    my $namespaces = $args{namespaces} || RDF::Trine::NamespaceMap->new;
    $namespaces = RDF::Trine::NamespaceMap->new( $namespaces ) unless
        blessed($namespaces) and $namespaces->isa('RDF::Trine::NamespaceMap');

    my $self = bless {
        namespaces => $namespaces,
    }, $class;

    if (blessed $rdf) {
        # add model by reference
        if ($rdf->isa('RDF::Trine::Model')) {
            $self->{model} = $rdf; # model added by reference
        } elsif ($rdf->isa('RDF::Trine::Store')) {
            $self->{model} = RDF::Trine::Model->new($rdf);
        }
    }

    if ( not $self->{model} ) {
        $self->{model} = RDF::Trine::Model->new;
        $self->add( $rdf, %args );
    }

    $self;
}

# method includes parts of RDF::TrineShortcuts::rdf_parse by Toby Inkster
sub add { # rdf by value
    my $self = shift;

    # TODO: have a look at RDF::TrineShortcuts::rdf_parse

    if (@_ == 3 and $_[1] !~ /^[a-z]+$/) { # TODO: allow 'a'?
        my @triple = @_;
        @triple = map { $self->uri($_) } @triple;
        if ( grep { not defined $_ } @triple ) {
            croak 'Failed to add pseudo-triple';
        }
        @triple = map { $_->trine } @triple;
        my $stm = RDF::Trine::Statement->new( @triple );
        $self->model->add_statement( $stm );
        return;
    }

    my ($rdf, %args) = @_;

    if (blessed $rdf) {
        if ($rdf->isa('RDF::Trine::Graph')) {
            $rdf = $rdf->get_statements;
        }
        if ($rdf->isa('RDF::Trine::Iterator::Graph')) {
            $self->model->begin_bulk_ops;
            while (my $row = $rdf->next) {
                $self->model->add_statement( $row );
            }
            $self->model->end_bulk_ops;
        } elsif ($rdf->isa('RDF::Trine::Statement')) {
            $self->model->add_statement( $rdf );
        } elsif ($rdf->isa('RDF::Trine::Model')) {
            $self->add( $rdf->as_stream );
        } else {
            croak 'Cannot add RDF object of type ' . ref($rdf);
        }
    } elsif ( ref $rdf ) {
        if ( ref $rdf eq 'HASH' ) {
            $self->model->add_hashref($rdf);
        } else {
            croak 'Cannot add RDF object of type ' . ref($rdf);
        }
    } else {
        # TODO: parse from file, glob, or string in Turtle syntax or other
        # reuse namespaces if parsing Turtle or SPARQL

        my $format = $args{format} || 'turtle';
        my $base   = $args{base} || 'http://localhost/';
        my $parser = RDF::Trine::Parser->new( $format );
        $parser->parse_into_model( $base, $rdf, $self->model );
    }
}

sub query {
    # TODO: See RDF::TrineShortcuts::rdf_query
    carp __PACKAGE__ . '::query not implemented yet';
}

*sparql = *query;

sub model { $_[0]->{model} }

sub size { $_[0]->{model}->size }

sub rels { shift->_relrev( 1, 'rel', @_  ); }
sub rel  { shift->_relrev( 0, 'rel', @_  ); }
sub rev  { shift->_relrev( 0, 'rev', @_  ); }
sub revs { shift->_relrev( 1, 'rev', @_  ); }

sub turtle {
    my $self     = shift;
    my $subject  = shift;

    use RDF::Trine::Serializer::Turtle;
    my $serializer = RDF::Trine::Serializer::Turtle->new( namespaces => $self->{namespaces} );

    my $iterator;

    if ($subject) {
        $subject = $self->uri($subject)
            unless blessed($subject) and $subject->isa('RDF::Lazy::Node');
        $iterator = $self->{model}->bounded_description( $subject->trine );
    } else {
        $iterator = $self->model->as_stream;
    }

    return $serializer->serialize_iterator_to_string( $iterator );
}

#*ttl = *turtle;

sub ttlpre {
    return '<pre class="turtle">'
        . escapeHTML( "# " . ($_[0]->str||'') . "\n" . turtle(@_) )
        . '</pre>';
}

sub resource { RDF::Lazy::Resource->new( @_ ) }
sub literal  { RDF::Lazy::Literal->new( @_ ) }
sub blank    { RDF::Lazy::Blank->new( @_ ) }

sub node {
    carp __PACKAGE__ . '::node is depreciated - use ::uri instead!';
    uri(@_);
}

sub uri {
    my ($self,$node) = @_;
    return unless defined $node;

    if (blessed $node) {
        if ($node->isa('RDF::Lazy::Node')) {
            # copy from another or from this graph
            # return $node if refaddr($node->graph) eq refaddr($self);
            $node = $self->trine;
        } 
        if ($node->isa('RDF::Trine::Node::Resource')) {
            return RDF::Lazy::Resource->new( $self, $node );
        } elsif ($node->isa('RDF::Trine::Node::Literal')) {
            return RDF::Lazy::Literal->new( $self, $node );
        } elsif ($node->isa('RDF::Trine::Node::Blank')) {
            return RDF::Lazy::Blank->new( $self, $node );
        } else {
            carp 'Cannot create RDF::Lazy::Node from ' . ref($node);
            return;
        }
    }

    my ($prefix,$local,$uri);

    if ( $node =~ /^<(.*)>$/ ) {
        return RDF::Lazy::Resource->new( $self, $1 );
    } elsif ( $node =~ /^_:(.*)$/ ) {
        return RDF::Lazy::Blank->new( $self, $1 );
    } elsif ( $node =~ /^\[\s*\]$/ ) {
        return RDF::Lazy::Blank->new( $self );
    } elsif ( $node =~ /^["'+-0-9]|^(true|false)$/ ) {
        return $self->_literal( $node );
    } elsif ( $node =~ /^([^:]*):([^:]*)$/ ) {
        ($prefix,$local) = ($1,$2);
    } elsif ( $node =~ /^(([^_:]*)_)?([^_:]+.*)$/ ) {
        ($prefix,$local) = ($2,$3);
    } else {
        return;
    }

    if (defined $prefix) {
        $uri = $self->{namespaces}->uri("$prefix:$local");
    } else {
        # Bug in RDF::Trine::NamespaceMap, line 133 - wait until fixed
        # $predicate = $self->{namespaces}->uri(":$local");
        my $ns = $self->{namespaces}->namesespace_uri("");
        $uri = $ns->uri($local) if defined $ns;
    }

    return unless defined $uri;
    return RDF::Lazy::Resource->new( $self, $uri );
}

sub namespaces {
    return shift->{namespaces};
}

sub subjects {
    my $self = shift;
    my ($predicate, $object) = map { $self->uri($_)->trine } @_;
    return map { $self->uri($_) } $self->model->subjects( $predicate, $object );
}

sub predicates {
    my $self= shift;
    my ($subject, $object) = map { $self->uri($_)->trine } @_;
    return map { $self->uri($_) } $self->model->predicates( $subject, $object );
}

sub objects {
    my ($self, $subject, $predicate, %options) = @_;
    ($subject, $predicate) = map { $self->uri($_)->trine } ($subject, $predicate);
    return map { $self->uri($_) } $self->model->objects( $subject, $predicate, %options );
}

sub AUTOLOAD {
    my $self = shift;
    return if !ref($self) or $AUTOLOAD =~ /^(.+::)?DESTROY$/;

    my $name = $AUTOLOAD;
    $name =~ s/.*:://;

    return $self->uri($name);
}

### internal methods

# parts from RDF/Trine/Parser/Turtle.pm
my $xsd        = RDF::Trine::Namespace->new('http://www.w3.org/2001/XMLSchema#');
#my $r_language = qr'[a-z]+(-[a-z0-9]+)*'i;
my $r_double   = qr'^[+-]?([0-9]+\.[0-9]*[eE][+-]?[0-9]+|\.[0-9]+[eE][+-]?[0-9]+|[0-9]+[eE][+-]?[0-9]+)$';
my $r_decimal  = qr'^[+-]?([0-9]+\.[0-9]*|\.([0-9])+)$';
my $r_integer  = qr'^[+-]?[0-9]+';
my $r_boolean  = qr'^(true|false)$';
my $r_string1  = qr'^"(.*)"(\@([a-z]+(-[a-z0-9]+)*))?$'i;
my $r_string2  = qr'^"(.*)"(\@([a-z]+(-[a-z0-9]+)*))?$'i;

sub _literal {
    my ($self, $s) = @_;

    my ($literal, $language, $datatype);

    if ( $s =~ $r_string1 or $s =~ $r_string2 ) {
        ($literal, $language) = ($1,$3);
    } elsif( $s =~ $r_double ) {
        $literal = $s;
        $datatype = $xsd->double;
    } elsif( $s =~ $r_decimal ) {
        $literal = $s;
        $datatype = $xsd->decimal;
    } elsif( $s =~ $r_integer ) {
        $literal = $s;
        $datatype = $xsd->integer;
    } elsif( $s =~ $r_boolean ) {
        $literal = $s;
        $datatype = $xsd->boolean;
    }

    return $self->literal( $literal, $language, $datatype );
}

sub _query {
    my ($self,$all,$dir,$subject,$property,@filter) = @_;

    $subject = $self->uri($subject)
        unless blessed($subject) and $subject->isa('RDF::Lazy::Node');

    $property = $self->uri($property) if defined $property;
    $property = $property->trine if defined $property;

    my @res;

    if ($dir eq 'rel') {
        @res = $self->{model}->objects( $subject->trine, $property );
    } elsif ($dir eq 'rev') {
        @res = $self->{model}->subjects( $property, $subject->trine );
    }

    @res = map { $self->uri( $_ ) } @res;

    # TODO apply filters one by one and return in order of filters
    @res = grep { $_->is(@filter) } @res if @filter;

    return $all ? \@res : $res[0];
}

sub _relrev {
    my $self    = shift;
    my $all     = shift;
    my $type    = shift;
    my $subject = shift;

    if (@_) {
        # get objects / subjects
        my ($property,@filter) = @_;
        $all = 1 if ($property and not ref $property and $property =~ s/^(.+[^_])_$/$1/);
        return $self->_query( $all, $type, $subject, $property, @filter );
    } else {
        # get all predicates
        $subject = $self->uri($subject)
            unless blessed($subject) and $subject->isa('RDF::Lazy::Node');

        my @res;

        if ($type eq 'rel') {
            @res = $self->{model}->predicates( $subject->trine, undef );
        } elsif ($type eq 'rev') {
            @res = $self->{model}->predicates( undef, $subject->trine );
        }

        return $all ? [ map { $self->uri( $_ ) } @res ] : $self->uri( $res[0] );
    }
}

1;

__END__

=head1 SYNOPSIS

  ### How to create a graph

  $g = RDF::Lazy->new(
     rdf        => $data,    # RDF::Trine::Model or ::Store (by reference)
     namespaces => {         # namespace prefix or RDF::Trine::NamespaceMap
         foaf => 'http://xmlns.com/foaf/0.1/',
         rdf  => "http://www.w3.org/1999/02/22-rdf-syntax-ns#",
         xsd  => "http://www.w3.org/2001/XMLSchema#",
     }
  );

  $g = RDF::Lazy->new( $data, format => 'turtle' );  # parse RDF/Turtle
  $g = RDF::Lazy->new( $data, format => 'rdfxml' );  # parse RDF/XML

  ### How to get nodes

  $p = $f->resource('http://xmlns.com/foaf/0.1/Person'); # get node
  $p = $f->uri('<http://xmlns.com/foaf/0.1/Person>');    # alternatively
  $p = $f->uri('foaf:Person);                            # same but lazier
  $p = $f->foaf_Person;                                  # same but laziest

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

=head1 DESCRIPTION

This module wraps L<RDF::Trine::Node> to provide simple node-centric access to
RDF data. It was designed to access RDF within L<Template> Toolkit but the
module does not depend on or and can be used independently. Basically, an
instance of RDF::Lazy contains an unlabeled RDF graph and a set of namespace
prefixes. For lazy access and graph traversal, each RDF node
(L<RDF::Lazy::Node>) is tied to the graph.

=method new ( [ [ rdf => ] $rdf ] [, namespaces => $namespaces ] [ %options ])

Return new RDF graph. Namespaces can be provided as hash reference or as
L<RDF::Trine::NamespaceMap>. RDF data can be L<RDF:Trine::Model> or
L<RDF::Trine::Store>, which are used by reference, or many other forms,
as supported by L<add|/add>.

=method resource ( $uri )

Return L<RDF::Lazy::Resource> node. The following statements are equivalent:

    $graph->resource('http://example.org');
    $graph->uri('<http://example.org>');

=method literal ( $string , $language_or_datatype, $datatype )

Return L<RDF::Lazy::Literal> node.

=method blank ( [ $identifier ] )

Return L<RDF::Lazy::Blank> node. A random identifier is generated unless you
provide an identifier as parameter.

=method uri ( $name | $node )

Returns a node that is connected to the graph. Note that every valid RDF node
is part of any RDF graph: this method does not check whether the graph actually
contains a triple with the given node. You can either pass a name or an
instance of L<RDF::Trine::Node>. This method is also called for any undefined
method, so the following statements are equivalent:

    $graph->true;
    $graph->uri('true');

=method rel / rels / rev / revs

Can be used to traverse the graph. See L<RDF::Lazy::Node>:

    $node->rel( ... )           # where $node is located in $graph
    $graph->rel( $node, ... )   # equivalent

=method add

Add RDF data. I<Sorry, not documented yet!>

=method ttl ( [ $node ] )

Returns a RDF/Turtle representation of a node's bounded description.

=method ttlpre ( [ $node ] )

Returns an HTML escaped RDF/Turtle representation of a node's bounded
description, wrapped in a HTML C<< <pre class="turtle"> >> element.

=head1 SEE ALSO

L<RDF::Helper> and L<RDF::TrineShortcuts> provide similar APIs.

=cut

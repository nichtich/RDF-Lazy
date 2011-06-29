use strict;
use warnings;
package RDF::Lazy::Node;
#ABSTRACT: A node in a lazy RDF graph

=head1 DESCRIPTION

This class wraps L<RDF::Trine::Node> and holds a pointer to the graph
(L<RDF::Lazy>) which a node belongs to. In detail there are node types
L<RDF::Lazy::Literal>, L<RDF::Lazy::Resource>, and L<RDF::Lazy::Blank>.

=cut

use RDF::Lazy::Literal;
use RDF::Lazy::Resource;
use RDF::Lazy::Blank;

our $AUTOLOAD;

sub trine { shift->[0]; }
sub graph { shift->[1]; }
sub esc   { shift->str; }

sub is_literal  { shift->[0]->is_literal; }
sub is_resource { shift->[0]->is_resource; }
sub is_blank    { shift->[0]->is_blank; }

sub AUTOLOAD {
    my $self = shift;
    return if !ref($self) or $AUTOLOAD =~ /^(.+::)?DESTROY$/;

    my $method = $AUTOLOAD;
    $method =~ s/.*:://;

    return $self->_autoload( $method, @_ );
}

sub is {
    my $self = shift;
    return 1 unless @_;

    foreach my $check (@_) {
        if ($self->is_literal) {
            return 1 if $check eq '' or $check eq 'literal';
            return 1 if $check eq '@' and $self->lang;
            return 1 if $check =~ /^@(.+)/ and $self->lang($1);
            return 1 if $check eq /^\^\^?$/ and $self->datatype;
        } elsif ($self->is_resource) {
            return 1 if $check eq ':' or $check eq 'resource';
        } elsif ($self->is_blank) {
            return 1 if $check eq '-' or $check eq 'blank';
        }
    }

    return 0;
}

sub turtle {
    return $_[0]->graph->turtle( @_ );
}

sub get {
    $_[0]->graph->objects( @_ ); 
}

sub objects { # depreciated
    $_[0]->graph->objects( @_ ); 
}

sub _autoload {
    my $self     = shift;
    my $property = shift;
    return if $property =~ /^(query|lang)$/; # reserved words
    return $self->objects( $property, @_ );
}

1;

=head1 USAGE

In general you should not use the node constructor to create new node objects
but use a graph as node factory:

    $graph->resource( $uri );
    $graph->literal( $string, $language, $datatype );
    $graph->blank( $id );

However, the following syntax is equivalent:

    RDF::Lazy::Node::Resource->new( $graph, $uri );
    RDF::Lazy::Node::Literal->new( $graph, $string, $language, $datatype );
    RDF::Lazy::Node::Blank->new( $graph, $id );

To convert a RDF::Trine::Node object into a RDF::Lazy::Node, you can use:

    $graph->node( $trine_node )

Note that all these methods silently return undef on failure.

Each RDF::Lazy::Node provides at least the following methods:

=over 4

=item str

Returns a string representation of the node's value. Is automatically
called on string conversion (C<< "$x" >> equals C<< $x->str >>).

=item esc

Returns a HTML-escaped string representation. This can safely be used
in HTML and XML.

=item is_literal / is_resource / is_blank

Returns true if the node is a literal / resource / blank node.

=item is ( $check1 [, $check2 ... ] ) 

Checks whether the node fullfills some matching criteria. 

=item trine

Returns the underlying L<RDF::Trine::Node>.

=item graph

Returns the underlying graph L<RDF::Lazy> that the node belongs to.

=item turtle

Returns an HTML escaped RDF/Turtle representation of the node's bounded 
connections.

=item dump

Returns an HTML representation of the node and its connections
(not implemented yet).

=back

In addition for literal nodes:

=over 4

=item esc

...

=item lang

Return the literal's language tag (if the literal has one).

=item type

...

=item is_xxx

Returns whether the literal has language tag xxx, where xxx is a BCP 47 language
tag locator. For instance C<is_en> matches language tag C<en> (but not C<en-us>), 
C<is_en_us> matches language tag C<en-us> and C<is_en_> matches C<en> and all
language tags that start with C<en->. Use C<lang> to check whether there is any
language tag.

=back

In addition for blank nodes:

=over 4

=item id

Returns the local, temporary identifier of this note.

=back

In addition for resource nodes:

=over 4

=item uri

...

=item href

...

=item objects

Any other method name is used to query objects. The following three statements
are equivalent:

    $x->foaf_name;
    $x->objects('foaf_name');
    $x->graph->objects( $x, 'foaf_name' );

=back

You can also add filters in a XPath-like language (the use of RDF::Lazy 
in a template is an example of a "RDFPath" language):
  
    $x->dc_title('@en')   # literal with language tag @en
    $x->dc_title('@en-')  # literal with language tag @en or @en-...
    $x->dc_title('')      # any literal
    $x->dc_title('@')     # literal with any language tag
    $x->dc_title('^')     # literal with any datatype
    $x->foaf_knows(':')   # any resource
    ...
=cut

1;

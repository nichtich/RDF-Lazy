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
use RDF::Trine qw(iri);
use CGI qw(escapeHTML);
use Carp qw(carp);

our $AUTOLOAD;
our $rdf_type = iri('http://www.w3.org/1999/02/22-rdf-syntax-ns#type');

sub trine { shift->[0]; }
sub graph { shift->[1]; }
#sub esc   { shift->str; }
sub esc { escapeHTML( shift->str ) }

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

sub type {
    my $self = shift;
    if ( @_ ) {
        my $types = $self->rels( $rdf_type ); # TODO use filter?
        foreach ( @_ ) {
            my $type = $self->graph->uri( $_ );
            return 1 if (grep { $_ eq $type } @$types);
        }
        return 0;
    } else {
        # TODO: return multiple types on request
        $self->rel( $rdf_type );
    }
}

sub types {
    my $self = shift;
    $self->rels( $rdf_type );
}

sub is {
    my $self = shift;
    return 1 unless @_;

    foreach my $check (@_) {
        if ($self->is_literal) {
            return 1 if $check eq '' or $check eq 'literal';
            return 1 if $check eq '@' and $self->lang;
            return 1 if $check =~ /^@(.+)/ and $self->lang($1);
            return 1 if $check =~ /^\^\^?$/ and $self->datatype;
            return 1 if $check =~ /^\^\^?(.+)$/ and $self->datatype($1);
        } elsif ($self->is_resource) {
            return 1 if $check eq ':' or $check eq 'resource';
        } elsif ($self->is_blank) {
            return 1 if $check eq '-' or $check eq 'blank';
        }
    }

    return 0;
}

sub turtle { $_[0]->graph->turtle( @_ ); }
sub ttlpre { $_[0]->graph->ttlpre( @_ ); }

sub rel  { $_[0]->graph->rel( @_ ); }
sub rels { $_[0]->graph->rels( @_ ); }
sub rev  { $_[0]->graph->rev( @_ ); }
sub revs { $_[0]->graph->revs( @_ ); }

sub _autoload {
    my $self     = shift;
    my $property = shift;
    return if $property =~ /^(query|lang)$/; # reserved words
    return $self->rel( $property, @_ );
}

sub eq {
    "$_[0]" eq "$_[1]";
}

1;

__END__

=head1 DESCRIPTION

You should not directly create instances of this class, but use L<RDF::Lazy> as
node factory to create instances of L<RDF::Node::Resource>,
L<RDF::Node::Literal>, and L<RDF::Node::Blank>.

    $graph->resource( $uri );    # returns a RDF::Node::Resource
    $graph->literal( $string );  # returns a RDF::Node::Literal
    $graph->blank( $id );        # returns a RDF::Node::Blank

A lazy node contains a L<RDF::Trine::Node> and a pointer to the
RDF::Lazy graph where the node is located in. You can create a
RDF::Lazy::Node from a RDF::Trine::Node just like this:

    $graph->uri( $trine_node )

=method str

Returns a string representation of the node's value. Is automatically
called on string conversion (C<< "$x" >> equals C<< $x->str >>).

=method esc

Returns a HTML-escaped string representation. This can safely be used
in HTML and XML.

=method is_literal / is_resource / is_blank

Returns true if the node is a literal, resource, or blank node.

=method graph

Returns the underlying graph L<RDF::Lazy> that the node belongs to.

=method type ( [ @types ] )

Returns some rdf:type of the node (if no types are provided) or checks
whether this node is of any of the provided types.

=method is ( $check1 [, $check2 ... ] )

Checks whether the node fullfills some matching criteria, for instance

    $x->is('')     # is_literal
    $x->is(':')    # is_resource
    $x->is('-')    # is_blank
    $x->is('@')    # is_literal and has language tag
    $x->is('@en')  # is_literal and has language tag 'en' (is_en)
    $x->is('@en-') # is_literal and is_en_
    $x->is('^')    # is_literal and has datatype
    $x->is('^^')   # is_literal and has datatype


=method trine

Returns the underlying L<RDF::Trine::Node>. You should better not use this.

=method turtle / ttl

Returns an RDF/Turtle representation of the node's bounded connections.

=method rel ( $property [, @filters ] )

Traverse the graph and return the first matching object.

=method rels

Traverse the graph and return all matching objects.

=method rev ( $property [, @filters ] )

Traverse the graph and return the first matching subject.

=method revs

Traverse the graph and return all matching subjects.

=head2 TRAVERSING THE GRAPH

Any other method name is used to query objects. The following three statements
are equivalent:

    $x->rel('foaf:name');
    $x->graph->rel( $x, 'foaf_name' );
    $x->rel('foaf_name');
    $x->foaf_name;

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

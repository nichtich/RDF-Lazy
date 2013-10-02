use strict;
use warnings;
package RDF::Lazy::Resource;
#ABSTRACT: URI reference node (aka resource) in a RDF::Lazy graph

use base 'RDF::Lazy::Node';
use Scalar::Util qw(blessed);
use CGI qw(escapeHTML);
use Try::Tiny;

use overload '""' => \&str;

sub new {
    my ($class, $graph, $resource) = @_;

    return unless defined $resource;

    unless (blessed($resource) and $resource->isa('RDF::Trine::Node::Resource')) {
        $resource = RDF::Trine::Node::Resource->new( $resource );
        return unless defined $resource;
    }

    bless [ 
        $resource,
        $graph || RDF::Lazy->new
    ], $class;
}

sub str {
    $_[0]->trine->uri_value;
}

*uri  = *str;

*href = *RDF::Lazy::Node::esc;

sub qname {
    my ($self) = @_;

    try {
        my ($ns,$local) = $self->[0]->qname; # let Trine split
        $ns = $self->[1]->ns($ns) || return "";
        return "$ns:$local";
    } catch {
        return "";
    }
}

1;

=head1 DESCRIPTION

L<RDF::Lazy::Resource> represents an URI references in a L<RDF::Lazy> RDF
graph. Do not use the constructor of this class but factory methods of
L<RDF::Lazy>. General RDF node methods are derived from L<RDF::Lazy::Node>.

=method str

Return the URI value of this node as string. Is also used for comparing nodes.

=method uri

Alias for method 'str'.

=method href

Return the HTML-escaped URI value. Alias for method 'esc'.

=method qname

Returns a qualified name (C<prefix:local>) if a mathcing namespace prefix is
defined. See also method L<RDF::Lazy#ns> for namespace handling.

=encoding utf8

=cut

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
    my $class    = shift;
    my $graph    = shift || RDF::Lazy->new;
    my $resource = shift;

    return unless defined $resource;

    unless (blessed($resource) and $resource->isa('RDF::Trine::Node::Resource')) {
        $resource = RDF::Trine::Node::Resource->new( $resource );
        return unless defined $resource;
    }

    return bless [ $resource, $graph ], $class;
}

sub str {
    shift->trine->uri_value;
}

*uri  = *str;

*href = *RDF::Lazy::Node::esc;

sub qname {
    my $self = shift;
    $self->[1]->{nsprefix} = $self->[1]->{namespaces}->REVERSE
        unless $self->[1]->{nsprefix};
    try {
        my ($ns,$local) = $self->[0]->qname;
        $ns = $self->[1]->{nsprefix}->{$ns} || return "";
        return "$ns:$local";
    } catch { 
        return ""; 
    }
}

1;

=head1 DESCRIPTION

You should not directly create instances of this class.
See L<RDF::Lazy::Node> for general node properties.

=method str

Return the URI value of this node as string. Is also used for comparing nodes.

=method uri

Alias for method 'str'.

=method href

Return the HTML-escaped URI value. Alias for method 'esc'.

=cut

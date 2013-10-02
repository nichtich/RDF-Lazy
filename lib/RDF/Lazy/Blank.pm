use strict;
use warnings;
package RDF::Lazy::Blank;
#ABSTRACT: Blank node in a RDF::Lazy graph

use base 'RDF::Lazy::Node';
use Scalar::Util qw(blessed);

use overload '""' => \&str;

sub new {
    my ($class, $graph, $blank) = @_;

    $blank = RDF::Trine::Node::Blank->new( $blank )
        unless blessed($blank) and $blank->isa('RDF::Trine::Node::Blank');
    return unless defined $blank;

    bless [ 
        $blank, 
        $graph || RDF::Lazy->new 
    ], $class;
}

sub id {
    $_[0]->trine->blank_identifier
}

sub str {
    '_:'.$_[0]->trine->blank_identifier
}

*qname = *str;

1;

=head1 DESCRIPTION

L<RDF::Lazy::Blank> represents a blank node in a L<RDF::Lazy> RDF graph. Do not
use the constructor of this class but factory methods of L<RDF::Lazy>. General
RDF node methods are derived from L<RDF::Lazy::Node>.

=method id

Return the local identifier of this node.

=method qname

Return the local identifier, prepended by "C<_:>".

=method str

Return the local identifier, prepended by "C<_:>".

=encoding utf8

=cut

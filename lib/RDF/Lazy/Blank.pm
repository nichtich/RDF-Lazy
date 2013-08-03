use strict;
use warnings;
package RDF::Lazy::Blank;
#ABSTRACT: Blank node in a RDF::Lazy graph

use base 'RDF::Lazy::Node';
use Scalar::Util qw(blessed);

use overload '""' => \&str;

sub new {
    my $class = shift;
    my $graph = shift || RDF::Lazy->new;
    my $blank = shift;

    $blank = RDF::Trine::Node::Blank->new( $blank )
        unless blessed($blank) and $blank->isa('RDF::Trine::Node::Blank');
    return unless defined $blank;

    return bless [ $blank, $graph ], $class;
}

sub id {
    shift->trine->blank_identifier
}

sub str {
    '_:'.shift->trine->blank_identifier
}

1;

=head1 DESCRIPTION

You should not directly create instances of this class.
See L<RDF::Lazy::Node> for general node properties.

=method id

Return the local identifier of this node.

=method str

Return the local identifier, prepended by "C<_:>".

=encoding utf8

=cut

use strict;
use warnings;
package RDF::Lazy::Literal;
#ABSTRACT: Literal node in a RDF::Lazy graph

use v5.10;

use base 'RDF::Lazy::Node';
use Scalar::Util qw(blessed);

use overload '""' => \&str;

# not very strict check for language tag look-alikes (see www.langtag.net)
our $LANGTAG = qr/^(([a-z]{2,8}|[a-z]{2,3}-[a-z]{3})(-[a-z0-9_]+)?-?)$/i;

sub new {
    my $class   = shift;
    my $graph   = shift // RDF::Lazy->new;
    my $literal = shift // "";
    my $kind    = shift;

    # TODO: why allow passing trine objects?
    unless( blessed($literal) and $literal->isa('RDF::Trine::Node::Literal') ) {
        my ($language, $datatype);

        if (defined $kind) {
            if ($kind =~ $LANGTAG) {
                ($language, $datatype) = ($kind);
            } else {
                ($language, $datatype) = (undef,$graph->uri($kind)->trine);
            }
        }

        # TODO: may croak?
        $literal = RDF::Trine::Node::Literal->new( $literal, $language, $datatype );
    }

    return bless [ $literal, $graph ], $class;
}

sub str {
    $_[0]->trine->literal_value
}

sub lang {
    my $self = shift;
    my $lang = $self->trine->literal_value_language || return;

    if (@_) {
        my $pattern = shift || "";
        $pattern =~ s/_/-/g;
        return unless $pattern =~ $LANGTAG;

        $pattern =~ s/-$/(-.+)?/;

        return if $lang !~ qr/^$pattern$/i;
    }

    # ISO 3166 recommends that country codes are capitalized
    $lang =~ s/-([^-]+)/'-'.uc($1)/e;

    return $lang;
}

sub datatype {
    my $self = shift;
    my $type = $self->graph->resource( $self->trine->literal_datatype );

    return $type unless @_ and $type;

    foreach (@_) {
        my $t = $self->graph->uri( $_ );
        return 1 if $t->is_resource and $t eq $type;
    }

    return;
}

sub _autoload {
    my ($self, $method) = @_;

    return unless $method =~ /^is_(.+)$/;

    # We assume that no language is named 'blank', 'literal', or 'resource'
    return $self->lang($1);
}

1;

=head1 DESCRIPTION

L<RDF::Lazy::Blank> represents a literal node in a L<RDF::Lazy> RDF graph. Do
not use the constructor of this class but factory methods of L<RDF::Lazy>.
General RDF node methods are derived from L<RDF::Lazy::Node>.

=method str

Return the literal string value of this node.

=method esc

Return the HTML-encoded literal string value.

=method lang ( [ $pattern ] )

Return the language tag (a BCP 47 language tag locator), if this node has one,
or test whether the language tag matches a pattern. For instance use 'de' for
plain German (but not 'de-AT') or 'de-' for plain German or any German dialect.

=method is_...

Return whether this node matches a given language tag, for instance

    $node->is_en   # equivalent to $node->lang('en')
    $node->is_en_  # equivalent to $node->lang('en-')

=method datatype ( [ @types ] )

Return the datatype (as L<RDF::Lazy::Resource>), if this node has one. Can also
be used to check whether the datatype matches to a given list of datatypes, for
instance:

    $node->datatype('xsd:integer','xsd:double');

=encoding utf8

=cut

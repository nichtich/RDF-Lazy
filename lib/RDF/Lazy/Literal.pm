use strict;
use warnings;
package RDF::Lazy::Literal;
#ABSTRACT: A literal node in a lazy RDF graph

use base 'RDF::Lazy::Node';
use CGI qw(escapeHTML);

use overload '""' => sub { shift->str; };

# not very strict check for language tag look-alikes (see www.langtag.net)
our $LANGTAG = qr/^(([a-z]{2,8}|[a-z]{2,3}-[a-z]{3})(-[a-z0-9_]+)?-?)$/;

sub new {
    my $class  = shift;
    my $graph  = shift || RDF::Lazy::Node::Graph->new;

    # TODO: lazier and datatype with !
    my ($literal, $language, $datatype) = @_;
    
    $literal = RDF::Trine::Node::Literal->new( $literal, $language, $datatype )
        unless UNIVERSAL::isa( $literal, 'RDF::Trine::Node::Literal');
    return unless defined $literal;
    
    return bless [ $literal, $graph ], $class;
}

sub str { shift->trine->literal_value }

sub esc { escapeHTML( shift->trine->literal_value ) }

sub lang { 
    my $self = shift;
    my $lang = $self->trine->literal_value_language;
    return $lang if not @_ or not $lang;

    my $xxx = shift || "";
    $xxx =~ s/_/-/g;
    return unless $xxx =~ $LANGTAG;

    if ( $xxx eq $lang or $xxx =~ s/-$// and index($lang, $xxx) == 0 ) {
        return $lang;
    }

    return; 
}

sub type { 
    my $self = shift;
    $self->graph->resource( $self->trine->literal_datatype );
}

# we may use a HTML method for xml:lang="lang">$str</

sub _autoload {
    my $self   = shift;
    my $method = shift;

    return unless $method =~ /^is_(.+)$/;

    # We assume that no language is named 'blank', 'literal', or 'resource'
    return 1 if $self->lang($1);
        
    return;
}

sub objects { } # literal notes have no properties

1;

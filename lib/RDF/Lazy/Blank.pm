use strict;
use warnings;
package RDF::Lazy::Blank;
#ABSTRACT: A blank node in a lazy RDF graph

use base 'RDF::Lazy::Node';

sub new {
    my $class = shift;
    my $graph = shift || RDF::Lazy::Node::Graph->new;
    my $blank = shift; 

    $blank = RDF::Trine::Node::Blank->new( $blank )
        unless UNIVERSAL::isa( $blank, 'RDF::Trine::Node::Blank' );
    return unless defined $blank;

    return bless [ $blank, $graph ], $class;
}

sub id { 
    shift->trine->blank_identifier
}

sub str { 
	# TODO: check whether non-XML characters are possible for esc
    '_:'.shift->trine->blank_identifier
}

1;

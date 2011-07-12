use strict;
use warnings;
package RDF::Lazy::Blank;
#ABSTRACT: A blank node in a lazy RDF graph

use base 'RDF::Lazy::Node';

use overload '""' => \&str, 'eq' => \&eq;

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

sub eq { $_[0]->id eq $_[1]->id; }

1;

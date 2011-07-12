use strict;
use warnings;
package RDF::Lazy::Resource;
#ABSTRACT: An resource (URI reference) node in a lazy RDF graph

use base 'RDF::Lazy::Node';
use CGI qw(escapeHTML);

use overload '""' => \&str, 'eq' => \&eq;

sub new {
    my $class    = shift;
    my $graph    = shift || RDF::Lazy::Node::Graph->new;
    my $resource = shift; 

    return unless defined $resource;

    if (!UNIVERSAL::isa( $resource, 'RDF::Trine::Node::Resource')) {
        $resource = RDF::Trine::Node::Resource->new( $resource );
        return unless defined $resource;
    }

    return bless [ $resource, $graph ], $class;
}

sub uri { 
    shift->trine->uri_value 
}

sub href { 
	# TODO: check whether non-XML characters are possible in URI values
    escapeHTML(shift->trine->uri_value); 
}

sub eq { "$_[0]" eq "$_[1]"; } 

*esc = *href;
*str = *uri;

1;

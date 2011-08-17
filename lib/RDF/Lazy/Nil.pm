use strict;
use warnings;
package RDF::Lazy::Nil;

use base 'RDF::Lazy::Node';

use overload '""' => sub { ""; }, 'bool' => sub { 0 };

sub new {
    my $class = shift;
    bless [ ], $class;
}

1;

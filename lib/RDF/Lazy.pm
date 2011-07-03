use strict;
use warnings;
package RDF::Lazy;
#ABSTRACT: Lazy typing access to RDF data

=head1 DESCRIPTION

This module wraps L<RDF::Trine::Node> to provide simple node-centric access to
RDF data. It was designed to access RDF within L<Template> Toolkit but you can
use it independently. Basically, L<RDF::Lazy> wraps an RDF graph that contains
RDF nodes (L<RDF::Lazy::Node>). Each node knows its graph, so you can traverse 
the graph starting from any node.

=cut

use RDF::Trine::Model;
use RDF::Trine::NamespaceMap;
use CGI qw(escapeHTML);

use RDF::Lazy::Node;
use Scalar::Util qw(blessed);
use Carp qw(carp croak);

our $AUTOLOAD;

sub new {
    my ($class, %arg) = @_;

	# TODO: constructor is not lazy enough
    my $namespaces = $arg{namespaces} || RDF::Trine::NamespaceMap->new;
    $namespaces = RDF::Trine::NamespaceMap->new( $namespaces ) unless 
		blessed($namespaces) and $namespaces->isa('RDF::Trine::NamespaceMap');

    my $model = $arg{model} || RDF::Trine::Model->new;
	# TODO: Store, Graph, serialization...

    bless {
        namespaces => $namespaces,
        model      => $model
    }, $class;
}

sub model { $_[0]->{model} }

sub objects {
	carp __PACKAGE__ . '::objects is depreciated - use ::get instead!';
	rel( @_ );
}

sub rels { # TODO: merge with sub rel
    my ($self,$subject,$property,@filter) = @_;

    $subject = $self->node($subject)
        unless UNIVERSAL::isa( $subject, 'RDF::Lazy::Node' );

    my $predicate = $self->node($property);

    if (defined $predicate) {
        my @objects = $self->{model}->objects( $subject->trine, $predicate->trine );

        @objects = map { $self->node( $_ ) } @objects;

        # TODO apply filters one by one and return in order of filters
        @objects = grep { $_->is(@filter) } @objects
            if @filter;

        return \@objects if @objects;
    }

    return;
}

sub rel {
    my $self     = shift;
    my $subject  = shift;
    my $property = shift; # mandatory
    my @filter   = @_;

    $subject = $self->node($subject)
        unless UNIVERSAL::isa( $subject, 'RDF::Lazy::Node' );

    my $all = ($property =~ s/^(.+[^_])_$/$1/) ? 1 : 0;
    my $predicate = $self->node($property);

    if (defined $predicate) {
        my @objects = $self->{model}->objects( $subject->trine, $predicate->trine );

        @objects = map { $self->node( $_ ) } @objects;

        # TODO apply filters one by one and return in order of filters
        @objects = grep { $_->is(@filter) } @objects
            if @filter;

        return unless @objects;
        
        if ($all) {
           return \@objects;
        } else {   
           return $objects[0];
        }
    }

    return;
}

sub rev {
    croak 'not implemented yet';
}

sub revs {
    croak 'not implemented yet';
}

*rel_ = *rels;
*rev_ = *revs;

sub turtle { # FIXME
    my $self     = shift;
    my $subject  = shift;

    $subject = $self->node($subject)
        unless UNIVERSAL::isa( $subject, 'RDF::Lazy::Node' );
   
    use RDF::Trine::Serializer::Turtle;
    my $serializer = RDF::Trine::Serializer::Turtle->new( namespaces => $self->{namespaces} );

    my $iterator = $self->{model}->bounded_description( $subject->trine );
    my $turtle   = $serializer->serialize_iterator_to_string( $iterator );
    my $html     = escapeHTML( '# '.$subject->str."\n$turtle" );

    return '<pre class="turtle">'.$html.'</pre>';
}

*ttl = *turtle;

sub resource { RDF::Lazy::Resource->new( @_ ) }
sub literal  { RDF::Lazy::Literal->new( @_ ) }
sub blank    { RDF::Lazy::Blank->new( @_ ) }

sub node {
    my $self = shift;

    if (!UNIVERSAL::isa( $_[0], 'RDF::Trine::Node' )) {
        my $name = shift;
        return unless defined $name;
		my ($prefix,$local,$uri);

	    if ( $name =~ /^([^:]*):([^:]*)$/ ) {
            ($prefix,$local) = ($1,$2);
		} elsif ( $name =~ /^(([^_:]*)_)?([^_:]+.*)$/ ) {
            ($prefix,$local) = ($2,$3);
            $local =~ s/__/_/g;
	    } else {
			return;
		}

        if (defined $prefix) {
            $uri = $self->{namespaces}->uri("$prefix:$local");
        } else {
            # TODO: Fix bug in RDF::Trine::NamespaceMap, line 133
            # $predicate = $self->{namespaces}->uri(":$local");
            my $ns = $self->{namespaces}->namespace_uri("");
            $uri = $ns->uri($local) if defined $ns;
        }

        return unless defined $uri; 
        @_ = ($uri);
    }

    return $self->resource( @_ )
        if UNIVERSAL::isa( $_[0], 'RDF::Trine::Node::Resource' ); 

    return $self->literal( @_ )
        if UNIVERSAL::isa( $_[0], 'RDF::Trine::Node::Literal' );

    return $self->blank( @_ )
        if UNIVERSAL::isa( $_[0], 'RDF::Trine::Node::Blank' );

    return;
}

sub add {
    my ($self, $add) = @_;
    
    if (UNIVERSAL::isa($add, 'RDF::Trine::Statement')) {
        $self->model->add_statement( $add );
    } elsif (UNIVERSAL::isa($add, 'RDF::Trine::Iterator')) {
        _add_iterator( $self->model, $add ); 
    } elsif (UNIVERSAL::isa($add, 'RDF::Trine::Model')) {
        $self->add( $add->as_stream ); # TODO: test this
    }

    # TODO: add triple with subject, predicate in custom form and object
    # as custom form, blank, or literal
}

# Is there no RDF::Trine::Model::add_iterator ??
sub _add_iterator {
    my ($model, $iter) = @_;
    
    $model->begin_bulk_ops;
    while (my $st = $iter->next) { 
        $model->add_statement( $st ); 
    }
    $model->end_bulk_ops;
}

sub AUTOLOAD {
    my $self = shift;
    return if !ref($self) or $AUTOLOAD =~ /^(.+::)?DESTROY$/;

    my $name = $AUTOLOAD;
    $name =~ s/.*:://;

    return if $name =~ /^(uri|query|sparql|model)$/; # reserved words

    return $self->node($name);
}

1;

__END__

=head1 SYNOPSIS

  $x->rel('foaf:knows');  # a person that $x knows
  $x->rev('foaf:knows');  # a person known by $x
  
  $x->rels('foaf:knows'); # all people that $x knows
  $x->rel_('foaf:knows'); # dito

  $x->revs('foaf:knows'); # all people known by $x
  $x->rev_('foaf:knows'); # dito

  $x->foaf_knows;         # short form of $x->rel('foaf:knows')
  $x->foaf_knows_;        # short form of $x->rels('foaf:knows')

=method resource
=method literal
=method blank

Return RDF nodes of type resource (L<RDF::Lazy::Resource>), literal 
(L<RDF::Lazy::Literal>), or blank (L<RDF::Lazy::Blank>).

=method node ( $name | $node )

Returns a node that is connected to the graph. Note that every valid RDF node
is part of any RDF graph: this method does not check whether the graph actually
contains a triple with the given node. You can either pass a name or an
instance of L<RDF::Trine::Node>. This method is also called for any undefined
method, so the following statements are equivalent:

    $graph->alice;
    $graph->node('alice');

=method rel ( $subject, $property [, @filters ] )

Returns a list of objects that occur in statements in this graph. The full
functionality of this method is not fixed yet.

=method turtle ( [ $node ] )
=method ttl ( [ $node ] )

Returns an HTML escaped RDF/Turtle representation of a node's bounded 
connections (not fully implemented yet).

=method dump ( [ $node ] )

Returns an HTML representation of a selected node and its connections or of
the full graph (not implemented yet).

=back

=cut

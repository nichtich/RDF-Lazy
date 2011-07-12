use strict;
use warnings;
package RDF::Lazy;
#ABSTRACT: Lazy typing access to RDF data

use RDF::Trine::Model;
use RDF::Trine::NamespaceMap;
use CGI qw(escapeHTML);

use RDF::Lazy::Node;
use Scalar::Util qw(blessed);
use Carp qw(carp croak);

our $AUTOLOAD;

sub new {
	my $class = shift;
	my ($rdf, %args) = (@_ % 2) ? @_ : (undef,@_);
    $rdf = $args{model} if defined $args{model};	

    my $namespaces = $args{namespaces} || RDF::Trine::NamespaceMap->new;
    $namespaces = RDF::Trine::NamespaceMap->new( $namespaces ) unless 
		blessed($namespaces) and $namespaces->isa('RDF::Trine::NamespaceMap');

    my $self = bless {
        namespaces => $namespaces,
    }, $class;

	$self->parse( $rdf, %args );

    $self;
}

# method includes parts of RDF::TrineShortcuts::rdf_parse by Toby Inkster
sub parse {
	my ($self,$rdf,%args) = @_;

    my $model = $args{model} || RDF::Trine::Model->new;

	# TODO: have a look at RDF::TrineShortcuts::rdf_parse

	if (not defined $rdf) {
		# empty model
	} elsif (blessed $rdf) {
		if ($rdf->isa('RDF::Trine::Graph')) {
			# we could use $rdf->{model} instead but not sure if we want
			$rdf = $rdf->get_statements; # by value
		}
		if ($rdf->isa('RDF::Trine::Model')) {
			$model = $rdf; # by reference
		} elsif ($rdf->isa('RDF::Trine::Store')) {
			$model = RDF::Trine::Model->new($rdf); # by reference
		} elsif ($rdf->isa('RDF::Trine::Iterator::Graph')) { 
			$model = RDF::Trine::Model->temporary_model;
			$model->begin_bulk_ops;
			while (my $row = $rdf->next) { 
				$model->add_statement( $row ); # by value
			}
			$model->end_bulk_ops;
		} elsif ($rdf->isa('RDF::Trine::Statement')) {
			$model = RDF::Trine::Model->temporary_model;
			$model->add_statement( $rdf ); # by value
		}
	} elsif ( ref $rdf and ref $rdf eq 'HASH' ) {
		$model->add_hashref($rdf);
	} else {
		# TODO: parse from file, glob, or string
		# reuse namespaces if parsing Turtle or SPARQL

		$model = RDF::Trine::Model->temporary_model;
		my $format = $args{format} || 'turtle';
		my $base   = $args{base} || 'http://localhost/';
		my $parser = RDF::Trine::Parser->new( $format );
		$parser->parse_into_model( $base, $rdf, $model );
	}
	croak __PACKAGE__ . '::new got unknown rdf source' unless $model;

	$self->{model} = $model;
}

sub query {
	# See RDF::TrineShortcuts::rdf_query
	carp __PACKAGE__ . '::query not implemented yet';
}

*sparql = *query;

sub model { $_[0]->{model} }

sub size { $_[0]->{model}->size }

sub objects {
	carp __PACKAGE__ . '::objects is depreciated - use ::get instead!';
	rel( @_ );
}

sub _query {
    my ($self,$all,$dir,$subject,$property,@filter) = @_;

    $subject = $self->uri($subject)
        unless UNIVERSAL::isa( $subject, 'RDF::Lazy::Node' );

    $property = $self->uri($property) if defined $property;
    $property = $property->trine if defined $property;

    my @res;

    if ($dir eq 'rel') {
	    @res = $self->{model}->objects( $subject->trine, $property );
	} elsif ($dir eq 'rev') {
	    @res = $self->{model}->subjects( $property, $subject->trine );
	}

	@res = map { $self->uri( $_ ) } @res;

	# TODO apply filters one by one and return in order of filters
	@res = grep { $_->is(@filter) } @res if @filter;

	return $all ? \@res : $res[0];
}

sub _relrev {
	my $self    = shift;
	my $all     = shift;
	my $type    = shift;
	my $subject = shift;

	if (@_) {
	    # get objects / subjects
        my ($property,@filter) = @_;
		$all = 1 if ($property and not ref $property and $property =~ s/^(.+[^_])_$/$1/);
        return $self->_query( $all, $type, $subject, $property, @filter );
	} else { 
	    # get all predicates
	    $subject = $self->uri($subject)
        unless UNIVERSAL::isa( $subject, 'RDF::Lazy::Node' );

		my @res;

	    if ($type eq 'rel') {
		    @res = $self->{model}->predicates( $subject->trine, undef );
		} elsif ($type eq 'rev') {
		    @res = $self->{model}->predicates( undef, $subject->trine );
		}

		return $all ? [ map { $self->uri( $_ ) } @res ] : $self->uri( $res[0] );
	}
}

sub rels { shift->_relrev( 1, 'rel', @_  ); }
sub rel  { shift->_relrev( 0, 'rel', @_  ); }
sub rev  { shift->_relrev( 0, 'rev', @_  ); }
sub revs { shift->_relrev( 1, 'rev', @_  ); }

*rel_ = *rels; # needed?
*rev_ = *revs;

sub turtle { # FIXME
    my $self     = shift;
    my $subject  = shift;

    $subject = $self->uri($subject)
        unless UNIVERSAL::isa( $subject, 'RDF::Lazy::Node' );
   
    use RDF::Trine::Serializer::Turtle;
    my $serializer = RDF::Trine::Serializer::Turtle->new( namespaces => $self->{namespaces} );

    my $iterator = $self->{model}->bounded_description( $subject->trine );
    my $turtle   = $serializer->serialize_iterator_to_string( $iterator );

    return $turtle;
}

*ttl = *turtle;

sub ttlpre {
    my ($self,$node) = @_;
    '<pre class="turtle">' . escapeHTML(
		"# $node\n" .$self->turtle($node)
	) . '</pre>';
}

sub resource { RDF::Lazy::Resource->new( @_ ) }
sub literal  { RDF::Lazy::Literal->new( @_ ) }
sub blank    { RDF::Lazy::Blank->new( @_ ) }

sub node {
	carp __PACKAGE__ . '::node is depreciated - use ::uri instead!';
	uri(@_);
}

sub uri {
    my $self = shift;

    if (!UNIVERSAL::isa( $_[0], 'RDF::Trine::Node' )) {
        my $name = shift;
        return unless defined $name;
		my ($prefix,$local,$uri);

	    if ( $name =~ /^([^:]*):([^:]*)$/ ) {
            ($prefix,$local) = ($1,$2);
		} elsif ( $name =~ /^(([^_:]*)_)?([^_:]+.*)$/ ) {
            ($prefix,$local) = ($2,$3);
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

    # TODO: parse and add in Turtle syntax

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

    return $self->uri($name);
}

1;

__END__

=head1 DESCRIPTION

This module wraps L<RDF::Trine::Node> to provide simple node-centric access to
RDF data. It was designed to access RDF within L<Template> Toolkit but it can
also be used independently. Basically, an instance of RDF::Lazy contains an
unlabeled RDF graph and a set of namespace prefix for lazy access. Each RDF 
nodes (L<RDF::Lazy::Node>) is connected to its graph for lazy graph traversal.

=head1 SYNOPSIS

  $g = RDF::Lazy->new(
  	  model      => $model,
  	  namespaces => { foaf => 'http://xmlns.com/foaf/0.1/' }
  );

  $p = $f->resource('http://xmlns.com/foaf/0.1/Person'); # create node
  $p = $f->uri('foaf:Person);                            # same but lazier
  $p = $f->foaf_Person;                                  # same but laziest


  $s = $g->label('Alice'); # creates a literal node
  $s = $g->blank;

  $x->rel('foaf:knows');   # a person that $x knows
  $x->rev('foaf:knows');   # a person known by $x
  
  $x->rels('foaf:knows');  # all people that $x knows
  $x->rel_('foaf:knows');  # same

  $x->revs('foaf:knows');  # all people known by $x
  $x->rev_('foaf:knows');  # same

  $x->foaf_knows;          # short form of $x->rel('foaf:knows')
  $x->foaf_knows_;         # short form of $x->rels('foaf:knows')

  $x->type;                # same as $x->rel('rdf:type')
  $x->types;               # same as $x->rels('rdf:type')

=method resource
=method literal
=method blank

Return RDF nodes of type resource (L<RDF::Lazy::Resource>), literal 
(L<RDF::Lazy::Literal>), or blank (L<RDF::Lazy::Blank>).

=method uri ( $name | $node )

Returns a node that is connected to the graph. Note that every valid RDF node
is part of any RDF graph: this method does not check whether the graph actually
contains a triple with the given node. You can either pass a name or an
instance of L<RDF::Trine::Node>. This method is also called for any undefined
method, so the following statements are equivalent:

    $graph->alice;
    $graph->uri('alice');

=method rel ( $subject, $property [, @filters ] )

Returns a list of objects that occur in statements in this graph. The full
functionality of this method is not fixed yet.

=method turtle ( [ $node ] )
=method ttl ( [ $node ] )

Returns a RDF/Turtle representation of a node's bounded description.

=method ttlpre ( [ $node ] )

Returns an HTML escaped RDF/Turtle representation of a node's bounded description.

=method dump ( [ $node ] )

Returns an HTML representation of a selected node and its connections or of
the full graph (not implemented yet).

=back

=head1 SEE ALSO

L<RDF::TrineShortcuts> provides some overlap with RDF::Lazy. 

=cut

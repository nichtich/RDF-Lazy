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

sub parse {
	my ($self,$rdf,%args) = @_;

    my $model = $args{model} || RDF::Trine::Model->new;

	# This is not fully transaction save!
	$self->{model} = $model;

	if (blessed $rdf) {
		if ($rdf->isa('RDF::Trine::Model')) {
			return; # model added by reference
		} elsif ($rdf->isa('RDF::Trine::Store')) {
			$self->{model} = RDF::Trine::Model->new($rdf); 
			return; # model added by reference
		}
	}

	$self->add( $rdf, %args );
}

# method includes parts of RDF::TrineShortcuts::rdf_parse by Toby Inkster
sub add { # rdf by value
	my $self = shift;

	# TODO: have a look at RDF::TrineShortcuts::rdf_parse

    if (@_ == 3 and $_[1] !~ /^[a-z]+$/) { # TODO: allow 'a'?
		my @triple = @_; 
		@triple = map { $self->uri($_) } @triple;
		unless ( grep { not defined $_ } @triple ) {
			@triple = map { $_->trine } @triple;
			my $stm = RDF::Trine::Statement->new( @triple );
			$self->model->add_statement( $stm );
		}
		return;
	}

    my ($rdf, %args) = @_;

	if (blessed $rdf) {
	    if ($rdf->isa('RDF::Trine::Graph')) {
			$rdf = $rdf->get_statements; # by value
		}
		if ($rdf->isa('RDF::Trine::Iterator::Graph')) { 
			$self->model->begin_bulk_ops;
			while (my $row = $rdf->next) { 
				$self->model->add_statement( $row );
			}
			$self->model->end_bulk_ops;
		} elsif ($rdf->isa('RDF::Trine::Statement')) {
			$self->model->add_statement( $rdf );
        } elsif ($rdf->isa('RDF::Trine::Model')) {
        	$self->add( $rdf->as_stream );
		} else {
			croak 'Cannot add RDF object of type ' . ref($rdf);
		}
	} elsif ( ref $rdf and ref $rdf eq 'HASH' ) {
		$self->model->add_hashref($rdf);
	} else {
		# TODO: parse from file, glob, or string in Turtle syntax or other
		# reuse namespaces if parsing Turtle or SPARQL

		my $format = $args{format} || 'turtle';
		my $base   = $args{base} || 'http://localhost/';
		my $parser = RDF::Trine::Parser->new( $format );
		$parser->parse_into_model( $base, $rdf, $self->model );
	}
}

sub query {
	# TODO: See RDF::TrineShortcuts::rdf_query
	carp __PACKAGE__ . '::query not implemented yet';
}

*sparql = *query;

sub model { $_[0]->{model} }

sub size { $_[0]->{model}->size }

sub objects {
	carp __PACKAGE__ . '::objects is depreciated - use ::get instead!';
	rel( @_ );
}


sub rels { shift->_relrev( 1, 'rel', @_  ); }
sub rel  { shift->_relrev( 0, 'rel', @_  ); }
sub rev  { shift->_relrev( 0, 'rev', @_  ); }
sub revs { shift->_relrev( 1, 'rev', @_  ); }

*rel_ = *rels; # needed?
*rev_ = *revs;

sub turtle {
    my $self     = shift;
    my $subject  = shift;
  
    use RDF::Trine::Serializer::Turtle;
    my $serializer = RDF::Trine::Serializer::Turtle->new( namespaces => $self->{namespaces} );

	my $iterator;

	if ($subject) {
	    $subject = $self->uri($subject)
    	    unless UNIVERSAL::isa( $subject, 'RDF::Lazy::Node' );
    	$iterator = $self->{model}->bounded_description( $subject->trine );
	} else {
		$iterator = $self->model->as_stream;
	}

    return $serializer->serialize_iterator_to_string( $iterator );
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
    my ($self,$node) = @_;
    return unless defined $node;

	if (blessed $node) {
   		if ($node->isa('RDF::Lazy::Node')) {
			$node = $self->uri( $node->trine ); # copy from another graph
		}
	    if ($node->isa('RDF::Trine::Node::Resource')) {
		    return $self->resource( $node );
        } elsif ($node->isa('RDF::Trine::Node::Literal')) {
   		 	return $self->literal( $node );
		} elsif ($node->isa('RDF::Trine::Node::Blank')) {
	    	return $self->blank( $node );
		} else {
			carp 'Cannot create RDF::Lazy::Node from '.ref($node);
			return;
		}
	}

	my ($prefix,$local,$uri);

	if ( $node =~ /^<(.*)>$/ ) {
		return $self->resource($1);
	} elsif ( $node =~ /^_:(.*)$/ ) {
		return $self->blank( $1 );
	} elsif ( $node =~ /^\[\s*\]$/ ) {
		return $self->blank;
	} elsif ( $node =~ /^["'](.*)["']?$/ ) {
		carp "literal uris not supported yet";
		return;
	} elsif ( $node =~ /^([^:]*):([^:]*)$/ ) {
		($prefix,$local) = ($1,$2);
	} elsif ( $node =~ /^(([^_:]*)_)?([^_:]+.*)$/ ) {
		($prefix,$local) = ($2,$3);
	} else {
		return;
	}

	if (defined $prefix) {
		$uri = $self->{namespaces}->uri("$prefix:$local");
	} else {
		# TODO: Fix bug in RDF::Trine::NamespaceMap, line 133
		# $predicate = $self->{namespaces}->uri(":$local");
		my $ns = $self->{namespaces}->namesespace_uri("");
		$uri = $ns->uri($local) if defined $ns;
	}

	return unless defined $uri; 
	return $self->resource( $uri );
}

sub AUTOLOAD {
    my $self = shift;
    return if !ref($self) or $AUTOLOAD =~ /^(.+::)?DESTROY$/;

    my $name = $AUTOLOAD;
    $name =~ s/.*:://;

    return $self->uri($name);
}

### internal methods

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

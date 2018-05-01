# This module is part of debbugs, and
# is released under the terms of the GPL version 2, or any later
# version (at your option). See the file README and COPYING for more
# information.
# Copyright 2018 by Don Armstrong <don@donarmstrong.com>.

package Debbugs::Version;

=head1 NAME

Debbugs::Version -- OO interface to Version

=head1 SYNOPSIS

   use Debbugs::Version;
   Debbugs::Version->new(schema => $s,binaries => [qw(foo)],sources => [qw(bar)]);

=head1 DESCRIPTION



=cut

use Mouse;
use strictures 2;
use namespace::autoclean;

use Debbugs::Collection::Package;
use Debbugs::OOTypes;

extends 'Debbugs::OOBase';

state $strong_severities =
   {map {($_,1)} @{$config{strong_severities}}};

has version => (is => 'ro', isa => 'Str',
		required => 1,
		builder => '_build_version',
		predicate => '_has_version',
	       );

has source_version => (is => 'ro',
		       isa => 'Str',
		       builder => '_build_source_version',
		       predicate => '_has_source_version',
		       clearer => '_clear_source_version',
		      );

has source => (is => 'ro',
	       isa => 'Debbugs::Package',
	       lazy => 1,
	       writer => 'set_source',
	       builder => '_build_source',
	       predicate => '_has_source',
	       clearer => '_clear_source',
	      );

has packages => (is => 'rw',
		 isa => 'Debbugs::Collection::Package',
		 writer => 'set_package',
		 builder => '_build_package',
		 predicate => '_has_package',
		 clearer => '_clear_package',
		);

has 'package_collection' => (is => 'ro',
			     isa => 'Debbugs::Collection::Package',
			     builder => '_build_package_collection',
			     lazy => 1,
			    );

sub _build_package_collection {
    return Debbugs::Collection::Package->new();
}

# one of source_version or version must be provided

sub BUILD {
    my $self = shift;
    my $args = shift;
    if (not $self->_has_version and
	not $self->_has_source_version) {
	confess("Version objects must have at least a source version or a version");
    }
    if ($self->_has_source and
	$self->source->is_source
       ) {
	confess("You have provided a source package which is not a source package");
    }
}

sub _build_version {
    my $self = shift;
    my $srcver = $self->source_version;
    $srcver =~ s{.+/}{};
    return $srcver;
}

sub _build_source_version {
    my $self = shift;
    # should we verify that $self->source is a valid package?
    my $src = $self->source;
    if ($src->is_valid) {
	return $self->source->name.'/'.$self->version;
    }
    # do we want invalid sources to be in parenthesis?
    return $self->version;
}

sub _build_source {
    my $self = shift;
    if ($self->_has_binaries) {
	# this should be the standard case
	if ($self->binaries->sources->count == 1) {
	    return $self->binaries->sources->first(sub {1});
	}
	# might need to figure out how to speed up limit_by_version
	return $self->binaries->limit_by_version($self->version)->
	    sources;
    }
    confess("No binary package, cannot know what source package this version is for");
}

sub _build_packages {
    my $self = shift;
    if ($self->_has_source) {
	return $self->package_collection->
	    get_or_create($self->source->binaries,$self->source);
    }
    confess("No source package, cannot know what binary packages this version is for");
}

__PACKAGE__->meta->make_immutable;
no Mouse;
1;


__END__
# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:

# This module is part of debbugs, and
# is released under the terms of the GPL version 2, or any later
# version (at your option). See the file README and COPYING for more
# information.
# Copyright 2018 by Don Armstrong <don@donarmstrong.com>.

package Debbugs::Version::Binary;

=head1 NAME

Debbugs::Version::Binary -- OO interface to Version

=head1 SYNOPSIS

   use Debbugs::Version::Binary;
   Debbugs::Version::Binary->new(schema => $s,binaries => [qw(foo)],sources => [qw(bar)]);

=head1 DESCRIPTION



=cut

use Mouse;
use v5.10;
use strictures 2;
use namespace::autoclean;

use Debbugs::Config qw(:config);
use Debbugs::Collection::Package;
use Debbugs::OOTypes;

extends 'Debbugs::Version';

sub type {
    return 'binary';
}

has source_version => (is => 'ro',
		       isa => 'Debbugs::Version::Source',
		       lazy => 1,
		       builder => '_build_source_version',
		      );

sub _build_source_version {
    my $self = shift;
    my $source_version =
	$self->package->
	get_source_version(version => $self->version,
			   $self->_count_archs?(archs => [$self->_archs]):(),
			  );
    if (defined $source_version) {
	return $source_version;
    }
    return Debbugs::Version::Source->new(version => $self->version,
					 package => '(unknown)',
					 valid => 0,
					 package_collection => $self->package_collection,
					);
}

has archs => (is => 'bare',
	      isa => 'ArrayRef[Str]',
	      builder => '_build_archs',
	      traits => ['Array'],
	      handles => {'_archs' => 'elements',
			  '_count_archs' => 'count',
			 },
	     );

sub _build_archs {
    my $self = shift;
    # this is wrong, but we'll start like this for now
    return ['any'];
}

sub arch {
    my $self = shift;
    return $self->_count_archs > 0?join('',$self->_archs):'any';
}


__PACKAGE__->meta->make_immutable;
no Mouse;
1;


__END__
# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:

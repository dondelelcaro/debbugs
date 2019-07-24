# This module is part of debbugs, and
# is released under the terms of the GPL version 2, or any later
# version (at your option). See the file README and COPYING for more
# information.
# Copyright 2018 by Don Armstrong <don@donarmstrong.com>.

package Debbugs::Version;

=head1 NAME

Debbugs::Version -- OO interface to Version

=head1 SYNOPSIS

This package provides a convenient interface to refer to package versions and
potentially make calculations based upon them

   use Debbugs::Version;
   my $v = Debbugs::Version->new(schema => $s,binaries => [qw(foo)],sources => [qw(bar)]);

=head1 DESCRIPTION



=cut

use Mouse;
use v5.10;
use strictures 2;
use namespace::autoclean;

use Debbugs::Config qw(:config);
use Debbugs::Collection::Package;
use Debbugs::OOTypes;
use Carp;

extends 'Debbugs::OOBase';

=head1 Object Creation

=head2 my $version = Debbugs::Version::Source->new(%params|$param)

or C<Debbugs::Version::Binary->new(%params|$param)> for a binary version

=over

=item schema

L<Debbugs::DB> schema which can be used to look up versions

=item package

String representation of the package

=item pkg

L<Debbugs::Package> which refers to the package given.

Only one of C<package> or C<pkg> should be given

=item package_collection

L<Debbugs::Collection::Package> which is used to generate a L<Debbugs::Package>
object from the package name

=back

=cut

around BUILDARGS => sub {
    my $orig = shift;
    my $class = shift;
    if ($class eq __PACKAGE__) {
        confess("You should not be instantiating Debbugs::Version. ".
                "Use Debbugs::Version::Source or ::Binary");
    }
    my %args;
    if (@_==1 and ref($_[0]) eq 'HASH') {
	%args = %{$_[0]};
    } else {
        %args = @_;
    }
    return $class->$orig(%args);
};



state $strong_severities =
   {map {($_,1)} @{$config{strong_severities}}};

=head1 Methods

=head2 version

     $version->version

Returns the source or binary package version

=cut

has version => (is => 'ro', isa => 'Str',
		required => 1,
		builder => '_build_version',
		predicate => '_has_version',
	       );

=head2 type

Returns 'source' if this is a source version, or 'binary' if this is a binary
version.

=cut

=head2 source_version

Returns the source version for this version; if this is a source version,
returns itself.

=cut

=head2 src_pkg_ver

Returns the fully qualified source_package/version string for this version.

=cut

=head2 package

Returns the name of the package that this version is in

=cut

has package => (is => 'ro',
                isa => 'Str',
                builder => '_build_package',
                predicate => '_has_package',
                lazy => 1,
               );

sub _build_package {
    my $self = shift;
    if ($self->_has_pkg) {
        return $self->pkg->name;
    }
    return '(unknown)';
}

=head2 pkg

Returns a L<Debbugs::Package> object corresponding to C<package>.

=cut


has pkg => (is => 'ro',
            isa => 'Debbugs::Package',
            lazy => 1,
            builder => '_build_pkg',
            reader => 'pkg',
            predicate => '_has_pkg',
           );

sub _build_pkg {
    my $self = shift;
    return Debbugs::Package->new(package => $self->package,
                                 type => $self->type,
                                 valid => 0,
                                 package_collection => $self->package_collection,
                                 $self->schema_argument,
                                );
}


=head2 valid

Returns 1 if this package is valid, 0 otherwise.

=cut

has valid => (is => 'ro',
	      isa => 'Bool',
	      reader => 'is_valid',
              lazy => 1,
              builder => '_build_valid',
	     );

sub _build_valid {
    my $self = shift;
    return 0;
}


=head2 package_collection

Returns the L<Debugs::Collection::Package> which is in use by this version
object.

=cut

has 'package_collection' => (is => 'ro',
			     isa => 'Debbugs::Collection::Package',
			     builder => '_build_package_collection',
			     lazy => 1,
			    );
sub _build_package_collection {
    my $self = shift;
    return Debbugs::Collection::Package->new($self->schema_arg)
}


__PACKAGE__->meta->make_immutable;
no Mouse;
1;


__END__
# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:

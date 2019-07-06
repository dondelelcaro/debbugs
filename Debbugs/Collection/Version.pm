# This module is part of debbugs, and
# is released under the terms of the GPL version 2, or any later
# version (at your option). See the file README and COPYING for more
# information.
# Copyright 2018 by Don Armstrong <don@donarmstrong.com>.

package Debbugs::Collection::Version;

=head1 NAME

Debbugs::Collection::Version -- Version generation factory

=head1 SYNOPSIS

This collection extends L<Debbugs::Collection> and contains members of
L<Debbugs::Version>. Useful for any field which contains package versions.


=head1 DESCRIPTION



=cut

use Mouse;
use strictures 2;
use v5.10; # for state
use namespace::autoclean;
use Debbugs::Common qw(make_list hash_slice);
use Debbugs::Config qw(:config);
use Debbugs::OOTypes;
use Debbugs::Version;

use List::AllUtils qw(part);

extends 'Debbugs::Collection';

=head2 my $bugs = Debbugs::Collection::version->new(%params|$param)

Parameters in addition to those defined by L<Debbugs::Collection>

=over

=item package_collection

Optional L<Debbugs::Collection::Package> which is used to look up packages

=item versions

Optional arrayref of C<package/version/arch> string triples

=back

=cut

has '+members' => (isa => 'ArrayRef[Debbugs::Version]');

has 'package_collection' =>
    (is => 'ro',
     isa => 'Debbugs::Collection::Package',
     builder => '_build_package_collection',
     lazy => 1,
    );

sub _build_package_collection {
    my $self = shift;
    return Debbugs::Collection::Package->new($self->schema_argument);
}

sub member_key {
    my ($self,$v) = @_;
    confess("v not defined") unless defined $v;
    return $v->package.'/'.$v->version.'/'.$v->arch;
}


around add_by_key => sub {
    my $orig = shift;
    my $self = shift;
    my @members =
        $self->_member_constructor(versions => [@_]);
    return $self->$orig(@members);
};

sub _member_constructor {
    my $self = shift;
    my %args = @_;
    my @return;
    for my $pkg_ver_arch (make_list($args{versions})) {
        my ($pkg,$ver,$arch) = $pkg_ver_arch =~ m{^([^/]+)/([^/]+)/?([^/]*)$} or
            confess("Invalid version key: $pkg_ver_arch");
        if ($pkg =~ s/^src://) {
            $arch = 'source';
        }
        if (not length $arch) {
            $arch = 'any';
        }
        if ($arch eq 'source') {
            push @return,
                Debbugs::Version::Source->
                    new($self->schema_argument,
                        package => $pkg,
                        version => $ver,
                       );
        } else {
            push @return,
                Debbugs::Version::Binary->
                    new($self->schema_argument,
                        package => $pkg,
                        version => $ver,
                        arch => [$arch],
                       );
        }
    }
    return @return;
}

=head2 $versions->universe

Unlike most collections, Debbugs::Collection::Version do not have a universe.

=cut

sub universe {
    return $_[0];
}

=head2 $versions->source

Returns a (potentially duplicated) list of source packages which are part of
this version collection

=cut

sub source {
    my $self = shift;
    return $self->map(sub{$_->source});
}

__PACKAGE__->meta->make_immutable;

1;

__END__
# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:

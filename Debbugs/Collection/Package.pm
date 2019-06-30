# This module is part of debbugs, and
# is released under the terms of the GPL version 2, or any later
# version (at your option). See the file README and COPYING for more
# information.
# Copyright 2018 by Don Armstrong <don@donarmstrong.com>.

package Debbugs::Collection::Package;

=head1 NAME

Debbugs::Collection::Package -- Package generation factory

=head1 SYNOPSIS

This collection extends L<Debbugs::Collection> and contains members of
L<Debbugs::Package>. Useful for any field which contains one or more package or
tracking lists of packages


=head1 DESCRIPTION



=cut

use Mouse;
use strictures 2;
use v5.10; # for state
use namespace::autoclean;

use Carp;
use Debbugs::Common qw(make_list hash_slice);
use Debbugs::Config qw(:config);
use Debbugs::OOTypes;
use Debbugs::Package;

use List::AllUtils qw(part);

use Debbugs::Version::Binary;
use Debbugs::Collection::Version;
use Debbugs::Collection::Correspondent;
use Debbugs::VersionTree;

extends 'Debbugs::Collection';

=head1 Object Creation

=head2 my $packages = Debbugs::Collection::Package->new(%params|$param)

Parameters in addition to those defined by L<Debbugs::Collection>

=over

=item correspondent_collection

Optional L<Debbugs::Collection::Correspondent> which is used to look up correspondents


=item versiontree

Optional L<Debbugs::VersionTree> which contains known package source versions

=back

=head1 Methods

=head2 correspondent_collection

     $packages->correspondent_collection

Returns the L<Debbugs::Collection::Correspondent> for this package collection

=head2 versiontree

Returns the L<Debbugs::VersionTree> for this package collection

=cut

has '+members' => (isa => 'ArrayRef[Debbugs::Package]');

sub BUILD {
    my $self = shift;
    my $args = shift;
    if (exists $args->{packages}) {
        $self->
            add($self->_member_constructor(packages =>
                                           $args->{packages}));
    }
}

around add_by_key => sub {
    my $orig = shift;
    my $self = shift;
    my @members =
        $self->_member_constructor(packages => [@_]);
    return $self->$orig(@members);
};

sub _member_constructor {
    # handle being called $self->_member_constructor;
    my $self = shift;
    my %args = @_;
    my $schema;
    if ($self->has_schema) {
        $schema = $self->schema;
    }
    my @return;
    if (defined $schema) {
        if (not ref($args{packages}) or @{$args{packages}} == 1 and
            $self->universe->count() > 0
           ) {
            carp("Likely inefficiency; member_constructor called with one argument");
        }
        my $packages =
            Debbugs::Package::_get_valid_version_info_from_db(packages => $args{packages},
                                                              schema => $schema,
                                                             );
        for my $package (keys %{$packages}) {
            push @return,
                Debbugs::Package->new(%{$packages->{$package}},
                                      schema => $schema,
                                      package_collection => $self->universe,
                                      correspondent_collection =>
                                      $self->correspondent_collection->universe,
                                     );
        }
    } else {
        carp "No schema\n";
        for my $package (make_list($args{packages})) {
            push @return,
                Debbugs::Package->new(name => $package,
                                      package_collection => $self->universe,
                                      correspondent_collection =>
                                      $self->correspondent_collection->universe,
                                     );
        }
    }
    return @return;
}

sub add_packages_and_versions {
    my $self = shift;
    $self->add($self->_member_constructor(packages => \@_));
}


sub member_key {
    return $_[1]->qualified_name;
}

has 'correspondent_collection' =>
    (is => 'ro',
     isa => 'Debbugs::Collection::Correspondent',
     default => sub {Debbugs::Collection::Correspondent->new()},
    );

has 'versiontree' =>
    (is => 'ro',
     isa => 'Debbugs::VersionTree',
     lazy => 1,
     builder => '_build_versiontree',
    );

sub _build_versiontree {
    my $self = shift;
    return Debbugs::VersionTree->new($self->has_schema?(schema => $self->schema):());
}

=head2 get_source_versions_distributions

     $packages->get_source_versions_distributions('unstable')

Given a list of distributions or suites, returns a
L<Debbugs::Collection::Version> of all of the versions in this package
collection which are known to match.

Effectively, this calls L<Debbugs::Package/get_source_version_distribution> for
each package in the collection and merges the results and returns them

=cut

sub get_source_versions_distributions {
    my $self = shift;
    my @return;
    push @return,
        $self->map(sub {$_->get_source_version_distribution(@_)});
    if (@return > 1) {
        return $return[0]->combine($return[1..$#return]);
    }
    return @return;
}


=head2 get_source_versions

    $packages->get_source_versions('1.2.3-1','foo/1.2.3-5')

Given a list of binary versions or src/versions, returns a
L<Debbugs::Collection::Version> of all of the versions in this package
collection which are known to match.

If you give a binary version ('1.2.3-1'), you must have already loaded source
packages into this package collection for it to find an appropriate match.

If no package is known to match, an version which is invalid will be returned

For fully qualified versions this loads the appropriate source package into the
universe of this collection and calls L<Debbugs::Package/get_source_version>.
For unqualified versions, calls L<Debbugs::Package/get_source_version>; if no
valid versions are returned, creates an invalid version.

=cut

sub get_source_versions {
    my $self = shift;
    my @return;
    for my $ver (@_) {
        my $sv;
        if ($ver =~ m{(?<src>.+?)/(?<ver>.+)$}) {
            my $sp = $self->universe->
                get_or_add_by_key('src:'.$+{src});
            push @return,
                $sp->get_source_version($+{ver});
           next;
        } else {
            my $found_valid = 0;
            for my $p ($self->members) {
                local $_;
                my @vs =
                    grep {$_->is_valid}
                    $p->get_source_version($ver);
                if (@vs) {
                    $found_valid = 1;
                    push @return,@vs;
                    next;
                }
            }
            if (not $found_valid) {
                push @return,
                    Debbugs::Version::Binary->new(version => $ver,
                                                  package_collection => $self->universe,
                                                  valid => 0,
                                                  $self->schema_argument,
                                                 );
            }
        }
    }
    return
        Debbugs::Collection::Version->new(members => \@return,
                                          $self->schema_argument,
                                          package_collection => $self->universe,
                                         );
}

=head2 source_names

     $packages->source_names()

Returns a unique list of source names from all members of this collection by
calling L<Debbugs::Package/source_names> on each member.

=cut

sub source_names {
    my $self = shift;
    local $_;
    return uniq map {$_->source_names} $self->members;
}

=head2 sources

     $packages->sources()

Returns a L<Debbugs::Collection::Package> limited to source packages
corresponding to all packages in this collection

=cut

sub sources {
    my $self = shift;
    return $self->universe->limit($self->source_names);
}


__PACKAGE__->meta->make_immutable;
no Mouse;

1;

__END__
# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:

# This module is part of debbugs, and
# is released under the terms of the GPL version 2, or any later
# version (at your option). See the file README and COPYING for more
# information.
# Copyright 2018 by Don Armstrong <don@donarmstrong.com>.

package Debbugs::Collection::Bug;

=head1 NAME

Debbugs::Collection::Bug -- Bug generation factory

=head1 SYNOPSIS

This collection extends L<Debbugs::Collection> and contains members of
L<Debbugs::Bug>. Useful for any field which contains one or more bug or tracking
lists of packages

=head1 DESCRIPTION



=head1 METHODS

=cut

use Mouse;
use strictures 2;
use namespace::autoclean;
use Debbugs::Common qw(make_list hash_slice);
use Debbugs::OOTypes;
use Debbugs::Status qw(get_bug_statuses);
use Debbugs::Collection::Package;
use Debbugs::Collection::Correspondent;

use Debbugs::Bug;

extends 'Debbugs::Collection';

=head2 my $bugs = Debbugs::Collection::Bug->new(%params|$param)

Parameters:

=over

=item package_collection

Optional L<Debbugs::Collection::Package> which is used to look up packages


=item correspondent_collection

Optional L<Debbugs::Collection::Correspondent> which is used to look up correspondents


=item users

Optional arrayref of L<Debbugs::User> which set usertags for bugs in this collection

=back

=head2 $bugs->package_collection()

Returns the package collection that this bug collection is using

=head2 $bugs->correspondent_collection()

Returns the correspondent collection that this bug collection is using

=head2 $bugs->users()

Returns the arrayref of users that this bug collection is using

=head2 $bugs->add_user($user)

Add a user to the set of users that this bug collection is using

=head2 $bugs->load_related_packages_and_versions()

Preload all of the related packages and versions for the bugs in this bug
collection. You should call this if you plan on calculating whether the bugs in
this collection are present/absent.

=cut

has '+members' => (isa => 'ArrayRef[Bug]');
has 'package_collection' =>
    (is => 'ro',
     isa => 'Debbugs::Collection::Package',
     builder => '_build_package_collection',
     lazy => 1,
    );

sub _build_package_collection {
    my $self = shift;
    return Debbugs::Collection::Package->new($self->has_schema?(schema => $self->schema):());
}

has 'correspondent_collection' =>
    (is => 'ro',
     isa => 'Debbugs::Collection::Correspondent',
     builder => '_build_correspondent_collection',
     lazy => 1,
    );

sub _build_correspondent_collection {
    my $self = shift;
    return Debbugs::Collection::Correspondent->new($self->has_schema?(schema => $self->schema):());
}

has 'users' =>
    (is => 'ro',
     isa => 'ArrayRef[Debbugs::User]',
     traits => ['Array'],
     default => sub {[]},
     handles => {'add_user' => 'push'},
    );

sub BUILD {
    my $self = shift;
    my $args = shift;
    if (exists $args->{bugs}) {
        $self->add(
            $self->_member_constructor(bugs => $args->{bugs}
                                      ));
    }
}

sub _member_constructor {
    # handle being called $self->_member_constructor;
    my $self = shift;
    my %args = @_;
    my @return;
    my $schema;
    $schema = $self->schema if $self->has_schema;

    if (defined $schema) {
        my $statuses = get_bug_statuses(bug => [make_list($args{bugs})],
                                        schema => $schema,
                                       );
        # preload as many of the packages as we need
        my %packages;
        while (my ($bug, $status) = each %{$statuses}) {
            $packages{$_} = 1 for split /,/, $status->{package};
            $packages{$_} = 1 for split /,/, $status->{source};
        }
        $self->package_collection->universe->add_by_key(keys %packages);
        while (my ($bug, $status) = each %{$statuses}) {
            push @return,
                Debbugs::Bug->new(bug => $bug,
                                  status =>
                                  Debbugs::Bug::Status->new(status => $status,
                                                            bug => $bug,
                                                            status_source => 'db',
                                                           ),
                                  schema => $schema,
                                  package_collection =>
                                  $self->package_collection->universe,
                                  bug_collection =>
                                  $self->universe,
                                  correspondent_collection =>
                                  $self->correspondent_collection->universe,
                                  @{$args{constructor_args}//[]},
                                 );
        }
    } else {
        for my $bug (make_list($args{bugs})) {
            push @return,
                Debbugs::Bug->new(bug => $bug,
                                  package_collection =>
                                  $self->package_collection->universe,
                                  bug_collection =>
                                  $self->universe,
                                  correspondent_collection =>
                                  $self->correspondent_collection->universe,
                                  @{$args{constructor_args}//[]},
                                 );
        }
    }
    return @return;
}

around add_by_key => sub {
    my $orig = shift;
    my $self = shift;
    my @members =
        $self->_member_constructor(bugs => [@_],
                                  );
    return $self->$orig(@members);
};

sub member_key {
    return $_[1]->bug;
}

sub load_related_packages_and_versions {
    my $self = shift;
    my @related_packages_and_versions =
        $self->map(sub {$_->related_packages_and_versions});
    $self->package_collection->
        add_packages_and_versions(@related_packages_and_versions);
}

__PACKAGE__->meta->make_immutable;

1;

__END__
# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:

# This module is part of debbugs, and
# is released under the terms of the GPL version 2, or any later
# version (at your option). See the file README and COPYING for more
# information.
# Copyright 2018 by Don Armstrong <don@donarmstrong.com>.

package Debbugs::Collection::Package;

=head1 NAME

Debbugs::Collection::Package -- Package generation factory

=head1 SYNOPSIS


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

# state $common_dists = [@{$config{distributions}}];
# sub _get_packages {
#     my %args = @_;
#     my $s = $args{schema};
#     my %src_packages;
#     my %src_ver_packages;
#     my %bin_packages;
#     my %bin_ver_packages;
#     # split packages into src/ver, bin/ver, src, and bin so we can select them
#     # from the database
#     local $_;
#     for my $pkg (@{$args{packages}}) {
#         if (ref($pkg)) {
#             if ($pkg->[0] =~ /^src:(.+)$/) {
#                 for my $ver (@{$pkg}[1..$#{$pkg}]) {
#                     $src_ver_packages{$1}{$ver} = 1;
#                 }
#             } else {
#                 for my $ver (@{$pkg}[1..$#{$pkg}]) {
#                     $bin_ver_packages{$pkg->[0]}{$ver} = 1;
#                 }
#             }
#         } elsif ($pkg =~ /^src:(.+)$/) {
#             $src_packages{$1} = 1;
#         } else {
#             $bin_packages{$pkg} = 1;
#         }
#     }
#     my @src_ver_search;
#     for my $sp (keys %src_ver_packages) {
#         push @src_ver_search,
#             (-and => {'src_pkg.pkg' => $sp,
#                       'me.ver' => [keys %{$src_ver_packages{$sp}}],
#                      },
#              );
#     }
#     my %packages;
#     my $src_rs = $s->resultset('SrcVer')->
#         search({-or => [-and => {'src_pkg.pkg' => [keys %src_packages],
#                                  -or => {'suite.codename' => $common_dists,
#                                          'suite.suite_name' => $common_dists,
#                                         },
#                                 },
#                         @src_ver_search,
#                        ],
#                },
#               {join => ['src_pkg',
#                         {'src_associations' => 'suite'},
#                        ],
#                '+select' => [qw(src_pkg.pkg),
#                              qw(suite.codename),
#                              qw(src_associations.modified),
#                              q(CONCAT(src_pkg.pkg,'/',me.ver))],
#                '+as' => [qw(src_pkg_name codename modified_time src_pkg_ver)],
#                result_class => 'DBIx::Class::ResultClass::HashRefInflator',
#                order_by => {-desc => 'me.ver'}
#               },
#               );
#     while (my $pkg = $src_rs->next) {
#         my $n = 'src:'.$pkg->{src_pkg_name};
#         if (exists $packages{$n}) {
#             push @{$packages{$n}{versions}},
#                 $pkg->{src_pkg_ver};
#             if (defined $pkg->{codename}) {
#                 push @{$packages{$n}{dists}{$pkg->{codename}}},
#                     $#{$packages{$n}{versions}};
#             }
#         } else {
#             $packages{$n} =
#            {name => $pkg->{src_pkg_name},
#             type => 'source',
#             valid => 1,
#             versions => [$pkg->{src_pkg_ver}],
#             dists => {defined $pkg->{codename}?($pkg->{codename} => [1]):()},
#            };
#         }
#     }
#     return \%packages;
# }

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


sub get_source_versions_distributions {
    my $self = shift;
    my @return;
    push @return,
            $self->apply(sub {$_->get_source_version_distribution(@_)});
    return
        Debbugs::Collection::Version->new(versions => \@return,
                                          $self->has_schema?(schema => $self->schema):(),
                                          package_collection => $self->universe,
                                         );
}

# given a list of binary versions or src/versions, returns all of the versions
# in this package collection which are known to match. You'll have to be sure to
# load appropriate versions beforehand for this to actually work.
sub get_source_versions {
    my $self = shift;
    my @return;
    for my $ver (@_) {
        my $sv;
        if ($ver =~ m{(<src>.+?)/(?<ver>.+)$/}) {
            my $sp = $self->get_or_create('src:'.$+{src});
            push @return,
                $sp->get_source_version($ver);
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
                                                  $self->has_schema?(schema => $self->schema):(),
                                                 );
            }
        }
    }
    return
        Debbugs::Collection::Version->new(versions => \@return,
                                          $self->has_schema?(schema => $self->schema):(),
                                          package_collection => $self->universe,
                                         );
}


__PACKAGE__->meta->make_immutable;

1;

__END__
# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:

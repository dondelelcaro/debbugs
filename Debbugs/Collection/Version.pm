# This module is part of debbugs, and
# is released under the terms of the GPL version 2, or any later
# version (at your option). See the file README and COPYING for more
# information.
# Copyright 2018 by Don Armstrong <don@donarmstrong.com>.

package Debbugs::Collection::Version;

=head1 NAME

Debbugs::Collection::Version -- Version generation factory

=head1 SYNOPSIS


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
    return $_[1]->package.'/'.$_[1]->version.'/'.$_[1]->arch;
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
    my @schema_arg;
    my @return;
    for my $pkg_ver_arch (make_list($args{versions})) {
        my ($pkg,$ver,$arch) = $pkg_ver_arch =~ m{^([^/]+)/([^/]+)/?([^/]*)$} or
            confess("Invalid version key: $pkg_ver_arch");
        if (not length $arch) {
            if ($pkg =~ /^src:/) {
                $arch = 'source';
            } else {
               $arch = 'any';
            }
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
}

# Debbugs::Collection::Versions do not have a universe.
sub universe {
    return $_[0];
}

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

# This module is part of debbugs, and
# is released under the terms of the GPL version 2, or any later
# version (at your option). See the file README and COPYING for more
# information.
# Copyright 2018 by Don Armstrong <don@donarmstrong.com>.

package Debbugs::Version::Source;

=head1 NAME

Debbugs::Version::Source -- OO interface to Version

=head1 SYNOPSIS

   use Debbugs::Version::Source;
   Debbugs::Version::Source->new(schema => $s,binaries => [qw(foo)],sources => [qw(bar)]);

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
    return 'source';
}

sub source_version {
    return $_[0];
}

sub src_pkg_ver {
    my $self = shift;
    return $self->package.'/'.$self->version;
}

has maintainer => (is => 'ro',
                   isa => 'Str',
                  );

sub source {
    my $self = shift;
    return $self->pkg;
}

sub arch {
    return 'source';
}


__PACKAGE__->meta->make_immutable;
no Mouse;
1;


__END__
# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:

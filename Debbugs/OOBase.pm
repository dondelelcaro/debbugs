# This module is part of debbugs, and
# is released under the terms of the GPL version 2, or any later
# version (at your option). See the file README and COPYING for more
# information.
# Copyright 2018 by Don Armstrong <don@donarmstrong.com>.

package Debbugs::OOBase;

=head1 NAME

Debbugs::OOBase -- OO Base class for Debbugs

=head1 SYNOPSIS


=head1 DESCRIPTION



=cut

use Mouse;
use strictures 2;
use namespace::autoclean;

has schema => (is => 'ro', isa => 'Object',
	       required => 0,
	       predicate => 'has_schema',
	      );

__PACKAGE__->meta->make_immutable;

1;

__END__
# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:

# This module is part of debbugs, and
# is released under the terms of the GPL version 2, or any later
# version (at your option). See the file README and COPYING for more
# information.
# Copyright 2018 by Don Armstrong <don@donarmstrong.com>.

package Debbugs::OOTypes;

=head1 NAME

Debbugs::OOTypes -- OO Types for Debbugs

=head1 SYNOPSIS


=head1 DESCRIPTION



=cut

use Mouse::Util::TypeConstraints;
use strictures 2;
use namespace::autoclean;

# Bug Subtype
subtype 'Bug' =>
    as 'Debbugs::Bug';

coerce 'Bug' =>
    from 'Int' =>
    via {Debbugs::Bug->new($_)};

# Package Subtype
subtype 'Package' =>
    as 'Debbugs::Package';

coerce 'Package' =>
    from 'Str' =>
    via {Debbugs::Package->new(package => $_)};


# Version Subtype
subtype 'Version' =>
    as 'Debbugs::Version';

coerce 'Version' =>
    from 'Str' =>
    via {Debbugs::Version->new(string=>$_)};

no Mouse::Util::TypeConstraints;
1;

__END__
# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:

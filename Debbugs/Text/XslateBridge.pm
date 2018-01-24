# This module is part of debbugs, and is released
# under the terms of the GPL version 2, or any later
# version at your option.
# See the file README and COPYING for more information.
#
# Copyright 2018 by Don Armstrong <don@donarmstrong.com>.

package Debbugs::Text::XslateBridge;

use warnings;
use strict;

use base qw(Text::Xslate::Bridge);

=head1 NAME

Debbugs::Text::XslateBridge -- bridge for Xslate to add in useful functions

=head1 DESCRIPTION

This module provides bridge functionality to load functions into
Text::Xslate. It's loosely modeled after
Text::Xslate::Bridge::TT2Like, but with fewer functions.

=head1 BUGS

None known.

=cut


use vars qw($VERSION);

BEGIN {
     $VERSION = 1.00;
}

use Text::Xslate;

__PACKAGE__->
    bridge(scalar => {length => \&__length,
                     },
           function => {length => \&__length,}
          );

sub __length {
    length $_[0];
}


1;

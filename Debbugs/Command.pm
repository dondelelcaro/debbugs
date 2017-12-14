# This module is part of debbugs, and is released under the terms of
# the GPL version 3, or any later version (at your option). See the
# file README and COPYING for more information.
# Copyright 2017 by Don Armstrong <don@donarmstrong.com>.

package Debbugs::Command;

=head1 NAME

Debbugs::Command -- Handle multiple subcommand-style commands

=head1 SYNOPSIS

 use Debbugs::Command;

=head1 DESCRIPTION


=head1 BUGS

None known.

=cut

use warnings;
use strict;
use vars qw($VERSION $DEBUG %EXPORT_TAGS @EXPORT_OK @EXPORT);
use base qw(Exporter);

BEGIN{
     $VERSION = '0.1';
     $DEBUG = 0 unless defined $DEBUG;

     @EXPORT = ();
     %EXPORT_TAGS = (commands    => [qw(handle_main_arguments),
                                     qw(handle_subcommand_arguments)
                                    ],
		    );
     @EXPORT_OK = ();
     Exporter::export_ok_tags(keys %EXPORT_TAGS);
     $EXPORT_TAGS{all} = [@EXPORT_OK];

}

use Getopt::Long qw(:config no_ignore_case);
use Pod::Usage qw(pod2usage);

=head1 Command processing (:commands)

Functions which parse arguments for commands (exportable with
C<:commands>)

=over

=item handle_main_arguments(

=cut 

sub handle_main_arguments {
    my ($options,@args) = @_;
    Getopt::Long::Configure('pass_through');
    GetOptions($options,@args);
    Getopt::Long::Configure('default');
    return $options;
}



sub handle_subcommand_arguments {
    my ($argv,$args,$subopt) = @_;
    $subopt //= {};
    Getopt::Long::GetOptionsFromArray($argv,
                                      $subopt,
                                      keys %{$args},
                                     );
    my @usage_errors;
    for my $arg  (keys %{$args}) {
        next unless $args->{$arg};
        my $r_arg = $arg; # real argument name
        $r_arg =~ s/[=\|].+//g;
        if (not defined $subopt->{$r_arg}) {
            push @usage_errors, "You must give a $r_arg option";
        }
    }
    pod2usage(join("\n",@usage_errors)) if @usage_errors;
    return $subopt;
}


1;


__END__
# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:

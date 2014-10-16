# This module is part of debbugs, and is released
# under the terms of the GPL version 2, or any later
# version at your option.
# See the file README and COPYING for more information.
#
# Copyright 2014 by Don Armstrong <don@donarmstrong.com>.

package Debbugs::BugWalker;

=head1 NAME

Debbugs::BugWalker -- Walk through all known bugs

=head1 SYNOPSIS

    use Debbugs::BugWalker;
    my $w = Debbugs::BugWalker->new();

=head1 DESCRIPTION

This module contains routines to walk through all known bugs (and
return specific files or bug numbers).

=head1 BUGS

=head1 FUNCTIONS

=cut

use warnings;
use strict;
use vars qw($VERSION $DEBUG %EXPORT_TAGS @EXPORT_OK @EXPORT);
use base qw(Exporter);

BEGIN{
     $VERSION = 1.00;
     $DEBUG = 0 unless defined $DEBUG;

     @EXPORT = ();
     %EXPORT_TAGS = ();
     @EXPORT_OK = ();
     $EXPORT_TAGS{all} = [@EXPORT_OK];
}

use Debbugs::Config qw(:config);
use Debbugs::Common qw(make_list);
use Moo;
use IO::File;
use IO::Dir;

=head1 Functions

=over

=item C<Debbugs::BugWalker-E<gt>new()>

Create a new bugwalker object to walk through available bugs.

Takes the following options

=over

=item progress

L<Term::ProgressBar> to update progress on a terminal dynamically
(optional)

=cut

has progress =>
    (is => 'ro',
     isa => sub {
         if (not defined $_[0] or
             $_[0]->can('update')
            ) {
             die "Progress must support ->update";
         }
     }
    );

=item dirs

Directories to use to search for bugs; defaults to
C<$config{spool_dir}>

=cut

has dirs =>
    (is => 'ro',
    );

=item what

What files/directories to return. Defaults to bug, but must be one of
summary, bug, log, or status.

=cut

has what =>
    (is => 'ro',
     isa => sub {
         die "Must be one of summary, bug, log, status, version, or debinfo"
             unless $_[0] =~ /^(?:summary|bug|log|status|version|debinfo)$/;
     });


=back

=back

=cut

sub get_next {
    my ($self) = @_;

    if (not defined $self->{_dirs}) {
        $self->{_dirs} = [make_list($self->dirs())];
        $self->{_done_dirs} = 0;
        $self->{_done_files} = 0;
        $self->{_avg_subfiles} = 0;
    }
    if (not defined $self->{_files}) {
        $self->{_files} = [];
    }
    while (not @{$self->{_files}}) {
        my $next_dir = shift @{$self->{_dirs}};
        my $nd = IO::Dir->new($next_dir) or
            die "Unable to open $next_dir for reading: $!";
        my $f;
        while (defined ($f = $nd->read)) {
            my $fn = File::Spec->catfile($next_dir,$f);
            if (-d $fn) {
                push @{$self->{_dirs}},$fn;
                $self->{_total_dirs}++;
            } elsif (-r _) {
                if ($self->{what} eq 'bug') {
                    next unless $fn =~ /(\d+)\.status$/;
                    push @{$self->{_files}}, $1;
                } else {
                    next unless $fn =~ /\.$self->{what}$/;
                    push @{$self->{_files}}, $fn;
                }
            }
        }
        if (defined $self->progress) {
            $self->progress->target($self->{_avg_subfiles}*$self->{_dirs}+
                                    $self->{_done_files}+@{$self->{_files}});
            $self->{_avg_subfiles} =
                ($self->{_avg_subfiles}*$self->{_done_dirs}+@{$self->{_files}})/
                ($self->{_done_dirs}+1);
        }
        $self->{_done_dirs}++;
    }
    if (@{$self->{_files}}) {
        $self->progress->update($self->{done_files}++);
        return shift @{$self->{_files}};
    }
    return undef;
}


1;

__END__

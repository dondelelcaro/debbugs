# This module is part of debbugs, and is released under the terms of the GPL
# version 2, or any later version (at your option). See the file README and
# COPYING for more information.
#
# Copyright 2017 by Don Armstrong <don@donarmstrong.com>.

package Debbugs::Log::Spam;

=head1 NAME

Debbugs::Log::Spam -- an interface to debbugs .log.spam files

=head1 SYNOPSIS

use Debbugs::Log::Spam;

my $spam = Debbugs::Log::Spam->new(bug_num => '12345');

=head1 DESCRIPTION


=head1 BUGS

None known.

=cut

use warnings;
use strict;
use vars qw($VERSION $DEBUG %EXPORT_TAGS @EXPORT_OK @EXPORT);
use base qw(Exporter);

BEGIN{
    $VERSION = 1;
    $DEBUG = 0 unless defined $DEBUG;

    @EXPORT = ();
    %EXPORT_TAGS = ();
    @EXPORT_OK = ();
    Exporter::export_ok_tags(keys %EXPORT_TAGS);
    $EXPORT_TAGS{all} = [@EXPORT_OK];

}

use Carp;
use feature 'state';
use Params::Validate qw(:types validate_with);
use Debbugs::Common qw(getbuglocation getbugcomponent filelock unfilelock);

=head1 FUNCTIONS

=over 4

=item new

Creates a new log spam reader.

    my $spam_log = Debbugs::Log::Spam->new(log_spam_name => "56/123456.log.spam");
    my $spam_log = Debbugs::Log::Spam->new(bug_num => $nnn);

Parameters

=over

=item bug_num -- bug number

=item log_spam_name -- name of log

=back

One of the above options must be passed.

=cut

sub new {
    my $this = shift;
    state $spec =
        {bug_num => {type => SCALAR,
                     optional => 1,
                    },
         log_spam_name => {type => SCALAR,
                           optional => 1,
                          },
        };
    my %param =
        validate_with(params => \@_,
                      spec   => $spec
                     );
    if (grep({exists $param{$_} and
              defined $param{$_}} qw(bug_num log_spam_name)) ne 1) {
        croak "Exactly one of bug_num or log_spam_name".
            "must be passed and must be defined";
    }

    my $class = ref($this) || $this;
    my $self = {};
    bless $self, $class;

    if (exists $param{log_spam_name}) {
        $self->{name} = $param{log_spam_name};
    } elsif (exists $param{bug_num}) {
        my $location = getbuglocation($param{bug_num},'log.spam');
        my $bug_log = getbugcomponent($param{bug_num},'log.spam',$location);
        $self->{name} = $bug_log;
    }
    $self->_init();
    return $self;
}


sub _init {
    my $self = shift;

    $self->{spam} = {};
    if (-e $self->{name}) {
        open(my $fh,'<',$self->{name}) or
            croak "Unable to open bug log spam '$self->{name}' for reading: $!";
        binmode($fh,':encoding(UTF-8)');
        while (<$fh>) {
            chomp;
            $self->{spam}{$_} = 1;
        }
        close ($fh);
    }
    return $self;
}

=item save

$self->save();

Saves changes to the bug log spam file.

=cut

sub save {
    my $self = shift;
    return unless keys %{$self->{spam}};
    filelock($self->{name}.'.lock');
    open(my $fh,'>',$self->{name}.'.tmp') or
        croak "Unable to open bug log spam '$self->{name}.tmp' for writing: $!";
    binmode($fh,':encoding(UTF-8)');
    for my $msgid (keys %{$self->{spam}}) {
        print {$fh} $msgid."\n";
    }
    close($fh) or croak "Unable to write to '$self->{name}.tmp': $!";
    rename($self->{name}.'.tmp',$self->{name});
    unfilelock();
}

=item is_spam

    next if ($spam_log->is_spam('12456@exmaple.com'));

Returns 1 if this message id confirms that the message is spam

Returns 0 if this message is not spam

=cut
sub is_spam {
    my ($self,$msgid) = @_;
    return 0 if not defined $msgid or not length $msgid;
    $msgid =~ s/^<|>$//;
    if (exists $self->{spam}{$msgid} and
        $self->{spam}{$msgid}
       ) {
        return 1;
    }
    return 0;
}

=item add_spam

    $spam_log->add_spam('123456@example.com');

Add a message id to the spam listing.

You must call C<$self->save()> if you wish the changes to be written out to disk.

=cut

sub add_spam {
    my ($self,$msgid) = @_;
    $msgid =~ s/^<|>$//;
    $self->{spam}{$msgid} = 1;
}

1;

=back

=cut

__END__

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:

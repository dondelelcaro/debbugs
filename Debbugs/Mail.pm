# This module is part of debbugs, and is released
# under the terms of the GPL version 2, or any later
# version at your option.
# See the file README and COPYING for more information.
#
# Copyright 2004-7 by Don Armstrong <don@donarmstrong.com>.

package Debbugs::Mail;

=head1 NAME

Debbugs::Mail -- Outgoing Mail Handling

=head1 SYNOPSIS

use Debbugs::Mail qw(send_mail_message get_addresses);

my @addresses = get_addresses('blah blah blah foo@bar.com')
send_mail_message(message => <<END, recipients=>[@addresses]);
To: $addresses[0]
Subject: Testing

Testing 1 2 3
END

=head1 EXPORT TAGS

=over

=item :all -- all functions that can be exported

=back

=head1 FUNCTIONS


=cut

use warnings;
use strict;
use vars qw($VERSION $DEBUG %EXPORT_TAGS @EXPORT_OK @EXPORT);
use base qw(Exporter);

use IPC::Open3;
use POSIX ":sys_wait_h";
use Time::HiRes qw(usleep);
use Mail::Address ();
use Debbugs::MIME qw(encode_rfc1522);
use Debbugs::Config qw(:config);
use Params::Validate qw(:types validate_with);

BEGIN{
     ($VERSION) = q$Revision: 1.1 $ =~ /^Revision:\s+([^\s+])/;
     $DEBUG = 0 unless defined $DEBUG;

     @EXPORT = ();
     @EXPORT_OK = qw(send_mail_message get_addresses encode_headers);
     $EXPORT_TAGS{all} = [@EXPORT_OK];

}

# We set this here so it can be overridden for testing purposes
our $SENDMAIL = $config{sendmail};

=head2 get_addresses

     my @addresses = get_addresses('don@debian.org blars@debian.org
                                    kamion@debian.org ajt@debian.org');

Given a string containing some e-mail addresses, parses the string
using Mail::Address->parse and returns a list of the addresses.

=cut

sub get_addresses {
     return map { $_->address() } map { Mail::Address->parse($_) } @_;
}



=head2 send_mail_message

     send_mail_message(message    => $message,
                       recipients => [@recipients],
                       envelope_from => 'don@debian.org',
                      );


=over

=item message -- message to send out

=item recipients -- recipients to send the message to. If undefed or
an empty arrayref, will use '-t' to parse the message for recipients.

=item envelope_from -- envelope_from for outgoing messages

=item encode_headers -- encode headers using RFC1522 (default)

=item parse_for_recipients -- use -t to parse the message for
recipients in addition to those specified. [Can be used to set Bcc
recipients, for example.]

=back

Returns true on success, false on failures. All errors are indicated
using warn.

=cut

sub send_mail_message{
     my %param = validate_with(params => \@_,
			       spec  => {sendmail_arguments => {type => ARRAYREF,
								default => [qw(-odq -oem -oi)],
							       },
					 parse_for_recipients => {type => BOOLEAN,
								  default => 0,
								 },
					 encode_headers       => {type => BOOLEAN,
								  default => 1,
								 },
					 message              => {type => SCALAR,
								 },
					 envelope_from        => {type => SCALAR,
								  optional => 1,
								 },
					 recipients           => {type => ARRAYREF|UNDEF,
								  optional => 1,
								 },
					},
			      );
     my @sendmail_arguments = qw(-odq -oem -oi);
     push @sendmail_arguments, '-f', $param{envelope_from} if exists $param{envelope_from};

     my @recipients;
     @recipients = @{$param{recipients}} if defined $param{recipients} and
	  ref($param{recipients}) eq 'ARRAY';
     # If there are no recipients, use -t to parse the message
     if (@recipients == 0) {
	  $param{parse_for_recipients} = 1 unless exists $param{parse_for_recipients};
     }
     # Encode headers if necessary
     $param{encode_headers} = 1 if not exists $param{encode_headers};
     if ($param{encode_headers}) {
	  $param{message} = encode_headers($param{message});
     }

     # First, try to send the message as is.
     eval {
	  _send_message($param{message},
			@sendmail_arguments,
			$param{parse_for_recipients}?q(-t):(),
			@recipients);
     };
     return 1 unless $@;
     # If there's only one recipient, there's nothing more we can do,
     # so bail out.
     warn $@ and return 0 if $@ and @recipients == 0;
     # If that fails, try to send the message to each of the
     # recipients separately. We also send the -t option separately in
     # case one of the @recipients is ok, but the addresses in the
     # mail message itself are malformed.
     my @errors;
     for my $recipient ($param{parse_for_recipients}?q(-t):(),@recipients) {
	  eval {
	       _send_message($param{message},@sendmail_arguments,$recipient);
	  };
	  push @errors, "Sending to $recipient failed with $@" if $@;
     }
     # If it still fails, complain bitterly but don't die.
     warn join(qq(\n),@errors) and return 0 if @errors;
     return 1;
}

=head2 encode_headers

     $message = encode_heeaders($message);

RFC 1522 encodes the headers of a message

=cut

sub encode_headers{
     my ($message) = @_;

     my ($header,$body) = split /\n\n/, $message, 2;
     $header = encode_rfc1522($header);
     return $header . qq(\n\n). $body;
}


=head1 PRIVATE FUNCTIONS

=head2 _send_message

     _send_message($message,@sendmail_args);

Private function that actually calls sendmail with @sendmail_args and
sends message $message.

dies with errors, so calls to this function in send_mail_message
should be wrapped in eval.

=cut

sub _send_message{
     my ($message,@sendmail_args) = @_;

     my ($wfh,$rfh);
     my $pid = open3($wfh,$rfh,$rfh,$SENDMAIL,@sendmail_args)
	  or die "Unable to fork off $SENDMAIL: $!";
     local $SIG{PIPE} = 'IGNORE';
     eval {
	  print {$wfh} $message or die "Unable to write to $SENDMAIL: $!";
	  close $wfh or die "$SENDMAIL exited with $?";
     };
     if ($@) {
	  local $\;
	  # Reap the zombie
	  waitpid($pid,WNOHANG);
	  # This shouldn't block because the pipe closing is the only
	  # way this should be triggered.
	  my $message = <$rfh>;
	  die "$@$message";
     }
     # Wait for sendmail to exit for at most 30 seconds.
     my $loop = 0;
     while (waitpid($pid, WNOHANG) == 0 or $loop++ >= 600){
	  # sleep for a 20th of a second
	  usleep(50_000);
     }
     if ($loop >= 600) {
	  warn "$SENDMAIL didn't exit within 30 seconds";
     }
}


1;


__END__







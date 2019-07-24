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
use Exporter qw(import);

use IPC::Open3;
use POSIX qw(:sys_wait_h strftime);
use Time::HiRes qw(usleep gettimeofday);
use Mail::Address ();
use Debbugs::MIME qw(encode_rfc1522);
use Debbugs::Config qw(:config);
use Params::Validate qw(:types validate_with);
use Encode qw(encode is_utf8);
use Debbugs::UTF8 qw(encode_utf8_safely convert_to_utf8);

use Debbugs::Packages;

BEGIN{
     ($VERSION) = q$Revision: 1.1 $ =~ /^Revision:\s+([^\s+])/;
     $DEBUG = 0 unless defined $DEBUG;

     @EXPORT = ();
     %EXPORT_TAGS = (addresses => [qw(get_addresses)],
		     misc      => [qw(rfc822_date)],
		     mail      => [qw(send_mail_message encode_headers default_headers)],
                     reply     => [qw(reply_headers)],
		    );
     @EXPORT_OK = ();
     Exporter::export_ok_tags(keys %EXPORT_TAGS);
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


=head2 default_headers

      my @head = default_headers(queue_file => 'foo',
                                 data       => $data,
                                 msgid      => $header{'message-id'},
                                 msgtype    => 'error',
                                 headers    => [...],
                                );
      create_mime_message(\@headers,
                         ...
                         );

This function is generally called to generate the headers for
create_mime_message (and anything else that needs a set of default
headers.)

In list context, returns an array of headers. In scalar context,
returns headers for shoving in a mail message after encoding using
encode_headers.

=head3 options

=over

=item queue_file -- the queue file which will generate this set of
headers (refered to as $nn in lots of the code)

=item data -- the data of the bug which this message involves; can be
undefined if there is no bug involved.

=item msgid -- the Message-ID: of the message which will generate this
set of headers

=item msgtype -- the type of message that this is.

=item pr_msg -- the pr message field

=item headers -- a set of headers which will override the default
headers; these headers will be passed through (and may be reordered.)
If a particular header is undef, it overrides the default, but isn't
passed through.

=back

=head3 default headers

=over

=item X-Loop -- set to the maintainer e-mail

=item From -- set to the maintainer e-mail

=item To -- set to Unknown recipients

=item Subject -- set to Unknown subject

=item Message-ID -- set appropriately (see code)

=item Precedence -- set to bulk

=item References -- set to the full set of message ids that are known
(from data and the msgid option)

=item In-Reply-To -- set to msg id or the msgid from data

=item X-Project-PR-Message -- set to pr_msg with the bug number appended

=item X-Project-PR-Package -- set to the package of the bug

=item X-Project-PR-Keywords -- set to the keywords of the bug

=item X-Project-PR-Source -- set to the source of the bug

=back

=cut

sub default_headers {
    my %param = validate_with(params => \@_,
			      spec   => {queue_file => {type => SCALAR|UNDEF,
							optional => 1,
						       },
					 data       => {type => HASHREF,
							optional => 1,
						       },
					 msgid      => {type => SCALAR|UNDEF,
							optional => 1,
						       },
					 msgtype    => {type => SCALAR|UNDEF,
							default => 'misc',
						       },
					 pr_msg     => {type => SCALAR|UNDEF,
							default => 'misc',
						       },
					 headers    => {type => ARRAYREF,
							default => [],
						       },
					},
			     );
    my @header_order = (qw(X-Loop From To subject),
			qw(Message-ID In-Reply-To References));
    # handle various things being undefined
    if (not exists $param{queue_file} or
	not defined $param{queue_file}) {
	$param{queue_file} = join('',gettimeofday())
    }
    for (qw(msgtype pr_msg)) {
	if (not exists $param{$_} or
	    not defined $param{$_}) {
	    $param{$_} = 'misc';
	}
    }
    my %header_order;
    @header_order{map {lc $_} @header_order} = 0..$#header_order;
    my %set_headers;
    my @ordered_headers;
    my @temp = @{$param{headers}};
    my @other_headers;
    while (my ($header,$value) = splice @temp,0,2) {
	if (exists $header_order{lc($header)}) {
	    push @{$ordered_headers[$header_order{lc($header)}]},
		($header,$value);
	}
	else {
	    push @other_headers,($header,$value);
	}
	$set_headers{lc($header)} = 1;
    }

    # calculate our headers
    my $bug_num = exists $param{data} ? $param{data}{bug_num} : 'x';
    my $nn = $param{queue_file};
    # handle the user giving the actual queue filename instead of nn
    $nn =~ s/^[a-zA-Z]([a-zA-Z])/$1/;
    $nn = lc($nn);
    my @msgids;
    if (exists $param{msgid} and defined $param{msgid}) {
	push @msgids, $param{msgid}
    }
    elsif (exists $param{data} and defined $param{data}{msgid}) {
	push @msgids, $param{data}{msgid}
    }
    my %default_header;
    $default_header{'X-Loop'} = $config{maintainer_email};
    $default_header{From}     = "$config{maintainer_email} ($config{project} $config{ubug} Tracking System)";
    $default_header{To}       = "Unknown recipients";
    $default_header{Subject}  = "Unknown subject";
    $default_header{'Message-ID'} = "<handler.${bug_num}.${nn}.$param{msgtype}\@$config{email_domain}>";
    if (@msgids) {
	$default_header{'In-Reply-To'} = $msgids[0];
	$default_header{'References'} = join(' ',@msgids);
    }
    $default_header{Precedence} = 'bulk';
    $default_header{"X-$config{project}-PR-Message"} = $param{pr_msg} . (exists $param{data} ? ' '.$param{data}{bug_num}:'');
    $default_header{Date} = rfc822_date();
    if (exists $param{data}) {
	if (defined $param{data}{keywords}) {
	    $default_header{"X-$config{project}-PR-Keywords"} = $param{data}{keywords};
	}
	if (defined $param{data}{package}) {
	    $default_header{"X-$config{project}-PR-Package"} = $param{data}{package};
	    if ($param{data}{package} =~ /^src:(.+)$/) {
		$default_header{"X-$config{project}-PR-Source"} = $1;
	    }
	    else {
		my $pkg_src = Debbugs::Packages::getpkgsrc();
		$default_header{"X-$config{project}-PR-Source"} = $pkg_src->{$param{data}{package}};
	    }
	}
    }
    for my $header (sort keys %default_header) {
	next if $set_headers{lc($header)};
	if (exists $header_order{lc($header)}) {
	    push @{$ordered_headers[$header_order{lc($header)}]},
		($header,$default_header{$header});
	}
	else {
	    push @other_headers,($header,$default_header{$header});
	}
    }
    my @headers;
    for my $hdr1 (@ordered_headers) {
	next if not defined $hdr1;
	my @temp = @{$hdr1};
	while (my ($header,$value) = splice @temp,0,2) {
	    next if not defined $value;
	    push @headers,($header,$value);
	}
    }
    push @headers,@other_headers;
    if (wantarray) {
	return @headers;
    }
    else {
	my $headers = '';
	while (my ($header,$value) = splice @headers,0,2) {
	    $headers .= "${header}: $value\n";
	}
	return $headers;
    }
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
								default => $config{sendmail_arguments},
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
								  default => $config{envelope_from},
								 },
					 recipients           => {type => ARRAYREF|UNDEF,
								  optional => 1,
								 },
					},
			      );
     my @sendmail_arguments = @{$param{sendmail_arguments}};
     push @sendmail_arguments, '-f', $param{envelope_from} if
	 exists $param{envelope_from} and
	 defined $param{envelope_from} and
	 length $param{envelope_from};

     my @recipients;
     @recipients = @{$param{recipients}} if defined $param{recipients} and
	  ref($param{recipients}) eq 'ARRAY';
     my %recipients;
     @recipients{@recipients} = (1) x @recipients;
     @recipients = keys %recipients;
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
     return $header . qq(\n\n). encode_utf8_safely($body);
}

=head2 rfc822_date

     rfc822_date

Return the current date in RFC822 format in the UTC timezone

=cut

sub rfc822_date{
     return scalar strftime "%a, %d %h %Y %T +0000", gmtime;
}

=head2 reply_headers

     reply_headers(MIME::Parser->new()->parse_data(\$data));

Generates suggested headers and a body for replies. Primarily useful
for use in RFC2368 mailto: entries.

=cut

sub reply_headers{
    my ($entity) = @_;

    my $head = $entity->head;
    # build reply link
    my %r_l;
    $r_l{subject} = $head->get('Subject');
    $r_l{subject} //= 'Your mail';
    $r_l{subject} = 'Re: '. $r_l{subject} unless $r_l{subject} =~ /(?:^|\s)Re:\s+/;
    $r_l{subject} =~ s/(?:^\s*|\s*$)//g;
    $r_l{'In-Reply-To'} = $head->get('Message-Id');
    $r_l{'In-Reply-To'} =~ s/(?:^\s*|\s*$)//g if defined $r_l{'In-Reply-To'};
    delete $r_l{'In-Reply-To'} unless defined $r_l{'In-Reply-To'};
    $r_l{References} = ($head->get('References')//''). ' '.($head->get('Message-Id')//'');
    $r_l{References} =~ s/(?:^\s*|\s*$)//g;
    my $date = $head->get('Date') // 'some date';
    $date =~ s/(?:^\s*|\s*$)//g;
    my $who = $head->get('From') // $head->get('Reply-To') // 'someone';
    $who =~ s/(?:^\s*|\s*$)//g;

    my $body = "On $date $who wrote:\n";
    my $i = 60;
    my $b_h;
    # Default to UTF-8.
    my $charset="utf-8";
    ## find the first part which has a defined body handle and appears
    ## to be text
    if (defined $entity->bodyhandle) {
	my $this_charset =
	    $entity->head->mime_attr("content-type.charset");
	$charset = $this_charset if
	    defined $this_charset and
	    length $this_charset;
        $b_h = $entity->bodyhandle;
    } elsif ($entity->parts) {
        my @parts = $entity->parts;
        while (defined(my $part = shift @parts)) {
            if ($part->parts) {
                push @parts,$part->parts;
            }
            if (defined $part->bodyhandle and
                $part->effective_type =~ /text/) {
		my $this_charset =
		    $part->head->mime_attr("content-type.charset");
		$charset =  $this_charset if
		    defined $this_charset and
		    length $this_charset;
                $b_h = $part->bodyhandle;
                last;
            }
        }
    }
    if (defined $b_h) {
        eval {
            my $IO = $b_h->open("r");
            while (defined($_ = $IO->getline)) {
                $i--;
                last if $i < 0;
                $body .= '> '. convert_to_utf8($_,$charset);
            }
            $IO->close();
        };
    }
    $r_l{body} = $body;
    return \%r_l;
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







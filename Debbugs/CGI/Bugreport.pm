# This module is part of debbugs, and is released
# under the terms of the GPL version 2, or any later version. See the
# file README and COPYING for more information.
#
# [Other people have contributed to this file; their copyrights should
# be listed here too.]
# Copyright 2008 by Don Armstrong <don@donarmstrong.com>.


package Debbugs::CGI::Bugreport;

=head1 NAME

Debbugs::CGI::Bugreport -- specific routines for the bugreport cgi script

=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 BUGS

None known.

=cut

use warnings;
use strict;
use vars qw($VERSION $DEBUG %EXPORT_TAGS @EXPORT_OK @EXPORT);
use base qw(Exporter);

use IO::Scalar;

BEGIN{
     ($VERSION) = q$Revision: 494 $ =~ /^Revision:\s+([^\s+])/;
     $DEBUG = 0 unless defined $DEBUG;

     @EXPORT = ();
     %EXPORT_TAGS = ();
     @EXPORT_OK = (qw(display_entities handle_record handle_email_message));
     Exporter::export_ok_tags(keys %EXPORT_TAGS);
     $EXPORT_TAGS{all} = [@EXPORT_OK];
}



=head2 display_entity

     display_entity(entity      => $entity,
                    bug_num     => $ref,
                    outer       => 1,
                    msg_num     => $msg_num,
                    attachments => \@attachments,
                    output      => \$output);


=over

=item entity -- MIME::Parser entity

=item bug_num -- Bug number

=item outer -- Whether this is the outer entity; defaults to 1

=item msg_num -- message number in the log

=item attachments -- arrayref of attachments

=item output -- scalar reference for output

=back

=cut

sub display_entity {
    my %param = valid_with(params => \@_,
			   spec   => {entity      => {type => OBJECT,
						     },
				      bug_num     => {type => SCALAR,
						      regex => qr/^\d+$/,
						     },
				      outer       => {type => BOOLEAN,
						      default => 1,
						      },
				      msg_num     => {type => SCALAR,
						     },
				      attachments => {type => ARRAYREF,
						      default => [],
						     },
				      output      => {type => SCALARREF|HANDLE,
						      default => \*STDOUT,
						     },
				      terse       => {type => BOOLEAN,
						      default => 0,
						     },
				      msg         => {type => SCALAR,
						      optional => 1,
						     },
				      attachment => {type => SCALAR,
						     optional => 1,
						    },
				     }
			  );

    my $entity = $param{entity};
    my $ref = $param{bug_num};
    my $top = $param{outer}
    my $xmessage = $param{msg_num};
    if (defined ref($options) and
	ref($param{output}) eq 'SCALAR' and
	not UNIVERSAL::isa($param{output},'GLOB')) {
	 $param{output} = IO::Scalar->new($param{output});
    }
    my $attachments = $param{attachments};

    my $head = $entity->head;
    my $disposition = $head->mime_attr('content-disposition');
    $disposition = 'inline' if not defined $disposition or $disposition eq '';
    my $type = $entity->effective_type;
    my $filename = $entity->head->recommended_filename;
    $filename = '' unless defined $filename;
    $filename = decode_rfc1522($filename);

    if ($top and not $param{terse}) {
	 my $header = $entity->head;
	 print {$param{output}} "<pre class=\"headers\">\n";
	 if ($trim_headers) {
	      my @headers;
	      foreach (qw(From To Cc Subject Date)) {
		   my $head_field = $head->get($_);
		   next unless defined $head_field and $head_field ne '';
		   push @headers, qq(<b>$_:</b> ) . html_escape(decode_rfc1522($head_field));
	      }
	      print {$param{output}} join(qq(), @headers);
	 } else {
	      print {$param{output}} html_escape(decode_rfc1522($entity->head->stringify));
	 }
	 print {$param{output}} "</pre>\n";
    }

    unless (($top and $type =~ m[^text(?:/plain)?(?:;|$)]) or
	    ($type =~ m[^multipart/])) {
	push @$attachments, $entity;
	my @dlargs = ($ref, msg=>$xmessage, att=>$#$attachments);
	push @dlargs, (filename=>$filename) if $filename ne '';
	my $printname = $filename;
	$printname = 'Message part ' . ($#$attachments + 1) if $filename eq '';
	print {$param{output}} '<pre class="mime">[<a href="' . html_escape(bug_url(@dlargs)) . qq{">$printname</a> } .
		  "($type, $disposition)]</pre>\n";

	if (exists $param{msg} and exists $param{att} and
	    $att == $#$attachments) {
	    my $head = $entity->head;
	    chomp(my $type = $entity->effective_type);
	    my $body = $entity->stringify_body;
	    print {$param{output}} "Content-Type: $type";
	    my ($charset) = $head->get('Content-Type:') =~ m/charset\s*=\s*\"?([\w-]+)\"?/i;
	    print {$param{output}} qq(; charset="$charset") if defined $charset;
	    print {$param{output}}"\n";
	    if ($filename ne '') {
		my $qf = $filename;
		$qf =~ s/"/\\"/g;
		$qf =~ s[.*/][];
		print {$param{output}} qq{Content-Disposition: inline; filename="$qf"\n};
	    }
	    print {$param{output}} "\n";
	    my $decoder = MIME::Decoder->new($head->mime_encoding);
	    $decoder->decode(new IO::Scalar(\$body), \*STDOUT);
	    exit(0);
	}
    }

    return if not $top and $disposition eq 'attachment' and not defined($att);
    return unless ($type =~ m[^text/?] and
		   $type !~ m[^text/(?:html|enriched)(?:;|$)]) or
		  $type =~ m[^application/pgp(?:;|$)] or
		  $entity->parts;

    if ($entity->is_multipart) {
	my @parts = $entity->parts;
	foreach my $part (@parts) {
	    display_entity(entity => $part,
			   bug_num => $ref,
			   outer => 0,
			   msg_num => $xmessage,
			   output => $param{output},
			   attachments => $attachments,
			   terse => $param{terse},
			   exists $param{msg}?(msg=>$param{msg}):(),
			   exists $param{attachment}?(attachment=>$param{attachment}):(),
			  );
	    print {$param{output}} "\n";
	}
    } elsif ($entity->parts) {
	# We must be dealing with a nested message.
	print {$param{output}} "<blockquote>\n";
	my @parts = $entity->parts;
	foreach my $part (@parts) {
	    display_entity(entity => $part,
			   bug_num => $ref,
			   outer => 1,
			   msg_num => $xmessage,
			   ouput => $param{output},
			   attachments => $attachments,
			   terse => $param{terse},
			   exists $param{msg}?(msg=>$param{msg}):(),
			   exists $param{attachment}?(attachment=>$param{attachment}):(),
			  );
	    print {$param{output}} "\n";
	}
	print {$param{output}} "</blockquote>\n";
    } elsif (not $param{terse}) {
	 my $content_type = $entity->head->get('Content-Type:') || "text/html";
	 my ($charset) = $content_type =~ m/charset\s*=\s*\"?([\w-]+)\"?/i;
	 my $body = $entity->bodyhandle->as_string;
	 $body = convert_to_utf8($body,$charset) if defined $charset;
	 $body = html_escape($body);
	 # Attempt to deal with format=flowed
	 if ($content_type =~ m/format\s*=\s*\"?flowed\"?/i) {
	      $body =~ s{^\ }{}mgo;
	      # we ignore the other things that you can do with
	      # flowed e-mails cause they don't really matter.
	 }
	 # Add links to URLs
	 # We don't html escape here because we escape above
	 $body =~ s{((ftp|http|https)://[\S~-]+?/?)((\&gt\;)?[)]?[']?[:.\,]?(\s|$))}
		   {<a href=\"$1\">$1</a>$3}go;
	 # Add links to bug closures
	 $body =~ s[(closes:\s*(?:bug)?\#?\s?\d+(?:,?\s*(?:bug)?\#?\s?\d+)*)]
		   [my $temp = $1;
		    $temp =~ s{(\d+)}
			      {qq(<a href=").
				    html_escape(bug_url($1)).
					 qq(">$1</a>)
				    }ge;
		    $temp;]gxie;
	 print {$param{output}} qq(<pre class="message">$body</pre>\n);
    }
}


=head2 handle_email_message

     handle_email_message($record->{text},
			  ref        => $bug_number,
			  msg_number => $msg_number,
			 );

Returns a decoded e-mail message and displays entities/attachments as
appropriate.


=cut

sub handle_email_message{
     my ($email,%options) = @_;

     my $output = '';
     my $parser = new MIME::Parser;
     # Because we are using memory, not tempfiles, there's no need to
     # clean up here like in Debbugs::MIME
     $parser->tmp_to_core(1);
     $parser->output_to_core(1);
     my $entity = $parser->parse_data( $email);
     my @attachments = ();
     display_entity(entity  => $entity,
		    bug_num => $options{ref},
		    outer   => 1,
		    msg_number => $options{msg_number},
		    ouput => $output,
		    attachments => \@attachments,
		    terse       => $params{terse},
		    exists $param{msg}?(msg=>$param{msg}):(),
		    exists $param{att}?(attachment=>$param{att}):(),
		   );
     return $output;

}

=head2 handle_record

     push @log, handle_record($record,$ref,$msg_num);

Deals with a record in a bug log as returned by
L<Debbugs::Log::read_log_records>; returns the log information that
should be output to the browser.

=cut

sub handle_record{
     my ($record,$bug_number,$msg_number,$seen_msg_ids) = @_;

     my $output = '';
     local $_ = $record->{type};
     if (/html/) {
	  my ($time) = $record->{text} =~ /<!--\s+time:(\d+)\s+-->/;
	  my $class = $record->{text} =~ /^<strong>(?:Acknowledgement|Reply|Information|Report|Notification)/ ? 'infmessage':'msgreceived';
	  $output .= decode_rfc1522($record->{text});
	  # Link to forwarded http:// urls in the midst of the report
	  # (even though these links already exist at the top)
	  $output =~ s,((?:ftp|http|https)://[\S~-]+?/?)([\)\'\:\.\,]?(?:\s|\.<|$)),<a href=\"$1\">$1</a>$2,go;
	  # Add links to the cloned bugs
	  $output =~ s{(Bug )(\d+)( cloned as bugs? )(\d+)(?:\-(\d+)|)}{$1.bug_links($2).$3.bug_links($4,$5)}eo;
	  # Add links to merged bugs
	  $output =~ s{(?<=Merged )([\d\s]+)(?=\.)}{join(' ',map {bug_links($_)} (split /\s+/, $1))}eo;
	  # Add links to blocked bugs
	  $output =~ s{(?<=Blocking bugs)(?:( of )(\d+))?( (?:added|set to|removed):\s+)([\d\s\,]+)}
		      {(defined $2?$1.bug_links($2):'').$3.
			    join(' ',map {bug_links($_)} (split /\,?\s+/, $4))}eo;
	  # Add links to reassigned packages
	  $output =~ s{(Bug reassigned from package \`)([^']+?)((?:'|\&\#39;) to \`)([^']+?)((?:'|\&\#39;))}
	  {$1.q(<a href=").html_escape(pkg_url(pkg=>$2)).qq(">$2</a>).$3.q(<a href=").html_escape(pkg_url(pkg=>$4)).qq(">$4</a>).$5}eo;
	  if (defined $time) {
	       $output .= ' ('.strftime('%a, %d %b %Y %T GMT',gmtime($time)).') ';
	  }
	  $output .= '<a href="' . html_escape(bug_url($ref, msg => ($msg_number+1))) . '">Full text</a> and <a href="' .
	       html_escape(bug_url($ref, msg => ($msg_number+1), mbox => 'yes')) . '">rfc822 format</a> available.';

	  $output = qq(<div class="$class"><hr>\n<a name="$msg_number"></a>\n) . $output . "</div>\n";
     }
     elsif (/recips/) {
	  my ($msg_id) = $record->{text} =~ /^Message-Id:\s+<(.+)>/im;
	  if (defined $msg_id and exists $$seen_msg_ids{$msg_id}) {
	       return ();
	  }
	  elsif (defined $msg_id) {
	       $$seen_msg_ids{$msg_id} = 1;
	  }
	  $output .= qq(<hr><p class="msgreceived"><a name="$msg_number"></a>\n);
	  $output .= 'View this message in <a href="' . html_escape(bug_url($ref, msg=>$msg_number, mbox=>'yes')) . '">rfc822 format</a></p>';
	  $output .= handle_email_message($record->{text},
				    ref        => $bug_number,
				    msg_number => $msg_number,
				   );
     }
     elsif (/autocheck/) {
	  # Do nothing
     }
     elsif (/incoming-recv/) {
	  my ($msg_id) = $record->{text} =~ /^Message-Id:\s+<(.+)>/im;
	  if (defined $msg_id and exists $$seen_msg_ids{$msg_id}) {
	       return ();
	  }
	  elsif (defined $msg_id) {
	       $$seen_msg_ids{$msg_id} = 1;
	  }
	  # Incomming Mail Message
	  my ($received,$hostname) = $record->{text} =~ m/Received: \(at (\S+)\) by (\S+)\;/;
	  $output .= qq|<hr><p class="msgreceived"><a name="$msg_number"></a><a name="msg$msg_number"></a><a href="#$msg_number">Message #$msg_number</a> received at |.
	       html_escape("$received\@$hostname") .
		    q| (<a href="| . html_escape(bug_url($ref, msg=>$msg_number)) . '">full text</a>'.
			 q|, <a href="| . html_escape(bug_url($ref, msg=>$msg_number,mbox=>'yes')) .'">mbox</a>)'.":</p>\n";
	  $output .= handle_email_message($record->{text},
				    ref        => $bug_number,
				    msg_number => $msg_number,
				   );
     }
     else {
	  die "Unknown record type $_";
     }
     return $output;
}



1;


__END__







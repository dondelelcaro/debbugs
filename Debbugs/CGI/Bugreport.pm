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
use Params::Validate qw(validate_with :types);
use Digest::MD5 qw(md5_hex);
use Debbugs::Mail qw(get_addresses);
use Debbugs::MIME qw(decode_rfc1522 create_mime_message);
use Debbugs::CGI qw(:url :html :util);
use Debbugs::Common qw(globify_scalar english_join);
use Debbugs::UTF8;
use Debbugs::Config qw(:config);
use POSIX qw(strftime);
use Encode qw(decode_utf8 encode_utf8);

BEGIN{
     ($VERSION) = q$Revision: 494 $ =~ /^Revision:\s+([^\s+])/;
     $DEBUG = 0 unless defined $DEBUG;

     @EXPORT = ();
     %EXPORT_TAGS = ();
     @EXPORT_OK = (qw(display_entity handle_record handle_email_message));
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
    my %param = validate_with(params => \@_,
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
					 att         => {type => SCALAR,
							 optional => 1,
							},
					 trim_headers => {type => BOOLEAN,
							  default => 1,
							 },
                                         avatars => {type => BOOLEAN,
                                                     default => 1,
                                                    },
					}
			     );

    my $output = globify_scalar($param{output});
    my $entity = $param{entity};
    my $ref = $param{bug_num};
    my $top = $param{outer};
    my $xmessage = $param{msg_num};
    my $attachments = $param{attachments};

    my $head = $entity->head;
    my $disposition = $head->mime_attr('content-disposition');
    $disposition = 'inline' if not defined $disposition or $disposition eq '';
    my $type = $entity->effective_type;
    my $filename = $entity->head->recommended_filename;
    $filename = '' unless defined $filename;
    $filename = decode_rfc1522($filename);

    if ($param{outer} and
	not $param{terse} and
	not exists $param{att}) {
	 my $header = $entity->head;
	 print {$output} "<div class=\"headers\">\n";
	 if ($param{trim_headers}) {
	      my @headers;
	      foreach (qw(From To Cc Subject Date)) {
		   my $head_field = $head->get($_);
		   next unless defined $head_field and $head_field ne '';
                   chomp $head_field;
                   if ($_ eq 'From' and $param{avatars}) {
                       my $libravatar_url = __libravatar_url(decode_rfc1522($head_field));
                       if (defined $libravatar_url and length $libravatar_url) {
                           push @headers,q(<img src=").$libravatar_url.qq(">\n);
                       }
                   }
		   push @headers, qq(<p><span class="header">$_:</span> ) . html_escape(decode_rfc1522($head_field))."</p>\n";
	      }
	      print {$output} join(qq(), @headers);
	 } else {
	      print {$output} "<pre>".html_escape(decode_rfc1522($entity->head->stringify))."</pre>\n";
	 }
	 print {$output} "</div>\n";
    }

    if (not (($param{outer} and $type =~ m{^text(?:/plain)?(?:;|$)})
	     or $type =~ m{^multipart/}
	    )) {
	push @$attachments, $param{entity};
	# output this attachment
	if (exists $param{att} and
	    $param{att} == $#$attachments) {
	    my $head = $entity->head;
	    chomp(my $type = $entity->effective_type);
	    my $body = $entity->stringify_body;
	    # this attachment has its own content type, so we must not
	    # try to convert it to UTF-8 or do anything funky.
	    binmode($output,':raw');
	    print {$output} "Content-Type: $type";
	    my ($charset) = $head->get('Content-Type:') =~ m/charset\s*=\s*\"?([\w-]+)\"?/i;
	    print {$output} qq(; charset="$charset") if defined $charset;
	    print {$output} "\n";
	    if ($filename ne '') {
		my $qf = $filename;
		$qf =~ s/"/\\"/g;
		$qf =~ s[.*/][];
		print {$output} qq{Content-Disposition: inline; filename="$qf"\n};
	    }
	    print {$output} "\n";
	    my $decoder = MIME::Decoder->new($head->mime_encoding);
	    $decoder->decode(IO::Scalar->new(\$body), $output);
            # we don't reset the layers here, because it makes no
            # sense to add anything to the output handle after this
            # point.
	    return(1);
	}
	elsif (not exists $param{att}) {
	     my @dlargs = (msg=>$xmessage, att=>$#$attachments);
	     push @dlargs, (filename=>$filename) if $filename ne '';
	     my $printname = $filename;
	     $printname = 'Message part ' . ($#$attachments + 1) if $filename eq '';
	     print {$output} '<pre class="mime">[<a href="' .
		  html_escape(bug_links(bug => $ref,
					links_only => 1,
					options => {@dlargs})
			     ) . qq{">$printname</a> } .
				  "($type, $disposition)]</pre>\n";
	}
    }

    return 0 if not $param{outer} and $disposition eq 'attachment' and not exists $param{att};
    return 0 unless (($type =~ m[^text/?] and
                      $type !~ m[^text/(?:html|enriched)(?:;|$)]) or
                     $type =~ m[^application/pgp(?:;|$)] or
                     $entity->parts);

    if ($entity->is_multipart) {
	my @parts = $entity->parts;
	foreach my $part (@parts) {
	    my $raw_output =
                display_entity(entity => $part,
                               bug_num => $ref,
                               outer => 0,
                               msg_num => $xmessage,
                               output => $output,
                               attachments => $attachments,
                               terse => $param{terse},
                               exists $param{msg}?(msg=>$param{msg}):(),
                               exists $param{att}?(att=>$param{att}):(),
                               exists $param{avatars}?(avatars=>$param{avatars}):(),
                              );
            if ($raw_output) {
                return $raw_output;
            }
	    # print {$output} "\n";
	}
    } elsif ($entity->parts) {
	# We must be dealing with a nested message.
	 if (not exists $param{att}) {
	      print {$output} "<blockquote>\n";
	 }
	my @parts = $entity->parts;
	foreach my $part (@parts) {
	    display_entity(entity => $part,
			   bug_num => $ref,
			   outer => 1,
			   msg_num => $xmessage,
			   output => $output,
			   attachments => $attachments,
			   terse => $param{terse},
			   exists $param{msg}?(msg=>$param{msg}):(),
			   exists $param{att}?(att=>$param{att}):(),
                           exists $param{avatars}?(avatars=>$param{avatars}):(),
			  );
	    # print {$output} "\n";
	}
	 if (not exists $param{att}) {
	      print {$output} "</blockquote>\n";
	 }
    } elsif (not $param{terse}) {
	 my $content_type = $entity->head->get('Content-Type:') || "text/html";
	 my ($charset) = $content_type =~ m/charset\s*=\s*\"?([\w-]+)\"?/i;
	 my $body = $entity->bodyhandle->as_string;
	 $body = convert_to_utf8($body,$charset//'utf8');
	 $body = html_escape($body);
	 # Attempt to deal with format=flowed
	 if ($content_type =~ m/format\s*=\s*\"?flowed\"?/i) {
	      $body =~ s{^\ }{}mgo;
	      # we ignore the other things that you can do with
	      # flowed e-mails cause they don't really matter.
	 }
	 # Add links to URLs
	 # We don't html escape here because we escape above;
	 # wierd terminators are because of that
	 $body =~ s{((?:ftp|http|https|svn|ftps|rsync)://[\S~-]+?/?) # Url
		    ((?:\&gt\;)?[)]?(?:'|\&\#39\;)?[:.\,]?(?:\s|$)) # terminators
	      }{<a href=\"$1\">$1</a>$2}gox;
	 # Add links to bug closures
	 $body =~ s[(closes:\s*(?:bug)?\#?\s?\d+(?:,?\s*(?:bug)?\#?\s?\d+)*)]
		   [my $temp = $1;
		    $temp =~ s{(\d+)}
			      {bug_links(bug=>$1)}ge;
		    $temp;]gxie;
	 if (defined $config{cve_tracker} and
	     length $config{cve_tracker}
	    ) {
	     # Add links to CVE vulnerabilities (closes #568464)
	     $body =~ s{(^|\s)(CVE-\d{4}-\d{4,})(\s|[,.-\[\]]|$)}
		       {$1<a href="http://$config{cve_tracker}$2">$2</a>$3}gxm;
	 }
	 if (not exists $param{att}) {
	      print {$output} qq(<pre class="message">$body</pre>\n);
	 }
    }
    return 0;
}


=head2 handle_email_message

     handle_email_message($record->{text},
			  ref        => $bug_number,
			  msg_num => $msg_number,
			 );

Returns a decoded e-mail message and displays entities/attachments as
appropriate.


=cut

sub handle_email_message{
     my ($email,%param) = @_;

     my $output;
     my $output_fh = globify_scalar(\$output);
     my $parser = MIME::Parser->new();
     # Because we are using memory, not tempfiles, there's no need to
     # clean up here like in Debbugs::MIME
     $parser->tmp_to_core(1);
     $parser->output_to_core(1);
     my $entity = $parser->parse_data( $email);
     my @attachments = ();
     my $raw_output =
         display_entity(entity  => $entity,
                        bug_num => $param{ref},
                        outer   => 1,
                        msg_num => $param{msg_num},
                        output => $output_fh,
                        attachments => \@attachments,
                        terse       => $param{terse},
                        exists $param{msg}?(msg=>$param{msg}):(),
                        exists $param{att}?(att=>$param{att}):(),
                        exists $param{trim_headers}?(trim_headers=>$param{trim_headers}):(),
                        exists $param{avatars}?(avatars=>$param{avatars}):(),
                       );
     return $raw_output?$output:decode_utf8($output);
}

=head2 handle_record

     push @log, handle_record($record,$ref,$msg_num);

Deals with a record in a bug log as returned by
L<Debbugs::Log::read_log_records>; returns the log information that
should be output to the browser.

=cut

sub handle_record{
     my ($record,$bug_number,$msg_number,$seen_msg_ids,%param) = @_;

     # output needs to have the is_utf8 flag on to avoid double
     # encoding
     my $output = decode_utf8('');
     local $_ = $record->{type};
     if (/html/) {
	 # $record->{text} is not in perl's internal encoding; convert it
	 my $text = decode_rfc1522(decode_utf8($record->{text}));
	  my ($time) = $text =~ /<!--\s+time:(\d+)\s+-->/;
	  my $class = $text =~ /^<strong>(?:Acknowledgement|Reply|Information|Report|Notification)/m ? 'infmessage':'msgreceived';
	  $output .= $text;
	  # Link to forwarded http:// urls in the midst of the report
	  # (even though these links already exist at the top)
	  $output =~ s,((?:ftp|http|https)://[\S~-]+?/?)((?:[\)\'\:\.\,]|\&\#39;)?(?:\s|\.<|$)),<a href=\"$1\">$1</a>$2,go;
	  # Add links to the cloned bugs
	  $output =~ s{(Bug )(\d+)( cloned as bugs? )(\d+)(?:\-(\d+)|)}{$1.bug_links(bug=>$2).$3.bug_links(bug=>(defined $5)?[$4..$5]:$4)}eo;
	  # Add links to merged bugs
	  $output =~ s{(?<=Merged )([\d\s]+)(?=\.)}{join(' ',map {bug_links(bug=>$_)} (split /\s+/, $1))}eo;
	  # Add links to blocked bugs
	  $output =~ s{(?<=Blocking bugs)(?:( of )(\d+))?( (?:added|set to|removed):\s+)([\d\s\,]+)}
		      {(defined $2?$1.bug_links(bug=>$2):'').$3.
			   english_join([map {bug_links(bug=>$_)} (split /\,?\s+/, $4)])}eo;
	  $output =~ s{((?:[Aa]dded|[Rr]emoved)\ blocking\ bug(?:\(s\))?)(?:(\ of\ )(\d+))?(:?\s+)
		       (\d+(?:,\s+\d+)*(?:\,?\s+and\s+\d+)?)}
		      {$1.(defined $3?$2.bug_links(bug=>$3):'').$4.
			   english_join([map {bug_links(bug=>$_)} (split /\,?\s+(?:and\s+)?/, $5)])}xeo;
	  $output =~ s{([Aa]dded|[Rr]emoved)( indication that bug )(\d+)( blocks )([\d\s\,]+)}
		      {$1.$2.(bug_links(bug=>$3)).$4.
			   english_join([map {bug_links(bug=>$_)} (split /\,?\s+(?:and\s+)?/, $5)])}eo;
	  # Add links to reassigned packages
	  $output =~ s{(Bug reassigned from package \`)([^']+?)((?:'|\&\#39;) to \`)([^']+?)((?:'|\&\#39;))}
	  {$1.q(<a href=").html_escape(package_links(package=>$2)).qq(">$2</a>).$3.q(<a href=").html_escape(package_links(package=>$4)).qq(">$4</a>).$5}eo;
	  if (defined $time) {
	       $output .= ' ('.strftime('%a, %d %b %Y %T GMT',gmtime($time)).') ';
	  }
	  $output .= '<a href="' .
	       html_escape(bug_links(bug => $bug_number,
				     options => {msg => ($msg_number+1)},
				     links_only => 1,
				    )
			  ) . '">Full text</a> and <a href="' .
			       html_escape(bug_links(bug => $bug_number,
						     options => {msg => ($msg_number+1),
								 mbox => 'yes'},
						     links_only => 1)
					  ) . '">rfc822 format</a> available.';

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
	  $output .= 'View this message in <a href="' . html_escape(bug_links(bug=>$bug_number, links_only => 1, options=>{msg=>$msg_number, mbox=>'yes'})) . '">rfc822 format</a></p>';
	  $output .= handle_email_message($record->{text},
					  ref     => $bug_number,
					  msg_num => $msg_number,
                                          %param,
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
		    q| (<a href="| . html_escape(bug_links(bug => $bug_number, links_only => 1, options => {msg=>$msg_number})) . '">full text</a>'.
			 q|, <a href="| . html_escape(bug_links(bug => $bug_number,
								links_only => 1,
								options => {msg=>$msg_number,
									    mbox=>'yes'}
							       )
						     ) .'">mbox</a>)'.":</p>\n";
	  $output .= handle_email_message($record->{text},
					  ref     => $bug_number,
					  msg_num => $msg_number,
                                          %param,
					 );
     }
     else {
	  die "Unknown record type $_";
     }
     return $output;
}


sub __libravatar_url {
    my ($email) = @_;
    if (not defined $config{libravatar_uri} or not length $config{libravatar_uri}) {
        return undef;
    }
    ($email) = get_addresses($email);
    return $config{libravatar_uri}.md5_hex(lc($email)).($config{libravatar_uri_options}//'');
}


1;


__END__







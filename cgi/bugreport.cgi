#!/usr/bin/perl -wT

package debbugs;

use strict;
use POSIX qw(strftime tzset);
use MIME::Parser;
use MIME::Decoder;
use IO::Scalar;
use IO::Lines;
use IO::File;

#require '/usr/lib/debbugs/errorlib';
require './common.pl';

require '/etc/debbugs/config';
require '/etc/debbugs/text';

use vars(qw($gEmailDomain $gHTMLTail $gSpoolDir $gWebDomain));

# for read_log_records
use Debbugs::Log;
use Debbugs::MIME qw(convert_to_utf8 decode_rfc1522);

use Scalar::Util qw(looks_like_number);

my %param = readparse();

my $tail_html;

my $ref = $param{'bug'} || quitcgi("No bug number");
$ref =~ /(\d+)/ or quitcgi("Invalid bug number");
$ref = $1;
my $short = "#$ref";
my $msg = $param{'msg'} || "";
my $att = $param{'att'};
my $boring = ($param{'boring'} || 'no') eq 'yes'; 
my $terse = ($param{'terse'} || 'no') eq 'yes';
my $reverse = ($param{'reverse'} || 'no') eq 'yes';
my $mbox = ($param{'mbox'} || 'no') eq 'yes'; 
my $mime = ($param{'mime'} || 'yes') eq 'yes';

my $trim_headers = ($param{trim} || ($msg?'no':'yes')) eq 'yes';

# Not used by this script directly, but fetch these so that pkgurl() and
# friends can propagate them correctly.
my $archive = ($param{'archive'} || 'no') eq 'yes';
my $repeatmerged = ($param{'repeatmerged'} || 'yes') eq 'yes';
set_option('archive', $archive);
set_option('repeatmerged', $repeatmerged);

my $buglog = buglog($ref);

if ($ENV{REQUEST_METHOD} eq 'HEAD' and not defined($att) and not $mbox) {
    print "Content-Type: text/html; charset=utf-8\n";
    my @stat = stat $buglog;
    if (@stat) {
	my $mtime = strftime '%a, %d %b %Y %T GMT', gmtime($stat[9]);
	print "Last-Modified: $mtime\n";
    }
    print "\n";
    exit 0;
}

sub display_entity ($$$$\$\@);
sub display_entity ($$$$\$\@) {
    my $entity = shift;
    my $ref = shift;
    my $top = shift;
    my $xmessage = shift;
    my $this = shift;
    my $attachments = shift;

    my $head = $entity->head;
    my $disposition = $head->mime_attr('content-disposition');
    $disposition = 'inline' if not defined $disposition or $disposition eq '';
    my $type = $entity->effective_type;
    my $filename = $entity->head->recommended_filename;
    $filename = '' unless defined $filename;
    $filename = decode_rfc1522($filename);

    if ($top) {
	 my $header = $entity->head;
	 if ($trim_headers and not $terse) {
	      my @headers;
	      foreach (qw(From To Cc Subject Date)) {
		   my $head_field = $head->get($_);
		   next unless defined $head_field and $head_field ne '';
		   push @headers, qq($_: ) . htmlsanit(decode_rfc1522($head_field));
	      }
	      $$this .= join(qq(), @headers) unless $terse;
	      $$this .= qq(\n);
	 }
	 elsif (not $terse) {
	      $$this .= htmlsanit(decode_rfc1522($entity->head->stringify));
	      $$this .= qq(\n);
	 }
    }

    unless (($top and $type =~ m[^text(?:/plain)?(?:;|$)]) or
	    ($type =~ m[^multipart/])) {
	push @$attachments, $entity;
	my @dlargs = ($ref, "msg=$xmessage", "att=$#$attachments");
	push @dlargs, "filename=$filename" if $filename ne '';
	my $printname = $filename;
	$printname = 'Message part ' . ($#$attachments + 1) if $filename eq '';
	$$this .= '[<a href="' . dlurl(@dlargs) . qq{">$printname</a> } .
		  "($type, $disposition)]\n\n";

	if ($msg and defined($att) and $att eq $#$attachments) {
	    my $head = $entity->head;
	    chomp(my $type = $entity->effective_type);
	    my $body = $entity->stringify_body;
	    print "Content-Type: $type\n";
	    if ($filename ne '') {
		my $qf = $filename;
		$qf =~ s/"/\\"/g;
		$qf =~ s[.*/][];
		print qq{Content-Disposition: attachment; filename="$qf"\n};
	    }
	    print "\n";
	    my $decoder = new MIME::Decoder($head->mime_encoding);
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
	    display_entity($part, $ref, 0, $xmessage,
			   $$this, @$attachments);
	    $$this .= "\n";
	}
    } elsif ($entity->parts) {
	# We must be dealing with a nested message.
	$$this .= "<blockquote>\n";
	my @parts = $entity->parts;
	foreach my $part (@parts) {
	    display_entity($part, $ref, 1, $xmessage,
			   $$this, @$attachments);
	    $$this .= "\n";
	}
	$$this .= "</blockquote>\n";
    } else {
	 if (not $terse) {
	      my $content_type = $entity->head->get('Content-Type:');
	      my ($charset) = $content_type =~ m/charset\s*=\s*\"?([\w-]+)\"?/i;
	      my $body = $entity->bodyhandle->as_string;
	      $body = convert_to_utf8($body,$charset) if defined $charset;
	      $$this .= htmlsanit($body);
	 }
    }
}

my %maintainer = %{getmaintainers()};
my %pkgsrc = %{getpkgsrc()};

my $indexentry;
my $descriptivehead;
my $showseverity;

my $tpack;
my $tmain;

$ENV{"TZ"} = 'UTC';
tzset();

my $dtime = strftime "%a, %e %b %Y %T UTC", localtime;
$tail_html = $debbugs::gHTMLTail;
$tail_html =~ s/SUBSTITUTE_DTIME/$dtime/;

my %status = %{getbugstatus($ref)};
unless (%status) {
    print <<EOF;
Content-Type: text/html; charset=utf-8

<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<html>
<head><title>$debbugs::gProject $debbugs::gBug report logs - $short</title></head>
<body>
<h1>$debbugs::gProject $debbugs::gBug report logs - $short</h1>
<p>There is no record of $debbugs::gBug $short.
Try the <a href="http://$gWebDomain/">search page</a> instead.</p>
$tail_html</body></html>
EOF
    exit 0;
}

$|=1;

$tpack = lc $status{'package'};
my @tpacks = splitpackages($tpack);

if  ($status{severity} eq 'normal') {
	$showseverity = '';
#} elsif (isstrongseverity($status{severity})) {
#	$showseverity = "<strong>Severity: $status{severity}</strong>;\n";
} else {
	$showseverity = "Severity: <em>$status{severity}</em>;\n";
}

$indexentry .= "<p>$showseverity";
$indexentry .= htmlpackagelinks($status{package}, 0) . ";\n";

$indexentry .= htmladdresslinks("Reported by: ", \&submitterurl,
                                $status{originator}) . ";\n";

$indexentry .= "Owned by: " . htmlsanit($status{owner}) . ";\n"
              if length $status{owner};

my $dummy = strftime "%a, %e %b %Y %T UTC", localtime($status{date});
$indexentry .= "Date: ".$dummy.";\n<br>";

my @descstates;

push @descstates, "Tags: <strong>"
		. htmlsanit(join(", ", sort(split(/\s+/, $status{tags}))))
		. "</strong>"
			if length($status{tags});

my @merged= split(/ /,$status{mergedwith});
if (@merged) {
	my $descmerged = 'merged with ';
	my $mseparator = '';
	for my $m (@merged) {
		$descmerged .= $mseparator."<a href=\"" . bugurl($m) . "\">#$m</a>";
		$mseparator= ",\n";
	}
	push @descstates, $descmerged;
}

if (@{$status{found_versions}}) {
    my $foundtext = 'Found in ';
    $foundtext .= (@{$status{found_versions}} == 1) ? 'version ' : 'versions ';
    $foundtext .= join ', ', map htmlsanit($_), @{$status{found_versions}};
    push @descstates, $foundtext;
}

if (@{$status{fixed_versions}}) {
    my $fixedtext = '<strong>Fixed</strong> in ';
    $fixedtext .= (@{$status{fixed_versions}} == 1) ? 'version ' : 'versions ';
    $fixedtext .= join ', ', map htmlsanit($_), @{$status{fixed_versions}};
    if (length($status{done})) {
	$fixedtext .= ' by ' . htmlsanit(decode_rfc1522($status{done}));
    }
    push @descstates, $fixedtext;
} elsif (length($status{done})) {
	push @descstates, "<strong>Done:</strong> ".htmlsanit(decode_rfc1522($status{done}));
} elsif (length($status{forwarded})) {
	push @descstates, "<strong>Forwarded</strong> to ".maybelink($status{forwarded});
}

$indexentry .= join(";\n", @descstates) . ";\n<br>" if @descstates;

$descriptivehead = $indexentry;
foreach my $pkg (@tpacks) {
    my $tmaint = defined($maintainer{$pkg}) ? $maintainer{$pkg} : '(unknown)';
    my $tsrc = defined($pkgsrc{$pkg}) ? $pkgsrc{$pkg} : '(unknown)';

    $descriptivehead .=
            htmlmaintlinks(sub { $_[0] == 1 ? "Maintainer for $pkg is\n"
                                            : "Maintainers for $pkg are\n" },
                           $tmaint);
    $descriptivehead .= ";\nSource for $pkg is\n".
            '<a href="'.srcurl($tsrc)."\">$tsrc</a>" if ($tsrc ne "(unknown)");
    $descriptivehead .= ".\n<br>";
}

my $buglogfh;
if ($buglog =~ m/\.gz$/) {
    my $oldpath = $ENV{'PATH'};
    $ENV{'PATH'} = '/bin:/usr/bin';
    $buglogfh = new IO::File "zcat $buglog |" or &quitcgi("open log for $ref: $!");
    $ENV{'PATH'} = $oldpath;
} else {
    $buglogfh = new IO::File "<$buglog" or &quitcgi("open log for $ref: $!");
}
if ($buglog !~ m#^\Q$gSpoolDir/db#) {
    $descriptivehead .= "\n<p>Bug is <strong>archived</strong>. No further changes may be made.</p>";
}


my @records = read_log_records($buglogfh);
undef $buglogfh;

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
     $parser->tmp_to_core(1);
     $parser->output_to_core(1);
     # $parser->output_under("/tmp");
     my $entity = $parser->parse_data( $email);
     # TODO: make local subdir, clean it ourselves
     # the following does NOT delete the msg dirs in /tmp
     END { if ( $entity ) { $entity->purge; } if ( $parser ) { $parser->filer->purge; } }
     my @attachments = ();
     display_entity($entity, $options{ref}, 1, $options{msg_number}, $output, @attachments);
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
	  $output .= decode_rfc1522($record->{text});
	  $output .= '<a href="' . bugurl($ref, 'msg='.($msg_number+1)) . '">Full text</a> and <a href="' .
	       bugurl($ref, 'msg='.($msg_number+1)) . '&mbox=yes">rfc822 format</a> available.</em>';
     }
     elsif (/recips/) {
	  my ($msg_id) = $record->{text} =~ /^Message-Id:\s+<(.+)>/im;
	  if (defined $msg_id and exists $$seen_msg_ids{$msg_id}) {
	       return ();
	  }
	  elsif (defined $msg_id) {
	       $$seen_msg_ids{$msg_id} = 1;
	  }
	  $output .= 'View this message in <a href="' . bugurl($ref, "msg=$msg_number") . '&mbox=yes">rfc822 format</a></em>';
	  $output .= '<pre class="message">' .
	       handle_email_message($record->{text},
				    ref        => $bug_number,
				    msg_number => $msg_number,
				   ) . '</pre>';
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
	  $output .= qq|<h2><a name="msg$msg_number">Message received at |.
	       htmlsanit("$received\@$hostname") . q| (<a href="| . bugurl($ref, "msg=$msg_number") . '">full text</a>'.q|, <a href="| . bugurl($ref, "msg=$msg_number") . '&mbox=yes">mbox</a>)'.":</a></h2>\n";
	  $output .= '<pre class="message">' .
	       handle_email_message($record->{text},
				    ref        => $bug_number,
				    msg_number => $msg_number,
				   ) . '</pre>';
     }
     else {
	  die "Unknown record type $_";
     }
     return $output;
}

my $log='';
my $msg_num = 0;
my $skip_next = 0;
if (looks_like_number($msg) and ($msg-1) <= $#records) {
     @records = ($records[$msg-1]);
     $msg_num = $msg - 1;
}
my @log;
if ( $mbox ) {
     if (@records > 1) {
	  print qq(Content-Disposition: attachment; filename="bug_${ref}.mbox"\n);
	  print "Content-Type: text/plain\n\n";
     }
     else {
	  print qq(Content-Disposition: attachment; filename="bug_${ref}_message_${msg_num}.mbox"\n);
	  print "Content-Type: message/rfc822\n\n";
     }
     for my $record (@records) {
	  next if $record->{type} !~ /^(?:recips|incoming-recv)$/;
	  next if not $boring and $record->{type} eq 'recips';
	  my @lines = split( "\n", $record->{text}, -1 );
	  if ( $lines[ 1 ] =~ m/^From / ) {
	       my $tmp = $lines[ 0 ];
	       $lines[ 0 ] = $lines[ 1 ];
	       $lines[ 1 ] = $tmp;
	  }
	  if ( !( $lines[ 0 ] =~ m/^From / ) ) {
	       my $date = strftime "%a %b %d %T %Y", localtime;
	       unshift @lines, "From unknown $date";
	  }
	  map { s/^(>*From )/>$1/ } @lines[ 1 .. $#lines ];
	  print join( "\n", @lines ) . "\n";
     }
     exit 0;
}

else {
     my %seen_msg_ids;
     for my $record (@records) {
	  $msg_num++;
	  if ($skip_next) {
	       $skip_next = 0;
	       next;
	  }
	  $skip_next = 1 if $record->{type} eq 'html' and not $boring;
	  push @log, handle_record($record,$ref,$msg_num,\%seen_msg_ids);
     }
}

@log = reverse @log if $reverse;
$log = join('<hr>',@log);


print "Content-Type: text/html; charset=utf-8\n\n";

my $title = htmlsanit($status{subject});

print "<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\">\n";
print "<HTML><HEAD>\n" . 
    "<TITLE>$debbugs::gProject $debbugs::gBug report logs - $short - $title</TITLE>\n" .
#    "<link rel=\"stylesheet\" href=\"$debbugs::gWebHostBugDir/bugs.css\" type=\"text/css\">" .
    "</HEAD>\n" .
    '<BODY>' .
    "\n";
print "<H1>" . "$debbugs::gProject $debbugs::gBug report logs - <A HREF=\"mailto:$ref\@$gEmailDomain\">$short</A>" .
      "<BR>" . $title . "</H1>\n";

print "$descriptivehead\n";
printf "<p>View this report as an <a href=\"%s\">mbox folder</a>.</p>\n", mboxurl($ref);
print "<HR>";
print "$log";
print $tail_html;

print "</BODY></HTML>\n";

exit 0;

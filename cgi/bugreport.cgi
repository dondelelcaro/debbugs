#!/usr/bin/perl -wT

package debbugs;

use strict;
use POSIX qw(strftime tzset);
use MIME::Parser;
use MIME::Decoder;
use IO::Scalar;

#require '/usr/lib/debbugs/errorlib';
require './common.pl';

require '/etc/debbugs/config';
require '/etc/debbugs/text';

use vars(qw($gHTMLTail $gWebDomain));

my %param = readparse();

my $tail_html;

my %maintainer = %{getmaintainers()};
my %pkgsrc = %{getpkgsrc()};

my $ref = $param{'bug'} || quit("No bug number");
my $msg = $param{'msg'} || "";
my $att = $param{'att'};
my $boring = ($param{'boring'} || 'no') eq 'yes'; 
my $reverse = ($param{'reverse'} || 'no') eq 'yes';
my $mbox = ($param{'mbox'} || 'no') eq 'yes'; 

my %status = %{getbugstatus($ref)} or &quit("Couldn't get bug status: $!");

my $indexentry;
my $descriptivehead;
my $submitted;
my $showseverity;

my $tpack;
my $tmain;

$ENV{"TZ"} = 'UTC';
tzset();

my $dtime = strftime "%a, %e %b %Y %T UTC", localtime;
$tail_html = $debbugs::gHTMLTail;
$tail_html =~ s/SUBSTITUTE_DTIME/$dtime/;

$|=1;

$tpack = lc $status{'package'};
$tpack =~ s/[^-+._a-z0-9()].*$//;

if  ($status{severity} eq 'normal') {
	$showseverity = '';
#} elsif (grep($status{severity} eq $_, @strongseverities)) {
#	$showseverity = "<strong>Severity: $status{severity}</strong>;\n";
} else {
	$showseverity = "Severity: <em>$status{severity}</em>;\n";
}

$indexentry .= $showseverity;
$indexentry .= "Package: <A HREF=\"" . pkgurl($status{package}) . "\">"
	    .htmlsanit($status{package})."</A>;\n";

$indexentry .= "Reported by: <a href=\"" . submitterurl($status{originator})
              . "\">" . htmlsanit($status{originator}) . "</a>";
$indexentry .= ";\nTags: <strong>"
		. htmlsanit(join(", ", sort(split(/\s+/, $status{tags}))))
		. "</strong>"
			if length($status{tags});

my @merged= split(/ /,$status{mergedwith});
if (@merged) {
	my $mseparator= ";\nmerged with ";
	for my $m (@merged) {
		$indexentry .= $mseparator."<A href=\"" . bugurl($m) . "\">#$m</A>";
		$mseparator= ",\n";
	}
}

my $dummy = strftime "%a, %e %b %Y %T UTC", localtime($status{date});
$submitted = ";\ndated ".$dummy;

if (length($status{done})) {
	$indexentry .= ";\n<strong>Done:</strong> ".htmlsanit($status{done});
} elsif (length($status{forwarded})) {
	$indexentry .= ";\n<strong>Forwarded</strong> to ".htmlsanit($status{forwarded});
}

my ($short, $tmaint, $tsrc);
$short = $ref; $short =~ s/^\d+/#$&/;
$tmaint = defined($maintainer{$tpack}) ? $maintainer{$tpack} : '(unknown)';
$tsrc = defined($pkgsrc{$tpack}) ? $pkgsrc{$tpack} : '(unknown)';
$descriptivehead= $indexentry.$submitted.";\nMaintainer for $status{package} is\n".
            '<A href="http://'.$debbugs::gWebDomain.'/db/ma/l'.&maintencoded($tmaint).'.html">'.htmlsanit($tmaint).'</A>';
$descriptivehead.= ";\n<br>Source for $status{package} is\n".
	    '<A href="'.srcurl($tsrc)."\">$tsrc</A>";
$descriptivehead.= ".";

my $buglog = buglog($ref);
open L, "<$buglog" or &quit("open log for $ref: $!");

my $log='';

my $xmessage = 1;
my $suppressnext = 0;

my $thisheader = '';
my $this = '';

my $cmsg = 1;

my $normstate= 'kill-init';
my $linenum = 0;
my $mail = '';
my @mails = ();
while(my $line = <L>) {
	$linenum++;
	if ($line =~ m/^.$/ and 1 <= ord($line) && ord($line) <= 7) {
		# state transitions
		my $newstate;
		my $statenum = ord($line);

		$newstate = 'autocheck'     if ($statenum == 1);
		$newstate = 'recips'        if ($statenum == 2);
		$newstate = 'kill-end'      if ($statenum == 3);
		$newstate = 'go'            if ($statenum == 5);
		$newstate = 'html'          if ($statenum == 6);
		$newstate = 'incoming-recv' if ($statenum == 7);

		# disallowed transitions:
		$_ = "$normstate $newstate";
		unless (m/^(go|go-nox|html) kill-end$/
		    || m/^(kill-init|kill-end) (incoming-recv|autocheck|recips|html)$/
		    || m/^kill-body go$/)
		{
			&quit("$ref: Transition from $normstate to $newstate at $linenum disallowed");
		}

		if ($newstate eq 'go') {
			$this .= "<pre>\n";
		}

		if ($newstate eq 'html') {
			$this = '';
		}

		if ($newstate eq 'kill-end') {

			my $show = 1;
			$show = $boring
				if ($suppressnext && $normstate ne 'html');

			$show = ($xmessage == $msg) if ($msg);

			push @mails, $mail if ( $mbox && $mail );
			if ($show) {
				my $downloadHtml = '';
				if ($mail) {
					my $parser = new MIME::Parser;
					$parser->tmp_to_core(1);
					$parser->output_to_core(1);
#					$parser->output_under("/tmp");
					my $entity = $parser->parse_data($mail);
					# TODO: make local subdir, clean it outselves
					# the following does NOT delete the msg dirs in /tmp
					END { $entity->purge; $parser->filer->purge; }
					my @attachments = ();
					if ( $entity->is_multipart ) {
						my @parts = $entity->parts_DFS;
#						$this .= htmlsanit($entity->head->stringify);
						my @keep = ();
						foreach ( @parts ) {
							my $head = $_->head;
#							$head->mime_attr("content-transfer-encoding" => "8bit")
#								if !$head->mime_attr("content-transfer-encoding");
							my ($disposition,$type) = (
								$head->mime_attr("content-disposition"),
								lc $head->mime_attr("content-type")
								);
							
#print STDERR "'$type' '$disposition'\n";
							if ($disposition && ( $disposition eq "attachment" || $disposition eq "inline" ) && $_->head->recommended_filename ) {
								push @attachments, $_;
								my $file = $_->head->recommended_filename;
								$downloadHtml .= "View Attachment: <a href=\"".dlurl($ref,"msg=$xmessage","att=$#attachments","filename=$file")."\">$file</a>\n";
								if ($msg && defined($att) && $att eq $#attachments) {
									my $head = $_->head;
									my $type;
									chomp($type = $head->mime_attr("content-type"));
									my $body = $_->stringify_body;
									print "Content-Type: $type; name=$file\n\n";
									my $decoder = new MIME::Decoder($head->mime_encoding);
									$decoder->decode(new IO::Scalar(\$body), \*STDOUT);
									exit(0);
								}
								if ($type eq 'text/plain') {
#									push @keep, $_;
								}
#								$this .= htmlsanit($_->head->stringify);
							} else {
#								$this .= htmlsanit($_->head->stringify);
#								push @keep, $_;
							}
#							$this .= "\n" . htmlsanit($_->stringify_body);
						}
#						$entity->parts(\@keep) if (!$msg);
					}
					$this .= htmlsanit($entity->stringify);
				}
				$this = "$downloadHtml\n$this$downloadHtml" if $downloadHtml;
				$downloadHtml = '';
				$this = "<pre>\n$this</pre>\n"
					if $normstate eq 'go' || $normstate eq 'go-nox';
				$this = "$thisheader$this" if $thisheader && !( $normstate eq 'html' );;
				$thisheader = '';
				if ($normstate eq 'html') {
					$this .= "  <em><A href=\"" . bugurl($ref, "msg=$xmessage") . "\">Full text</A> available.</em>";
				}
				if ($reverse) {
					$log = "$this\n<hr>$log";
				} else {
					$log .= "$this\n<hr>\n";
				}
			}

			$xmessage++ if ($normstate ne 'html');

			$suppressnext = $normstate eq 'html';
		}
		
		$normstate = $newstate;
		$mail = '';
		next;
	}

	$_ = $line;
	if ($normstate eq 'incoming-recv') {
		my $pl= $_;
		$pl =~ s/\n+$//;
		m/^Received: \(at (\S+)\) by (\S+)\;/
			|| &quit("bad line \`$pl' in state incoming-recv");
		$thisheader = "<h2>Message received at ".htmlsanit("$1\@$2")
		        . ":</h2>\n";
		$this = '';
		$normstate= 'go';
		$mail .= $_;
	} elsif ($normstate eq 'html') {
		$this .= $_;
	} elsif ($normstate eq 'go') {
		if ($mail) {
			$mail .= $_;
		} else {
			$this .= htmlsanit($_);
		}
	} elsif ($normstate eq 'go-nox') {
		next if !s/^X//;
		if ($mail) {
			$mail .= $_;
		} else {
			$this .= htmlsanit($_);
		}
        } elsif ($normstate eq 'recips') {
		if (m/^-t$/) {
			$this = "<h2>Message sent:</h2>\n";
		} else {
			s/\04/, /g; s/\n$//;
			$this = "<h2>Message sent to ".htmlsanit($_).":</h2>\n";
		}
		$normstate= 'kill-body';
	} elsif ($normstate eq 'autocheck') {
		next if !m/^X-Debian-Bugs(-\w+)?: This is an autoforward from (\S+)/;
		$normstate= 'autowait';
		$thisheader = "<h2>Message received at $2:</h2>\n";
		$this = '';
		$mail .= $_;
	} elsif ($normstate eq 'autowait') {
		next if !m/^$/;
		$normstate= 'go-nox';
	} else {
		&quit("$ref state $normstate line \`$_'");
	}
}
&quit("$ref state $normstate at end") unless $normstate eq 'kill-end';
close(L);

if ( $mbox ) {
	print "Content-Type: text/plain\n\n";
	foreach ( @mails ) {
		my @lines = split( "\n", $_, -1 );
		if ( $lines[ 1 ] =~ m/^From / ) {
			my $tmp = $lines[ 0 ];
			$lines[ 0 ] = $lines[ 1 ];
			$lines[ 1 ] = $tmp;
			$_ = join( "\n", @lines ) . "\n";
		}
		if ( !( $lines[ 0 ] =~ m/^From / ) ) {
			$ENV{ PATH } = "/bin:/usr/bin:/usr/local/bin";
			my $date = `date "+%a %b %d %T %Y"`;
			chomp $date;
			$_ = "From unknown $date\n" . $_;
		}
	}
	print join("", @mails );
	exit 0;
}
print "Content-Type: text/html\n\n";

print "<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\">\n";
print "<HTML><HEAD>\n" . 
    "<TITLE>$debbugs::gProject $debbugs::gBug report logs - $short</TITLE>\n" .
    "</HEAD>\n" .
    '<BODY TEXT="#000000" BGCOLOR="#FFFFFF" LINK="#0000FF" VLINK="#800080">' .
    "\n";
print "<H1>" .  "$debbugs::gProject $debbugs::gBug report logs - <A HREF=\"mailto:$ref\@bugs.debian.org\">$short</A>" .
      "<BR>" . htmlsanit($status{subject}) . "</H1>\n";

print "$descriptivehead\n";
printf "<p><a href=\"%s\">View</a> this report as an mbox folder.</p>", mboxurl($ref);
print "<HR>";
print "$log";
print $tail_html;

print "</BODY></HTML>\n";

exit 0;

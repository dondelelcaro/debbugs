#!/usr/bin/perl -wT

package debbugs;

use strict;
use POSIX qw(strftime tzset);
use MIME::Parser;
use MIME::Decoder;
use IO::Scalar;
use IO::Lines;

#require '/usr/lib/debbugs/errorlib';
require './common.pl';

require '/etc/debbugs/config';
require '/etc/debbugs/text';

use vars(qw($gEmailDomain $gHTMLTail $gSpoolDir $gWebDomain));

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

my $buglog = buglog($ref);

if ($ENV{REQUEST_METHOD} eq 'HEAD' and not defined($att) and not $mbox) {
    print "Content-Type: text/html\n";
    my @stat = stat $buglog;
    if (@stat) {
	my $mtime = strftime '%a, %d %b %Y %T GMT', gmtime($stat[9]);
	print "Last-Modified: $mtime\n";
    }
    print "\n";
    exit 0;
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
Content-Type: text/html

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
#} elsif (grep($status{severity} eq $_, @strongseverities)) {
#	$showseverity = "<strong>Severity: $status{severity}</strong>;\n";
} else {
	$showseverity = "Severity: <em>$status{severity}</em>;\n";
}

$indexentry .= "<p>$showseverity";
$indexentry .= htmlpackagelinks($status{package}, 0);

$indexentry .= "Reported by: <a href=\"" . submitterurl($status{originator})
              . "\">" . htmlsanit($status{originator}) . "</a>;\n";

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

if (length($status{done})) {
	push @descstates, "<strong>Done:</strong> ".htmlsanit($status{done});
} elsif (length($status{forwarded})) {
	push @descstates, "<strong>Forwarded</strong> to ".maybelink($status{forwarded});
}

$indexentry .= join(";\n", @descstates) . ";\n<br>" if @descstates;

$descriptivehead = $indexentry;
foreach my $pkg (@tpacks) {
    my $tmaint = defined($maintainer{$pkg}) ? $maintainer{$pkg} : '(unknown)';
    my $tsrc = defined($pkgsrc{$pkg}) ? $pkgsrc{$pkg} : '(unknown)';

    $descriptivehead .= "Maintainer for $pkg is\n".
            '<a href="'.mainturl($tmaint).'">'.htmlsanit($tmaint).'</a>';
    $descriptivehead .= ";\nSource for $pkg is\n".
            '<a href="'.srcurl($tsrc)."\">$tsrc</a>" if ($tsrc ne "(unknown)");
    $descriptivehead .= ".\n<br>";
}

open L, "<$buglog" or &quitcgi("open log for $ref: $!");
if ($buglog !~ m#^\Q$gSpoolDir/db-h/#) {
    $descriptivehead .= "\n<p>Bug is <strong>archived</strong>. No further changes may be made.</p>";
}

my $log='';

my $xmessage = 1;
my $suppressnext = 0;

my $thisheader = '';
my $this = '';

my $cmsg = 1;

my $normstate= 'kill-init';
my $linenum = 0;
my @mail = ();
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
			&quitcgi("$ref: Transition from $normstate to $newstate at $linenum disallowed");
		}

#$this .= "\n<br>states: $normstate $newstate<br>\n";

#		if ($newstate eq 'go') {
#			$this .= "<pre>\n";
#		}
		if ($newstate eq 'html') {
			$this = '';
		}

		if ($newstate eq 'kill-end') {

			my $show = 1;
			$show = $boring
				if ($suppressnext && $normstate ne 'html');

			$show = ($xmessage == $msg) if ($msg);

			push @mails, join( '', @mail ) if ( $mbox && @mail );
			if ($show) {
				my $downloadHtml = '';
				if (@mail) {
					my $parser = new MIME::Parser;
					$parser->tmp_to_core(1);
					$parser->output_to_core(1);
#					$parser->output_under("/tmp");
					my $entity = $parser->parse( new IO::Lines \@mail );
					# TODO: make local subdir, clean it outselves
					# the following does NOT delete the msg dirs in /tmp
					END { if ( $entity ) { $entity->purge; } if ( $parser ) { $parser->filer->purge; } }
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
#				if ($normstate eq 'go' || $normstate eq 'go-nox') {
				if ($normstate ne 'html') {
					$this = "<pre>\n$this</pre>\n";
				}
				if ($normstate eq 'html') {
					$this .= "  <em><a href=\"" . bugurl($ref, "msg=$xmessage") . "\">Full text</a> available.</em>";
				}
				$this = "$thisheader$this" if $thisheader && !( $normstate eq 'html' );;
				$this = "$downloadHtml" if ($terse && $normstate ne 'html');
				$downloadHtml = '';
				$thisheader = '';
				my $delim = $terse ? "<p>" : "<hr>";
				if ($reverse) {
					$log = "$this\n$delim$log";
				} else {
					$log .= "$this\n$delim\n";
				}
			}

			$xmessage++ if ($normstate ne 'html');

			$suppressnext = $normstate eq 'html';
		}
		
		$normstate = $newstate;
		@mail = ();
		next;
	}

	$_ = $line;
	if ($normstate eq 'incoming-recv') {
		my $pl= $_;
		$pl =~ s/\n+$//;
		m/^Received: \(at (\S+)\) by (\S+)\;/
			|| &quitcgi("bad line \`$pl' in state incoming-recv");
		$thisheader = "<h2>Message received at ".htmlsanit("$1\@$2")
		        . ":</h2>\n";
		$this = '';
		$normstate= 'go';
		push @mail, $_;
	} elsif ($normstate eq 'html') {
		$this .= $_;
	} elsif ($normstate eq 'go') {
		s/^\030//;
		if (@mail) {
			push @mail, $_;
		} else {
			$this .= htmlsanit($_);
		}
	} elsif ($normstate eq 'go-nox') {
		next if !s/^X//;
		if (@mail) {
			push @mail, $_;
		} else {
			$this .= htmlsanit($_);
		}
        } elsif ($normstate eq 'recips') {
		if (m/^-t$/) {
			$thisheader = "<h2>Message sent:</h2>\n";
		} else {
			s/\04/, /g; s/\n$//;
			$thisheader = "<h2>Message sent to ".htmlsanit($_).":</h2>\n";
		}
		$this = "";
		$normstate= 'kill-body';
	} elsif ($normstate eq 'autocheck') {
		next if !m/^X-Debian-Bugs(-\w+)?: This is an autoforward from (\S+)/;
		$normstate= 'autowait';
		$thisheader = "<h2>Message received at $2:</h2>\n";
		$this = '';
		push @mail, $_;
	} elsif ($normstate eq 'autowait') {
		next if !m/^$/;
		$normstate= 'go-nox';
	} else {
		&quitcgi("$ref state $normstate line \`$_'");
	}
}
&quitcgi("$ref state $normstate at end") unless $normstate eq 'kill-end';
close(L);

if ( $mbox ) {
	print "Content-Type: text/plain\n\n";
	foreach ( @mails ) {
		my @lines = split( "\n", $_, -1 );
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
		$_ = join( "\n", @lines ) . "\n";
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
print "<H1>" .  "$debbugs::gProject $debbugs::gBug report logs - <A HREF=\"mailto:$ref\@$gEmailDomain\">$short</A>" .
      "<BR>" . htmlsanit($status{subject}) . "</H1>\n";

print "$descriptivehead\n";
printf "<p>View this report as an <a href=\"%s\">mbox folder</a>.</p>\n", mboxurl($ref);
print "<HR>";
print "$log";
print $tail_html;

print "</BODY></HTML>\n";

exit 0;

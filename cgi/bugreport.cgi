#!/usr/bin/perl -w

package debbugs;

use strict;
use CGI qw/:standard/;

require '/usr/lib/debbugs/errorlib';
require '/usr/lib/debbugs/common.pl';

require '/etc/debbugs/config';
require '/etc/debbugs/text';

my $dtime;
my $tail_html;

my %maintainer = getmaintainers();

my $ref= param('bug') || die("No bug number");
my $archive = (param('archive') || 'no') eq 'yes';
my %status = getbugstatus($ref, $archive);

my $msg = param('msg') || "";
my $boring = (param('boring') || 'no') eq 'yes'; 
my $reverse = (param('reverse') || 'no') eq 'yes';

my $indexentry;
my $descriptivehead;
my $submitted;
my $showseverity;

my $tpack;
my $tmain;

$dtime=`date -u '+%H:%M:%S GMT %a %d %h'`;
chomp($dtime);

$tail_html = $debbugs::gHTMLTail;
$tail_html =~ s/SUBSTITUTE_DTIME/$dtime/;

$|=1;

$tpack = lc $status{package};
$tpack =~ s/[^-+._a-z0-9()].*$//;

if  ($status{severity} eq 'normal') {
	$showseverity = '';
#} elsif (grep($status{severity} eq $_, @strongseverities)) {
#	$showseverity = "<strong>Severity: $status{severity}</strong>;\n";
} else {
	$showseverity = "Severity: <em>$status{severity}</em>;\n";
}

$indexentry .= $showseverity;
$indexentry .= "Reported by: ".&sani($status{originator});
$indexentry .= ";\nKeywords: ".&sani($status{keywords}) 
			if length($status{keywords});

my @merged= split(/ /,$status{mergedwith});
if (@merged) {
	my $mseparator= ";\nmerged with ";
	for my $m (@merged) {
		$indexentry .= $mseparator."<A href=\"" . bugurl($m) . "\">#$m</A>";
		$mseparator= ",\n";
	}
}

$submitted = `TZ=GMT LANG=C \\
		date -d '1 Jan 1970 00:00:00 + $status{date} seconds' \\
		'+ %a, %d %b %Y %T %Z'`;

if (length($status{done})) {
	$indexentry .= ";\n<strong>Done:</strong> ".&sani($status{done});
} elsif (length($status{forwarded})) {
	$indexentry .= ";\n<strong>Forwarded</strong> to ".&sani($status{forwarded});
}

my ($short, $tmaint);
$short = $ref; $short =~ s/^\d+/#$&/;
$tmaint = defined($maintainer{$tpack}) ? $maintainer{$tpack} : '(unknown)';
$descriptivehead= $indexentry.$submitted.";\nMaintainer for $status{package} is\n".
            '<A href="http://'.$debbugs::gWebDomain.'/ma/l'.&maintencoded($tmaint).'.html">'.&sani($tmaint).'</A>.';

my $buglog = buglog($ref, $archive);
open L, "<$buglog" || &quit("open log for $ref: $!");

my $log='';

my $xmessage = 1;
my $suppressnext = 0;

my $this = '';

my $cmsg = 1;

my $normstate= 'kill-init';
my $linenum = 0;
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

			$this .= "</pre>\n"
				if $normstate eq 'go' || $normstate eq 'go-nox';

			if ($normstate eq 'html') {
				$this .= "  <em><A href=\"" . bugurl($ref, "msg=$xmessage", "archive=$archive") . "\">Full text</A> available.</em>";
			}

			my $show = 1;
			$show = $boring
				if ($suppressnext && $normstate ne 'html');

			$show = ($xmessage == $msg) if ($msg);

			if ($show) {
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
		next;
	}

	$_ = $line;
	if ($normstate eq 'incoming-recv') {
		my $pl= $_;
		$pl =~ s/\n+$//;
		m/^Received: \(at (\S+)\) by (\S+)\;/
			|| &quit("bad line \`$pl' in state incoming-recv");
		$this = "<h2>Message received at ".&sani("$1\@$2")
		        . ":</h2><br>\n<pre>\n$_";
		$normstate= 'go';
	} elsif ($normstate eq 'html') {
		$this .= $_;
	} elsif ($normstate eq 'go') {
		$this .= &sani($_);
	} elsif ($normstate eq 'go-nox') {
		next if !s/^X//;
		$this .= &sani($_);
        } elsif ($normstate eq 'recips') {
		if (m/^-t$/) {
			$this = "<h2>Message sent:</h2><br>\n";
		} else {
			s/\04/, /g; s/\n$//;
			$this = "<h2>Message sent to ".&sani($_).":</h2><br>\n";
		}
		$normstate= 'kill-body';
	} elsif ($normstate eq 'autocheck') {
		next if !m/^X-Debian-Bugs(-\w+)?: This is an autoforward from (\S+)/;
		$normstate= 'autowait';
		$this = "<h2>Message received at $2:</h2><br>\n";
	} elsif ($normstate eq 'autowait') {
		next if !m/^$/;
		$normstate= 'go-nox';
		$this .= "<pre>\n";
	} else {
		&quit("$ref state $normstate line \`$_'");
	}
}
&quit("$ref state $normstate at end") unless $normstate eq 'kill-end';
close(L);

print header;
print start_html("$debbugs::gProject $debbugs::gBug report logs - $short");

print h1("$debbugs::gProject $debbugs::gBug report logs -  $short<br>\n"
	. sani($status{subject}));

print "$descriptivehead\n";
print hr;
print "$log";
print $tail_html;

print end_html;

sub maintencoded {
	return "";
}

exit 0;

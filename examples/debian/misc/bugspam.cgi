#!/usr/bin/perl -wT

use strict;
use CGI qw(param remote_host);

sub quitcgi($;$) {
    my ($msg, $status) = @_;
    $status //= '500 Internal Server Error';
    print "Status: $status\n";
    print "Content-Type: text/html\n\n";
    print "<HTML><HEAD><TITLE>Error</TITLE></HEAD><BODY>\n";
    print "An error occurred. Dammit.\n";
    print "Error was: $msg.\n";
    print "</BODY></HTML>\n";
    exit 0;
}

my $bug = param('bug') or quitcgi('No bug specfied', '400 Bad Request');
quitcgi('No valid bug number', '400 Bad Request') unless $bug =~ /^\d{3,6}$/;
my $remote_host = remote_host or quitcgi("No remote host");
my $ok = param('ok');
if (not defined $ok) {
   print "Content-Type: text/html\n\n";
   print "<HTML><HEAD><TITLE>Verify submission</TITLE></HEAD><BODY>\n";
   print "<H2>Verify report for bug $bug</H2>\n";
   print qq(<A HREF="bugspam.cgi?bug=$bug;ok=ok">Yes, report that bug $bug has spam</A>\n);
   print "</BODY></HTML>\n";
   exit 0;
}
my $time = time();

if ($remote_host =~ /^(?:222\.145\.167\.130|222\.148\.27\.140|61\.192\.213\.69|59\.124\.205\.94|221\.191\.105\.116|87\.69\.80\.58|201\.215\.217\.26|201\.215\.217\.32|66\.63\.250\.28|124\.29\.15\.132|61\.192\.200\.111|58\.81\.190\.204|220\.150\.239\.110|59\.106\.128\.138|216\.170\.223\.41|87\.165\.200\.176|62\.4\.19\.137|122\.16\.111\.96|121\.94\.6\.159|190\.42\.8\.125|61\.192\.200\.130|82\.135\.92\.154|221\.115\.95\.197|222\.239\.79\.10(?:7|8)|210\.91\.8\.51|61\.192\.206\.109|61\.192\.203\.55|140\.123\.100\.(?:15|13)|193\.203\.240\.134)$/) {
    print "Content-Type: text/html\n\n";
    print "<HTML><HEAD><TITLE>Go Away</TITLE></HEAD><BODY>\n";
    print "<h2>Report rejeted</h2>\n";
    print "You have been abusing the BTS.  Please go away.  Contact owner\@bugs.debian.org if you can explain why you should be allowed to use the BTS.\n";
    print "</BODY></HTML>\n";
    exit 0;
}

open SPAMEDBUGS, '>>', '/org/bugs.debian.org/spammed/spammedbugs'
    or quitcgi("opening spammedbugs: $!");
print SPAMEDBUGS "$bug\t$remote_host\t$time\n"
    or quitcgi("writing spammedbugs: $!");
close SPAMEDBUGS;

print "Content-Type: text/html\n\n";
print "<HTML><HEAD><TITLE>Thanks</TITLE></HEAD><BODY>\n";
print "<h2>Report accepted</h2>\n";
print "Thank you for reporting that this bug log contains spam.  These reports\n";
print "are reviewed regularly and used to clean the bug logs and train the spam filters.\n";
print "</BODY></HTML>\n";
exit 0;

#!/usr/bin/perl -wT

use warnings;
use strict;

use POSIX qw(strftime tzset);
use MIME::Parser;
use MIME::Decoder;
use IO::Scalar;
use IO::File;

use Debbugs::Config qw(:globals :text);

# for read_log_records
use Debbugs::Log qw(read_log_records);
use Debbugs::MIME qw(convert_to_utf8 decode_rfc1522 create_mime_message);
use Debbugs::CGI qw(:url :html :util);
use Debbugs::CGI::Bugreport qw(:all);
use Debbugs::Common qw(buglog getmaintainers);
use Debbugs::Packages qw(getpkgsrc);
use Debbugs::Status qw(splitpackages get_bug_status isstrongseverity);

use Scalar::Util qw(looks_like_number);
use CGI::Simple;
my $q = new CGI::Simple;

my %param = cgi_parameters(query => $q,
			   single => [qw(bug msg att boring terse),
				      qw(reverse mbox mime trim),
				      qw(mboxstat mboxmaint archive),
				      qw(repeatmerged)
				     ],
			   default => {msg       => '',
				       boring    => 'no',
				       terse     => 'no',
				       reverse   => 'no',
				       mbox      => 'no',
				       mime      => 'no',
				       mboxstat  => 'no',
				       mboxmaint => 'no',
				       archive   => 'no',
				       repeatmerged => 'yes',
				      },
			  );
# This is craptacular.

my $tail_html;

my $ref = $param{bug} or quitcgi("No bug number");
$ref =~ /(\d+)/ or quitcgi("Invalid bug number");
$ref = $1;
my $short = "#$ref";
my $msg = $param{'msg'};
my $att = $param{'att'};
my $boring = $param{'boring'} eq 'yes';
my $terse = $param{'terse'} eq 'yes';
my $reverse = $param{'reverse'} eq 'yes';
my $mbox = $param{'mbox'} eq 'yes';
my $mime = $param{'mime'} eq 'yes';

my $trim_headers = ($param{trim} || ($msg?'no':'yes')) eq 'yes';

my $mbox_status_message = $param{mboxstat} eq 'yes';
my $mbox_maint = $param{mboxmaint} eq 'yes';
$mbox = 1 if $mbox_status_message or $mbox_maint;


# Not used by this script directly, but fetch these so that pkgurl() and
# friends can propagate them correctly.
my $archive = $param{'archive'} eq 'yes';
my $repeatmerged = $param{'repeatmerged'} eq 'yes';

my $buglog = buglog($ref);

if (defined $ENV{REQUEST_METHOD} and $ENV{REQUEST_METHOD} eq 'HEAD' and not defined($att) and not $mbox) {
    print "Content-Type: text/html; charset=utf-8\n";
    my @stat = stat $buglog;
    if (@stat) {
	my $mtime = strftime '%a, %d %b %Y %T GMT', gmtime($stat[9]);
	print "Last-Modified: $mtime\n";
    }
    print "\n";
    exit 0;
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


my @records;
eval{
     @records = read_log_records($buglogfh);
};
if ($@) {
     quitcgi("Bad bug log for $gBug $ref. Unable to read records: $@");
}
undef $buglogfh;


my $log='';
my $msg_num = 0;
my $skip_next = 0;
if (looks_like_number($msg) and ($msg-1) <= $#records) {
     @records = ($records[$msg-1]);
     $msg_num = $msg - 1;
}
my @log;
if ( $mbox ) {
     my $date = strftime "%a %b %d %T %Y", localtime;
     if (@records > 1) {
	  print qq(Content-Disposition: attachment; filename="bug_${ref}.mbox"\n);
	  print "Content-Type: text/plain\n\n";
     }
     else {
	  $msg_num++;
	  print qq(Content-Disposition: attachment; filename="bug_${ref}_message_${msg_num}.mbox"\n);
	  print "Content-Type: message/rfc822\n\n";
     }
     if ($mbox_status_message and @records > 1) {
	  my $status_message='';
	  my @status_fields = (retitle   => 'subject',
			       package   => 'package',
			       submitter => 'originator',
			       severity  => 'severity',
			       tag       => 'tags',
			       owner     => 'owner',
			       blocks    => 'blocks',
			       forward   => 'forward',
			      );
	  my ($key,$value);
	  while (($key,$value) = splice(@status_fields,0,2)) {
	       if (defined $status{$value} and length $status{$value}) {
		    $status_message .= qq($key $ref $status{$value}\n);
	       }
	  }
	  print STDOUT qq(From unknown $date\n),
	       create_mime_message([From       => "$gBug#$ref <$ref\@$gEmailDomain>",
				    To         => "$gBug#$ref <$ref\@$gEmailDomain>",
				    Subject    => "Status: $status{subject}",
				    "Reply-To" => "$gBug#$ref <$ref\@$gEmailDomain>",
				   ],
				   <<END,);
$status_message
thanks


END
     }
     my $message_number=0;
     my %seen_message_ids;
     for my $record (@records) {
	  next if $record->{type} !~ /^(?:recips|incoming-recv)$/;
	  my $wanted_type = $mbox_maint?'recips':'incoming-recv';
	  # we want to include control messages anyway
	  my $record_wanted_anyway = 0;
	  my ($msg_id) = $record->{text} =~ /^Message-Id:\s+<(.+)>/im;
	  next if exists $seen_message_ids{$msg_id};
	  next if $msg_id =~/handler\..+\.ack(?:info|done)?\@/;
	  $record_wanted_anyway = 1 if $record->{text} =~ /^Received: \(at control\)/;
	  next if not $boring and not $record->{type} eq $wanted_type and not $record_wanted_anyway and @records > 1;
	  $seen_message_ids{$msg_id} = 1;
	  my @lines = split( "\n", $record->{text}, -1 );
	  if ( $lines[ 1 ] =~ m/^From / ) {
	       my $tmp = $lines[ 0 ];
	       $lines[ 0 ] = $lines[ 1 ];
	       $lines[ 1 ] = $tmp;
	  }
	  if ( !( $lines[ 0 ] =~ m/^From / ) ) {
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
$log = join("\n",@log);


# All of the below should be turned into a template

my %maintainer = %{getmaintainers()};
my %pkgsrc = %{getpkgsrc()};

my $indexentry;
my $showseverity;

my $tpack;
my $tmain;

my $dtime = strftime "%a, %e %b %Y %T UTC", gmtime;
$tail_html = $gHTMLTail;
$tail_html =~ s/SUBSTITUTE_DTIME/$dtime/;

my %status = %{get_bug_status(bug=>$ref)};
unless (%status) {
    print "Content-Type: text/html; charset=utf-8\n\n";
    print fill_in_template(template=>'cgi/no_such_bug',
			   variables => {modify_time => $dtime,
					 bug_num     => $ref,
					},
			  )
    exit 0;
}

$|=1;

$tpack = lc $status{'package'};
my @tpacks = splitpackages($tpack);

if  ($status{severity} eq 'normal') {
	$showseverity = '';
} elsif (isstrongseverity($status{severity})) {
	$showseverity = "Severity: <em class=\"severity\">$status{severity}</em>;\n";
} else {
	$showseverity = "Severity: $status{severity};\n";
}

if (@{$status{found_versions}} or @{$status{fixed_versions}}) {
     $indexentry.= q(<div style="float:right"><a href=").
	  html_escape(version_url(package => $status{package},
				  found => $status{found_versions},
				  fixed => $status{fixed_versions},
				 )).
	  q("><img alt="version graph" src=").
	       html_escape(version_url(package => $status{package},
				       found => $status{found_versions},
				       fixed => $status{fixed_versions},
				       width => 2,
				       height => 2,
				      )).qq{"></a></div>};
}


$indexentry .= "<div class=\"msgreceived\">\n";
$indexentry .= htmlize_packagelinks($status{package}, 0) . ";\n";

foreach my $pkg (@tpacks) {
    my $tmaint = defined($maintainer{$pkg}) ? $maintainer{$pkg} : '(unknown)';
    my $tsrc = defined($pkgsrc{$pkg}) ? $pkgsrc{$pkg} : '(unknown)';

    $indexentry .=
            htmlize_maintlinks(sub { $_[0] == 1 ? "Maintainer for $pkg is\n"
                                            : "Maintainers for $pkg are\n" },
                           $tmaint);
    $indexentry .= ";\nSource for $pkg is\n".
            '<a href="'.html_escape(pkg_url(src=>$tsrc))."\">$tsrc</a>" if ($tsrc ne "(unknown)");
    $indexentry .= ".\n";
}

$indexentry .= "<br>";
$indexentry .= htmlize_addresslinks("Reported by: ", \&submitterurl,
                                $status{originator}) . ";\n";
$indexentry .= sprintf "Date: %s.\n",
		(strftime "%a, %e %b %Y %T UTC", localtime($status{date}));

$indexentry .= "<br>Owned by: " . html_escape($status{owner}) . ".\n"
              if length $status{owner};

$indexentry .= "</div>\n";

my @descstates;

$indexentry .= "<h3>$showseverity";
$indexentry .= sprintf "Tags: %s;\n", 
		html_escape(join(", ", sort(split(/\s+/, $status{tags}))))
			if length($status{tags});
$indexentry .= "<br>" if (length($showseverity) or length($status{tags}));

my @merged= split(/ /,$status{mergedwith});
if (@merged) {
	my $descmerged = 'Merged with ';
	my $mseparator = '';
	for my $m (@merged) {
		$descmerged .= $mseparator."<a href=\"" . html_escape(bug_url($m)) . "\">#$m</a>";
		$mseparator= ",\n";
	}
	push @descstates, $descmerged;
}

if (@{$status{found_versions}}) {
    my $foundtext = 'Found in ';
    $foundtext .= (@{$status{found_versions}} == 1) ? 'version ' : 'versions ';
    $foundtext .= join ', ', map html_escape($_), @{$status{found_versions}};
    push @descstates, $foundtext;
}
if (@{$status{fixed_versions}}) {
    my $fixedtext = '<strong>Fixed</strong> in ';
    $fixedtext .= (@{$status{fixed_versions}} == 1) ? 'version ' : 'versions ';
    $fixedtext .= join ', ', map html_escape($_), @{$status{fixed_versions}};
    if (length($status{done})) {
	$fixedtext .= ' by ' . html_escape(decode_rfc1522($status{done}));
    }
    push @descstates, $fixedtext;
}

if (@{$status{found_versions}} or @{$status{fixed_versions}}) {
     push @descstates, '<a href="'.
	  html_escape(version_url($status{package},
				  $status{found_versions},
				  $status{fixed_versions},
				 )).qq{">Version Graph</a>};
}

if (length($status{done})) {
    push @descstates, "<strong>Done:</strong> ".html_escape(decode_rfc1522($status{done}));
}

if (length($status{forwarded})) {
    my $forward_link = html_escape($status{forwarded});
    $forward_link =~ s,((ftp|http|https)://[\S~-]+?/?)((\&gt\;)?[)]?[']?[:.\,]?(\s|$)),<a href="$1">$1</a>$3,go;
    push @descstates, "<strong>Forwarded</strong> to $forward_link";
}


my @blockedby= split(/ /, $status{blockedby});
if (@blockedby && $status{"pending"} ne 'fixed' && ! length($status{done})) {
    for my $b (@blockedby) {
        my %s = %{get_bug_status($b)};
        next if $s{"pending"} eq 'fixed' || length $s{done};
        push @descstates, "Fix blocked by <a href=\"" . html_escape(bug_url($b)) . "\">#$b</a>: ".html_escape($s{subject});
    }
}

my @blocks= split(/ /, $status{blocks});
if (@blocks && $status{"pending"} ne 'fixed' && ! length($status{done})) {
    for my $b (@blocks) {
        my %s = %{get_bug_status($b)};
        next if $s{"pending"} eq 'fixed' || length $s{done};
        push @descstates, "Blocking fix for <a href=\"" . html_escape(bug_url($b)) . "\">#$b</a>: ".html_escape($s{subject});
    }
}

if ($buglog !~ m#^\Q$gSpoolDir/db#) {
    push @descstates, "Bug is archived. No further changes may be made";
}

$indexentry .= join(";\n<br>", @descstates) . ".\n" if @descstates;
$indexentry .= "</h3>\n";

my $descriptivehead = $indexentry;

print "Content-Type: text/html; charset=utf-8\n";

my @stat = stat $buglog;
if (@stat) {
     my $mtime = strftime '%a, %d %b %Y %T GMT', gmtime($stat[9]);
     print "Last-Modified: $mtime\n";
}

print "\n";

my $title = html_escape($status{subject});

my $dummy2 = $gWebHostBugDir;

print "<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\">\n";
print <<END;
<HTML><HEAD>
<TITLE>$short - $title - $gProject $gBug report logs</TITLE>
<meta http-equiv="Content-Type" content="text/html;charset=utf-8">
<link rel="stylesheet" href="$gWebHostBugDir/css/bugs.css" type="text/css">
<script type="text/javascript">
<!--
function toggle_infmessages()
{
        allDivs=document.getElementsByTagName("div");
        for (var i = 0 ; i < allDivs.length ; i++ )
        {
                if (allDivs[i].className == "infmessage")
                {
                        allDivs[i].style.display=(allDivs[i].style.display == 'none' | allDivs[i].style.display == '') ? 'block' : 'none';
                }
        }
}
-->
</script>
</HEAD>
<BODY>
END
print "<H1>" . "$gProject $gBug report logs - <A HREF=\"mailto:$ref\@$gEmailDomain\">$short</A>" .
      "<BR>" . $title . "</H1>\n";
print "$descriptivehead\n";

if (looks_like_number($msg)) {
     printf qq(<p><a href="%s">Full log</a></p>),html_escape(bug_url($ref));
}
else {
     print qq(<p><a href="mailto:$ref\@$gEmailDomain">Reply</a> ),
	  qq(or <a href="mailto:$ref-subscribe\@$gEmailDomain">subscribe</a> ),
	       qq(to this bug.</p>\n);
     print qq(<p><a href="javascript:toggle_infmessages();">Toggle useless messages</a></p>);
     printf qq(<div class="msgreceived"><p>View this report as an <a href="%s">mbox folder</a>, ).
	  qq(<a href="%s">status mbox</a>, <a href="%s">maintainer mbox</a></p></div>\n),
	       html_escape(bug_url($ref, mbox=>'yes')),
		    html_escape(bug_url($ref, mbox=>'yes',mboxstatus=>'yes')),
			 html_escape(bug_url($ref, mbox=>'yes',mboxmaint=>'yes'));
}
print "$log";
print "<HR>";
print "<p class=\"msgreceived\">Send a report that <a href=\"/cgi-bin/bugspam.cgi?bug=$ref\">this bug log contains spam</a>.</p>\n<HR>\n";
print $tail_html;

print "</BODY></HTML>\n";

exit 0;

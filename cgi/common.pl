#!/usr/bin/perl -w

my $common_archive = 0;
my $common_repeatmerged = 1;
my %common_include = ();
my %common_exclude = ();

my $debug = 0;

sub set_option {
    my ($opt, $val) = @_;
    if ($opt eq "archive") { $common_archive = $val; }
    if ($opt eq "repeatmerged") { $common_repeatmerged = $val; }
    if ($opt eq "exclude") { %common_exclude = %{$val}; }
    if ($opt eq "include") { %common_include = %{$val}; }
}

sub readparse {
    my ($in, $key, $val, %ret);
    if (defined $ENV{"QUERY_STRING"} && $ENV{"QUERY_STRING"} ne "") {
        $in=$ENV{QUERY_STRING};
    } elsif(defined $ENV{"REQUEST_METHOD"}
        && $ENV{"REQUEST_METHOD"} eq "POST")
    {
        read(STDIN,$in,$ENV{CONTENT_LENGTH});
    } else {
        return;
    }
    foreach (split(/&/,$in)) {
        s/\+/ /g;
        ($key, $val) = split(/=/,$_,2);
        $key=~s/%(..)/pack("c",hex($1))/ge;
        $val=~s/%(..)/pack("c",hex($1))/ge;
        $ret{$key}=$val;
    }
$debug = 1 if ($ret{"debug"} eq "aj");
    return %ret;
}

sub quit {
    my $msg = shift;
    print "Content-Type: text/html\n\n";
    print "<HTML><HEAD><TITLE>Error</TITLE></HEAD><BODY>\n";
    print "An error occurred. Dammit.\n";
    print "Error was: $msg.\n";
    print "</BODY></HTML>\n";
    exit 0;
}

#sub abort {
#    my $msg = shift;
#    my $Archive = $common_archive ? "archive" : "";
#    print header . start_html("Sorry");
#    print "Sorry bug #$msg doesn't seem to be in the $Archive database.\n";
#    print end_html;
#    exit 0;
#}

sub htmlindexentry {
    my $ref = shift;
    my %status = getbugstatus($ref);
    return htmlindexentrystatus(%status) if (%status);
    return "";
}

sub htmlindexentrystatus {
    my $s = shift;
    my %status = %{$s};

    my $result = "";

    if  ($status{severity} eq 'normal') {
        $showseverity = '';
    } elsif (grep($status{severity} eq $_, @debbugs::gStrongSeverities)) {
        $showseverity = "<strong>Severity: $status{severity}</strong>;\n";
    } else {
        $showseverity = "Severity: <em>$status{severity}</em>;\n";
    }

    $result .= "Package: <a href=\"" . pkgurl($status{"package"}) . "\">"
               . "<strong>" . htmlsanit($status{"package"}) . "</strong></a>;\n"
               if (length($status{"package"}));
    $result .= $showseverity;
    $result .= "Reported by: " . htmlsanit($status{originator});
    $result .= ";\nTags: <strong>" 
		 . htmlsanit(join(", ", sort(split(/\s+/, $status{tags}))))
		 . "</strong>"
                       if (length($status{tags}));

    my @merged= split(/ /,$status{mergedwith});
    my $mseparator= ";\nmerged with ";
    for my $m (@merged) {
        $result .= $mseparator."<A href=\"" . bugurl($m) . "\">#$m</A>";
        $mseparator= ", ";
    }

    if (length($status{done})) {
        $result .= ";\n<strong>Done:</strong> " . htmlsanit($status{done});
    } elsif (length($status{forwarded})) {
        $result .= ";\n<strong>Forwarded</strong> to "
                   . htmlsanit($status{forwarded});
    } else {
        my $daysold = int((time - $status{date}) / 86400);   # seconds to days
        if ($daysold >= 7) {
            my $font = "";
            my $efont = "";
            $font = "em" if ($daysold > 30);
            $font = "strong" if ($daysold > 60);
            $efont = "</$font>" if ($font);
            $font = "<$font>" if ($font);

            my $yearsold = int($daysold / 364);
            $daysold = $daysold - $yearsold * 364;

            $result .= ";\n $font";
            $result .= "1 year and " if ($yearsold == 1);
            $result .= "$yearsold years and " if ($yearsold > 1);
            $result .= "1 day old" if ($daysold == 1);
            $result .= "$daysold days old" if ($daysold != 1);
            $result .= "$efont";
        }
    }

    $result .= ".";

    return $result;
}

sub submitterurl {
    my $ref = shift || "";
    my $params = "submitter=" . emailfromrfc822($ref);
    $params .= "&archive=yes" if ($common_archive);
    $params .= "&repeatmerged=yes" if ($common_repeatmerged);
    return urlsanit($debbugs::gCGIDomain . "pkgreport.cgi" . "?" . $params);
}

sub mainturl {
    my $ref = shift || "";
    my $params = "maint=" . emailfromrfc822($ref);
    $params .= "&archive=yes" if ($common_archive);
    $params .= "&repeatmerged=yes" if ($common_repeatmerged);
    return urlsanit($debbugs::gCGIDomain . "pkgreport.cgi" . "?" . $params);
}

sub pkgurl {
    my $ref = shift;
    my $params = "pkg=$ref";
    $params .= "&archive=yes" if ($common_archive);
    $params .= "&repeatmerged=yes" if ($common_repeatmerged);
    
    return urlsanit($debbugs::gCGIDomain . "pkgreport.cgi" . "?" . "$params");
}

sub urlsanit {
    my $url = shift;
    $url =~ s/%/%25/g;
    $url =~ s/\+/%2b/g;
    return $url;
}

sub htmlsanit {
    my %saniarray = ('<','lt', '>','gt', '&','amp', '"','quot');
    my $in = shift || "";
    my $out;
    while ($in =~ m/[<>&"]/) {
        $out .= $`. '&'. $saniarray{$&}. ';';
        $in = $';
    }
    $out .= $in;
    return $out;
}

sub bugurl {
    my $ref = shift;
    my $params = "bug=$ref";
    foreach my $val (@_) {
	$params .= "\&msg=$1" if ($val =~ /^msg=([0-9]+)/);
	$params .= "\&archive=yes" if (!$common_archive && $val =~ /^archive.*$/);
    }
    $params .= "&archive=yes" if ($common_archive);
    $params .= "&repeatmerged=yes" if ($common_repeatmerged);

    return $debbugs::gCGIDomain . "bugreport.cgi" . "?" . "$params";
}

sub packageurl {
    my $ref = shift;
    return $debbugs::gCGIDomain . "package.cgi" . "?" . "package=$ref";
}

sub allbugs {
    my @bugs = ();

    opendir(D, "$debbugs::gSpoolDir/db") or &quit("opendir db: $!");
    @bugs = sort {$a<=>$b} grep s/\.status$//,
		 (grep m/^[0-9]+\.status$/,
		 (readdir(D)));
    closedir(D);

    return @bugs;
}

sub htmlizebugs {
    my @bugs = @_;

    my %section = ();

    my %displayshowpending = ("pending", "outstanding",
                              "done", "resolved",
                              "forwarded", "forwarded to upstream software authors");

    if (@bugs == 0) {
        return "<HR><H2>No reports found!</H2></HR>\n";
    }

    foreach my $bug (sort {$a<=>$b} @bugs) {
	my %status = getbugstatus($bug);
        next unless %status;
	my @merged = sort {$a<=>$b} ($bug, split(/ /, $status{mergedwith}));
	next unless ($common_repeatmerged || $bug == $merged[0]);
	if (%common_include) {
	    my $okay = 0;
	    foreach my $t (split /\s+/, $status{tags}) {
		$okay = 1, last if (defined $common_include{$t});
	    }
	    if (defined $common_include{subj}) {
                if (index($status{subject}, $common_include{subj}) > -1) {
                    $okay = 1;
                }
            }
	    next unless ($okay);
        }
	if (%common_exclude) {
	    my $okay = 1;
	    foreach my $t (split /\s+/, $status{tags}) {
		$okay = 0, last if (defined $comon_exclude{$t});
	    }
	    if (defined $common_exclude{subj}) {
                if (index($status{subject}, $common_exclude{subj}) > -1) {
                    $okay = 0;
                }
            }
	    next unless ($okay);
	}
	    
	$section{$status{pending} . "_" . $status{severity}} .=
	    sprintf "<li><a href=\"%s\">#%d: %s</a>\n<br>",
		bugurl($bug), $bug, htmlsanit($status{subject});
	$section{$status{pending} . "_" . $status{severity}} .=
	    htmlindexentrystatus(\%status) . "\n";
    }

    my $result = "";
    my $anydone = 0;
    foreach my $pending (qw(pending forwarded done)) {
        foreach my $severity(@debbugs::gSeverityList) {
            $severity = $debbugs::gDefaultSeverity if ($severity eq '');
            next unless defined $section{${pending} . "_" . ${severity}};
            $result .= "<HR><H2>$debbugs::gSeverityDisplay{$severity} - $displayshowpending{$pending}</H2>\n";
            $result .= "(A list of <a href=\"http://${debbugs::gWebDomain}/db/si/$pending$severity\">all such bugs</a> is available).\n";
            $result .= "<UL>\n";
	    $result .= $section{$pending . "_" . $severity}; 
	    $result .= "</UL>\n";
            $anydone = 1 if ($pending eq "done");
         }
    }

    $result .= $debbugs::gHTMLExpireNote if ($anydone);
    return $result;
}

sub countbugs {
    my $bugfunc = shift;
    if ($common_archive) {
        open I, "<$debbugs::gSpoolDir/index.archive" or &quit("bugindex: $!");
    } else {
        open I, "<$debbugs::gSpoolDir/index.db" or &quit("bugindex: $!");
    }

    my %count = ();
    while(<I>) 
    {
        if (m/^(\S+)\s+(\d+)\s+(\d+)\s+(\S+)\s+\[\s*([^]]*)\s*\]\s+(\w+)\s+(.*)$/) {
            my $x = $bugfunc->(pkg => $1, bug => $2, status => $4, 
                               submitter => $5, severity => $6, tags => $7);
	    $count{$x}++;
	}
    }
    close I;
    return %count;
}

sub getbugs {
    my $bugfunc = shift;

    if ( $common_archive ) {
        open I, "<$debbugs::gSpoolDir/index.archive" or &quit("bugindex: $!");
    } else {
        open I, "<$debbugs::gSpoolDir/index.db" or &quit("bugindex: $!");
    }
    
    my @result = ();
print STDERR "here start getbugs\n" if ($debug);
    while(<I>) 
    {
        if (m/^(\S+)\s+(\d+)\s+(\d+)\s+(\S+)\s+\[\s*([^]]*)\s*\]\s+(\w+)\s+(.*)$/) {
            if ($bugfunc->(pkg => $1, bug => $2, status => $4, submitter => $5,
			   severity => $6, tags => $7))
	    {
	    	push (@result, $2);
		#last if (@result > 400);
	    }
	}
    }
    close I;
print STDERR "here end getbugs\n" if ($debug);
    return sort {$a <=> $b} @result;
}

sub emailfromrfc822 {
    my $email = shift;
    $email =~ s/\s*\(.*\)\s*//;
    $email = $1 if ($email =~ m/<(.*)>/);
    return $email;
}

sub maintencoded {
    my $input = shift;
    my $encoded = '';

    while ($input =~ m/\W/) {
 	$encoded.=$`.sprintf("-%02x_",unpack("C",$&));
        $input= $';
    }

    $encoded.= $input;
    $encoded =~ s/-2e_/\./g;
    $encoded =~ s/^([^,]+)-20_-3c_(.*)-40_(.*)-3e_/$1,$2,$3,/;
    $encoded =~ s/^(.*)-40_(.*)-20_-28_([^,]+)-29_$/,$1,$2,$3/;
    $encoded =~ s/-20_/_/g;
    $encoded =~ s/-([^_]+)_-/-$1/g;
    return $encoded;
}

sub getmaintainers {
    my %maintainer;

    open(MM,"$gMaintainerFile") or &quit("open $gMaintainerFile: $!");
    while(<MM>) {
	next unless m/^(\S+)\s+(\S.*\S)\s*$/;
	($a,$b)=($1,$2);
	$a =~ y/A-Z/a-z/;
	$maintainer{$a}= $b;
    }
    close(MM);

    return %maintainer;
}

sub getbugstatus {
    my $bugnum = shift;

    my %status;

    unless (open(S,"$gSpoolDir/db/$bugnum.status")) {
        my $archdir = sprintf "%02d", $bugnum % 100;
	open(S,"$gSpoolDir/archive/$archdir/$bugnum.status" ) or return ();
    }
    my @lines = qw(originator date subject msgid package tags done
			forwarded mergedwith severity);
    while(<S>) {
        chomp;
	$status{shift @lines} = $_;
    }
    close(S);
    $status{shift @lines} = '' while(@lines);

    $status{"package"} =~ s/\s*$//;
    $status{"package"} = 'unknown' if ($status{"package"} eq '');
    $status{"severity"} = 'normal' if ($status{"severity"} eq '');

    $status{"pending"} = 'pending';
    $status{"pending"} = 'forwarded' if (length($status{"forwarded"}));
    $status{"pending"} = 'done'      if (length($status{"done"}));

    return %status;
}

sub buglog {
    my $bugnum = shift;
    my $res;

    $res = "$gSpoolDir/db/$bugnum.log"; 
    return $res if ( -e $res );

    my $archdir = sprintf "%02d", $bugnum % 100;
    $res = "$gSpoolDir/archive/$archdir/$bugnum.log";
    return $res if ( -e $res );

    return "";
}

1

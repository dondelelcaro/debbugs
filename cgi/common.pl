#!/usr/bin/perl -w

my $common_archive = 0;
my $common_repeatmerged = 1;

sub set_option {
    my ($opt, $val) = @_;
    if ($opt eq "archive") { $common_archive = $val; }
    if ($opt eq "repeatmerged") { $common_repeatmerged = $val; }
}

sub quit {
    my $msg = shift;
    print header . start_html("Error");
    print "An error occurred. Dammit.\n";
    print "Error was: $msg.\n";
    print end_html;
    exit 0;
}

sub abort {
    my $msg = shift;
    my $Archive = $common_archive ? "archive" : "";
    print header . start_html("Sorry");
    print "Sorry bug #$msg doesn't seem to be in the $Archive database.\n";
    print end_html;
    exit 0;
}

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
    $result .= ";\nKeywords: " . htmlsanit($status{keywords})
                       if (length($status{keywords}));

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

sub mainturl {
    my $ref = shift;
    return sprintf "http://%s/db/ma/l%s.html",
	$debbugs::gWebDomain, maintencoded($ref);
}

sub pkgurl {
    my $ref = shift;
    my $params = "pkg=$ref";
    $params .= "&archive=yes" if ($common_archive);
    $params .= "&repeatmerged=yes" if ($common_repeatmerged);
    
    return $debbugs::gCGIDomain . "pkgreport.cgi" . "?" . "$params";
}

sub htmlsanit {
    my %saniarray = ('<','lt', '>','gt', '&','amp', '"','quot');
    my $in = shift;
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
        return hr . h2("No reports found!");
    }

    foreach my $bug (sort {$a<=>$b} @bugs) {
	my %status = getbugstatus($bug);
        next unless %status;
	my @merged = sort {$a<=>$b} ($bug, split(/ /, $status{mergedwith}));
	if ($common_repeatmerged || $bug == $merged[0]) {
	    $section{$status{pending} . "_" . $status{severity}} .=
	        sprintf "<li><a href=\"%s\">#%d: %s</a>\n<br>",
		    bugurl($bug), $bug, htmlsanit($status{subject});
	    $section{$status{pending} . "_" . $status{severity}} .=
		htmlindexentrystatus(\%status) . "\n";
	}
    }

    my $result = "";
    my $anydone = 0;
    foreach my $pending (qw(pending forwarded done)) {
        foreach my $severity(@debbugs::gSeverityList) {
            $severity = $debbugs::gDefaultSeverity if ($severity eq '');
            next unless defined $section{${pending} . "_" . ${severity}};
            $result .= hr . h2("$debbugs::gSeverityDisplay{$severity} - $displayshowpending{$pending}");
            $result .= "(A list of <a href=\"http://www.debian.org/Bugs/db/si/$pending$severity\">all such bugs</a> is available).\n";
            $result .= ul($section{$pending . "_" . $severity});
            $anydone = 1 if ($pending eq "done");
         }
    }

    $result .= $debbugs::gHTMLExpireNote if ($anydone);
    return $result;
}

sub maintbugs {
    my $maint = shift;
    my $chk = sub {
        my %d = @_;
        ($maintemail = $d{"maint"}) =~ s/\s*\(.*\)\s*//;
        if ($maintemail =~ m/<(.*)>/) { $maintemail = $1 }
        return $maintemail eq $maint;
    };
    return getbugs($chk);
}

sub maintencbugs {
    my $maint = shift;
    return getbugs(sub {my %d=@_; return maintencoded($d{"maint"}) eq $maint});
}

sub pkgbugs {
    my $inpkg = shift;
    return getbugs( sub { my %d = @_; return $inpkg eq $d{"pkg"} });
}

sub getbugs {
    my $bugfunc = shift;

    if ( $common_archive ) {
        open I, "<$debbugs::gSpoolDir/index.archive" or &quit("bugindex: $!");
    } else {
        open I, "<$debbugs::gSpoolDir/index.db" or &quit("bugindex: $!");
    }
    
    my @result = ();
    while(<I>) 
    {
        if (m/^(\S+)\s+(\d+)\s+(\S+)\s+(\d+)\s+\[\s*([^]]*)\s*\]\s+(\w+)\s+(.+)$/) {
            if ($bugfunc->(pkg => $1, bug => $2, maint => $5,
			   severity => $6, title => $7))
	    {
	    	push (@result, $2);
	    }
	}
    }
    close I;
    return sort {$a <=> $b} @result;
}

sub pkgbugsindex {
    my %descstr = ();
    if ( $common_archive ) {
        open I, "<$debbugs::gSpoolDir/index.archive" or &quit("bugindex: $!");
    } else {
        open I, "<$debbugs::gSpoolDir/index.db" or &quit("bugindex: $!");
    }
    while(<I>) { 
        $descstr{ $1 } = 1 if (m/^(\S+)/);
    }
    return %descstr;
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
	m/^(\S+)\s+(\S.*\S)\s*$/ or &quit("$gMaintainerFile: \`$_'");
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
    my @lines = qw(originator date subject msgid package keywords done
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

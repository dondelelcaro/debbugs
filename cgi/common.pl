#!/usr/bin/perl -w

use DB_File;
use Fcntl qw/O_RDONLY/;
use Mail::Address;
$config_path = '/etc/debbugs';
$lib_path = '/usr/lib/debbugs';
require "$lib_path/errorlib";

my $common_archive = 0;
my $common_repeatmerged = 1;
my %common_include = ();
my %common_exclude = ();
my $common_raw_sort = 0;
my $common_bug_reverse = 0;
my $common_pending_reverse = 0;
my $common_severity_reverse = 0;

my @common_pending_include = ();
my @common_pending_exclude = ();
my @common_severity_include = ();
my @common_severity_exclude = ();

my $debug = 0;

sub set_option {
    my ($opt, $val) = @_;
    if ($opt eq "archive") { $common_archive = $val; }
    if ($opt eq "repeatmerged") { $common_repeatmerged = $val; }
    if ($opt eq "exclude") {
	my @vals;
	@vals = ( $val ) if (ref($val) eq "" && $val );
	@vals = ( $$val ) if (ref($val) eq "SCALAR" && $$val );
	@vals = @{$val} if (ref($val) eq "ARRAY" );
	%common_exclude = map {
	    if (/^(.*):(.*)$/) { ($1, $2) } else { ($_, 1) }
	} split /[\s,]+/, join ',', @vals;
    }
    if ($opt eq "include") {
	my @vals;
	@vals = ( $val, ) if (ref($val) eq "" && $val );
	@vals = ( $$val, ) if (ref($val) eq "SCALAR" && $$val );
	@vals = @{$val} if (ref($val) eq "ARRAY" );
	%common_include = map {
	    if (/^(.*):(.*)$/) { ($1, $2) } else { ($_, 1) }
	} split /[\s,]+/, join ',', @vals;
    }
    if ($opt eq "raw") { $common_raw_sort = $val; }
    if ($opt eq "bug-rev") { $common_bug_reverse = $val; }
    if ($opt eq "pend-rev") { $common_pending_reverse = $val; }
    if ($opt eq "sev-rev") { $common_severity_reverse = $val; }
    if ($opt eq "pend-exc") {
	my @vals;
	@vals = ( $val ) if (ref($val) eq "" && $val );
	@vals = ( $$val ) if (ref($val) eq "SCALAR" && $$val );
	@vals = @{$val} if (ref($val) eq "ARRAY" );
	@common_pending_exclude = @vals if (@vals);
    }
    if ($opt eq "pend-inc") {
	my @vals;
	@vals = ( $val, ) if (ref($val) eq "" && $val );
	@vals = ( $$val, ) if (ref($val) eq "SCALAR" && $$val );
	@vals = @{$val} if (ref($val) eq "ARRAY" );
	@common_pending_include = @vals if (@vals);
    }
    if ($opt eq "sev-exc") {
	my @vals;
	@vals = ( $val ) if (ref($val) eq "" && $val );
	@vals = ( $$val ) if (ref($val) eq "SCALAR" && $$val );
	@vals = @{$val} if (ref($val) eq "ARRAY" );
	@common_severity_exclude = @vals if (@vals);
    }
    if ($opt eq "sev-inc") {
	my @vals;
	@vals = ( $val ) if (ref($val) eq "" && $val );
	@vals = ( $$val ) if (ref($val) eq "SCALAR" && $$val );
	@vals = @{$val} if (ref($val) eq "ARRAY" );
	@common_severity_include = @vals if (@vals);
    }
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
    foreach (split(/[&;]/,$in)) {
        s/\+/ /g;
        ($key, $val) = split(/=/,$_,2);
        $key=~s/%(..)/pack("c",hex($1))/ge;
        $val=~s/%(..)/pack("c",hex($1))/ge;
	if ( exists $ret{$key} ) {
	    if ( !exists $ret{"&$key"} ) {
		$ret{"&$key"} = [ $ret{$key} ];
	    }
	    push @{$ret{"&$key"}},$val;
	}
        $ret{$key}=$val;
    }
$debug = 1 if (defined $ret{"debug"} && $ret{"debug"} eq "aj");
    return %ret;
}

sub quitcgi {
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

# Split a package string from the status file into a list of package names.
sub splitpackages {
    my $pkgs = shift;
    return unless defined $pkgs;
    return map lc, split /[ \t?,()]+/, $pkgs;
}

my %_parsedaddrs;
sub getparsedaddrs {
    my $addr = shift;
    return () unless defined $addr;
    return @{$_parsedaddrs{$addr}} if exists $_parsedaddrs{$addr};
    @{$_parsedaddrs{$addr}} = Mail::Address->parse($addr);
    return @{$_parsedaddrs{$addr}};
}

# Generate a comma-separated list of HTML links to each package given in
# $pkgs. $pkgs may be empty, in which case an empty string is returned, or
# it may be a comma-separated list of package names.
sub htmlpackagelinks {
    my $pkgs = shift;
    return unless defined $pkgs and $pkgs ne '';
    my $strong = shift;
    my @pkglist = splitpackages($pkgs);

    my $openstrong  = $strong ? '<strong>' : '';
    my $closestrong = $strong ? '</strong>' : '';

    return 'Package' . (@pkglist > 1 ? 's' : '') . ': ' .
           join(', ',
                map {
                    '<a href="' . pkgurl($_) . '">' .
                    $openstrong . htmlsanit($_) . $closestrong . '</a>'
                } @pkglist
           ) . ";\n";
}

# Generate a comma-separated list of HTML links to each maintainer given in
# $maints, which should be a comma-separated list of RFC822 addresses.
sub htmlmaintlinks {
    my ($prefixfunc, $maints) = @_;
    if (defined $maints and $maints ne '') {
        my @maintaddrs = getparsedaddrs($maints);
        my $prefix = (ref $prefixfunc) ? $prefixfunc->(scalar @maintaddrs)
                                       : $prefixfunc;
        return $prefix .
               join ', ', map { sprintf '<a href="%s">%s</a>',
                                        mainturl($_->address),
                                        htmlsanit($_->format) || '(unknown)'
                              } @maintaddrs;
    } else {
        my $prefix = (ref $prefixfunc) ? $prefixfunc->(1) : $prefixfunc;
        return sprintf '%s<a href="%s">(unknown)</a>', $prefix, mainturl('');
    }
}

sub htmlindexentry {
    my $ref = shift;
    my %status = %{getbugstatus($ref)};
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

    $result .= htmlpackagelinks($status{"package"}, 1);
    $result .= $showseverity;
    $result .= "Reported by: <a href=\"" . submitterurl($status{originator})
               . "\">" . htmlsanit($status{originator}) . "</a>";
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
    } else {
        if (length($status{forwarded})) {
            $result .= ";\n<strong>Forwarded</strong> to "
                       . maybelink($status{forwarded});
        }
        my $daysold = int((time - $status{date}) / 86400);   # seconds to days
        if ($daysold >= 7) {
            my $font = "";
            my $efont = "";
            $font = "em" if ($daysold > 30);
            $font = "strong" if ($daysold > 60);
            $efont = "</$font>" if ($font);
            $font = "<$font>" if ($font);

            my $yearsold = int($daysold / 365);
            $daysold -= $yearsold * 365;

            $result .= ";\n $font";
            my @age;
            push @age, "1 year" if ($yearsold == 1);
            push @age, "$yearsold years" if ($yearsold > 1);
            push @age, "1 day" if ($daysold == 1);
            push @age, "$daysold days" if ($daysold > 1);
            $result .= join(" and ", @age);
            $result .= " old$efont";
        }
    }

    $result .= ".";

    return $result;
}

sub submitterurl {
    my $ref = shift || "";
    my $params = "submitter=" . emailfromrfc822($ref);
    $params .= "&archive=yes" if ($common_archive);
    $params .= "&repeatmerged=no" unless ($common_repeatmerged);
    return urlsanit("pkgreport.cgi" . "?" . $params);
}

sub mainturl {
    my $ref = shift || "";
    my $params = "maint=" . emailfromrfc822($ref);
    $params .= "&archive=yes" if ($common_archive);
    $params .= "&repeatmerged=no" unless ($common_repeatmerged);
    return urlsanit("pkgreport.cgi" . "?" . $params);
}

sub pkgurl {
    my $ref = shift;
    my $params = "pkg=$ref";
    $params .= "&archive=yes" if ($common_archive);
    $params .= "&repeatmerged=no" unless ($common_repeatmerged);
    
    return urlsanit("pkgreport.cgi" . "?" . "$params");
}

sub srcurl {
    my $ref = shift;
    my $params = "src=$ref";
    $params .= "&archive=yes" if ($common_archive);
    $params .= "&repeatmerged=no" unless ($common_repeatmerged);
    return urlsanit("pkgreport.cgi" . "?" . "$params");
}

sub urlsanit {
    my $url = shift;
    $url =~ s/%/%25/g;
    $url =~ s/\+/%2b/g;
    my %saniarray = ('<','lt', '>','gt', '&','amp', '"','quot');
    $url =~ s/([<>&"])/\&$saniarray{$1};/g;
    return $url;
}

sub htmlsanit {
    my %saniarray = ('<','lt', '>','gt', '&','amp', '"','quot');
    my $in = shift || "";
    $in =~ s/([<>&"])/\&$saniarray{$1};/g;
    return $in;
}

sub maybelink {
    my $in = shift;
    if ($in =~ /^[a-zA-Z0-9+.-]+:/) { # RFC 1738 scheme
	return qq{<a href="$in">} . htmlsanit($in) . '</a>';
    } else {
	return htmlsanit($in);
    }
}

sub bugurl {
    my $ref = shift;
    my $params = "bug=$ref";
    foreach my $val (@_) {
	$params .= "\&msg=$1" if ($val =~ /^msg=([0-9]+)/);
	$params .= "\&archive=yes" if (!$common_archive && $val =~ /^archive.*$/);
    }
    $params .= "&archive=yes" if ($common_archive);
    $params .= "&repeatmerged=no" unless ($common_repeatmerged);

    return urlsanit("bugreport.cgi" . "?" . "$params");
}

sub dlurl {
    my $ref = shift;
    my $params = "bug=$ref";
    my $filename = '';
    foreach my $val (@_) {
	$params .= "\&$1=$2" if ($val =~ /^(msg|att)=([0-9]+)/);
	$filename = $1 if ($val =~ /^filename=(.*)$/);
    }
    $params .= "&archive=yes" if ($common_archive);
    my $pathinfo = '';
    $pathinfo = "/$filename" if $filename ne '';

    return urlsanit("bugreport.cgi$pathinfo?$params");
}

sub mboxurl {
    my $ref = shift;
    return urlsanit("bugreport.cgi" . "?" . "bug=$ref&mbox=yes");
}

sub allbugs {
    return @{getbugs(sub { 1 })};
}

sub htmlizebugs {
    $b = $_[0];
    my @bugs = @$b;
    my @rawsort;

    my %section = ();

    my %displayshowpending = ("pending", "outstanding",
			      "pending-fixed", "pending upload",
			      "fixed", "fixed in NMU",
                              "done", "resolved",
                              "forwarded", "forwarded to upstream software authors");

    if (@bugs == 0) {
        return "<HR><H2>No reports found!</H2></HR>\n";
    }

    if ( $common_bug_reverse ) {
	@bugs = sort {$b<=>$a} @bugs;
    } else {
	@bugs = sort {$a<=>$b} @bugs;
    }
    my %seenmerged;
    foreach my $bug (@bugs) {
	my %status = %{getbugstatus($bug)};
        next unless %status;
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
		$okay = 0, last if (defined $common_exclude{$t});
	    }
	    if (defined $common_exclude{subj}) {
                if (index($status{subject}, $common_exclude{subj}) > -1) {
                    $okay = 0;
                }
            }
	    next unless ($okay);
	}
	next if @common_pending_include and
	     not grep { $_ eq $status{pending} } @common_pending_include;
	next if @common_severity_include and
	     not grep { $_ eq $status{severity} } @common_severity_include;
	next if grep { $_ eq $status{pending} } @common_pending_exclude;
	next if grep { $_ eq $status{severity} } @common_severity_exclude;

	my @merged = sort {$a<=>$b} ($bug, split(/ /, $status{mergedwith}));
	next unless ($common_repeatmerged || !$seenmerged{$merged[0]});
	$seenmerged{$merged[0]} = 1;

	my $html = sprintf "<li><a href=\"%s\">#%d: %s</a>\n<br>",
	    bugurl($bug), $bug, htmlsanit($status{subject});
	$html .= htmlindexentrystatus(\%status) . "\n";
	$section{$status{pending} . "_" . $status{severity}} .= $html;
	push @rawsort, $html if $common_raw_sort;
    }

    my $result = "";
    my $anydone = 0;
    if ($common_raw_sort) {
	$result .= "<UL>\n" . join("", @rawsort ) . "</UL>\n";
    } else {
	my @pendingList = qw(pending forwarded pending-fixed fixed done);
	@pendingList = reverse @pendingList if $common_pending_reverse;
#print STDERR join(",",@pendingList)."\n";
#print STDERR join(",",@common_pending_include).":$#common_pending_include\n";
    foreach my $pending (@pendingList) {
	my @severityList = @debbugs::gSeverityList;
	@severityList = reverse @severityList if $common_severity_reverse;
#print STDERR join(",",@severityList)."\n";

#        foreach my $severity(@debbugs::gSeverityList) {
        foreach my $severity(@severityList) {
            $severity = $debbugs::gDefaultSeverity if ($severity eq '');
            next unless defined $section{${pending} . "_" . ${severity}};
            $result .= "<HR><H2>$debbugs::gSeverityDisplay{$severity} - $displayshowpending{$pending}</H2>\n";
            #$result .= "(A list of <a href=\"http://${debbugs::gWebDomain}/db/si/$pending$severity\">all such bugs</a> is available).\n";
            #$result .= "(A list of all such bugs used to be available).\n";
            $result .= "<UL>\n";
	    $result .= $section{$pending . "_" . $severity}; 
	    $result .= "</UL>\n";
            $anydone = 1 if ($pending eq "done");
         }
    }

    }
    $result .= $debbugs::gHTMLExpireNote if ($anydone);
    return $result;
}

sub countbugs {
    my $bugfunc = shift;
    if ($common_archive) {
        open I, "<$debbugs::gSpoolDir/index.archive"
            or &quitcgi("$debbugs::gSpoolDir/index.archive: $!");
    } else {
        open I, "<$debbugs::gSpoolDir/index.db"
            or &quitcgi("$debbugs::gSpoolDir/index.db: $!");
    }

    my %count = ();
    while(<I>) 
    {
        if (m/^(\S+)\s+(\d+)\s+(\d+)\s+(\S+)\s+\[\s*([^]]*)\s*\]\s+(\w+)\s+(.*)$/) {
            my @x = $bugfunc->(pkg => $1, bug => $2, status => $4, 
                               submitter => $5, severity => $6, tags => $7);
            local $_;
            $count{$_}++ foreach @x;
	}
    }
    close I;
    return %count;
}

sub getbugs {
    my $bugfunc = shift;
    my $opt = shift;

    my @result = ();

    if (!$common_archive && defined $opt && 
        -e "$debbugs::gSpoolDir/by-$opt.idx") 
    {
        my %lookup;
print STDERR "optimized\n" if ($debug);
        tie %lookup, DB_File => "$debbugs::gSpoolDir/by-$opt.idx", O_RDONLY
            or die "$0: can't open $debbugs::gSpoolDir/by-$opt.idx ($!)\n";
	while ($key = shift) {
            my $bugs = $lookup{$key};
            if (defined $bugs) {
                push @result, (unpack 'N*', $bugs);
            }
        }
	untie %lookup;
print STDERR "done optimized\n" if ($debug);
    } else {
        if ( $common_archive ) {
            open I, "<$debbugs::gSpoolDir/index.archive" 
                or &quitcgi("$debbugs::gSpoolDir/index.archive: $!");
        } else {
            open I, "<$debbugs::gSpoolDir/index.db" 
                or &quitcgi("$debbugs::gSpoolDir/index.db: $!");
        }
        while(<I>) {
            if (m/^(\S+)\s+(\d+)\s+(\d+)\s+(\S+)\s+\[\s*([^]]*)\s*\]\s+(\w+)\s+(.*)$/) {
                if ($bugfunc->(pkg => $1, bug => $2, status => $4,
			    submitter => $5, severity => $6, tags => $7)) 
		{
	       	    push (@result, $2);
	        }
	    }
        }
        close I;
    }
    @result = sort {$a <=> $b} @result;
    return \@result;
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

my $_maintainer;
sub getmaintainers {
    return $_maintainer if $_maintainer;
    my %maintainer;

    open(MM,"$gMaintainerFile") or &quitcgi("open $gMaintainerFile: $!");
    while(<MM>) {
	next unless m/^(\S+)\s+(\S.*\S)\s*$/;
	($a,$b)=($1,$2);
	$a =~ y/A-Z/a-z/;
	$maintainer{$a}= $b;
    }
    close(MM);
    if (defined $gMaintainerFileOverride) {
	open(MM,"$gMaintainerFileOverride") or &quitcgi("open $gMaintainerFileOverride: $!");
	while(<MM>) {
	    next unless m/^(\S+)\s+(\S.*\S)\s*$/;
	    ($a,$b)=($1,$2);
	    $a =~ y/A-Z/a-z/;
	    $maintainer{$a}= $b;
	}
	close(MM);
    }
    $_maintainer = \%maintainer;
    return $_maintainer;
}

my $_pkgsrc;
my $_pkgcomponent;
sub getpkgsrc {
    return $_pkgsrc if $_pkgsrc;
    return {} unless defined $gPackageSource;
    my %pkgsrc;
    my %pkgcomponent;

    open(MM,"$gPackageSource") or &quitcgi("open $gPackageSource: $!");
    while(<MM>) {
	next unless m/^(\S+)\s+(\S+)\s+(\S.*\S)\s*$/;
	($a,$b,$c)=($1,$2,$3);
	$a =~ y/A-Z/a-z/;
	$pkgsrc{$a}= $c;
	$pkgcomponent{$a}= $b;
    }
    close(MM);
    $_pkgsrc = \%pkgsrc;
    $_pkgcomponent = \%pkgcomponent;
    return $_pkgsrc;
}

sub getpkgcomponent {
    return $_pkgcomponent if $_pkgcomponent;
    getpkgsrc();
    return $_pkgcomponent;
}

my $_pseudodesc;
sub getpseudodesc {
    return $_pseudodesc if $_pseudodesc;
    my %pseudodesc;

    open(PSEUDO, "< $gPseudoDescFile") or &quitcgi("open $gPseudoDescFile: $!");
    while(<PSEUDO>) {
	next unless m/^(\S+)\s+(\S.*\S)\s*$/;
	$pseudodesc{lc $1} = $2;
    }
    close(PSEUDO);
    $_pseudodesc = \%pseudodesc;
    return $_pseudodesc;
}

sub getbugstatus {
    my $bugnum = shift;

    my %status;

    my $location = getbuglocation( $bugnum, "status" );
    return {} if ( !$location );
    %status = %{ readbug( $bugnum, $location ) };

    $status{tags} = $status{keywords};

    $status{"package"} =~ s/\s*$//;
    $status{"package"} = 'unknown' if ($status{"package"} eq '');
    $status{"severity"} = 'normal' if ($status{"severity"} eq '');

    $status{"pending"} = 'pending';
    $status{"pending"} = 'forwarded'	    if (length($status{"forwarded"}));
    $status{"pending"} = 'pending-fixed'    if ($status{"tags"} =~ /\bpending\b/);
    $status{"pending"} = 'fixed'	    if ($status{"tags"} =~ /\bfixed\b/);
    $status{"pending"} = 'done'		    if (length($status{"done"}));

    return \%status;
}

sub getsrcpkgs {
    my $src = shift;
    return () if !$src;
    my %pkgsrc = %{getpkgsrc()};
    my @pkgs;
    foreach ( keys %pkgsrc ) {
	push @pkgs, $_ if $pkgsrc{$_} eq $src;
    }
    return @pkgs;
}
   
sub buglog {
    my $bugnum = shift;
    my $location = getbuglocation($bugnum, 'log');
    return getbugcomponent($bugnum, 'log', $location);
}

1;

#!/usr/bin/perl -w

use DB_File;
use Fcntl qw/O_RDONLY/;
use Mail::Address;
use MLDBM qw/DB_File/;
use POSIX qw/ceil/;

use URI::Escape;

$config_path = '/etc/debbugs';
$lib_path = '/usr/lib/debbugs';
require "$lib_path/errorlib";

use Debbugs::Packages;
use Debbugs::Versions;
use Debbugs::MIME qw(decode_rfc1522);

$MLDBM::RemoveTaint = 1;

my $common_archive = 0;
my $common_repeatmerged = 1;
my %common_include = ();
my %common_exclude = ();
my $common_raw_sort = 0;
my $common_bug_reverse = 0;

my %common_reverse = (
    'pending' => 0,
    'severity' => 0,
);
my %common = (
    'show_list_header' => 1,
    'show_list_footer' => 1,
);

sub exact_field_match {
    my ($field, $values, $status) = @_; 
    my @values = @$values;
    my @ret = grep {$_ eq $status->{$field} } @values;
    $#ret != -1;
}
sub contains_field_match {
    my ($field, $values, $status) = @_; 
    foreach my $data (@$values) {
        return 1 if (index($status->{$field}, $data) > -1);
    }
    return 0;        
}

sub detect_user_agent {
    my $userAgent = $ENV{HTTP_USER_AGENT};
    return { 'name' => 'unknown' } unless defined $userAgent;
    return { 'name' => 'links' } if ( $userAgent =~ m,^ELinks,);
    return { 'name' => 'lynx' } if ( $userAgent =~ m,^Lynx,);
    return { 'name' => 'wget' } if ( $userAgent =~ m,^Wget,);
    return { 'name' => 'gecko' } if ( $userAgent =~ m,^Mozilla.* Gecko/,);
    return { 'name' => 'ie' } if ( $userAgent =~ m,^.*MSIE.*,);
    return { 'name' => 'unknown' };
}

my %field_match = (
    'subject' => \&contains_field_match,
    'tags' => sub {
        my ($field, $values, $status) = @_; 
	my %values = map {$_=>1} @$values;
	foreach my $t (split /\s+/, $status->{$field}) {
            return 1 if (defined $values{$t});
        }
        return 0;
    },
    'severity' => \&exact_field_match,
    'pending' => \&exact_field_match,
    'originator' => \%contains_field_match,
    'forwarded' => \%contains_field_match,
    'owner' => \%contains_field_match,
);
my @common_grouping = ( 'severity', 'pending' );
my %common_grouping_order = (
    'pending' => [ qw( pending forwarded pending-fixed fixed done absent ) ],
    'severity' => \@debbugs::gSeverityList,
);
my %common_grouping_display = (
    'pending' => 'Status',
    'severity' => 'Severity',
);
my %common_headers = (
    'pending' => {
	"pending"	=> "outstanding",
	"pending-fixed"	=> "pending upload",
	"fixed"		=> "fixed in NMU",
	"done"		=> "resolved",
	"forwarded"	=> "forwarded to upstream software authors",
	"absent"	=> "not applicable to this version",
    },
    'severity' => \%debbugs::gSeverityDisplay,
);

my $common_version;
my $common_dist;
my $common_arch;

my $debug = 0;
my $use_bug_idx = 0;
my %bugidx;

sub array_option($) {
    my ($val) = @_;
    my @vals;
    @vals = ( $val ) if (ref($val) eq "" && $val );
    @vals = ( $$val ) if (ref($val) eq "SCALAR" && $$val );
    @vals = @{$val} if (ref($val) eq "ARRAY" );
    return @vals;
}

sub filter_include_exclude($\%) {
    my ($val, $filter_map) = @_;
    my @vals = array_option($val);
    my @data = map {
        if (/^([^:]*):(.*)$/) { if ($1 eq 'subj') { ['subject', $2]; } else { [$1, $2] } } else { ['tags', $_] }
    } split /[\s,]+/, join ',', @vals;
    foreach my $data (@data) {
	&quitcgi("Invalid filter key: '$data->[0]'") if (!exists($field_match{$data->[0]}));
        push @{$filter_map->{$data->[0]}}, $data->[1];
    }
}

sub filter_option($$\%) {
    my ($key, $val, $filter_map) = @_;
    my @vals = array_option($val);
    foreach $val (@vals) {
        push @{$filter_map->{$key}}, $val;
    }
}

sub set_option {
    my ($opt, $val) = @_;
    if ($opt eq "use-bug-idx") {
	$use_bug_idx = $val;
	if ( $val ) {
	    $common_headers{pending}{open} = $common_headers{pending}{pending};
	    my $bugidx = tie %bugidx, MLDBM => "$debbugs::gSpoolDir/realtime/bug.idx", O_RDONLY
		or quitcgi( "$0: can't open $debbugs::gSpoolDir/realtime/bug.idx ($!)\n" );
	    $bugidx->RemoveTaint(1);
	} else {
	    untie %bugidx;
	}
    }
    if ($opt =~ m/^show_list_(foot|head)er$/) { $common{$opt} = $val; }
    if ($opt eq "archive") { $common_archive = $val; }
    if ($opt eq "repeatmerged") { $common_repeatmerged = $val; }
    if ($opt eq "exclude") {
	filter_include_exclude($val, %common_exclude);
    }
    if ($opt eq "include") {
	filter_include_exclude($val, %common_include);
    }
    if ($opt eq "raw") { $common_raw_sort = $val; }
    if ($opt eq "bug-rev") { $common_bug_reverse = $val; }
    if ($opt eq "pend-rev") { $common_reverse{pending} = $val; }
    if ($opt eq "sev-rev") { $common_reverse{severity} = $val; }
    if ($opt eq "pend-exc") {
	filter_option('pending', $val, %common_exclude);
    }
    if ($opt eq "pend-inc") {
	filter_option('pending', $val, %common_include);
    }
    if ($opt eq "sev-exc") {
	filter_option('severity', $val, %common_exclude);
    }
    if ($opt eq "sev-inc") {
	filter_option('severity', $val, %common_include);
    }
    if ($opt eq "version") { $common_version = $val; }
    if ($opt eq "dist") { $common_dist = $val; }
    if ($opt eq "arch") { $common_arch = $val; }
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
           );
}

# Generate a comma-separated list of HTML links to each address given in
# $addresses, which should be a comma-separated list of RFC822 addresses.
# $urlfunc should be a reference to a function like mainturl or submitterurl
# which returns the URL for each individual address.
sub htmladdresslinks {
    my ($prefixfunc, $urlfunc, $addresses) = @_;
    if (defined $addresses and $addresses ne '') {
        my @addrs = getparsedaddrs($addresses);
        my $prefix = (ref $prefixfunc) ? $prefixfunc->(scalar @addrs)
                                       : $prefixfunc;
        return $prefix .
               join ', ', map { sprintf '<a href="%s">%s</a>',
                                        $urlfunc->($_->address),
                                        htmlsanit($_->format) || '(unknown)'
                              } @addrs;
    } else {
        my $prefix = (ref $prefixfunc) ? $prefixfunc->(1) : $prefixfunc;
        return sprintf '%s<a href="%s">(unknown)</a>', $prefix, $urlfunc->('');
    }
}

# Generate a comma-separated list of HTML links to each maintainer given in
# $maints, which should be a comma-separated list of RFC822 addresses.
sub htmlmaintlinks {
    my ($prefixfunc, $maints) = @_;
    return htmladdresslinks($prefixfunc, \&mainturl, $maints);
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
    } elsif (isstrongseverity($status{severity})) {
        $showseverity = "<strong>Severity: $status{severity}</strong>;\n";
    } else {
        $showseverity = "Severity: <em>$status{severity}</em>;\n";
    }

    $result .= htmlpackagelinks($status{"package"}, 1);

    my $showversions = '';
    if (@{$status{found_versions}}) {
        my @found = @{$status{found_versions}};
        local $_;
        s{/}{ } foreach @found;
        $showversions .= join ', ', map htmlsanit($_), @found;
    }
    if (@{$status{fixed_versions}}) {
        $showversions .= '; ' if length $showversions;
        $showversions .= '<strong>fixed</strong>: ';
        my @fixed = @{$status{fixed_versions}};
        local $_;
        s{/}{ } foreach @fixed;
        $showversions .= join ', ', map htmlsanit($_), @fixed;
    }
    $result .= " ($showversions)" if length $showversions;
    $result .= ";\n";

    $result .= $showseverity;
    $result .= htmladdresslinks("Reported by: ", \&submitterurl,
                                $status{originator});
    $result .= ";\nOwned by: " . htmlsanit($status{owner})
               if length $status{owner};
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
        $days = ceil($debbugs::gRemoveAge - -M buglog($status{id}));
        if ($days >= 0) {
            $result .= ";\n<strong>Will be archived:</strong>" . ( $days == 0 ? " today" : $days == 1 ? " in $days day" : " in $days days" );
        } else {
            $result .= ";\n<strong>Archived</strong>";
        }
    }

    unless (length($status{done})) {
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

sub urlargs {
    my $args = '';
    $args .= "&archive=yes" if $common_archive;
    $args .= "&repeatmerged=no" unless $common_repeatmerged;
    $args .= "&version=$common_version" if defined $common_version;
    $args .= "&dist=$common_dist" if defined $common_dist;
    $args .= "&arch=$common_arch" if defined $common_arch;
    return $args;
}

sub submitterurl {
    my $ref = shift || "";
    my $params = "submitter=" . emailfromrfc822($ref);
    $params .= urlargs();
    return urlsanit("pkgreport.cgi" . "?" . $params);
}

sub mainturl {
    my $ref = shift || "";
    my $params = "maint=" . emailfromrfc822($ref);
    $params .= urlargs();
    return urlsanit("pkgreport.cgi" . "?" . $params);
}

sub pkgurl {
    my $ref = shift;
    my $params = "pkg=$ref";
    $params .= urlargs();
    return urlsanit("pkgreport.cgi" . "?" . "$params");
}

sub srcurl {
    my $ref = shift;
    my $params = "src=$ref";
    $params .= urlargs();
    return urlsanit("pkgreport.cgi" . "?" . "$params");
}

sub tagurl {
    my $ref = shift;
    my $params = "tag=$ref";
    $params .= urlargs();
    return urlsanit("pkgreport.cgi" . "?" . "$params");
}

sub urlsanit {
    my $url = shift;
    $url =~ s/%/%25/g;
    $url =~ s/#/%23/g;
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
    $pathinfo = '/'.uri_escape($filename) if $filename ne '';

    return urlsanit("bugreport.cgi$pathinfo?$params");
}

sub mboxurl {
    my $ref = shift;
    return urlsanit("bugreport.cgi" . "?" . "bug=$ref&mbox=yes");
}

sub allbugs {
    return @{getbugs(sub { 1 })};
}

sub bugmatches(\%\%) {
    my ($hash, $status) = @_;
    foreach my $key( keys( %$hash ) ) {
        my $value = $hash->{$key};
	my $sub = $field_match{$key};
	return 1 if ($sub->($key, $value, $status));
    }
    return 0;
}
sub bugfilter($%) {
    my ($bug, %status) = @_;
    our (%seenmerged);
    if (%common_include) {
	return 1 if (!bugmatches(%common_include, %status));
    }
    if (%common_exclude) {
	return 1 if (bugmatches(%common_exclude, %status));
    }
    my @merged = sort {$a<=>$b} $bug, split(/ /, $status{mergedwith});
    return 1 unless ($common_repeatmerged || !$seenmerged{$merged[0]});
    $seenmerged{$merged[0]} = 1;
    return 0;
}

sub htmlizebugs {
    $b = $_[0];
    my @bugs = @$b;
    my $anydone = 0;

    my @status = ();
    my %count;
    my $header = '';
    my $footer = '';

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
	next if bugfilter($bug, %status);

	my $html = sprintf "<li><a href=\"%s\">#%d: %s</a>\n<br>",
	    bugurl($bug), $bug, htmlsanit($status{subject});
	$html .= htmlindexentrystatus(\%status) . "\n";
	my $key = join( '_', map( {$status{$_}} @common_grouping ) );
	$section{$key} .= $html;
	$count{"_$key"}++;
	foreach my $grouping ( @common_grouping ) {
	    $count{"${grouping}_$status{$grouping}"}++;
	}
	$anydone = 1 if $status{pending} eq 'done';
	push @status, [ $bug, \%status, $html ];
    }

    my $result = "";
    if ($common_raw_sort) {
	$result .= "<UL>\n" . join("", map( { $_->[ 2 ] } @status ) ) . "</UL>\n";
    } else {
	my (@order, @headers);
	for( my $i = 0; $i < @common_grouping; $i++ ) {
	    my $grouping_name = $common_grouping[ $i ];
	    my @items = @{ $common_grouping_order{ $grouping_name } };
	    @items = reverse( @items ) if ( $common_reverse{ $grouping_name } );
	    my @neworder = ();
	    my @newheaders = ();
	    if ( @order ) {
		foreach my $grouping ( @items ) {
		    push @neworder, map( { "${_}_$grouping" } @order );
		    push @newheaders, map( { "$_ - $common_headers{$grouping_name}{$grouping}" } @headers );
		}
		@order = @neworder;
		@headers = @newheaders;
	    } else {
		push @order, @items;
		push @headers, map( { $common_headers{$common_grouping[$i]}{$_} } @items );
	    }
	}
	$header .= "<ul>\n";
	for ( my $i = 0; $i < @order; $i++ ) {
	    my $order = $order[ $i ];
	    next unless defined $section{$order};
	    my $count = $count{"_$order"};
	    my $bugs = $count == 1 ? "bug" : "bugs";
	    $header .= "<li><a href=\"#$order\">$headers[$i]</a> ($count $bugs)</li>\n";
	}
	$header .= "</ul>\n";
	for ( my $i = 0; $i < @order; $i++ ) {
	    my $order = $order[ $i ];
	    next unless defined $section{$order};
	    if ($common{show_list_header}) {
		my $count = $count{"_$order"};
		my $bugs = $count == 1 ? "bug" : "bugs";
		$result .= "<HR><H2><a name=\"$order\"></a>$headers[$i] ($count $bugs)</H2>\n";
	    } else {
		$result .= "<HR><H2>$headers[$i]</H2>\n";
	    }
	    $result .= "<UL>\n";
	    $result .= $section{$order};
	    $result .= "</UL>\n";
	}    
	$footer .= "<ul>\n";
	foreach my $grouping ( @common_grouping ) {
	    my $local_result = '';
	    foreach my $key ( @{$common_grouping_order{ $grouping }} ) {
		my $count = $count{"${grouping}_$key"};
		next if !$count;
		$local_result .= "<li>$count $common_headers{$grouping}{$key}</li>\n";
	    }
	    if ( $local_result ) {
		$footer .= "<li>$common_grouping_display{$grouping}<ul>\n$local_result</ul></li>\n";
	    }
	}
	$footer .= "</ul>\n";
    }

    $result = $header . $result if ( $common{show_list_header} );
    $result .= $debbugs::gHTMLExpireNote if $debbugs::gRemoveAge and $anydone;
    $result .= "<hr>" . $footer if ( $common{show_list_footer} );
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

    my $fastidx;
    if (!defined $opt) {
        # leave $fastidx undefined;
    } elsif (!$common_archive) {
        $fastidx = "$debbugs::gSpoolDir/by-$opt.idx";
    } else {
        $fastidx = "$debbugs::gSpoolDir/by-$opt-arc.idx";
    }

    if (defined $fastidx && -e $fastidx) {
        my %lookup;
print STDERR "optimized\n" if ($debug);
        tie %lookup, DB_File => $fastidx, O_RDONLY
            or die "$0: can't open $fastidx ($!)\n";
	while ($key = shift) {
            my $bugs = $lookup{$key};
            if (defined $bugs) {
                push @result, (unpack 'N*', $bugs);
            } elsif (defined $lookup{"count $key"}) {
		my $which = 0;
		while (1) {
		    $bugs = $lookup{"$which $key"};
		    last unless defined $bugs;
		    push @result, (unpack 'N*', $bugs);
		    $which += 100;
		}
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

    open(MM,"$debbugs::gMaintainerFile") or &quitcgi("open $debbugs::gMaintainerFile: $!");
    while(<MM>) {
	next unless m/^(\S+)\s+(\S.*\S)\s*$/;
	($a,$b)=($1,$2);
	$a =~ y/A-Z/a-z/;
	$maintainer{$a}= $b;
    }
    close(MM);
    if (defined $debbugs::gMaintainerFileOverride) {
	open(MM,"$debbugs::gMaintainerFileOverride") or &quitcgi("open $debbugs::gMaintainerFileOverride: $!");
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

my $_pseudodesc;
sub getpseudodesc {
    return $_pseudodesc if $_pseudodesc;
    my %pseudodesc;

    open(PSEUDO, "< $debbugs::gPseudoDescFile") or &quitcgi("open $debbugs::gPseudoDescFile: $!");
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

    if ( $use_bug_idx eq 1 && exists( $bugidx{ $bugnum } ) ) {
	%status = %{ $bugidx{ $bugnum } };
	$status{ pending } = $status{ status };
	$status{ id } = $bugnum;
	return \%status;
    }

    my $location = getbuglocation( $bugnum, 'summary' );
    return {} if ( !$location );
    %status = %{ readbug( $bugnum, $location ) };
    $status{ id } = $bugnum;

    $status{tags} = $status{keywords};
    my %tags = map { $_ => 1 } split ' ', $status{tags};

    $status{"package"} =~ s/\s*$//;
    $status{"package"} = 'unknown' if ($status{"package"} eq '');
    $status{"severity"} = 'normal' if ($status{"severity"} eq '');

    $status{"pending"} = 'pending';
    $status{"pending"} = 'forwarded'	    if (length($status{"forwarded"}));
    $status{"pending"} = 'pending-fixed'    if ($tags{pending});
    $status{"pending"} = 'fixed'	    if ($tags{fixed});

    my @versions;
    if (defined $common_version) {
        @versions = ($common_version);
    } elsif (defined $common_dist) {
        @versions = getversions($status{package}, $common_dist, $common_arch);
    }

    # TODO: This should probably be handled further out for efficiency and
    # for more ease of distinguishing between pkg= and src= queries.
    my @sourceversions = makesourceversions($status{package}, $common_arch,
                                            @versions);

    if (@sourceversions) {
        # Resolve bugginess states (we might be looking at multiple
        # architectures, say). Found wins, then fixed, then absent.
        my $maxbuggy = 'absent';
        for my $version (@sourceversions) {
            my $buggy = buggyversion($bugnum, $version, \%status);
            if ($buggy eq 'found') {
                $maxbuggy = 'found';
                last;
            } elsif ($buggy eq 'fixed' and $maxbuggy ne 'found') {
                $maxbuggy = 'fixed';
            }
        }
        if ($maxbuggy eq 'absent') {
            $status{"pending"} = 'absent';
        } elsif ($maxbuggy eq 'fixed') {
            $status{"pending"} = 'done';
        }
    }
    
    if (length($status{done}) and
            (not @sourceversions or not @{$status{fixed_versions}})) {
        $status{"pending"} = 'done';
    }

    return \%status;
}

sub buglog {
    my $bugnum = shift;
    my $location = getbuglocation($bugnum, 'log');
    return getbugcomponent($bugnum, 'log', $location) if ($location);
    $location = getbuglocation($bugnum, 'log.gz');
    return getbugcomponent($bugnum, 'log.gz', $location);
}

# Canonicalize versions into source versions, which have an explicitly
# named source package. This is used to cope with source packages whose
# names have changed during their history, and with cases where source
# version numbers differ from binary version numbers.
sub makesourceversions {
    my $pkg = shift;
    my $arch = shift;
    my %sourceversions;

    for my $version (@_) {
        if ($version =~ m[/]) {
            # Already a source version.
            $sourceversions{$version} = 1;
        } else {
            my @srcinfo = binarytosource($pkg, $version, $arch);
            unless (@srcinfo) {
                # We don't have explicit information about the
                # binary-to-source mapping for this version (yet). Since
                # this is a CGI script and our output is transient, we can
                # get away with just looking in the unversioned map; if it's
                # wrong (as it will be when binary and source package
                # versions differ), too bad.
                my $pkgsrc = getpkgsrc();
                if (exists $pkgsrc->{$pkg}) {
                    @srcinfo = ([$pkgsrc->{$pkg}, $version]);
                } else {
                    next;
                }
            }
            $sourceversions{"$_->[0]/$_->[1]"} = 1 foreach @srcinfo;
        }
    }

    return sort keys %sourceversions;
}

my %_versionobj;
sub buggyversion {
    my ($bug, $ver, $status) = @_;
    return '' unless defined $debbugs::gVersionPackagesDir;
    my $src = getpkgsrc()->{$status->{package}};
    $src = $status->{package} unless defined $src;

    my $tree;
    if (exists $_versionobj{$src}) {
        $tree = $_versionobj{$src};
    } else {
        $tree = Debbugs::Versions->new(\&DpkgVer::vercmp);
        my $srchash = substr $src, 0, 1;
        if (open VERFILE, "< $debbugs::gVersionPackagesDir/$srchash/$src") {
            $tree->load(\*VERFILE);
            close VERFILE;
        }
        $_versionobj{$src} = $tree;
    }

    my @found = makesourceversions($status->{package}, undef,
                                   @{$status->{found_versions}});
    my @fixed = makesourceversions($status->{package}, undef,
                                   @{$status->{fixed_versions}});

    return $tree->buggy($ver, \@found, \@fixed);
}

my %_versions;
sub getversions {
    my ($pkg, $dist, $arch) = @_;
    return () unless defined $debbugs::gVersionIndex;
    $dist = 'unstable' unless defined $dist;

    unless (tied %_versions) {
        tie %_versions, 'MLDBM', $debbugs::gVersionIndex, O_RDONLY
            or die "can't open versions index: $!";
    }

    if (defined $arch and exists $_versions{$pkg}{$dist}{$arch}) {
        my $ver = $_versions{$pkg}{$dist}{$arch};
        return $ver if defined $ver;
        return ();
    } else {
        my %uniq;
        for my $ar (keys %{$_versions{$pkg}{$dist}}) {
            $uniq{$_versions{$pkg}{$dist}{$ar}} = 1 unless $ar eq 'source';
        }
        return keys %uniq;
    }
}

sub getversiondesc {
    my $pkg = shift;

    if (defined $common_version) {
        return "version $common_version";
    } elsif (defined $common_dist) {
        my @distvers = getversions($pkg, $common_dist, $common_arch);
        @distvers = sort @distvers;
        local $" = ', ';
        if (@distvers > 1) {
            return "versions @distvers";
        } elsif (@distvers == 1) {
            return "version @distvers";
        }
    }

    return undef;
}

1;

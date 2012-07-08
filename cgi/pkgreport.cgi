#!/usr/bin/perl -wT
# This script is part of debbugs, and is released
# under the terms of the GPL version 2, or any later
# version at your option.
# See the file README and COPYING for more information.
#
# [Other people have contributed to this file; their copyrights should
# go here too.]
# Copyright 2004-2006 by Anthony Towns <ajt@debian.org>
# Copyright 2007 by Don Armstrong <don@donarmstrong.com>.


use warnings;
use strict;

# Sanitize environent for taint
BEGIN{
    delete @ENV{qw(IFS CDPATH ENV BASH_ENV)};
}

# STDOUT should be in utf8 mode
binmode(STDOUT,':utf8');

use POSIX qw(strftime nice);

use Debbugs::Config qw(:globals :text :config);

use Debbugs::User;

use Debbugs::Common qw(getparsedaddrs make_list getmaintainers getpseudodesc);

use Debbugs::Bugs qw(get_bugs bug_filter newest_bug);
use Debbugs::Packages qw(getsrcpkgs getpkgsrc get_versions);

use Debbugs::Status qw(splitpackages);

use Debbugs::CGI qw(:all);

if (defined $ENV{REMOTE_ADDR} and $ENV{REMOTE_ADDR} =~ /^(?:218\.175\.56\.14|64\.126\
.93\.93|72\.17\.168\.57|208\.138\.29\.104|66\.63\.250\.28|71\.70\.91\.207|121\.14\.75\.|121\.14\.96\.|219\.129\.83\.13|58\.254\.39\.23)/) {
    sleep(5);
    print "Content-Type: text/html\n\nGo away.";
    exit 0;
}

use Debbugs::CGI::Pkgreport qw(:all);

use Debbugs::Text qw(:templates);

use CGI::Simple;
my $q = new CGI::Simple;

if ($q->request_method() eq 'HEAD') {
     print $q->header(-type => "text/html",
		      -charset => 'utf-8',
		     );
     exit 0;
}

my $default_params = {ordering => 'normal',
		      archive  => 0,
		      repeatmerged => 0,
		      include      => [],
		      exclude      => [],
		     };

our %param = cgi_parameters(query => $q,
			    single => [qw(ordering archive repeatmerged),
				       qw(bug-rev pend-rev sev-rev),
				       qw(maxdays mindays version),
				       qw(data which dist newest),
				       qw(noaffects),
				      ],
			    default => $default_params,
			   );

my ($form_options,$param) = ({},undef);
($form_options,$param)= form_options_and_normal_param(\%param)
     if $param{form_options};

%param = %{$param} if defined $param;

if (exists $param{form_options} and defined $param{form_options}) {
     delete $param{form_options};
     delete $param{submit} if exists $param{submit};
     for my $default (keys %{$default_params}) {
	  if (exists $param{$default} and
	      not ref($default_params->{$default}) and
	      $default_params->{$default} eq $param{$default}
	     ) {
	       delete $param{$default};
	  }
     }
     for my $incexc (qw(include exclude)) {
	  next unless exists $param{$incexc};
	  # normalize tag to tags
	  $param{$incexc} = [map {s/^tag:/tags:/; $_} grep /\S\:\S/, make_list($param{$incexc})];
     }
     for my $key (keys %package_search_keys) {
	  next unless exists $param{key};
	  $param{$key} = [map {split /\s*,\s*/} make_list($param{$key})];
     }
     # kill off keys for which empty values are meaningless
     for my $key (qw(package src submitter affects severity status dist)) {
	  next unless exists $param{$key};
	  $param{$key} = [grep {defined $_ and length $_}
			  make_list($param{$key})];
     }
     print $q->redirect(munge_url('pkgreport.cgi?',%param));
     exit 0;
}

# normalize innclude/exclude keys; currently this is in two locations,
# which is suboptimal. Closes: #567407
for my $incexc (qw(include exclude)) {
    next unless exists $param{$incexc};
    # normalize tag to tags
    $param{$incexc} = [map {s/^tag:/tags:/; $_} make_list($param{$incexc})];
}



# map from yes|no to 1|0
for my $key (qw(repeatmerged bug-rev pend-rev sev-rev)) {
     if (exists $param{$key}){
	  if ($param{$key} =~ /^no$/i) {
	       $param{$key} = 0;
	  }
	  elsif ($param{$key}) {
	       $param{$key} = 1;
	  }
     }
}

if (lc($param{archive}) eq 'no') {
     $param{archive} = 0;
}
elsif (lc($param{archive}) eq 'yes') {
     $param{archive} = 1;
}

# fixup dist
if (exists $param{dist} and $param{dist} eq '') {
     delete $param{dist};
}

my $include = $param{'&include'} || $param{'include'} || "";
my $exclude = $param{'&exclude'} || $param{'exclude'} || "";

my $users = $param{'users'} || "";

my $ordering = $param{'ordering'};
my $raw_sort = ($param{'raw'} || "no") eq "yes";
my $old_view = ($param{'oldview'} || "no") eq "yes";
my $age_sort = ($param{'age'} || "no") eq "yes";
unless (defined $ordering) {
   $ordering = "normal";
   $ordering = "oldview" if $old_view;
   $ordering = "raw" if $raw_sort;
   $ordering = 'age' if $age_sort;
}
$param{ordering} = $ordering;

our ($bug_order) = $ordering =~ /(age(?:rev)?)/;
$bug_order = '' if not defined $bug_order;

my $bug_rev = ($param{'bug-rev'} || "no") eq "yes";
my $pend_rev = ($param{'pend-rev'} || "no") eq "yes";
my $sev_rev = ($param{'sev-rev'} || "no") eq "yes";

my @inc_exc_mapping = ({name   => 'pending',
			incexc => 'include',
			key    => 'pend-inc',
		       },
		       {name   => 'pending',
			incexc => 'exclude',
			key    => 'pend-exc',
		       },
		       {name   => 'severity',
			incexc => 'include',
			key    => 'sev-inc',
		       },
		       {name   => 'severity',
			incexc => 'exclude',
			key    => 'sev-exc',
		       },
		       {name   => 'subject',
			incexc => 'include',
			key    => 'includesubj',
		       },
		       {name   => 'subject',
			incexc => 'exclude',
			key    => 'excludesubj',
		       },
		      );
for my $incexcmap (@inc_exc_mapping) {
     push @{$param{$incexcmap->{incexc}}}, map {"$incexcmap->{name}:$_"}
	  map{split /\s*,\s*/} make_list($param{$incexcmap->{key}})
	       if exists $param{$incexcmap->{key}};
     delete $param{$incexcmap->{key}};
}


my $maxdays = ($param{'maxdays'} || -1);
my $mindays = ($param{'mindays'} || 0);
my $version = $param{'version'} || undef;


our %hidden = map { $_, 1 } qw(status severity classification);
our %cats = (
    "status" => [ {
        "nam" => "Status",
        "pri" => [map { "pending=$_" }
            qw(pending forwarded pending-fixed fixed done absent)],
        "ttl" => ["Outstanding","Forwarded","Pending Upload",
                  "Fixed in NMU","Resolved","From other Branch"],
        "def" => "Unknown Pending Status",
        "ord" => [0,1,2,3,4,5,6],
    } ],
    "severity" => [ {
        "nam" => "Severity",
        "pri" => [map { "severity=$_" } @gSeverityList],
        "ttl" => [map { $gSeverityDisplay{$_} } @gSeverityList],
        "def" => "Unknown Severity",
        "ord" => [0..@gSeverityList],
    } ],
    "classification" => [ {
        "nam" => "Classification",
        "pri" => [qw(pending=pending+tag=wontfix 
                     pending=pending+tag=moreinfo
                     pending=pending+tag=patch
                     pending=pending+tag=confirmed
                     pending=pending)],
        "ttl" => ["Will Not Fix","More information needed",
                  "Patch Available","Confirmed"],
        "def" => "Unclassified",
        "ord" => [2,3,4,1,0,5],
    } ],
    "oldview" => [ qw(status severity) ],
    "normal" => [ qw(status severity classification) ],
);

if (exists $param{which} and exists $param{data}) {
     $param{$param{which}} = [exists $param{$param{which}}?(make_list($param{$param{which}})):(),
			      make_list($param{data}),
			     ];
     delete $param{which};
     delete $param{data};
}

if (defined $param{maintenc}) {
     $param{maint} = maint_decode($param{maintenc});
     delete $param{maintenc}
}

if (exists $param{pkg}) {
     $param{package} = $param{pkg};
     delete $param{pkg};
}

if (not grep {exists $param{$_}} keys %package_search_keys and exists $param{users}) {
     $param{usertag} = [make_list($param{users})];
}

my %bugusertags;
my %ut;
my %seen_users;

for my $user (map {split /[\s*,\s*]+/} make_list($param{users}||[])) {
    next unless length($user);
    add_user($user,\%ut,\%bugusertags,\%seen_users,\%cats,\%hidden);
}

if (defined $param{usertag}) {
     for my $usertag (make_list($param{usertag})) {
	  my %select_ut = ();
	  my ($u, $t) = split /:/, $usertag, 2;
	  Debbugs::User::read_usertags(\%select_ut, $u);
	  unless (defined $t && $t ne "") {
	       $t = join(",", keys(%select_ut));
	  }
	  add_user($u,\%ut,\%bugusertags,\%seen_users,\%cats,\%hidden);
	  push @{$param{tag}}, split /,/, $t;
     }
}

quitcgi("You have to choose something to select by") unless grep {exists $param{$_}} keys %package_search_keys;


my $Archived = $param{archive} ? " Archived" : "";

my $this = munge_url('pkgreport.cgi?',
		      %param,
		     );

my %indexentry;
my %strings = ();

my @bugs;

# addusers for source and binary packages being searched for
my $pkgsrc = getpkgsrc();
my $srcpkg = getsrcpkgs();
for my $package (# For binary packages, add the binary package
		 # and corresponding source package
		 make_list($param{package}||[]),
		 (map {defined $pkgsrc->{$_}?($pkgsrc->{$_}):()}
		  make_list($param{package}||[]),
		 ),
		 # For source packages, add the source package
		 # and corresponding binary packages
		 make_list($param{src}||[]),
		 (map {defined $srcpkg->{$_}?($srcpkg->{$_}):()}
		  make_list($param{src}||[]),
		 ),
		) {
     next unless defined $package;
     add_user($package.'@'.$config{usertag_package_domain},
	      \%ut,\%bugusertags,\%seen_users,\%cats,\%hidden)
	  if defined $config{usertag_package_domain};
}


# walk through the keys and make the right get_bugs query.

my $form_option_variables = {};
$form_option_variables->{search_key_order} = [@package_search_key_order];

# Set the title sanely and clean up parameters
my @title;
my @temp = @package_search_key_order;
while (my ($key,$value) = splice @temp, 0, 2) {
     next unless exists $param{$key};
     my @entries = ();
     for my $entry (make_list($param{$key})) {
	  # we'll handle newest below
	  next if $key eq 'newest';
	  my $extra = '';
	  if (exists $param{dist} and ($key eq 'package' or $key eq 'src')) {
	       my %versions = get_versions(package => $entry,
					   (exists $param{dist}?(dist => $param{dist}):()),
					   (exists $param{arch}?(arch => $param{arch}):(arch => $config{default_architectures})),
					   ($key eq 'src'?(arch => q(source)):()),
					   no_source_arch => 1,
					   return_archs => 1,
					  );
	       my $verdesc;
	       if (keys %versions > 1) {
		    $verdesc = 'versions '. join(', ',
				    map { $_ .' ['.join(', ',
						    sort @{$versions{$_}}
						   ).']';
				   } keys %versions);
	       }
	       else {
		    $verdesc = 'version '.join(', ',
					       keys %versions
					      );
	       }
	       $extra= " ($verdesc)" if keys %versions;
	  }
	  if ($key eq 'maint' and $entry eq '') {
	       push @entries, "no one (packages without maintainers)"
	  }
	  else {
	       push @entries, $entry.$extra;
	  }
     }
     push @title,$value.' '.join(' or ', @entries) if @entries;
}
if (defined $param{newest}) {
     my $newest_bug = newest_bug();
     @bugs = ($newest_bug - $param{newest} + 1) .. $newest_bug;
     push @title, 'in '.@bugs.' newest reports';
     $param{bugs} = [exists $param{bugs}?make_list($param{bugs}):(),
		     @bugs,
		    ];
}

my $title = $gBugs.' '.join(' and ', map {/ or /?"($_)":$_} @title);
@title = ();

#yeah for magick!
@bugs = get_bugs((map {exists $param{$_}?($_,$param{$_}):()}
		  grep {$_ ne 'newest'}
		  keys %package_search_keys, 'archive'),
		 usertags => \%ut,
		);

# shove in bugs which affect this package if there is a package or a
# source given (by default), but no affects options given
if (not exists $param{affects} and not exists $param{noaffects} and
    (exists $param{src} or
     exists $param{package})) {
    push @bugs, get_bugs((map {my $key = $_;
			       exists $param{$key}?($key =~ /^(?:package|src)$/?'affects':$key,
						  ($key eq 'src'?[map {"src:$_"}make_list($param{$key})]:$param{$_})):()}
			  grep {$_ ne 'newest'}
			  keys %package_search_keys, 'archive'),
			 usertags => \%ut,
			);
}

# filter out included or excluded bugs


if (defined $param{version}) {
     $title .= " at version $param{version}";
}
elsif (defined $param{dist}) {
     $title .= " in $param{dist}";
}

$title = html_escape($title);

my @names; my @prior; my @order;
determine_ordering(cats => \%cats,
		   param => \%param,
		   ordering => \$ordering,
		   names => \@names,
		   prior => \@prior,
		   title => \@title,
		   order => \@order,
		  );

# strip out duplicate bugs
my %bugs;
@bugs{@bugs} = @bugs;
@bugs = keys %bugs;

my $result = pkg_htmlizebugs(bugs => \@bugs,
			     names => \@names,
			     title => \@title,
			     order => \@order,
			     prior => \@prior,
			     ordering => $ordering,
			     bugusertags => \%bugusertags,
			     bug_rev => $bug_rev,
			     bug_order => $bug_order,
			     repeatmerged => $param{repeatmerged},
			     include => $include,
			     exclude => $exclude,
			     this => $this,
			     options => \%param,
			     (exists $param{dist})?(dist    => $param{dist}):(),
			    );

print "Content-Type: text/html; charset=utf-8\n\n";

print "<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\">\n";
print "<HTML><HEAD>\n" . 
    "<TITLE>$title -- $gProject$Archived $gBug report logs</TITLE>\n" .
    qq(<link rel="stylesheet" href="$gWebHostBugDir/css/bugs.css" type="text/css">) .
    "</HEAD>\n" .
    '<BODY onload="pagemain();">' .
    "\n";
print qq(<DIV id="status_mask"></DIV>\n);
print "<H1>" . "$gProject$Archived $gBug report logs: $title" .
      "</H1>\n";

my $showresult = 1;

my $pkg = $param{package} if defined $param{package};
my $src = $param{src} if defined $param{src};

my $pseudodesc = getpseudodesc();
if (defined $pseudodesc and defined $pkg and exists $pseudodesc->{$pkg}) {
     delete $param{dist};
}

# output information about the packages

for my $package (make_list($param{package}||[])) {
     print generate_package_info(binary => 1,
				 package => $package,
				 options => \%param,
				 bugs    => \@bugs,
				);
}
for my $package (make_list($param{src}||[])) {
     print generate_package_info(binary => 0,
				 package => $package,
				 options => \%param,
				 bugs    => \@bugs,
				);
}

if (exists $param{maint} or exists $param{maintenc}) {
    print "<p>Note that maintainers may use different Maintainer fields for\n";
    print "different packages, so there may be other reports filed under\n";
    print "different addresses.\n";
}
if (exists $param{submitter}) {
    print "<p>Note that people may use different email accounts for\n";
    print "different bugs, so there may be other reports filed under\n";
    print "different addresses.\n";
}

print $result;

print fill_in_template(template=>'cgi/pkgreport_javascript');

print qq(<h2 class="outstanding"><!--<a class="options" href="javascript:toggle(1)">-->Options<!--</a>--></h2>\n);

print option_form(template => 'cgi/pkgreport_options',
		  param    => \%param,
		  form_options => $form_options,
		  variables => $form_option_variables,
		 );

print "<hr>\n";
print fill_in_template(template=>'html/html_tail',
		       hole_var => {'&strftime' => \&POSIX::strftime,
				   },
		      );
print "</body></html>\n";


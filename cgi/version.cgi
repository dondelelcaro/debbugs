#!/usr/bin/perl

use warnings;
use strict;

# Hack to work on merkel where suexec is in place
BEGIN{
     if ($ENV{HTTP_HOST} eq 'merkel.debian.org') {
	  unshift @INC, qw(/home/don/perl/usr/share/perl5 /home/don/perl/usr/lib/perl5 /home/don/source);
	  $ENV{DEBBUGS_CONFIG_FILE}="/home/don/config_internal";
     }
}


use CGI::Simple;

use CGI::Alert 'don@donarmstrong.com';

use Debbugs::Config qw(:config);
use Debbugs::CGI qw(htmlize_packagelinks html_escape);
use Debbugs::Versions;
use Debbugs::Versions::Dpkg;
use Debbugs::Packages qw(getversions);
use HTML::Entities qw(encode_entities);
use File::Temp qw(tempdir);
use IO::File;
use IO::Handle;



my $q = new CGI::Simple;

my %cgi_var = cgi_parameters($q);

$cgi_var{package} = ['xterm'] if not defined $cgi_var{package};
$cgi_var{found} = [] if not defined $cgi_var{found};
$cgi_var{fixed} = [] if not defined $cgi_var{fixed};

# we only care about one package
$cgi_var{package} = $cgi_var{package}[0];

# we want to first load the appropriate file,
# then figure out which versions are there in which architectures,
my %versions;
my %version_to_dist;
for my $dist (qw(oldstable stable testing unstable)) {
     $versions{$dist} = [getversions($cgi_var{package},$dist)];
     # make version_to_dist
     foreach my $version (@{$versions{$dist}}){
	  push @{$version_to_dist{$version}}, $dist;
     }
}
# then figure out which are affected.

my $srchash = substr $cgi_var{package}, 0, 1;
my $version = Debbugs::Versions->new(\&Debbugs::Versions::Dpkg::vercmp);
my $version_fh = new IO::File "$config{version_packages_dir}/$srchash/$cgi_var{package}", 'r';
$version->load($version_fh);
# Here, we need to generate a short version to full version map
my %version_map;
foreach my $key (keys %{$version->{parent}}) {
     my ($short_version) = $key =~ m{/(.+)$};
     next unless length $short_version;
     # we let the first short version have presidence.
     $version_map{$short_version} = $key if not exists $version_map{$short_version};
}
# Turn all short versions into long versions
for my $found_fixed (qw(found fixed)) {
     $cgi_var{$found_fixed} =
	  [
	   map {
		if ($_ !~ m{/}) { # short version
		     ($version_map{$_});
		}
		else { # long version
		     ($_);
		}
	   } @{$cgi_var{$found_fixed}}
	  ];
}
my %all_states = $version->allstates($cgi_var{found},$cgi_var{fixed});

my $dot = "digraph G {\n";
my %state = (found  => ['fillcolor="salmon"',
			'style="filled"',
			'shape="diamond"',
		       ],
	     absent => ['fillcolor="grey"',
			'style="filled"',
		       ],
	     fixed  => ['fillcolor="chartreuse"',
			'style="filled"',
			'shape="rect"',
		       ],
	    );
foreach my $key (keys %all_states) {
     my ($short_version) = $key =~ m{/(.+)$};
     my @attributes = @{$state{$all_states{$key}}};
     if (length $short_version and exists $version_to_dist{$short_version}) {
	  push @attributes, 'label="'.$key.'\n'."(".join(', ',@{$version_to_dist{$short_version}}).")\"";
     }
     my $node_attributes = qq("$key" [).join(',',@attributes).qq(]\n);
     $dot .= $node_attributes;
}
foreach my $key (keys %{$version->{parent}}) {
     $dot .= qq("$key").'->'.qq("$version->{parent}{$key}" [dir="back"])."\n" if defined $version->{parent}{$key};
}
$dot .= "}\n";

my $temp_dir = tempdir(CLEANUP => 1);

if (not defined $cgi_var{dot}) {
     my $dot_fh = new IO::File "$temp_dir/temp.dot",'w' or
	  die "Unable to open $temp_dir/temp.dot for writing: $!";
     print {$dot_fh} $dot or die "Unable to print output to the dot file: $!";
     close $dot_fh or die "Unable to close the dot file: $!";
     system('dot','-Tpng',"$temp_dir/temp.dot",'-o',"$temp_dir/temp.png") == 0
	  or print "Content-Type: text\n\nDot failed." and die "Dot failed: $?";
     my $png_fh = new IO::File "$temp_dir/temp.png", 'r' or
	  die "Unable to open $temp_dir/temp.png for reading: $!";
     print "Content-Type: image/png\n\n";
     print <$png_fh>;
     close $png_fh;
}
else {
     print "Content-Type: text\n\n";
     print $dot;
}

sub cgi_parameters {
     my ($q) = @_;

     my %param;
     foreach my $paramname ($q->param) {
	  $param{$paramname} = [$q->param($paramname)]
     }
     return %param;
}

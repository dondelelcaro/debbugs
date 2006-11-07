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
use Debbugs::CGI qw(htmlize_packagelinks html_escape cgi_parameters);
use Debbugs::Versions;
use Debbugs::Versions::Dpkg;
use Debbugs::Packages qw(getversions makesourceversions);
use HTML::Entities qw(encode_entities);
use File::Temp qw(tempdir);
use IO::File;
use IO::Handle;


my %img_types = (svg => 'image/svg+xml',
		 png => 'image/png',
		);

my $q = new CGI::Simple;

my %cgi_var = cgi_parameters(query   => $q,
			     single  => [qw(package format ignore_boring)],
			     default => {package       => 'xterm',
					 found         => [],
					 fixed         => [],
					 ignore_boring => 1,
					 format        => 'png',
					},
			    );

# we want to first load the appropriate file,
# then figure out which versions are there in which architectures,
my %versions;
my %version_to_dist;
for my $dist (qw(oldstable stable testing unstable experimental)) {
     $versions{$dist} = [getversions($cgi_var{package},$dist)];
     # make version_to_dist
     foreach my $version (@{$versions{$dist}}){
	  push @{$version_to_dist{$version}}, $dist;
     }
}
# then figure out which are affected.
# turn found and fixed into full versions
@{$cgi_var{found}} = makesourceversions($cgi_var{package},undef,@{$cgi_var{found}});
@{$cgi_var{fixed}} = makesourceversions($cgi_var{package},undef,@{$cgi_var{fixed}});
my @interesting_versions = makesourceversions($cgi_var{package},undef,keys %version_to_dist);

# We need to be able to rip out leaves which the versions that do not affect the current versions of unstable/testing
my %sources;
@sources{map {m{(.+)/}; $1} @{$cgi_var{found}}} = (1) x @{$cgi_var{found}};
@sources{map {m{(.+)/}; $1} @{$cgi_var{fixed}}} = (1) x @{$cgi_var{fixed}};
my $version = Debbugs::Versions->new(\&Debbugs::Versions::Dpkg::vercmp);
foreach my $source (keys %sources) {
     my $srchash = substr $source, 0, 1;
     my $version_fh = new IO::File "$config{version_packages_dir}/$srchash/$source", 'r';
     $version->load($version_fh);
}
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
     next if $cgi_var{ignore_boring} and (not defined $all_states{$key}
					  or $all_states{$key} eq 'absent');
     next if $cgi_var{ignore_boring} and not version_relevant($version,$key,\@interesting_versions);
     my @attributes = @{$state{$all_states{$key}}};
     if (length $short_version and exists $version_to_dist{$short_version}) {
	  push @attributes, 'label="'.$key.'\n'."(".join(', ',@{$version_to_dist{$short_version}}).")\"";
     }
     my $node_attributes = qq("$key" [).join(',',@attributes).qq(]\n);
     $dot .= $node_attributes;
}
foreach my $key (keys %{$version->{parent}}) {
     next if not defined $version->{parent}{$key};
     next if $cgi_var{ignore_boring} and $all_states{$key} eq 'absent';
     next if $cgi_var{ignore_boring} and (not defined $all_states{$version->{parent}{$key}}
					  or $all_states{$version->{parent}{$key}} eq 'absent');
     # Ignore branches which are not ancestors of a currently distributed version
     next if $cgi_var{ignore_boring} and not version_relevant($version,$key,\@interesting_versions);
     $dot .= qq("$key").'->'.qq("$version->{parent}{$key}" [dir="back"])."\n" if defined $version->{parent}{$key};
}
$dot .= "}\n";

my $temp_dir = tempdir(CLEANUP => 1);

if (not defined $cgi_var{dot}) {
     my $dot_fh = new IO::File "$temp_dir/temp.dot",'w' or
	  die "Unable to open $temp_dir/temp.dot for writing: $!";
     print {$dot_fh} $dot or die "Unable to print output to the dot file: $!";
     close $dot_fh or die "Unable to close the dot file: $!";
     system('dot','-T'.$cgi_var{format},"$temp_dir/temp.dot",'-o',"$temp_dir/temp.$cgi_var{format}") == 0
	  or print "Content-Type: text\n\nDot failed." and die "Dot failed: $?";
     my $img_fh = new IO::File "$temp_dir/temp.$cgi_var{format}", 'r' or
	  die "Unable to open $temp_dir/temp.$cgi_var{format} for reading: $!";
     print "Content-Type: $img_types{$cgi_var{format}}\n\n";
     print <$img_fh>;
     close $img_fh;
}
else {
     print "Content-Type: text\n\n";
     print $dot;
}


my %_version_relevant_cache;
sub version_relevant {
     my ($version,$test_version,$relevant_versions) = @_;
     for my $dist_version (@{$relevant_versions}) {
	  print STDERR "Testing $dist_version against $test_version\n";
	  return 1 if $version->isancestor($test_version,$dist_version);
     }
     return 0;
}



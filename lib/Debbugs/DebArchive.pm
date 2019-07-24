# This module is part of debbugs, and is released
# under the terms of the GPL version 2, or any later
# version at your option.
# See the file README and COPYING for more information.
#
# Copyright 2017 by Don Armstrong <don@donarmstrong.com>.

package Debbugs::DebArchive;

use warnings;
use strict;

=head1 NAME

Debbugs::DebArchive -- Routines for reading files from Debian archives

=head1 SYNOPSIS

use Debbugs::DebArchive;

   read_packages('/srv/mirrors/ftp.debian.org/ftp/dist',
                 sub { print map {qq($_\n)} @_ },
                 Term::ProgressBar->new(),
                );


=head1 DESCRIPTION

This module implements a set of routines for reading Packages.gz, Sources.gz and
Release files from the dists directory of a Debian archive.

=head1 BUGS

None known.

=cut


use vars qw($DEBUG $VERSION @EXPORT_OK %EXPORT_TAGS @EXPORT);
use base qw(Exporter);

BEGIN {
    $VERSION = 1.00;
    $DEBUG = 0 unless defined $DEBUG;

    @EXPORT = ();
    %EXPORT_TAGS = (read => [qw(read_release_file read_packages),
                            ],
		   );
    @EXPORT_OK = ();
    Exporter::export_ok_tags(keys %EXPORT_TAGS);
    $EXPORT_TAGS{all} = [@EXPORT_OK];
}

use File::Spec qw();
use File::Basename;
use Debbugs::Config qw(:config);
use Debbugs::Common qw(open_compressed_file make_list);
use IO::Dir;

use Carp;

=over

=item read_release_file

     read_release_file('stable/Release')

Reads a Debian release file and returns a hashref of information about the
release file, including the Packages and Sources files for that distribution

=cut

sub read_release_file {
    my ($file) = @_;
    # parse release
    my $rfh =  open_compressed_file($file) or
	die "Unable to open $file for reading: $!";
    my %dist_info;
    my $in_sha1;
    my %p_f;
    while (<$rfh>) {
	chomp;
	if (s/^(\S+):\s*//) {
	    if ($1 eq 'SHA1'or $1 eq 'SHA256') {
		$in_sha1 = 1;
		next;
	    }
	    $dist_info{$1} = $_;
	} elsif ($in_sha1) {
	    s/^\s//;
	    my ($sha,$size,$f) = split /\s+/,$_;
	    next unless $f =~ /(?:Packages|Sources)(?:\.gz|\.xz)$/;
	    next unless $f =~ m{^([^/]+)/([^/]+)/([^/]+)$};
	    my ($component,$arch,$package_source) = ($1,$2,$3);
	    $arch =~ s/binary-//;
	    next if exists $p_f{$component}{$arch} and
                $p_f{$component}{$arch} =~ /\.xz$/;
	    $p_f{$component}{$arch} = File::Spec->catfile(dirname($file),$f);
	}
    }
    return (\%dist_info,\%p_f);
}

=item read_packages

     read_packages($dist_dir,$callback,$progress)

=over

=item dist_dir

Path to dists directory

=item callback

Function which is called with key, value pairs of suite, arch, component,
Package, Source, Version, and Maintainer information for each package in the
Packages file.

=item progress

Optional Term::ProgressBar object to output progress while reading packages.

=back


=cut

sub read_packages {
    my ($dist_dir,$callback,$p) = @_;

    my %s_p;
    my $tot = 0;
    for my $dist (make_list($dist_dir)) {
	my $dist_dir_h = IO::Dir->new($dist);
	my @dist_names =
	    grep { $_ !~ /^\./ and
		   -d $dist.'/'.$_ and
		   not -l $dist.'/'.$_
	       } $dist_dir_h->read or
               die "Unable to read from dir: $!";
        $dist_dir_h->close or
            die "Unable to close dir: $!";
	while (my $dist = shift @dist_names) {
	    my $dir = $dist_dir.'/'.$dist;
	    my ($dist_info,$package_files) =
		read_release_file(File::Spec->catfile($dist_dir,
                                                      $dist,
                                                      'Release'));
	    $s_p{$dist_info->{Codename}} = $package_files;
	}
	for my $suite (keys %s_p) {
	    for my $component (keys %{$s_p{$suite}}) {
		$tot += scalar keys %{$s_p{$suite}{$component}};
	    }
	}
    }
    $p->target($tot) if $p;
    my $done_archs = 0;
    # parse packages files
    for my $suite (keys %s_p) {
	my $pkgs = 0;
	for my $component (keys %{$s_p{$suite}}) {
	    my @archs = keys %{$s_p{$suite}{$component}};
	    if (grep {$_ eq 'source'} @archs) {
		@archs = ('source',grep {$_ ne 'source'} @archs);
	    }
	    for my $arch (@archs) {
		my $pfh =  open_compressed_file($s_p{$suite}{$component}{$arch}) or
		    die "Unable to open $s_p{$suite}{$component}{$arch} for reading: $!";
		local $_;
		local $/ = '';	# paragraph mode
		while (<$pfh>) {
		    my %pkg;
		    for my $field (qw(Package Maintainer Version Source)) {
			/^\Q$field\E: (.*)/m;
			$pkg{$field} = $1;
		    }
		    next unless defined $pkg{Package} and
			defined $pkg{Version};
                    $pkg{suite} = $suite;
                    $pkg{arch} = $arch;
                    $pkg{component} = $component;
		    $callback->(%pkg);
		}
                $p->update(++$done_archs) if $p;
	    }
	}
    }
    $p->remove() if $p;
}

=back

=cut

1;

__END__
# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:

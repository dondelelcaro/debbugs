# This module is part of debbugs, and is released
# under the terms of the GPL version 2, or any later
# version at your option.
# See the file README and COPYING for more information.
#
# [Other people have contributed to this file; their copyrights should
# go here too.]
# Copyright 2007 by Don Armstrong <don@donarmstrong.com>.

package Debbugs::Packages;

use warnings;
use strict;

use Debbugs::Config qw(:config :globals);

use base qw(Exporter);
use vars qw($VERSION @EXPORT_OK %EXPORT_TAGS @EXPORT);

BEGIN {
    $VERSION = 1.00;

     @EXPORT = ();
     %EXPORT_TAGS = (versions => [qw(getversions get_versions)],
		     mapping  => [qw(getpkgsrc getpkgcomponent getsrcpkgs),
				  qw(binarytosource sourcetobinary makesourceversions)
				 ],
		    );
     @EXPORT_OK = ();
     Exporter::export_ok_tags(qw(versions mapping));
     $EXPORT_TAGS{all} = [@EXPORT_OK];
}

use Fcntl qw(O_RDONLY);
use MLDBM qw(DB_File Storable);
use Storable qw(dclone);
use Params::Validate qw(validate_with :types);
use Debbugs::Common qw(make_list);

use List::Util qw(min max);

$MLDBM::DumpMeth = 'portable';
$MLDBM::RemoveTaint = 1;

=head1 NAME

Debbugs::Packages - debbugs binary/source package handling

=head1 DESCRIPTION

The Debbugs::Packages module provides support functions to map binary
packages to their corresponding source packages and vice versa. (This makes
sense for software distributions, where developers may work on a single
source package which produces several binary packages for use by users; it
may not make sense in other contexts.)

=head1 METHODS

=over 8

=item getpkgsrc

Returns a reference to a hash of binary package names to their corresponding
source package names.

=cut

our $_pkgsrc;
our $_pkgcomponent;
our $_srcpkg;
sub getpkgsrc {
    return $_pkgsrc if $_pkgsrc;
    return {} unless defined $Debbugs::Packages::gPackageSource;
    my %pkgsrc;
    my %pkgcomponent;
    my %srcpkg;

    open(MM,"$Debbugs::Packages::gPackageSource")
	or die("open $Debbugs::Packages::gPackageSource: $!");
    while(<MM>) {
	next unless m/^(\S+)\s+(\S+)\s+(\S.*\S)\s*$/;
	my ($bin,$cmp,$src)=($1,$2,$3);
	$bin =~ y/A-Z/a-z/;
	$pkgsrc{$bin}= $src;
	push @{$srcpkg{$src}}, $bin;
	$pkgcomponent{$bin}= $cmp;
    }
    close(MM);
    $_pkgsrc = \%pkgsrc;
    $_pkgcomponent = \%pkgcomponent;
    $_srcpkg = \%srcpkg;
    return $_pkgsrc;
}

=item getpkgcomponent

Returns a reference to a hash of binary package names to the component of
the archive containing those binary packages (e.g. "main", "contrib",
"non-free").

=cut

sub getpkgcomponent {
    return $_pkgcomponent if $_pkgcomponent;
    getpkgsrc();
    return $_pkgcomponent;
}

=item getsrcpkgs

Returns a list of the binary packages produced by a given source package.

=cut

sub getsrcpkgs {
    my $src = shift;
    getpkgsrc() if not defined $_srcpkg;
    return () if not defined $src or not exists $_srcpkg->{$src};
    return @{$_srcpkg->{$src}};
}

=item binarytosource

Returns a reference to the source package name and version pair
corresponding to a given binary package name, version, and architecture. If
undef is passed as the architecture, returns a list of references to all
possible pairs of source package names and versions for all architectures,
with any duplicates removed.

=cut

our %_binarytosource;
sub binarytosource {
    my ($binname, $binver, $binarch) = @_;

    # TODO: This gets hit a lot, especially from buggyversion() - probably
    # need an extra cache for speed here.
    return () unless defined $gBinarySourceMap;

    if (not tied %_binarytosource) {
	 tie %_binarytosource, MLDBM => $gBinarySourceMap, O_RDONLY or
	      die "Unable to open $gBinarySourceMap for reading";
    }

    # avoid autovivification
    my $binary = $_binarytosource{$binname};
    return () unless defined $binary;
    my %binary = %{$binary};
    if (exists $binary{$binver}) {
	 if (defined $binarch) {
	      my $src = $binary{$binver}{$binarch};
	      return () unless defined $src; # not on this arch
	      # Copy the data to avoid tiedness problems.
	      return dclone($src);
	 } else {
	      # Get (srcname, srcver) pairs for all architectures and
	      # remove any duplicates. This involves some slightly tricky
	      # multidimensional hashing; sorry. Fortunately there'll
	      # usually only be one pair returned.
	      my %uniq;
	      for my $ar (keys %{$binary{$binver}}) {
		   my $src = $binary{$binver}{$ar};
		   next unless defined $src;
		   $uniq{$src->[0]}{$src->[1]} = 1;
	      }
	      my @uniq;
	      for my $sn (sort keys %uniq) {
		   push @uniq, [$sn, $_] for sort keys %{$uniq{$sn}};
	      }
	      return @uniq;
	 }
    }

    # No $gBinarySourceMap, or it didn't have an entry for this name and
    # version.
    return ();
}

=item sourcetobinary

Returns a list of references to triplets of binary package names, versions,
and architectures corresponding to a given source package name and version.
If the given source package name and version cannot be found in the database
but the source package name is in the unversioned package-to-source map
file, then a reference to a binary package name and version pair will be
returned, without the architecture.

=cut

our %_sourcetobinary;
sub sourcetobinary {
    my ($srcname, $srcver) = @_;

    if (not tied %_sourcetobinary) {
	 tie %_sourcetobinary, MLDBM => $gSourceBinaryMap, O_RDONLY or
	      die "Unable top open $gSourceBinaryMap for reading";
    }



    # avoid autovivification
    my $source = $_sourcetobinary{$srcname};
    return () unless defined $source;
    my %source = %{$source};
    if (exists $source{$srcver}) {
	 my $bin = $source{$srcver};
	 return () unless defined $bin;
	 return @$bin;
    }
    # No $gSourceBinaryMap, or it didn't have an entry for this name and
    # version. Try $gPackageSource (unversioned) instead.
    my @srcpkgs = getsrcpkgs($srcname);
    return map [$_, $srcver], @srcpkgs;
}

=item getversions

Returns versions of the package in a distribution at a specific
architecture

=cut

sub getversions {
    my ($pkg, $dist, $arch) = @_;
    return get_versions(package=>$pkg,
			dist => $dist,
			defined $arch ? (arch => $arch):(),
		       );
}



=head2 get_versions

     get_versions(package=>'foopkg',
                  dist => 'unstable',
                  arch => 'i386',
                 );

Returns a list of the versions of package in the distributions and
architectures listed. This routine only returns unique values.

=over

=item package -- package to return list of versions

=item dist -- distribution (unstable, stable, testing); can be an
arrayref

=item arch -- architecture (i386, source, ...); can be an arrayref

=item time -- returns a version=>time hash at which the newest package
matching this version was uploaded

=item source -- returns source/version instead of just versions

=item no_source_arch -- discards the source architecture when arch is
not passed. [Used for finding the versions of binary packages only.]
Defaults to 0, which does not discard the source architecture. (This
may change in the future, so if you care, please code accordingly.)

=item return_archs -- returns a version=>[archs] hash indicating which
architectures are at which versions.

=back

When called in scalar context, this function will return hashrefs or
arrayrefs as appropriate, in list context, it will return paired lists
or unpaired lists as appropriate.

=cut

our %_versions;
our %_versions_time;

sub get_versions{
     my %param = validate_with(params => \@_,
				spec   => {package => {type => SCALAR|ARRAYREF,
						      },
					   dist    => {type => SCALAR|ARRAYREF,
						       default => 'unstable',
						      },
					   arch    => {type => SCALAR|ARRAYREF,
						       optional => 1,
						      },
					   time    => {type    => BOOLEAN,
						       default => 0,
						      },
					   source  => {type    => BOOLEAN,
						       default => 0,
						      },
					   no_source_arch => {type => BOOLEAN,
							      default => 0,
							     },
					   return_archs => {type => BOOLEAN,
							    default => 0,
							   },
					  },
			       );
     my $versions;
     if ($param{time}) {
	  return () if not defined $gVersionTimeIndex;
	  unless (tied %_versions_time) {
	       tie %_versions_time, 'MLDBM', $gVersionTimeIndex, O_RDONLY
		    or die "can't open versions index $gVersionTimeIndex: $!";
	  }
	  $versions = \%_versions_time;
     }
     else {
	  return () if not defined $gVersionIndex;
	  unless (tied %_versions) {
	       tie %_versions, 'MLDBM', $gVersionIndex, O_RDONLY
		    or die "can't open versions index $gVersionIndex: $!";
	  }
	  $versions = \%_versions;
     }
     my %versions;
     for my $package (make_list($param{package})) {
	  my $version = $versions->{$package};
	  next unless defined $version;
	  for my $dist (make_list($param{dist})) {
	       for my $arch (exists $param{arch}?
			     make_list($param{arch}):
			     (grep {not $param{no_source_arch} or
					 $_ ne 'source'
			       } keys %{$version->{$dist}})) {
		    next unless defined $version->{$dist}{$arch};
		    for my $ver (ref $version->{$dist}{$arch} ?
				 keys %{$version->{$dist}{$arch}} :
				 $version->{$dist}{$arch}
				) {
			 my $f_ver = $ver;
			 if ($param{source}) {
			      ($f_ver) = makesourceversions($package,$arch,$ver);
			      next unless defined $f_ver;
			 }
			 if ($param{time}) {
			      $versions{$f_ver} = max($versions{$f_ver}||0,$version->{$dist}{$arch}{$ver});
			 }
			 else {
			      push @{$versions{$f_ver}},$arch;
			 }
		    }
	       }
	  }
     }
     if ($param{time} or $param{return_archs}) {
	  return wantarray?%versions :\%versions;
     }
     return wantarray?keys %versions :[keys %versions];
}


=item makesourceversions

     @{$cgi_var{found}} = makesourceversions($cgi_var{package},undef,@{$cgi_var{found}});

Canonicalize versions into source versions, which have an explicitly
named source package. This is used to cope with source packages whose
names have changed during their history, and with cases where source
version numbers differ from binary version numbers.

=cut

our %_sourceversioncache = ();
sub makesourceversions {
    my $pkg = shift;
    my $arch = shift;
    my %sourceversions;
    die "Package $pkg is multiple packages; split on , and call makesourceversions multiple times"
	 if $pkg =~ /,/;

    for my $version (@_) {
        if ($version =~ m[/]) {
            # Already a source version.
            $sourceversions{$version} = 1;
        } else {
            my $cachearch = (defined $arch) ? $arch : '';
            my $cachekey = "$pkg/$cachearch/$version";
            if (exists($_sourceversioncache{$cachekey})) {
                for my $v (@{$_sourceversioncache{$cachekey}}) {
		    $sourceversions{$v} = 1;
		}
                next;
            }

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
                } elsif (getsrcpkgs($pkg)) {
                    # If we're looking at a source package that doesn't have
                    # a binary of the same name, just try the same version.
                    @srcinfo = ([$pkg, $version]);
                } else {
                    next;
                }
            }
            $sourceversions{"$_->[0]/$_->[1]"} = 1 foreach @srcinfo;
            $_sourceversioncache{$cachekey} = [ map { "$_->[0]/$_->[1]" } @srcinfo ];
        }
    }

    return sort keys %sourceversions;
}



=back

=cut

1;

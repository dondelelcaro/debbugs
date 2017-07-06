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

use Exporter qw(import);
use vars qw($VERSION @EXPORT_OK %EXPORT_TAGS @EXPORT);

use Carp;

use Debbugs::Config qw(:config :globals);

BEGIN {
    $VERSION = 1.00;

     @EXPORT = ();
     %EXPORT_TAGS = (versions => [qw(getversions get_versions make_source_versions)],
		     mapping  => [qw(getpkgsrc getpkgcomponent getsrcpkgs),
				  qw(binary_to_source sourcetobinary makesourceversions)
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
use Debbugs::Common qw(make_list globify_scalar sort_versions);

use List::AllUtils qw(min max);

use IO::File;

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

=head2 getpkgsrc

Returns a reference to a hash of binary package names to their corresponding
source package names.

=cut

our $_pkgsrc;
our $_pkgcomponent;
our $_srcpkg;
sub getpkgsrc {
    return $_pkgsrc if $_pkgsrc;
    return {} unless defined $config{package_source} and
	length $config{package_source};
    my %pkgsrc;
    my %pkgcomponent;
    my %srcpkg;

    my $fh = IO::File->new($config{package_source},'r')
	or croak("Unable to open $config{package_source} for reading: $!");
    while(<$fh>) {
	next unless m/^(\S+)\s+(\S+)\s+(\S.*\S)\s*$/;
	my ($bin,$cmp,$src)=($1,$2,$3);
	$bin = lc($bin);
	$pkgsrc{$bin}= $src;
	push @{$srcpkg{$src}}, $bin;
	$pkgcomponent{$bin}= $cmp;
    }
    close($fh);
    $_pkgsrc = \%pkgsrc;
    $_pkgcomponent = \%pkgcomponent;
    $_srcpkg = \%srcpkg;
    return $_pkgsrc;
}

=head2 getpkgcomponent

Returns a reference to a hash of binary package names to the component of
the archive containing those binary packages (e.g. "main", "contrib",
"non-free").

=cut

sub getpkgcomponent {
    return $_pkgcomponent if $_pkgcomponent;
    getpkgsrc();
    return $_pkgcomponent;
}

=head2 getsrcpkgs

Returns a list of the binary packages produced by a given source package.

=cut

sub getsrcpkgs {
    my $src = shift;
    getpkgsrc() if not defined $_srcpkg;
    return () if not defined $src or not exists $_srcpkg->{$src};
    return @{$_srcpkg->{$src}};
}

=head2 binary_to_source

     binary_to_source(package => 'foo',
                      version => '1.2.3',
                      arch    => 'i386');


Turn a binary package (at optional version in optional architecture)
into a single (or set) of source packages (optionally) with associated
versions.

By default, in LIST context, returns a LIST of array refs of source
package, source version pairs corresponding to the binary package(s),
arch(s), and verion(s) passed.

In SCALAR context, only the corresponding source packages are
returned, concatenated with ', ' if necessary.

If no source can be found, returns undef in scalar context, or the
empty list in list context.

=over

=item binary -- binary package name(s) as a SCALAR or ARRAYREF

=item version -- binary package version(s) as a SCALAR or ARRAYREF;
optional, defaults to all versions.

=item arch -- binary package architecture(s) as a SCALAR or ARRAYREF;
optional, defaults to all architectures.

=item source_only -- return only the source name (forced on if in
SCALAR context), defaults to false.

=item scalar_only -- return a scalar only (forced true if in SCALAR
context, also causes source_only to be true), defaults to false.

=item cache -- optional HASHREF to be used to cache results of
binary_to_source.

=back

=cut

# the two global variables below are used to tie the source maps; we
# probably should be retying them in long lived processes.
our %_binarytosource;
our %_sourcetobinary;
sub binary_to_source{
    my %param = validate_with(params => \@_,
			      spec   => {binary => {type => SCALAR|ARRAYREF,
						    },
					 version => {type => SCALAR|ARRAYREF,
						     optional => 1,
						    },
					 arch    => {type => SCALAR|ARRAYREF,
						     optional => 1,
						    },
					 source_only => {default => 0,
							},
					 scalar_only => {default => 0,
							},
					 cache => {type => HASHREF,
						   default => {},
						  },
					},
			     );

    # TODO: This gets hit a lot, especially from buggyversion() - probably
    # need an extra cache for speed here.
    return () unless defined $gBinarySourceMap;

    if ($param{scalar_only} or not wantarray) {
	$param{source_only} = 1;
	$param{scalar_only} = 1;
    }

    my @source;
    my @binaries = grep {defined $_} make_list(exists $param{binary}?$param{binary}:[]);
    my @versions = grep {defined $_} make_list(exists $param{version}?$param{version}:[]);
    my @archs = grep {defined $_} make_list(exists $param{arch}?$param{arch}:[]);
    return () unless @binaries;
    my $cache_key = join("\1",
			 join("\0",@binaries),
			 join("\0",@versions),
			 join("\0",@archs),
			 join("\0",@param{qw(source_only scalar_only)}));
    if (exists $param{cache}{$cache_key}) {
	return $param{scalar_only} ? $param{cache}{$cache_key}[0]:
	    @{$param{cache}{$cache_key}};
    }
    for my $binary (@binaries) {
	if ($binary =~ m/^src:(.+)$/) {
	    push @source,[$1,''];
	    next;
	}
	if (not tied %_binarytosource) {
	    tie %_binarytosource, MLDBM => $config{binary_source_map}, O_RDONLY or
		die "Unable to open $config{binary_source_map} for reading";
	}
	# avoid autovivification
	my $bin = $_binarytosource{$binary};
	next unless defined $bin;
	if (not @versions) {
	    for my $ver (keys %{$bin}) {
		for my $ar (keys %{$bin->{$ver}}) {
		    my $src = $bin->{$ver}{$ar};
		    next unless defined $src;
		    push @source,[$src->[0],$src->[1]];
		}
	    }
	}
	else {
	    for my $version (@versions) {
		next unless exists $bin->{$version};
		if (exists $bin->{$version}{all}) {
		    push @source,dclone($bin->{$version}{all});
		    next;
		}
		my @t_archs;
		if (@archs) {
		    @t_archs = @archs;
		}
		else {
		    @t_archs = keys %{$bin->{$version}};
		}
		for my $arch (@t_archs) {
		    push @source,dclone($bin->{$version}{$arch}) if
			exists $bin->{$version}{$arch};
		}
	    }
	}
    }

    if (not @source and not @versions and not @archs) {
	# ok, we haven't found any results at all. If we weren't given
	# a specific version and architecture, then we should try
	# really hard to figure out the right source

	# if any the packages we've been given are a valid source
	# package name, and there's no binary of the same name (we got
	# here, so there isn't), return it.

	if (not tied %_sourcetobinary) {
	    tie %_sourcetobinary, MLDBM => $config{source_binary_map}, O_RDONLY or
		die "Unable top open $gSourceBinaryMap for reading";
	}
	for my $maybe_sourcepkg (@binaries) {
	    if (exists $_sourcetobinary{$maybe_sourcepkg}) {
		push @source,[$maybe_sourcepkg,$_] for keys %{$_sourcetobinary{$maybe_sourcepkg}};
	    }
	}
	# if @source is still empty here, it's probably a non-existant
	# source package, so don't return anything.
    }

    my @result;

    if ($param{source_only}) {
	my %uniq;
	for my $s (@source) {
	    # we shouldn't need to do this, but do this temporarily to
	    # stop the warning.
	    next unless defined $s->[0];
	    $uniq{$s->[0]} = 1;
	}
	@result = sort keys %uniq;
	if ($param{scalar_only}) {
	    @result = join(', ',@result);
	}
    }
    else {
	my %uniq;
	for my $s (@source) {
	    $uniq{$s->[0]}{$s->[1]} = 1;
	}
	for my $sn (sort keys %uniq) {
	    push @result, [$sn, $_] for sort keys %{$uniq{$sn}};
	}
    }

    # No $gBinarySourceMap, or it didn't have an entry for this name and
    # version.
    $param{cache}{$cache_key} = \@result;
    return $param{scalar_only} ? $result[0] : @result;
}

=head2 sourcetobinary

Returns a list of references to triplets of binary package names, versions,
and architectures corresponding to a given source package name and version.
If the given source package name and version cannot be found in the database
but the source package name is in the unversioned package-to-source map
file, then a reference to a binary package name and version pair will be
returned, without the architecture.

=cut

sub sourcetobinary {
    my ($srcname, $srcver) = @_;

    if (not tied %_sourcetobinary) {
	tie %_sourcetobinary, MLDBM => $config{source_binary_map}, O_RDONLY or
	    die "Unable top open $config{source_binary_map} for reading";
    }



    # avoid autovivification
    my $source = $_sourcetobinary{$srcname};
    return () unless defined $source;
    if (exists $source->{$srcver}) {
	 my $bin = $source->{$srcver};
	 return () unless defined $bin;
	 return @$bin;
    }
    # No $gSourceBinaryMap, or it didn't have an entry for this name and
    # version. Try $gPackageSource (unversioned) instead.
    my @srcpkgs = getsrcpkgs($srcname);
    return map [$_, $srcver], @srcpkgs;
}

=head2 getversions

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

=item largest_source_version_only -- if there is more than one source
version in a particular distribution, discards all versions but the
largest in that distribution. Defaults to 1, as this used to be the
way that the Debian archive worked.

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
					   largest_source_version_only => {type => BOOLEAN,
								       default => 1,
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
	  my $source_only = 0;
	  if ($package =~ s/^src://) {
	       $source_only = 1;
	  }
	  my $version = $versions->{$package};
	  next unless defined $version;
	  for my $dist (make_list($param{dist})) {
	       for my $arch (exists $param{arch}?
			     make_list($param{arch}):
			     (grep {not $param{no_source_arch} or
					$_ ne 'source'
				    } $source_only?'source':keys %{$version->{$dist}})) {
		    next unless defined $version->{$dist}{$arch};
		    my @vers = ref $version->{$dist}{$arch} eq 'HASH' ?
			keys %{$version->{$dist}{$arch}} :
			    make_list($version->{$dist}{$arch});
		    if ($param{largest_source_version_only} and
			$arch eq 'source' and @vers > 1) {
			# order the versions, then pick the biggest version number
			@vers = sort_versions(@vers);
			@vers = $vers[-1];
		    }
		    for my $ver (@vers) {
			 my $f_ver = $ver;
			 if ($param{source}) {
			      ($f_ver) = make_source_versions(package => $package,
							      arch => $arch,
							      versions => $ver);
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


=head2 makesourceversions

     @{$cgi_var{found}} = makesourceversions($cgi_var{package},undef,@{$cgi_var{found}});

Canonicalize versions into source versions, which have an explicitly
named source package. This is used to cope with source packages whose
names have changed during their history, and with cases where source
version numbers differ from binary version numbers.

=cut

our %_sourceversioncache = ();
sub makesourceversions {
    my ($package,$arch,@versions) = @_;
    die "Package $package is multiple packages; split on , and call makesourceversions multiple times"
	 if $package =~ /,/;
    return make_source_versions(package => $package,
				(defined $arch)?(arch => $arch):(),
				versions => \@versions
			       );
}

=head2 make_source_versions

     make_source_versions(package => 'foo',
                          arch    => 'source',
                          versions => '0.1.1',
                          guess_source => 1,
                          warnings => \$warnings,
                         );

An extended version of makesourceversions (which calls this function
internally) that allows for multiple packages, architectures, and
outputs warnings and debugging information to provided SCALARREFs or
HANDLEs.

The guess_source option determines whether the source package is
guessed at if there is no obviously correct package. Things that use
this function for non-transient output should set this to false,
things that use it for transient output can set this to true.
Currently it defaults to true, but that is not a sane option.


=cut

sub make_source_versions {
    my %param = validate_with(params => \@_,
			      spec   => {package => {type => SCALAR|ARRAYREF,
						    },
					 arch    => {type => SCALAR|ARRAYREF|UNDEF,
						     default => ''
						    },
					 versions => {type => SCALAR|ARRAYREF,
						      default => [],
						     },
					 guess_source => {type => BOOLEAN,
							  default => 1,
							 },
					 source_version_cache => {type => HASHREF,
								  optional => 1,
								 },
					 debug    => {type => SCALARREF|HANDLE,
						      optional => 1,
						     },
					 warnings => {type => SCALARREF|HANDLE,
						      optional => 1,
						     },
					},
			     );
    my ($warnings) = globify_scalar(exists $param{warnings}?$param{warnings}:undef);

    my @packages = grep {defined $_ and length $_ } make_list($param{package});
    my @archs    = grep {defined $_ } make_list ($param{arch});
    if (not @archs) {
	push @archs, '';
    }
    if (not exists $param{source_version_cache}) {
	$param{source_version_cache} = \%_sourceversioncache;
    }
    if (grep {/,/} make_list($param{package})) {
	croak "Package names contain ,; split on /,/ and call make_source_versions with an arrayref of packages"
    }
    my %sourceversions;
    for my $version (make_list($param{versions})) {
        if ($version =~ m{(.+)/([^/]+)$}) {
	    # Already a source version.
            $sourceversions{$version} = 1;
	    next unless exists $param{warnings};
	    # check to see if this source version is even possible
	    my @bin_versions = sourcetobinary($1,$2);
	    if (not @bin_versions or
		@{$bin_versions[0]} != 3) {
		print {$warnings} "The source $1 and version $2 do not appear to match any binary packages\n";
	    }
        } else {
	    if (not @packages) {
		croak "You must provide at least one package if the versions are not fully qualified";
	    }
	    for my $pkg (@packages) {
		if ($pkg =~ /^src:(.+)/) {
		    $sourceversions{"$1/$version"} = 1;
		    next unless exists $param{warnings};
		    # check to see if this source version is even possible
		    my @bin_versions = sourcetobinary($1,$version);
		    if (not @bin_versions or
			@{$bin_versions[0]} != 3) {
			print {$warnings} "The source '$1' and version '$version' do not appear to match any binary packages\n";
		    }
		    next;
		}
		for my $arch (@archs) {
		    my $cachearch = (defined $arch) ? $arch : '';
		    my $cachekey = "$pkg/$cachearch/$version";
		    if (exists($param{source_version_cache}{$cachekey})) {
			for my $v (@{$param{source_version_cache}{$cachekey}}) {
			    $sourceversions{$v} = 1;
			}
			next;
		    }
		    elsif ($param{guess_source} and
			   exists$param{source_version_cache}{$cachekey.'/guess'}) {
			for my $v (@{$param{source_version_cache}{$cachekey.'/guess'}}) {
			    $sourceversions{$v} = 1;
			}
			next;
		    }
		    my @srcinfo = binary_to_source(binary => $pkg,
						   version => $version,
						   length($arch)?(arch    => $arch):());
		    if (not @srcinfo) {
			# We don't have explicit information about the
			# binary-to-source mapping for this version
			# (yet).
			print {$warnings} "There is no source info for the package '$pkg' at version '$version' with architecture '$arch'\n";
			if ($param{guess_source}) {
			    # Lets guess it
			    my $pkgsrc = getpkgsrc();
			    if (exists $pkgsrc->{$pkg}) {
				@srcinfo = ([$pkgsrc->{$pkg}, $version]);
			    } elsif (getsrcpkgs($pkg)) {
				# If we're looking at a source package
				# that doesn't have a binary of the
				# same name, just try the same
				# version.
				@srcinfo = ([$pkg, $version]);
			    } else {
				next;
			    }
			    # store guesses in a slightly different location
			    $param{source_version_cache}{$cachekey.'/guess'} = [ map { "$_->[0]/$_->[1]" } @srcinfo ];
			}
		    }
		    else {
			# only store this if we didn't have to guess it
			$param{source_version_cache}{$cachekey} = [ map { "$_->[0]/$_->[1]" } @srcinfo ];
		    }
		    $sourceversions{"$_->[0]/$_->[1]"} = 1 foreach @srcinfo;
		}
	    }
        }
    }
    return sort keys %sourceversions;
}



1;

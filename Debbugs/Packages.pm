package Debbugs::Packages;

use strict;

use Debbugs::Config qw(:config :globals);

use Exporter ();
use vars qw($VERSION @ISA @EXPORT);

BEGIN {
    $VERSION = 1.00;

    @ISA = qw(Exporter);
    @EXPORT = qw(getpkgsrc getpkgcomponent getsrcpkgs
		 binarytosource sourcetobinary getversions);
}

use Fcntl qw(O_RDONLY);
use MLDBM qw(DB_File);

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

my $_pkgsrc;
my $_pkgcomponent;
sub getpkgsrc {
    return $_pkgsrc if $_pkgsrc;
    return {} unless defined $Debbugs::Packages::gPackageSource;
    my %pkgsrc;
    my %pkgcomponent;

    open(MM,"$Debbugs::Packages::gPackageSource")
	or die("open $Debbugs::Packages::gPackageSource: $!");
    while(<MM>) {
	next unless m/^(\S+)\s+(\S+)\s+(\S.*\S)\s*$/;
	my ($bin,$cmp,$src)=($1,$2,$3);
	$bin =~ y/A-Z/a-z/;
	$pkgsrc{$bin}= $src;
	$pkgcomponent{$bin}= $cmp;
    }
    close(MM);
    $_pkgsrc = \%pkgsrc;
    $_pkgcomponent = \%pkgcomponent;
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
    return () if !$src;
    my %pkgsrc = %{getpkgsrc()};
    my @pkgs;
    foreach ( keys %pkgsrc ) {
	push @pkgs, $_ if $pkgsrc{$_} eq $src;
    }
    return @pkgs;
}

=item binarytosource

Returns a reference to the source package name and version pair
corresponding to a given binary package name, version, and architecture. If
undef is passed as the architecture, returns a list of references to all
possible pairs of source package names and versions for all architectures,
with any duplicates removed.

=cut

my %_binarytosource;
sub binarytosource {
    my ($binname, $binver, $binarch) = @_;

    # TODO: This gets hit a lot, especially from buggyversion() - probably
    # need an extra cache for speed here.

    if (tied %_binarytosource or
	    tie %_binarytosource, 'MLDBM',
		$Debbugs::Packages::gBinarySourceMap, O_RDONLY) {
	# avoid autovivification
	if (exists $_binarytosource{$binname} and
		exists $_binarytosource{$binname}{$binver}) {
	    if (defined $binarch) {
		my $src = $_binarytosource{$binname}{$binver}{$binarch};
		return () unless defined $src; # not on this arch
		# Copy the data to avoid tiedness problems.
		return [@$src];
	    } else {
		# Get (srcname, srcver) pairs for all architectures and
		# remove any duplicates. This involves some slightly tricky
		# multidimensional hashing; sorry. Fortunately there'll
		# usually only be one pair returned.
		my %uniq;
		for my $ar (keys %{$_binarytosource{$binname}{$binver}}) {
		    my $src = $_binarytosource{$binname}{$binver}{$ar};
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

my %_sourcetobinary;
sub sourcetobinary {
    my ($srcname, $srcver) = @_;

    if (tied %_sourcetobinary or
	    tie %_sourcetobinary, 'MLDBM',
		$Debbugs::Packages::gSourceBinaryMap, O_RDONLY) {
	# avoid autovivification
	if (exists $_sourcetobinary{$srcname} and
		exists $_sourcetobinary{$srcname}{$srcver}) {
	    my $bin = $_sourcetobinary{$srcname}{$srcver};
	    return () unless defined $bin;
	    # Copy the data to avoid tiedness problems.
	    return @$bin;
	}
    }

    # No $gSourceBinaryMap, or it didn't have an entry for this name and
    # version. Try $gPackageSource (unversioned) instead.
    my @srcpkgs = getsrcpkgs($srcname);
    return map [$_, $srcver], @srcpkgs;
}

=item getversions

Returns versions of the package in distribution at a specific architecture

=cut

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
        if (%uniq) {
            return keys %uniq;
        } elsif (exists $_versions{$pkg}{$dist}{source}) {
            # Maybe this is actually a source package with no corresponding
            # binaries?
            return $_versions{$pkg}{$dist}{source};
        } else {
            return ();
        }
    }
}



=back

=cut

1;

package Debbugs::Versions::Dpkg;

use strict;

=head1 NAME

Debbugs::Versions::Dpkg - pure-Perl dpkg-style version comparison

=head1 DESCRIPTION

The Debbugs::Versions::Dpkg module provides pure-Perl routines to compare
dpkg-style version numbers, as used in Debian packages. If you have the
libapt-pkg Perl bindings available (Debian package libapt-pkg-perl), they
may offer better performance.

=head1 METHODS

=over 8

=cut

sub parseversion ($)
{
    my $ver = shift;
    my %verhash;
    if ($ver =~ /:/)
    {
	$ver =~ /^(\d+):(.+)/ or die "bad version number '$ver'";
	$verhash{epoch} = $1;
	$ver = $2;
    }
    else
    {
	$verhash{epoch} = 0;
    }
    if ($ver =~ /(.+)-(.+)$/)
    {
	$verhash{version} = $1;
	$verhash{revision} = $2;
    }
    else
    {
	$verhash{version} = $ver;
	$verhash{revision} = 0;
    }
    return %verhash;
}

sub verrevcmp ($$)
{
    my ($val, $ref) = @_;
    for (;;)
    {
	$val =~ s/^(\D*)//;
	my $alphaval = $1;
	$ref =~ s/^(\D*)//;
	my $alpharef = $1;
	if (length $alphaval or length $alpharef)
	{
	    my @avsplit = split //, $alphaval;
	    my @arsplit = split //, $alpharef;
	    my ($av, $ar) = (0, 0);
	    while ($av < @avsplit and $ar < @arsplit)
	    {
		my ($v, $r) = (ord $avsplit[$av], ord $arsplit[$ar]);
		$v += 256 unless chr($v) =~ /[A-Za-z]/;
		$r += 256 unless chr($r) =~ /[A-Za-z]/;
		return $v <=> $r if $v != $r;
		$av++;
		$ar++;
	    }
	    return 1 if $av < @avsplit;
	    return -1 if $ar < @arsplit;
	}

	return 0 unless length $val and length $ref;

	$val =~ s/^(\d*)//;
	my $numval = $1;
	$ref =~ s/^(\d*)//;
	my $numref = $1;
	return $numval <=> $numref if $numval != $numref;
    }
}

=item vercmp

Compare the two arguments as dpkg-style version numbers. Returns -1 if the
first argument represents a lower version number than the second, 1 if the
first argument represents a higher version number than the second, and 0 if
the two arguments represent equal version numbers.

=cut

sub vercmp ($$)
{
    my %version = parseversion $_[0];
    my %refversion = parseversion $_[1];
    return 1 if $version{epoch} > $refversion{epoch};
    return -1 if $version{epoch} < $refversion{epoch};
    my $r = verrevcmp $version{version}, $refversion{version};
    return $r if $r;
    return verrevcmp $version{revision}, $refversion{revision};
}

=back

=head1 BUGS

Version numbers containing the C<~> character, used for pre-releases of
packages, are not yet supported.

=head1 AUTHOR

Colin Watson E<lt>cjwatson@debian.orgE<gt>, based on the implementation in
C<dpkg/lib/vercmp.c> by Ian Jackson and others.

=cut

1;

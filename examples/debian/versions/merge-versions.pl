#!/usr/bin/perl
# merge-versions.pl merges multiple .versions files from dak
# and is released under the terms of the GNU GPL version 3, or any
# later version, at your option. See the file README and COPYING for
# more information.
# Copyright 2017 by Don Armstrong <don@donarmstrong.com>.


use warnings;
use strict;

use Getopt::Long;
use Pod::Usage;

=head1 NAME

merge-versions.pl - merges multiple .versions files from dak

=head1 SYNOPSIS

merge-versions.pl [options]

 Options:
   --debug, -d debugging level (Default 0)
   --help, -h display this help
   --man, -m display manual

=head1 OPTIONS

=over

=item B<--debug, -d>

Debug verbosity. (Default 0)

=item B<--help, -h>

Display brief usage information.

=item B<--man, -m>

Display this manual.

=back

=head1 EXAMPLES

merge-versions.pl

=cut


use vars qw($DEBUG);

my %options = (debug           => 0,
               help            => 0,
               man             => 0,
              );

GetOptions(\%options,
           'debug|d+','help|h|?','man|m');

pod2usage() if $options{help};
pod2usage({verbose=>2}) if $options{man};

$DEBUG = $options{debug};

my @USAGE_ERRORS;
if (not @ARGV) {
    push @USAGE_ERRORS,"You must provide at least one .versions file";
}

pod2usage(join("\n",@USAGE_ERRORS)) if @USAGE_ERRORS;


use strict;
use File::Find;
use Debbugs::Versions;
use Debbugs::Versions::Dpkg;
use Data::Printer;

my $tree = Debbugs::Versions->new(\&Debbugs::Versions::Dpkg::vercmp);
for my $ver_file (@ARGV) {
    open(my $fh,'<',$ver_file) or
	die "Unable to open $ver_file for reading: $!";
    my $pkg;
    my $versions = '';
    while (<$fh>) {
	my ($s_pkg,$ver) = $_ =~/^(\S+)\s*\(([^\)]+)\)/ or next;
	$pkg = $s_pkg unless defined $pkg;
	$versions .= ' ' if length $versions;
	$versions .= $ver;
    }
    $versions .= "\n";
    open (my $v_fh,'<',\$versions);
    $tree->load($v_fh);
    p $tree->{parent};
    $tree->save(*STDOUT);
    close($v_fh);
}




__END__
# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:


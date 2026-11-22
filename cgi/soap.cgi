#!/usr/bin/perl -T

use warnings;
use strict;

# if we're running out of git, we want to use the git base directory as the
# first INC directory. If you're not running out of git, don't do that.
use File::Basename qw(dirname);
use Cwd qw(abs_path);
our $debbugs_dir;
BEGIN {
    $debbugs_dir =
	abs_path(dirname(abs_path(__FILE__)) . '/../');
    # clear the taint; we'll assume that the absolute path to __FILE__ is the
    # right path if there's a .git directory there
    ($debbugs_dir) = $debbugs_dir =~ /([[:print:]]+)/;
    if (defined $debbugs_dir and
	-d $debbugs_dir . '/.git/') {
    } else {
	undef $debbugs_dir;
    }
    # if the first directory in @INC is not an absolute directory, assume that
    # someone has overridden us via -I.
    if ($INC[0] !~ /^\//) {
    }
}
use if defined $debbugs_dir, lib => $debbugs_dir;

#use SOAP::Transport::HTTP;

use Debbugs::SOAP::Server;

# Work around stupid soap bug on line 411
if (not exists $ENV{EXPECT}) {
     $ENV{EXPECT} = '';
}

my $soap = Debbugs::SOAP::Server
#my $soap = SOAP::Transport::HTTP::CGI
    -> dispatch_to('Debbugs::SOAP');
#$soap->serializer()->soapversion(1.2);
# soapy is stupid, and is using the 1999 schema; override it.
*SOAP::XMLSchema1999::Serializer::as_base64Binary = \&SOAP::XMLSchema2001::Serializer::as_base64Binary;
*SOAP::Serializer::as_anyURI       = \&SOAP::XMLSchema2001::Serializer::as_string;
# do this twice to avoid the warning if the serializer doesn't get
# used
*SOAP::XMLSchema1999::Serializer::as_base64Binary = \&SOAP::XMLSchema2001::Serializer::as_base64Binary;
*SOAP::Serializer::as_anyURI       = \&SOAP::XMLSchema2001::Serializer::as_string;
# to work around the serializer improperly using date/time stuff
# (Nothing in Debbugs should be looked at as if it were date/time) we
# kill off all of the date/time related bits in the serializer.
my $typelookup = $soap->serializer()->{_typelookup};
for my $key (keys %{$typelookup}) {
    if (defined $key and
        $key =~ /Month|Day|Year|date|time|duration/i
       ) {
        # set the sub to always return 0
        $typelookup->{$key}[1] = sub { 0 };
    }
}

our $warnings = '';
eval {
    # Ignore stupid warning because elements (hashes) can't start with
    # numbers
    local $SIG{__WARN__} = sub {$warnings .= $_[0] unless $_[0] =~ /Cannot encode unnamed element/};
    $soap->handle;
};
die $@ if $@;
warn $warnings if length $warnings;

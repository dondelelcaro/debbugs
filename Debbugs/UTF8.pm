# This module is part of debbugs, and is released
# under the terms of the GPL version 2, or any later
# version at your option.
# See the file README and COPYING for more information.
#
# Copyright 2013 by Don Armstrong <don@donarmstrong.com>.

package Debbugs::UTF8;

=head1 NAME

Debbugs::UTF8 -- Routines for handling conversion of charsets to UTF8

=head1 SYNOPSIS

use Debbugs::UTF8;


=head1 DESCRIPTION

This module contains routines which convert from various different
charsets to UTF8.

=head1 FUNCTIONS

=cut

use warnings;
use strict;
use vars qw($VERSION $DEBUG %EXPORT_TAGS @EXPORT_OK @EXPORT);
use base qw(Exporter);

BEGIN{
     $VERSION = 1.00;
     $DEBUG = 0 unless defined $DEBUG;

     %EXPORT_TAGS = (utf8   => [qw(encode_utf8_structure encode_utf8_safely),
                                qw(convert_to_utf8 decode_utf8_safely)],
                    );
     @EXPORT = (@{$EXPORT_TAGS{utf8}});
     @EXPORT_OK = ();
     Exporter::export_ok_tags(keys %EXPORT_TAGS);
     $EXPORT_TAGS{all} = [@EXPORT_OK];
}

use Carp;
$Carp::Verbose = 1;

use Encode qw(encode_utf8 is_utf8 decode decode_utf8);
use Text::Iconv;
use Storable qw(dclone);


=head1 UTF-8

These functions are exported with the :utf8 tag

=head2 encode_utf8_structure

     %newdata = encode_utf8_structure(%newdata);

Takes a complex data structure and encodes any strings with is_utf8
set into their constituent octets.

=cut

our $depth = 0;
sub encode_utf8_structure {
    ++$depth;
    my @ret;
    for my $_ (@_) {
	if (ref($_) eq 'HASH') {
	    push @ret, {encode_utf8_structure(%{$depth == 1 ? dclone($_):$_})};
	}
	elsif (ref($_) eq 'ARRAY') {
	    push @ret, [encode_utf8_structure(@{$depth == 1 ? dclone($_):$_})];
	}
	elsif (ref($_)) {
	    # we don't know how to handle non hash or non arrays
	    push @ret,$_;
	}
	else {
	    push @ret,encode_utf8_safely($_);
	}
    }
    --$depth;
    return @ret;
}

=head2 encode_utf8_safely

     $octets = encode_utf8_safely($string);

Given a $string, returns the octet equivalent of $string if $string is
in perl's internal encoding; otherwise returns $string.

Silently returns REFs without encoding them. [If you want to deeply
encode REFs, see encode_utf8_structure.]

=cut


sub encode_utf8_safely{
    my @ret;
    for my $r (@_) {
        if (not ref($r) and is_utf8($r)) {
	    $r = encode_utf8($r);
	}
	push @ret,$r;
    }
    return wantarray ? @ret : (@_ > 1 ? @ret : $ret[0]);
}

=head2 decode_utf8_safely

     $string = decode_utf8_safely($octets);

Given $octets in UTF8, returns the perl-internal equivalent of $octets
if $octets does not have is_utf8 set; otherwise returns $octets.

Silently returns REFs without encoding them.

=cut


sub decode_utf8_safely{
    my @ret;
    for my $r (@_) {
        if (not ref($r) and not is_utf8($r)) {
	    $r = decode_utf8($r);
	}
	push @ret, $r;
    }
    return wantarray ? @ret : (@_ > 1 ? @ret : $ret[0]);
}




=head2 convert_to_utf8

    $utf8 = convert_to_utf8("text","charset");

=cut

our %iconv_converters;

sub convert_to_utf8 {
    my ($data,$charset) = @_;
    if (is_utf8($data)) {
        cluck("utf8 flag is set when calling convert_to_utf8");
        return $data;
    }
    $charset = uc($charset//'UTF-8');
    if ($charset eq 'RAW') {
        croak("Charset must not be raw when calling convert_to_utf8");
    }
    if (not defined $iconv_converters{$charset}) {
        eval {
            $iconv_converters{$charset} = Text::Iconv->new($charset,"UTF-8") or
                die "Unable to create converter for '$charset'";
        };
        if ($@) {
            warn $@;
            # We weren't able to create the converter, so use Encode
            # instead
            return __fallback_convert_to_utf8($data,$charset);
        }
    }
    if (not defined $iconv_converters{$charset}) {
        warn "The converter for $charset wasn't created properly somehow!";
        return __fallback_convert_to_utf8($data,$charset);
    }
    my $converted_data = $iconv_converters{$charset}->convert($data);
    # if the conversion failed, retval will be undefined or perhaps
    # -1.
    my $retval = $iconv_converters{$charset}->retval();
    if (not defined $retval or
        $retval < 0
       ) {
        warn "failed to convert to utf8";
        # Fallback to encode, which will probably also fail.
        return __fallback_convert_to_utf8($data,$charset);
    }
    return decode("UTF-8",$converted_data);
}

# this returns data in perl's internal encoding
sub __fallback_convert_to_utf8 {
     my ($data, $charset) = @_;
     # raw data just gets returned (that's the charset WordDecorder
     # uses when it doesn't know what to do)
     return $data if $charset eq 'raw';
     if (not defined $charset and not is_utf8($data)) {
         warn ("Undefined charset, and string '$data' is not in perl's internal encoding");
         return $data;
     }
     # lets assume everything that doesn't have a charset is utf8
     $charset //= 'utf8';
     my $result;
     eval {
	 $result = decode($charset,$data);
     };
     if ($@) {
	  warn "Unable to decode charset; '$charset' and '$data': $@";
	  return $data;
     }
     return $result;
}



1;

__END__

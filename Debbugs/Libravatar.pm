# This module is part of debbugs, and is released
# under the terms of the GPL version 2, or any later version. See the
# file README and COPYING for more information.
# Copyright 2013 by Don Armstrong <don@donarmstrong.com>.

package Debbugs::Libravatar;

=head1 NAME

Debbugs::Libravatar -- Libravatar service handler (mod_perl)

=head1 SYNOPSIS

<Location /libravatar>
   SetHandler perl-script
   PerlResponseHandler Debbugs::Libravatar
</Location>

=head1 DESCRIPTION

Debbugs::Libravatar is a libravatar service handler which will serve
libravatar requests. It also contains utility routines which are used
by the libravatar.cgi script for those who do not have mod_perl.

=head1 BUGS

None known.

=cut

use warnings;
use strict;
use vars qw($VERSION $DEBUG %EXPORT_TAGS @EXPORT_OK @EXPORT);
use base qw(Exporter);

BEGIN{
     ($VERSION) = q$Revision$ =~ /^Revision:\s+([^\s+])/;
     $DEBUG = 0 unless defined $DEBUG;

     @EXPORT = ();
     %EXPORT_TAGS = (libravatar => [qw(cache_valid serve_cache retrieve_libravatar)]
		    );
     @EXPORT_OK = ();
     Exporter::export_ok_tags(keys %EXPORT_TAGS);
     $EXPORT_TAGS{all} = [@EXPORT_OK];
}

sub cache_valid{
    my ($cache_location) = @_;
    if (-e $cache_location) {
        if (time - (stat($cache_location))[9] < 60*60) {
            return 1;
        }
    }
    return 0;
}

=item retreive_libravatar

     $cache_location = retreive_libravatar(location => $cache_location,
                                           email => lc($param{email}),
                                          );

Returns the cache location where a specific avatar can be loaded. If
there isn't a matching avatar, or there is an error, returns undef.


=cut

sub retreive_libravatar{
    my %type_mapping =
        (jpeg => 'jpg',
         png => 'png',
         gif => 'png',
         tiff => 'png',
         tif => 'png',
         pjpeg => 'jpg',
         jpg => 'jpg'
        );
    my %param = @_;
    my $cache_location = $param{location};
    $cache_location =~ s/\.[^\.]+$//;
    my $uri = libravatar_url(email => $param{email},
                             default => 404,
                             size => 80);
    my $ua = LWP::UserAgent->new(agent => 'Debbugs libravatar service (not Mozilla)',
                                );
    $ua->from($config{maintainer});
    # if we don't get an avatar within 10 seconds, return so we don't
    # block forever
    $ua->timeout(10);
    # if the avatar is bigger than 30K, we don't want it either
    $ua->max_size(30*1024);
    my $r = $ua->get($uri);
    if (not $r->is_success()) {
        return undef;
    }
    my $aborted = $r->header('Client-Aborted');
    # if we exceeded max size, I'm not sure if we'll be successfull or
    # not, but regardless, there will be a Client-Aborted header. Stop
    # here if that header is defined.
    return undef if defined $aborted;
    my $type = $r->header('Content-Type');
    # if there's no content type, or it's not one we like, we won't
    # bother going further
    return undef if not defined $type;
    return undef if not $type =~ m{^image/([^/]+)$};
    my $dest_type = $type_mapping{$1};
    return undef if not defined $dest_type;
    # undo any content encoding
    $r->decode() or return undef;
    # ok, now we need to convert it from whatever it is into a format
    # that we actually like
    my ($temp_fh,$temp_fn) = tempfile() or
        return undef;
    eval {
        print {$temp_fh} $r->content() or
            die "Unable to print to temp file";
        close ($temp_fh);
        ### resize all images to 80x80 and strip comments out of them.
        ### If convert has a bug, it would be possible for this to be
        ### an attack vector, but hopefully minimizing the size above,
        ### and requiring proper mime types will minimize that
        ### slightly. Doing this will at least make it harder for
        ### malicious web images to harm our users
        system('convert','-resize','80x80',
               '-strip',
               $temp_fn,
               $cache_location.'.'.$dest_type) == 0 or
                   die "convert file failed";
        unlink($temp_fh);
    };
    if ($@) {
        unlink($cache_location.'.'.$dest_type) if -e $cache_location.'.'.$dest_type;
        unlink($temp_fn) if -e $temp_fn;
        return undef;
    }
    return $cache_location.'.'.$dest_type;
}

sub cache_location {
    my ($md5sum) = @_;
    for my $ext (qw(.png .jpg)) {
        if (-e $config{libravatar_cache_dir}.'/'.$md5sum.$ext) {
            return $config{libravatar_cache_dir}.'/'.$md5sum.$ext;
        }
    }
    return $config{libravatar_cache_dir}.'/'.$md5sum;
}



1;


__END__

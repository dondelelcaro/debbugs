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
use Exporter qw(import);

use Debbugs::Config qw(:config);
use Debbugs::Common qw(:lock);
use Libravatar::URL;
use CGI::Simple;
use Debbugs::CGI qw(cgi_parameters);
use Digest::MD5 qw(md5_hex);
use File::Temp qw(tempfile);
use File::LibMagic;
use Cwd qw(abs_path);

use Carp;

BEGIN{
     ($VERSION) = q$Revision$ =~ /^Revision:\s+([^\s+])/;
     $DEBUG = 0 unless defined $DEBUG;

     @EXPORT = ();
     %EXPORT_TAGS = (libravatar => [qw(retrieve_libravatar cache_location)]
		    );
     @EXPORT_OK = ();
     Exporter::export_ok_tags(keys %EXPORT_TAGS);
     $EXPORT_TAGS{all} = [@EXPORT_OK];
}


=over

=item retrieve_libravatar

     $cache_location = retrieve_libravatar(location => $cache_location,
                                           email => lc($param{email}),
                                          );

Returns the cache location where a specific avatar can be loaded. If
there isn't a matching avatar, or there is an error, returns undef.


=cut

sub retrieve_libravatar{
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
    my $timestamp;
    $cache_location =~ s/\.[^\.\/]+$//;
    # take out a lock on the cache location so that if another request
    # is made while we are serving this one, we don't do double work
    my ($fh,$lockfile,$errors) =
        simple_filelock($cache_location.'.lock',20,0.5);
    if (not $fh) {
        return undef;
    } else {
        # figure out if the cache is now valid; if it is, return the
        # cache location
	my $temp_location;
        ($temp_location, $timestamp) = cache_location(email => $param{email});
        if ($timestamp) {
            return ($temp_location,$timestamp);
        }
    }
    require LWP::UserAgent;

    my $dest_type;
    eval {
        my $uri = libravatar_url(email => $param{email},
                                 default => 404,
                                 size => 80);
        my $ua = LWP::UserAgent->new(agent => 'Debbugs libravatar service (not Mozilla)',
                                    );
        $ua->from($config{maintainer});
        # if we don't get an avatar within 10 seconds, return so we
        # don't block forever
        $ua->timeout(10);
        # if the avatar is bigger than 30K, we don't want it either
        $ua->max_size(30*1024);
        my $r = $ua->get($uri);
        if (not $r->is_success()) {
            if ($r->code != 404) {
                die "Not successful in request";
            }
            # No avatar - cache a negative result
            if ($config{libravatar_default_image} =~ m/\.(png|jpg)$/) {
                $dest_type = $1;

                system('cp', '-laf', $config{libravatar_default_image},  $cache_location.'.'.$dest_type) == 0
                  or die("Cannot copy $config{libravatar_default_image}");
                # Returns from eval {}
                return;
            }
        }
        my $aborted = $r->header('Client-Aborted');
        # if we exceeded max size, I'm not sure if we'll be
        # successfull or not, but regardless, there will be a
        # Client-Aborted header. Stop here if that header is defined.
        die "Client aborted header" if defined $aborted;
        my $type = $r->header('Content-Type');
        # if there's no content type, or it's not one we like, we won't
        # bother going further
        die "No content type" if not defined $type;
        die "Wrong content type" if not $type =~ m{^image/([^/]+)$};
        $dest_type = $type_mapping{$1};
        die "No dest type" if not defined $dest_type;
        # undo any content encoding
        $r->decode() or die "Unable to decode content encoding";
        # ok, now we need to convert it from whatever it is into a
        # format that we actually like
        my ($temp_fh,$temp_fn) = tempfile() or
            die "Unable to create temporary file";
        eval {
            print {$temp_fh} $r->content() or
                die "Unable to print to temp file";
            close ($temp_fh);
            ### resize all images to 80x80 and strip comments out of
            ### them. If convert has a bug, it would be possible for
            ### this to be an attack vector, but hopefully minimizing
            ### the size above, and requiring proper mime types will
            ### minimize that slightly. Doing this will at least make
            ### it harder for malicious web images to harm our users
            system('convert','-resize','80x80',
                   '-strip',
                   $temp_fn,
                   $cache_location.'.'.$dest_type) == 0 or
                       die "convert file failed";
            unlink($temp_fn);
        };
        if ($@) {
            unlink($cache_location.'.'.$dest_type) if -e $cache_location.'.'.$dest_type;
            unlink($temp_fn) if -e $temp_fn;
            die "Unable to convert image";
        }
    };
    if ($@) {
        # there was some kind of error; return undef and unlock the
        # lock
        simple_unlockfile($fh,$lockfile);
        return undef;
    }
    simple_unlockfile($fh,$lockfile);
    $timestamp = (stat($cache_location.'.'.$dest_type))[9];
    return ($cache_location.'.'.$dest_type,$timestamp);
}

sub blocked_libravatar {
    my ($email,$md5sum) = @_;
    my $blocked = 0;
    for my $blocker (@{$config{libravatar_blacklist}||[]}) {
        for my $element ($email,$md5sum) {
            next unless defined $element;
            eval {
                if ($element =~ /$blocker/) {
                    $blocked=1;
                }
            };
        }
    }
    return $blocked;
}

# Returns ($path, $timestamp)
# - For blocked images, $path will be undef
# - If $timestamp is 0 (and $path is not undef), the image should
#   be re-fetched.
sub cache_location {
    my %param = @_;
    my ($md5sum, $stem);
    if (exists $param{md5sum}) {
        $md5sum = $param{md5sum};
    }elsif (exists $param{email}) {
        $md5sum = md5_hex(lc($param{email}));
    } else {
        croak("cache_location must be called with one of md5sum or email");
    }
    return (undef, 0) if blocked_libravatar($param{email},$md5sum);
    $stem = $config{libravatar_cache_dir}.'/'.$md5sum;
    for my $ext ('.png', '.jpg', '') {
        my $path = $stem.$ext;
        if (-e $path) {
            my $timestamp = (time - (stat(_))[9] < 60*60) ? (stat(_))[9] : 0;
            return ($path, $timestamp);
        }
    }
    return ($stem, 0);
}

## the following is mod_perl specific

BEGIN{
    if (exists $ENV{MOD_PERL_API_VERSION}) {
        if ($ENV{MOD_PERL_API_VERSION} == 2) {
            require Apache2::RequestIO;
            require Apache2::RequestRec;
            require Apache2::RequestUtil;
            require Apache2::Const;
            require APR::Finfo;
            require APR::Const;
            APR::Const->import(-compile => qw(FINFO_NORM));
            Apache2::Const->import(-compile => qw(OK DECLINED FORBIDDEN NOT_FOUND HTTP_NOT_MODIFIED));
        } else {
            die "Unsupported mod perl api; mod_perl 2.0.0 or later is required";
        }
    }
}

sub handler {
    die "Calling handler only makes sense if this is running under mod_perl" unless exists $ENV{MOD_PERL_API_VERSION};
    my $r = shift or Apache2::RequestUtil->request;

    # we only want GET or HEAD requests
    unless ($r->method eq 'HEAD' or $r->method eq 'GET') {
        return Apache2::Const::DECLINED();
    }
    $r->headers_out->{"X-Powered-By"} = "Debbugs libravatar";

    my $uri = $r->uri();
    # subtract out location
    my $location = $r->location();
    my ($email) = $uri =~ m/\Q$location\E\/?(.*)$/;
    if (not length $email) {
        return Apache2::Const::NOT_FOUND();
    }
    my $q = CGI::Simple->new();
    my %param = cgi_parameters(query => $q,
                               single => [qw(avatar)],
                               default => {avatar => 'yes',
                                          },
                              );
    if ($param{avatar} ne 'yes' or not defined $email or not length $email) {
        serve_cache_mod_perl('',$r);
        return Apache2::Const::DECLINED();
    }
    # figure out what the md5sum of the e-mail is.
    my ($cache_location, $timestamp) = cache_location(email => $email);
    # if we've got it, and it's less than one hour old, return it.
    if ($timestamp) {
        serve_cache_mod_perl($cache_location,$r);
        return Apache2::Const::DECLINED();
    }
    ($cache_location,$timestamp) =
	retrieve_libravatar(location => $cache_location,
			    email => $email,
			   );
    if (not defined $cache_location) {
        # failure, serve the default image
        serve_cache_mod_perl('',$r,$timestamp);
        return Apache2::Const::DECLINED();
    } else {
        serve_cache_mod_perl($cache_location,$r,$timestamp);
        return Apache2::Const::DECLINED();
    }
}



our $magic;

sub serve_cache_mod_perl {
    my ($cache_location,$r,$timestamp) = @_;
    if (not defined $cache_location or not length $cache_location) {
        # serve the default image
        $cache_location = $config{libravatar_default_image};
    }
    $magic = File::LibMagic->new() if not defined $magic;

    return Apache2::Const::DECLINED() if not defined $magic;

    $r->content_type($magic->checktype_filename(abs_path($cache_location)));

    $r->filename($cache_location);
    $r->path_info('');
    $r->finfo(APR::Finfo::stat($cache_location, APR::Const::FINFO_NORM(), $r->pool));
}

=back

=cut

1;


__END__

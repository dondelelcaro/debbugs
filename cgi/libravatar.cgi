#!/usr/bin/perl

use warnings;
use strict;

use Debbugs::Config qw(:config);
use Debbugs::CGI qw(cgi_parameters);
use Debbugs::Common;
use Digest::MD5 qw(md5_hex);
use Gravatar::URL;
use File::LibMagic;
use File::Temp qw(tempfile);

use Libravatar::URL;

use LWP::UserAgent;
use HTTP::Request;

use CGI::Simple;

my $q = CGI::Simple->new();

my %param =
    cgi_parameters(query => $q,
                   single => [qw(email avatar default)],
                   default => {avatar => 'yes',
                               default => $config{libravatar_uri_options},
                              },
                  );
# if avatar is no, serve the empty png
if ($param{avatar} ne 'yes' or not defined $param{email} or not length $param{email}) {
    serve_cache('',$q);
    exit 0;
}

# figure out what the md5sum of the e-mail is.
my $email_md5sum = md5_hex(lc($param{email}));
my $cache_location = cache_location($email_md5sum);
# if we've got it, and it's less than one hour old, return it.
if (cache_valid($cache_location)) {
    serve_cache($cache_location,$q);
    exit 0;
}
# if we don't have it, get it, and store it in the cache
$cache_location = retreive_libravatar(location => $cache_location,
                                      email => lc($param{email}),
                                     );
if (not defined $cache_location) {
    # failure, serve the default image
    serve_cache('',$q);
    exit 0;
} else {
    serve_cache($cache_location,$q);
    exit 0;
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
        system('convert','-geometry','80x80',
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

sub serve_cache {
    my ($cache_location,$q) = @_;
    if (not defined $cache_location or not length $cache_location) {
        # serve the default image
        $cache_location = $config{libravatar_default_image};
    }
    my $fh = IO::File->new($cache_location,'r') or
        error(404, "Failed to open cached image $cache_location");
    my $m = File::LibMagic->new() or
        error(500,'Unable to create File::LibMagic object');
    my $mime_string = $m->checktype_filename($cache_location) or
        error(500,'Bad file; no mime known');
    print $q->header(-type => $mime_string,
                     -expires => '+1d',
                    );
    print STDOUT <$fh>;
    close($fh);
}


sub error {
    my ($error,$text) = @_;
    $text //= '';
    print $q->header(-status => $error);
    print "<h2>$error: $text</h2>";
    exit 0;
}

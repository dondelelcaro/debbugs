#!/usr/bin/perl

use warnings;
use strict;

use Debbugs::Config qw(:config);
use Debbugs::CGI qw(cgi_parameters);
use Debbugs::Common;
use File::LibMagic;
use Debbugs::Libravatar qw(:libravatar);

use Libravatar::URL;

use CGI::Simple;
use Cwd qw(abs_path);
use Digest::MD5 qw(md5_hex);

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
    serve_cache('',$q,0);
    exit 0;
}

my ($cache_location, $timestamp) = cache_location(email => lc($param{email}));
# if we've got it, and it's less than one hour old, return it.
if ($timestamp) {
    serve_cache($cache_location,$q,$timestamp);
    exit 0;
}
# if we don't have it, get it, and store it in the cache
($cache_location,$timestamp) =
    retrieve_libravatar(location => $cache_location,
			email => lc($param{email}),
		       );
if (not defined $cache_location) {
    # failure, serve the default image
    serve_cache('',$q,0);
    exit 0;
} else {
    serve_cache($cache_location,$q,$timestamp);
    exit 0;
}


sub serve_cache {
    my ($cache_location,$q,$timestamp) = @_;
    if (not defined $cache_location or not length $cache_location) {
        # serve the default image
        $cache_location = $config{libravatar_default_image};
	if (not defined $timestamp or not $timestamp) {
	    $timestamp = (stat($cache_location))[9];
	}
    }
    if (not defined $timestamp) {
	# this probably means that the default image doesn't exist
	print $q->header(status => 404);
	print "404: Not found\n";
	return;
    }
    my $etag = md5_hex($cache_location.$timestamp);
    if (defined $q->http('if-none-match')
	and $etag eq $q->http('if-none-match')) {
	print $q->header(-status => 304);
	print "304: Not modified\n";
	return;
    }
    my $fh = IO::File->new($cache_location,'r') or
	error($q,404, "Failed to open cached image $cache_location");
    my $m = File::LibMagic->new() or
	error($q,500,'Unable to create File::LibMagic object');
    my $mime_string = $m->checktype_filename(abs_path($cache_location)) or
	error($q,500,'Bad file; no mime known');
    print $q->header(-type => $mime_string,
		     -expires => '+1d',
		     -status => 200,
		     -etag => $etag,
		    );
    print <$fh>;
    close($fh);
}


sub error {
    my ($q,$error,$text) = @_;
    $text //= '';
    print $q->header(-status => $error);
    print "<h2>$error: $text</h2>";
    exit 0;
}

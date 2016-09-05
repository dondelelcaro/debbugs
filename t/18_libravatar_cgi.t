# -*- mode: cperl;-*-

use warnings;
use strict;

use Test::More;
# The test functions are placed here to make things easier
use lib qw(t/lib);
use DebbugsTest qw(:all);

plan tests => 3;

my $port = 11344;

# HTTP::Server:::Simple defines a SIG{CHLD} handler that breaks system; undef it here.
$SIG{CHLD} = sub {};
our %config;
eval {
    %config = create_debbugs_configuration();
};
if ($@) {
     BAIL_OUT($@);
 }
$ENV{DEBBUGS_CONFIG_FILE}  = "$config{config_dir}/debbugs_config";

my $libravatar_cgi_handler = sub {
    my $fh;
    $ENV{DEBBUGS_CONFIG_FILE} = $config{config_dir}."/debbugs_config";
    open($fh,'-|',-e './cgi/libravatar.cgi'? './cgi/libravatar.cgi'
	 : '../cgi/libravatar.cgi');
    my $headers;
    my $status = 200;
    while (<$fh>) {
	if (/^\s*$/ and $status) {
	    print "HTTP/1.1 $status OK\n";
	    print $headers;
	    $status = 0;
	    print $_;
	} elsif ($status) {
	    $headers .= $_;
	    if (/^Status:\s*(\d+)/i) {
		$status = $1;
	    }
	} else {
	    print $_;
	}
    }
};


ok(DebbugsTest::HTTPServer::fork_and_create_webserver($libravatar_cgi_handler,$port),
   'forked HTTP::Server::Simple successfully');

use LWP::UserAgent;
my $ua = LWP::UserAgent->new;
$ua->agent("DebbugsTesting/0.1 ");

# Create a request
my $req = HTTP::Request->new(GET => "http://localhost:$port/?avatar=no");

my $res = $ua->request($req);
ok($res->is_success(),'cgi/libravatar.cgi returns success');
my $etag = $res->header('Etag');

$req = HTTP::Request->new(GET => "http://localhost:$port/?avatar=no",
			  ['If-None-Match',$etag]);
$res = $ua->request($req);
ok($res->code() eq '304','If-None-Match set gives us 304 not modified');




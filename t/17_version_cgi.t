# -*- mode: cperl;-*-

use Test::More;

use warnings;
use strict;

plan tests => 2;

my $port = 11343;

our $child_pid = undef;

END{
     if (defined $child_pid) {
	  my $temp_exit = $?;
	  kill(15,$child_pid);
	  waitpid(-1,0);
	  $? = $temp_exit;
     }
}

my $pid = fork;
die "Unable to fork child" if not defined $pid;
if ($pid) {
     $child_pid = $pid;
     # Wait for two seconds to let the child start
     sleep 2;
}
else {
    # UGH.
    package SillyWebServer;
    use HTTP::Server::Simple;
    use base qw(HTTP::Server::Simple::CGI::Environment HTTP::Server::Simple);
    sub handler {
	my $fh;
	open($fh,'-|',-e './cgi/version.cgi'? './cgi/version.cgi' : '../cgi/version.cgi');
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
     }
    my $server = SillyWebServer->new($port);
    $server->run();
    exit 0;
}


use LWP::UserAgent;
my $ua = LWP::UserAgent->new;
$ua->agent("DebbugsTesting/0.1 ");

# Create a request
my $req = HTTP::Request->new(GET => "http://localhost:$port/");

my $res = $ua->request($req);
ok($res->is_success(),'cgi/version.cgi returns success');
my $etag = $res->header('Etag');

$req = HTTP::Request->new(GET => "http://localhost:$port/",['If-None-Match',$etag]);
$res = $ua->request($req);
ok($res->code() eq '304','If-None-Match set gives us 304 not modified');




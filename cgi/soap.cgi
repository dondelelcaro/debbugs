#!/usr/bin/perl -wT

package debbugs;

use SOAP::Transport::HTTP;

use Debbugs::SOAP::Usertag;

SOAP::Transport::HTTP::CGI
    -> dispatch_to('Debbugs::SOAP::Usertag')
    -> handle;


#!/usr/bin/perl -wT

package debbugs;

use SOAP::Transport::HTTP;

use Debbugs::SOAP::Usertag;
use Debbugs::SOAP::Status;

SOAP::Transport::HTTP::CGI
    -> dispatch_to('Debbugs::SOAP::Usertag', 'Debbugs::SOAP::Status')
    -> handle;


#!/usr/bin/perl -wT

package debbugs;

use SOAP::Transport::HTTP;

use Debbugs::SOAP::Usertag;
use Debbugs::SOAP::Status;

my $soap = SOAP::Transport::HTTP::CGI
    -> dispatch_to('Debbugs::SOAP::Usertag', 'Debbugs::SOAP::Status');
$soap->serializer()->soapversion(1.2);
# soapy is stupid, and is using the 1999 schema; override it.
*SOAP::XMLSchema1999::Serializer::as_base64Binary = \&SOAP::XMLSchema2001::Serializer::as_base64Binary;
$soap-> handle;


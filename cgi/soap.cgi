#!/usr/bin/perl -wT

#use SOAP::Transport::HTTP;

# Work around stupid soap bug on line 411
if (not exists $ENV{EXPECT}) {
     $ENV{EXPECT} = '';
}

my $soap = Debbugs::SOAP::Server
#my $soap = SOAP::Transport::HTTP::CGI
    -> dispatch_to('Debbugs::SOAP');
#$soap->serializer()->soapversion(1.2);
# soapy is stupid, and is using the 1999 schema; override it.
*SOAP::XMLSchema1999::Serializer::as_base64Binary = \&SOAP::XMLSchema2001::Serializer::as_base64Binary;
$soap-> handle;


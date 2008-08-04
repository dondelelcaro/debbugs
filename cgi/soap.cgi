#!/usr/bin/perl -wT

#use SOAP::Transport::HTTP;

use Debbugs::SOAP::Server;

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
*SOAP::Serializer::as_anyURI       = \&SOAP::XMLSchema2001::Serializer::as_string;
# to work around the serializer improperly using date/time stuff
# (Nothing in Debbugs should be looked at as if it were date/time) we
# kill off all of the date/time related bits in the serializer.
my $typelookup = $soap->serializer()->{_typelookup};
for my $key (keys %{$typelookup}) {
     next unless /Month|Day|Year|date|time|duration/i;
     delete $typelookup->{$key};
}
$soap->handle;


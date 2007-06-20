# This module is part of debbugs, and is released
# under the terms of the GPL version 2, or any later version at your option.
# See the file README and COPYING for more information.
# Copyright 2007 by Don Armstrong <don@donarmstrong.com>.

package Debbugs::SOAP::Server;

=head1 NAME

Debbugs::SOAP::Server -- Server Transport module

=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 BUGS

None known.

=cut

use warnings;
use strict;
use vars qw(@ISA);
use SOAP::Transport::HTTP;
BEGIN{
     # Eventually we'll probably change this to just be HTTP::Server and
     # have the soap.cgi declare a class which inherits from both
     push @ISA,qw(SOAP::Transport::HTTP::CGI);
}

use Debbugs::SOAP;

sub find_target {
     my ($self,$request) = @_;

     # WTF does this do?
     $request->match((ref $request)->method);
     my $method_uri = $request->namespaceuriof || 'Debbugs/SOAP';
     my $method_name = $request->dataof->name;
     $method_uri =~ s{(?:/?Status/?|/?Usertag/?)}{};
     $method_uri =~ s{(Debbugs/SOAP/)[vV](\d+)/?}{$1};
     my ($soap_version) = $2 if defined $2;
     $self->dispatched('Debbugs:::SOAP');
     $request->{___debbugs_soap_version} = $soap_version || '';
     return ('Debbugs::SOAP',$method_uri,$method_name);
}


1;


__END__







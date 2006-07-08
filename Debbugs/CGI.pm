
package Debbugs::CGI;

=head1 NAME

Debbugs::CGI -- General routines for the cgi scripts

=head1 SYNOPSIS

use Debbugs::CGI qw(:url :html);

html_escape(bug_url($ref,mbox=>'yes',mboxstatus=>'yes'));

=head1 DESCRIPTION

This module is a replacement for parts of common.pl; subroutines in
common.pl will be gradually phased out and replaced with equivalent
(or better) functionality here.

=head1 BUGS

None known.

=cut

use warnings;
use strict;
use vars qw($VERSION $DEBUG %EXPORT_TAGS @EXPORT_OK @EXPORT);
use base qw(Exporter);
use Debbugs::URI;
use HTML::Entities;
use Debbugs::Common qw();

BEGIN{
     ($VERSION) = q$Revision: 1.3 $ =~ /^Revision:\s+([^\s+])/;
     $DEBUG = 0 unless defined $DEBUG;

     @EXPORT = ();
     %EXPORT_TAGS = (url    => [qw(bug_url)],
		     html   => [qw(html_escape)],
		     #status => [qw(getbugstatus)],
		    );
     @EXPORT_OK = ();
     Exporter::export_ok_tags(qw(url html));
     $EXPORT_TAGS{all} = [@EXPORT_OK];
}




=head2 bug_url

     bug_url($ref,mbox=>'yes',mboxstat=>'yes');

Constructs urls which point to a specific

=cut

sub bug_url{
     my $ref = shift;
     my %params = @_;
     my $url = Debbugs::URI->new('bugreport.cgi?');
     $url->query_form(bug=>$ref,%params);
     return $url->as_string;
}

=head2 html_escape

     html_escape($string)

Escapes html entities by calling HTML::Entities::encode_entities;

=cut

sub html_escape{
     my ($string) = @_;

     return HTML::Entities::encode_entities($string)
}

my %common_bugusertags;

# =head2 get_bug_status
# 
#      my $status = getbugstatus($bug_num)
# 
#      my $status = getbugstatus($bug_num,$bug_index)
# 
# 
# =cut
# 
# sub get_bug_status {
#     my ($bugnum,$bugidx) = @_;
# 
#     my %status;
# 
#     if (defined $bugidx and exists $bugidx->{$bugnum}) {
# 	%status = %{ $bugidx->{$bugnum} };
# 	$status{pending} = $status{ status };
# 	$status{id} = $bugnum;
# 	return \%status;
#     }
# 
#     my $location = getbuglocation($bugnum, 'summary');
#     return {} if not length $location;
#     %status = %{ readbug( $bugnum, $location ) };
#     $status{id} = $bugnum;
# 
# 
#     if (defined $common_bugusertags{$bugnum}) {
#         $status{keywords} = "" unless defined $status{keywords};
#         $status{keywords} .= " " unless $status{keywords} eq "";
#         $status{keywords} .= join(" ", @{$common_bugusertags{$bugnum}});
#     }
#     $status{tags} = $status{keywords};
#     my %tags = map { $_ => 1 } split ' ', $status{tags};
# 
#     $status{"package"} =~ s/\s*$//;
#     $status{"package"} = 'unknown' if ($status{"package"} eq '');
#     $status{"severity"} = 'normal' if ($status{"severity"} eq '');
# 
#     $status{"pending"} = 'pending';
#     $status{"pending"} = 'forwarded'	    if (length($status{"forwarded"}));
#     $status{"pending"} = 'pending-fixed'    if ($tags{pending});
#     $status{"pending"} = 'fixed'	    if ($tags{fixed});
# 
#     my @versions;
#     if (defined $common_version) {
#         @versions = ($common_version);
#     } elsif (defined $common_dist) {
#         @versions = getversions($status{package}, $common_dist, $common_arch);
#     }
# 
#     # TODO: This should probably be handled further out for efficiency and
#     # for more ease of distinguishing between pkg= and src= queries.
#     my @sourceversions = makesourceversions($status{package}, $common_arch,
#                                             @versions);
# 
#     if (@sourceversions) {
#         # Resolve bugginess states (we might be looking at multiple
#         # architectures, say). Found wins, then fixed, then absent.
#         my $maxbuggy = 'absent';
#         for my $version (@sourceversions) {
#             my $buggy = buggyversion($bugnum, $version, \%status);
#             if ($buggy eq 'found') {
#                 $maxbuggy = 'found';
#                 last;
#             } elsif ($buggy eq 'fixed' and $maxbuggy ne 'found') {
#                 $maxbuggy = 'fixed';
#             }
#         }
#         if ($maxbuggy eq 'absent') {
#             $status{"pending"} = 'absent';
#         } elsif ($maxbuggy eq 'fixed') {
#             $status{"pending"} = 'done';
#         }
#     }
#     
#     if (length($status{done}) and
#             (not @sourceversions or not @{$status{fixed_versions}})) {
#         $status{"pending"} = 'done';
#     }
# 
#     return \%status;
# }



1;


__END__







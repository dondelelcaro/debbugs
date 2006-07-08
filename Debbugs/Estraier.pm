
package Debbugs::Estraier;

=head1 NAME

Debbugs::Estraier -- Routines for interfacing bugs to HyperEstraier

=head1 SYNOPSIS

use Debbugs::Estraier;


=head1 DESCRIPTION


=head1 BUGS

None known.

=cut

use warnings;
use strict;
use vars qw($VERSION $DEBUG %EXPORT_TAGS @EXPORT_OK @EXPORT);
use base qw(Exporter);
use Debbugs::Log;
#use Params::Validate;
use Search::Estraier;
use Date::Manip;
use Debbugs::Common qw(getbuglocation getbugcomponent readbug);


BEGIN{
     ($VERSION) = q$Revision: 1.3 $ =~ /^Revision:\s+([^\s+])/;
     $DEBUG = 0 unless defined $DEBUG;

     @EXPORT = ();
     %EXPORT_TAGS = (add    => [qw(add_bug_log add_bug_message)],
		    );
     @EXPORT_OK = ();
     Exporter::export_ok_tags(qw(add));
     $EXPORT_TAGS{all} = [@EXPORT_OK];
}


sub add_bug_log{
     my ($est,$bug_num) = @_;

     # We want to read the entire bug log, pulling out individual
     # messages, and shooting them through hyper estraier

     my $location = getbuglocation($bug_num,'log');
     my $bug_log = getbugcomponent($bug_num,'log',$location);
     my $log_fh = new IO::File $bug_log, 'r' or
	  die "Unable to open bug log $bug_log for reading: $!";

     my $log = Debbugs::Log->new($log_fh) or
	  die "Debbugs::Log was unable to be initialized";

     my %seen_msg_ids;
     my $msg_num=0;
     my $status = {};
     if (my $location = getbuglocation($bug_num,'summary')) {
	  $status = readbug($bug_num,$location);
     }
     while (my $record = $log->read_record()) {
	  $msg_num++;
	  next unless $record->{type} eq 'incoming-recv';
	  my ($msg_id) = $record->{text} =~ /^Message-Id:\s+<(.+)>/im;
	  next if defined $msg_id and exists $seen_msg_ids{$msg_id};
	  $seen_msg_ids{$msg_id} = 1 if defined $msg_id;
	  next if $msg_id =~ /handler\..+\.ack(?:info)?\@/;
	  add_bug_message($est,$record->{text},$bug_num,$msg_num,$status)
     }
}

sub add_bug_message{
     my ($est,$bug_message,$bug_num,
	 $msg_num,$status) = @_;

     my $doc;
     my $uri = "$bug_num/$msg_num";
     $doc = $est->get_doc_by_uri($uri);
     $doc = new Search::Estraier::Document if not defined $doc;
     $doc->add_text($bug_message);

     # * @id : the ID number determined automatically when the document is registered.
     # * @uri : the location of a document which any document should have.
     # * @digest : the message digest calculated automatically when the document is registered.
     # * @cdate : the creation date.
     # * @mdate : the last modification date.
     # * @adate : the last access date.
     # * @title : the title used as a headline in the search result.
     # * @author : the author.
     # * @type : the media type.
     # * @lang : the language.
     # * @genre : the genre.
     # * @size : the size.
     # * @weight : the scoring weight.
     # * @misc : miscellaneous information.
     my @attr = qw(status subject date submitter package tags severity);
     # parse the date
     my ($date) = $bug_message =~ /^Date:\s+(.+?)\s*$/mi;
     $doc->add_attr('@cdate' => $date);
     # parse the title
     my ($subject) = $bug_message =~ /^Subject:\s+(.+?)\s*$/mi;
     $doc->add_attr('@title' => $subject);
     # parse the author
     my ($author) = $bug_message =~ /^From:\s+(.+?)\s*$/mi;
     $doc->add_attr('@author' => $author);
     # create the uri
     $doc->add_attr('@uri' => $uri);
     foreach my $attr (@attr) {
	  $doc->add_attr($attr => $status->{$attr});
     }
     print STDERR "adding $uri\n" if $DEBUG;
     # Try a bit harder if estraier is returning timeouts
     my $attempt = 5;
     while ($attempt > 0) {
	  $est->put_doc($doc) and last;
	  my $status = $est->status;
	  $attempt--;
	  print STDERR "Failed to add $uri\n".$status."\n";
	  last unless $status =~ /^5/;
	  sleep 20;
     }

}


1;


__END__







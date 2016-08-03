# This module is part of debbugs, and is released
# under the terms of the GPL version 2, or any later
# version at your option.
# See the file README and COPYING for more information.
#
# Copyright 2007 by Don Armstrong <don@donarmstrong.com>.

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
use Exporter qw(import);
use Debbugs::Log;
use Search::Estraier;
use Debbugs::Common qw(getbuglocation getbugcomponent make_list);
use Debbugs::Status qw(readbug);
use Debbugs::MIME qw(parse);
use Encode qw(encode_utf8);

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
	  next if defined $msg_id and $msg_id =~ /handler\..+\.ack(?:info)?\@/;
	  add_bug_message($est,$record->{text},$bug_num,$msg_num,$status)
     }
     return $msg_num;
}

=head2 remove_old_message

     remove_old_message($est,300000,50);

Removes all messages which are no longer in the log

=cut

sub remove_old_messages{
     my ($est,$bug_num,$max_message) = @_;
     # remove records which are no longer present in the log (uri > $msg_num)
     my $cond = new Search::Estraier::Condition;
     $cond->add_attr('@uri STRBW '.$bug_num.'/');
     $cond->set_max(50);
     my $skip;
     my $nres;
     while ($nres = $est->search($cond,0) and $nres->doc_num > 0){
	  for my $rdoc (map {$nres->get_doc($_)} 0..($nres->doc_num-1)) {
	       my $uri = $rdoc->uri;
	       my ($this_message) = $uri =~ m{/(\d+)$};
	       next unless $this_message > $max_message;
	       $est->out_doc_by_uri($uri);
	  }
	  last unless $nres->doc_num >= $cond->max;
	  $cond->set_skip($cond->skip+$cond->max);
     }

}

sub add_bug_message{
     my ($est,$bug_message,$bug_num,
	 $msg_num,$status) = @_;

     my $doc;
     my $uri = "$bug_num/$msg_num";
     $doc = $est->get_doc_by_uri($uri);
     $doc = new Search::Estraier::Document if not defined $doc;

     my $message = parse($bug_message);
     $doc->add_text(encode_utf8(join("\n",make_list(values %{$message}))));

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
     $doc->add_attr('@cdate' => encode_utf8($date)) if defined $date;
     # parse the title
     my ($subject) = $bug_message =~ /^Subject:\s+(.+?)\s*$/mi;
     $doc->add_attr('@title' => encode_utf8($subject)) if defined $subject;
     # parse the author
     my ($author) = $bug_message =~ /^From:\s+(.+?)\s*$/mi;
     $doc->add_attr('@author' => encode_utf8($author)) if defined $author;
     # create the uri
     $doc->add_attr('@uri' => encode_utf8($uri));
     foreach my $attr (@attr) {
	  $doc->add_attr($attr => encode_utf8($status->{$attr})) if defined $status->{$attr};
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







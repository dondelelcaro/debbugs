# This module is part of debbugs, and is released
# under the terms of the GPL version 2, or any later version. See the
# file README and COPYING for more information.
# Copyright 2013 by Don Armstrong <don@donarmstrong.com>.

package Debbugs::DB::Load;

=head1 NAME

Debbugs::DB::Load -- Utility routines for loading the database

=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 BUGS

None known.

=cut

use warnings;
use strict;
use v5.10;
use vars qw($VERSION $DEBUG %EXPORT_TAGS @EXPORT_OK @EXPORT);
use base qw(Exporter);

BEGIN{
     ($VERSION) = q$Revision$ =~ /^Revision:\s+([^\s+])/;
     $DEBUG = 0 unless defined $DEBUG;

     @EXPORT = ();
     %EXPORT_TAGS = (load_bug    => [qw(load_bug handle_load_bug_queue load_bug_log)],
		     load_debinfo => [qw(load_debinfo)],
		     load_package => [qw(load_packages)],
		     load_suite => [qw(load_suite)],
		    );
     @EXPORT_OK = ();
     Exporter::export_ok_tags(keys %EXPORT_TAGS);
     $EXPORT_TAGS{all} = [@EXPORT_OK];
}

use Params::Validate qw(validate_with :types);
use List::AllUtils qw(natatime);

use Debbugs::Status qw(read_bug split_status_fields);
use Debbugs::DB;
use DateTime;
use Debbugs::Common qw(make_list getparsedaddrs);
use Debbugs::Config qw(:config);
use Debbugs::MIME qw(parse_to_mime_entity decode_rfc1522);
use DateTime::Format::Mail;
use Carp;

=head2 Bug loading

Routines to load bug; exported with :load_bug

=over

=item load_bug

     load_bug(db => $schema,
              data => split_status_fields($data),
              tags => \%tags,
              queue => \%queue);

Loads a bug's metadata into the database. (Does not load any messages)

=over

=item db -- Debbugs::DB object

=item data -- Bug data (from read_bug) which has been split with split_status_fields

=item tags -- tag cache (hashref); optional

=item queue -- queue of operations to perform after bug is loaded; optional.

=back

=cut

sub load_bug {
    my %param = validate_with(params => \@_,
                              spec => {db => {type => OBJECT,
                                             },
                                       data => {type => HASHREF,
                                                optional => 1,
                                               },
                                       bug => {type => SCALAR,
                                               optional => 1,
                                              },
                                       tags => {type => HASHREF,
                                                default => sub {return {}},
                                                optional => 1},
                                       severities => {type => HASHREF,
                                                      default => sub {return {}},
                                                      optional => 1,
                                                     },
                                       queue => {type => HASHREF,
                                                 optional => 1},
				       packages => {type => HASHREF,
						    default => sub {return {}},
						    optional => 1,
						   },
                                      });
    my $s = $param{db};
    if (not exists $param{data} and not exists $param{bug}) {
        croak "One of data or bug must be provided to load_bug";
    }
    if (not exists $param{data}) {
        $param{data} = read_bug(bug => $param{bug});
    }
    my $data = $param{data};
    my $tags = $param{tags};
    my $queue = $param{queue};
    my $severities = $param{severities};
    my $can_queue = 1;
    if (not defined $queue) {
        $can_queue = 0;
        $queue = {};
    }
    my %tags;
    $data = split_status_fields($data);
    for my $tag (make_list($data->{keywords})) {
	next unless defined $tag and length $tag;
	# this allows for invalid tags. But we'll use this to try to
	# find those bugs and clean them up
	if (not exists $tags->{$tag}) {
	    $tags->{$tag} = $s->resultset('Tag')->
            find_or_create({tag => $tag});
	}
	$tags{$tag} = $tags->{$tag};
    }
    my $severity = length($data->{severity}) ? $data->{severity} :
	$config{default_severity};
    if (not exists $severities->{$severity}) {
	$severities->{$severity} =
	    $s->resultset('Severity')->
            find_or_create({severity => $severity},
			  );
    }
    $severity = $severities->{$severity};
    my $bug =
        {id => $data->{bug_num},
         creation => DateTime->from_epoch(epoch => $data->{date}),
         log_modified => DateTime->from_epoch(epoch => $data->{log_modified}),
         last_modified => DateTime->from_epoch(epoch => $data->{last_modified}),
         archived => $data->{archived},
         (defined $data->{unarchived} and length($data->{unarchived}))?
	 (unarchived => DateTime->from_epoch(epoch => $data->{unarchived})):(),
         forwarded => $data->{forwarded} // '',
         summary => $data->{summary} // '',
         outlook => $data->{outlook} // '',
         subject => $data->{subject} // '',
         done_full => $data->{done} // '',
         severity => $severity,
         owner_full => $data->{owner} // '',
         submitter_full => $data->{originator} // '',
        };
    my %addr_map =
        (done => 'done',
         owner => 'owner',
         submitter => 'originator',
        );
    for my $addr_type (keys %addr_map) {
	$bug->{$addr_type} = undef;
	next unless defined $data->{$addr_map{$addr_type}} and
	    length($data->{$addr_map{$addr_type}});
        $bug->{$addr_type} =
	    $s->resultset('Correspondent')->
	    get_correspondent_id($data->{$addr_map{$addr_type}})
    }
    my $b = $s->resultset('Bug')->update_or_create($bug) or
        die "Unable to update or create bug $bug->{id}";
    $s->txn_do(sub {
		 $b->set_related_packages('binpackages',
					  [grep {defined $_ and
						   length $_ and $_ !~ /^src:/}
					   make_list($data->{package})],
					  $param{packages},
					 );
		 $b->set_related_packages('srcpackages',
					  [map {s/src://;
                                                $_}
                                           grep {defined $_ and
						   $_ =~ /^src:/}
					   make_list($data->{package})],
					  $param{packages},
					 );
		 $b->set_related_packages('affects_binpackages',
					  [grep {defined $_ and
						   length $_ and $_ !~ /^src:/}
					   make_list($data->{affects})
					  ],
					  $param{packages},
					 );
		 $b->set_related_packages('affects_srcpackages',
					  [map {s/src://;
                                                $_}
                                           grep {defined $_ and
						   $_ =~ /^src:/}
					   make_list($data->{affects})],
					  $param{packages},
					 );
		 for my $ff (qw(found fixed)) {
		       my @elements = $s->resultset('BugVer')->search({bug => $data->{bug_num},
								       found  => $ff eq 'found'?1:0,
								      });
		       my %elements_to_delete = map {($elements[$_]->ver_string(),
						      $elements[$_])} 0..$#elements;
		       my %elements_to_add;
                       my @elements_to_keep;
		       for my $version (@{$data->{"${ff}_versions"}}) {
			   if (exists $elements_to_delete{$version}) {
			       push @elements_to_keep,$version;
			   } else {
			       $elements_to_add{$version} = 1;
			   }
		       }
                       for my $version (@elements_to_keep) {
                           delete $elements_to_delete{$version};
                       }
		       for my $element (keys %elements_to_delete) {
                           $elements_to_delete{$element}->delete();
		       }
		       for my $element (keys %elements_to_add) {
			   # find source package and source version id
			   my $ne = $s->resultset('BugVer')->new_result({bug => $data->{bug_num},
									 ver_string => $element,
									 found => $ff eq 'found'?1:0,
									}
								       );
			   if (my ($src_pkg,$src_ver) = $element =~ m{^([^\/]+)/(.+)$}) {
			       my $src_pkg_e = $s->resultset('SrcPkg')->single({pkg => $src_pkg});
			       if (defined $src_pkg_e) {
				   $ne->src_pkg($src_pkg_e->id());
				   my $src_ver_e = $s->resultset('SrcVer')->single({src_pkg => $src_pkg_e->id(),
										    ver => $src_ver
										   });
				   $ne->src_ver($src_ver_e->id()) if defined $src_ver_e;
			       }
			   }
			   $ne->insert();
		       }
		   }
	       });
    ### set bug tags
    $s->txn_do(sub {$b->set_tags([values %tags ] )});
    # because these bugs reference other bugs which might not exist
    # yet, we can't handle them until we've loaded all bugs. queue
    # them up.
    for my $merge_block (qw(mergedwith blocks)) {
        if (@{$data->{$merge_block}||[]}) {
            my $count = $s->resultset('Bug')->
                search({id => [@{$data->{$merge_block}}]})->
                count();
            # if all of the bugs exist, immediately fix the merge/blocks
            if ($count == @{$data->{$merge_block}}) {
                handle_load_bug_queue(db=>$s,
                                      queue => {$merge_block,
                                               {$data->{bug_num},[@{$data->{$merge_block}}]}
                                               });
            } else {
                $queue->{$merge_block}{$data->{bug_num}} = [@{$data->{$merge_block}}];
            }
        }
    }

    if (not $can_queue and keys %{$queue}) {
        handle_load_bug_queue(db => $s,queue => $queue);
    }

    # still need to handle merges, versions, etc.
}

=item handle_load_bug_queue

     handle_load_bug_queue(db => $schema,queue => $queue);

Handles a queue of operations created by load bug. [These operations
are used to handle cases where a bug referenced by a loaded bug may
not exist yet. In cases where the bugs should exist, the queue is
cleared automatically by load_bug if queue is undefined.

=cut

sub handle_load_bug_queue{
    my %param = validate_with(params => \@_,
                              spec => {db => {type => OBJECT,
                                             },
                                       queue => {type => HASHREF,
                                                },
                                      });
    my $s = $param{db};
    my $queue = $param{queue};
    my %queue_types =
	(mergedwith => {set => 'BugMerged',
                        columns => [qw(bug merged)],
                        bug => 'bug',
                       },
	 blocks => {set => 'BugBlock',
                    columns => [qw(bug blocks)],
                    bug => 'bug',
                   },
	);
    for my $queue_type (keys %queue_types) {
        my $qt = $queue_types{$queue_type};
        my @bugs = keys %{$queue->{$queue_type}};
        my @entries;
        for my $bug (@bugs) {
            push @entries,
                map {[$bug,$_]}
                @{$queue->{$queue_type}{$bug}};
        }
        $s->txn_do(sub {
                       $s->resultset($qt->{set})->
                           search({$qt->{bug}=>\@bugs})->delete();
                       $s->resultset($qt->{set})->
                           populate([[@{$qt->{columns}}],
                                     @entries]) if @entries;
		       }
                  );
    }
}

=item load_bug_log -- load bug logs

       load_bug_log(db  => $s,
                    bug => $bug);


=over

=item db -- database 

=item bug -- bug whose log should be loaded

=back

=cut

sub load_bug_log {
    my %param = validate_with(params => \@_,
                              spec => {db => {type => OBJECT,
                                             },
                                       bug => {type => SCALAR,
                                              },
                                       queue => {type => HASHREF,
                                                 optional => 1},
                                      });
    my $s = $param{db};
    my $msg_num=0;
    my %seen_msg_ids;
    my $log = Debbugs::Log->new(bug_num => $param{bug}) or
        die "Unable to open log for $param{bug} for reading: $!";
    while (my $record = $log->read_record()) {
        next unless $record->{type} eq 'incoming-recv';
        my ($msg_id) = $record->{text} =~ /^Message-Id:\s+<(.+)>/im;
        next if defined $msg_id and exists $seen_msg_ids{$msg_id};
        $seen_msg_ids{$msg_id} = 1 if defined $msg_id;
        next if defined $msg_id and $msg_id =~ /handler\..+\.ack(?:info)?\@/;
        my $entity = parse_to_mime_entity($record);
        # search for a message with this message id in the database
        $msg_id = $entity->head->get('Message-Id') //
            $entity->head->get('Resent-Message-ID') //
            '';
	$msg_id =~ s/^\s*\<//;
	$msg_id =~ s/>\s*$//;
	# check to see if the subject, to, and from match. if so, it's
        # probably the same message.
	my $subject = decode_rfc1522($entity->head->get('Subject')//'');
	$subject =~ s/\n(?:(\s)\s*|\s*$)//g;
	my $to = decode_rfc1522($entity->head->get('To')//'');
	$to =~ s/\n(?:(\s)\s*|\s*$)//g;
	my $from = decode_rfc1522($entity->head->get('From')//'');
	$from =~ s/\n(?:(\s)\s*|\s*$)//g;
	my $m = $s->resultset('Message')->
	    find({msgid => $msg_id,
		  from_complete => $from,
		  to_complete => $to,
		  subject => $subject
		 });
	if (not defined $m) {
	    # if not, create a new message
	    $m = $s->resultset('Message')->
		find_or_create({msgid => $msg_id,
				from_complete => $from,
				to_complete => $to,
				subject => $subject
			       });
	    eval {
		my $date = DateTime::Format::Mail->
                    parse_datetime($entity->head->get('Date',0));
                if (abs($date->offset) >= 60 * 60 * 12) {
                    $date = $date->set_time_zone('UTC');
                }
                $m->sent_date($date);
	    };
	    my $spam = $entity->head->get('X-Spam-Status',0)//'';
	    if ($spam=~ /score=([\d\.]+)/) {
		$m->spam_score($1);
	    }
	    my %corr;
	    @{$corr{from}} = getparsedaddrs($from);
	    @{$corr{to}} = getparsedaddrs($to);
	    @{$corr{cc}} = getparsedaddrs($entity->head->get('Cc'));
	    # add correspondents if necessary
	    my @cors;
	    for my $type (keys %corr) {
		for my $addr (@{$corr{$type}}) {
                    my $cor = $s->resultset('Correspondent')->
                        get_correspondent_id($addr);
                    next unless defined $cor;
		    push @cors,
			{correspondent => $cor,
			 correspondent_type => $type,
			};
		}
	    }
	    $m->update();
	    $s->txn_do(sub {
			   $m->message_correspondents()->delete();
			   $m->add_to_message_correspondents(@cors) if
                               @cors;
		       }
		      );
	}
	my $recv;
	if ($entity->head->get('Received',0)
	    =~ /via spool by (\S+)/) {
	    $recv = $s->resultset('Correspondent')->
		get_correspondent_id($1);
	    $m->add_to_message_correspondents({correspondent=>$recv,
					       correspondent_type => 'recv'});
	}
        # link message to bugs if necessary
	$m->find_or_create_related('bug_messages',
				  {bug=>$param{bug},
				   message_number => $msg_num});
    }

}

=back

=head2 Debinfo

Commands to handle src and package version loading from debinfo files

=over

=item load_debinfo

     load_debinfo($schema,$binname, $binver, $binarch, $srcname, $srcver);



=cut

sub load_debinfo {
    my ($s,$binname, $binver, $binarch, $srcname, $srcver,$ct_date,$cache) = @_;
    $cache //= {};
    my $sp;
    if (not defined $cache->{sp}{$srcname}) {
        $cache->{sp}{$srcname} =
            $s->resultset('SrcPkg')->find_or_create({pkg => $srcname});
    }
    $sp = $cache->{sp}{$srcname};
    # update the creation date if the data we have is earlier
    if (defined $ct_date and
        (not defined $sp->creation or
         $ct_date < $sp->creation)) {
        $sp->creation($ct_date);
        $sp->last_modified(DateTime->now);
        $sp->update;
    }
    my $sv;
    if (not defined $cache->{sv}{$srcname}{$srcver}) {
        $cache->{sv}{$srcname}{$srcver} =
            $s->resultset('SrcVer')->
            find_or_create({src_pkg =>$sp->id(),
                            ver => $srcver});
    }
    $sv = $cache->{sv}{$srcname}{$srcver};
    if (defined $ct_date and
        (not defined $sv->upload_date() or $ct_date < $sv->upload_date())) {
        $sv->upload_date($ct_date);
        $sv->update;
    }
    my $arch;
    if (not defined $cache->{arch}{$binarch}) {
        $cache->{arch}{$binarch} =
            $s->resultset('Arch')->
            find_or_create({arch => $binarch},
                          )->id();
    }
    $arch = $cache->{arch}{$binarch};
    my $bp;
    if (not defined $cache->{bp}{$binname}) {
        $cache->{bp}{$binname} =
            $s->resultset('BinPkg')->
            get_bin_pkg_id($binname);
    }
    $bp = $cache->{bp}{$binname};
    $s->resultset('BinVer')->
        get_bin_ver_id($bp,$binver,$arch,$sv->id());
}


=back

=head2 Packages

=over

=item load_package

     load_package($schema,$suite,$component,$arch,$pkg)

=cut

sub load_packages {
    my ($schema,$suite,$pkgs,$p) = @_;
    my $suite_id = $schema->resultset('Suite')->
	find_or_create({codename => $suite})->id;
    my %maint_cache;
    my %arch_cache;
    my %source_cache;
    my $src_max_last_modified = $schema->resultset('SrcAssociation')->
	search_rs({suite => $suite_id},
		 {order_by => {-desc => ['me.modified']},
		  rows => 1,
		  page => 1
		 }
		 )->single();
    my $bin_max_last_modified = $schema->resultset('BinAssociation')->
	search_rs({suite => $suite_id},
		 {order_by => {-desc => ['me.modified']},
		  rows => 1,
		  page => 1
		 }
		 )->single();
    my %maints;
    my %sources;
    my %bins;
    for my $pkg_tuple (@{$pkgs}) {
	my ($arch,$component,$pkg) = @{$pkg_tuple};
	$maints{$pkg->{Maintainer}} = $pkg->{Maintainer};
	if ($arch eq 'source') {
	    my $source = $pkg->{Package};
	    my $source_ver = $pkg->{Version};
	    $sources{$source}{$source_ver} = $pkg->{Maintainer};
	} else {
	    my $source = $pkg->{Source} // $pkg->{Package};
	    my $source_ver = $pkg->{Version};
	    if ($source =~ /^\s*(\S+) \(([^\)]+)\)\s*$/) {
		($source,$source_ver) = ($1,$2);
	    }
	    $sources{$source}{$source_ver} = $pkg->{Maintainer};
	    $bins{$arch}{$pkg->{Package}} =
	       {arch => $arch,
		bin => $pkg->{Package},
		bin_ver => $pkg->{Version},
		src_ver => $source_ver,
		source  => $source,
		maint   => $pkg->{Maintainer},
	       };
	}
    }
    # Retrieve and Insert new maintainers
    my $maints =
	$schema->resultset('Maintainer')->
	get_maintainers(keys %maints);
    my $archs =
	$schema->resultset('Arch')->
	get_archs(keys %bins);
    # We want all of the source package/versions which are in this suite to
    # start with
    my @sa_to_add;
    my @sa_to_del;
    my %included_sa;
    # Calculate which source packages are no longer in this suite
    for my $s ($schema->resultset('SrcPkg')->
	       src_pkg_and_ver_in_suite($suite)) {
	if (not exists $sources{$s->{pkg}} or
	    not exists $sources{$s->{pkg}}{$s->{src_vers}{ver}}
	   ) {
	    push @sa_to_del,
		$s->{src_associations}{id};
	}
	$included_sa{$s->{pkg}}{$s->{src_vers}} = 1;
    }
    # Calculate which source packages are newly in this suite
    for my $s (keys %sources) {
	for my $v (keys %{$sources{$s}}) {
	    if (not exists $included_sa{$s} and
		not $included_sa{$s}{$v}) {
		push @sa_to_add,
		    [$s,$v,$sources{$s}{$v}];
	    } else {
		$p->update() if defined $p;
	    }
	}
    }
    # add new source packages
    my $it = natatime 100, @sa_to_add;
    while (my @v = $it->()) {
	$schema->txn_do(
	    sub {
		for my $svm (@_) {
		    my $s_id = $schema->resultset('SrcPkg')->
			get_src_pkg_id($svm->[0]);
		    my $sv_id = $schema->resultset('SrcVer')->
			get_src_ver_id($s_id,$svm->[1],$maints->{$svm->[2]});
		    $schema->resultset('SrcAssociation')->
			insert_suite_src_ver_association($suite_id,$sv_id);
		}
	    },
			@v
		       );
	$p->update($p->last_update()+
		   scalar @v) if defined $p;
    }
    # remove associations for packages not in this suite
    if (@sa_to_del) {
        $it = natatime 1000, @sa_to_del;
        while (my @v = $it->()) {
            $schema->
                txn_do(sub {
                           $schema->resultset('SrcAssociation')->
                               search_rs({id => \@v})->
                               delete();
                       });
        }
    }
    # update packages in this suite to have a modification time of now
    $schema->resultset('SrcAssociation')->
	search_rs({suite => $suite_id})->
	update({modified => 'NOW()'});
    ## Handle binary packages
    my @bin_to_del;
    my @bin_to_add;
    my %included_bin;
    # calculate which binary packages are no longer in this suite
    for my $b ($schema->resultset('BinPkg')->
	       bin_pkg_and_ver_in_suite($suite)) {
	if (not exists $bins{$b->{arch}{arch}} or
	    not exists $bins{$b->{arch}{arch}}{$b->{pkg}} or
	    ($bins{$b->{arch}{arch}}{$b->{pkg}}{bin_ver} ne
	     $b->{bin_vers}{ver}
	    )
	   ) {
	    push @bin_to_del,
		$b->{bin_associations}{id};
	}
	$included_bin{$b->{arch}{arch}}{$b->{pkg}} =
	    $b->{bin_vers}{ver};
    }
    # calculate which binary packages are newly in this suite
    for my $a (keys %bins) {
	for my $pkg (keys %{$bins{$a}}) {
	    if (not exists $included_bin{$a} or
		not exists $included_bin{$a}{$pkg} or
		$bins{$a}{$pkg}{bin_ver} ne
		$included_bin{$a}{$pkg}) {
		push @bin_to_add,
		    $bins{$a}{$pkg};
	    } else {
		$p->update() if defined $p;
	    }
	}
    }
    $it = natatime 100, @bin_to_add;
    while (my @v = $it->()) {
	$schema->txn_do(
	sub {
	    for my $bvm (@_) {
		my $s_id = $schema->resultset('SrcPkg')->
		    get_src_pkg_id($bvm->{source});
		my $sv_id = $schema->resultset('SrcVer')->
		    get_src_ver_id($s_id,$bvm->{src_ver},$maints->{$bvm->{maint}});
		my $b_id = $schema->resultset('BinPkg')->
		    get_bin_pkg_id($bvm->{bin});
		my $bv_id = $schema->resultset('BinVer')->
		    get_bin_ver_id($b_id,$bvm->{bin_ver},
				   $archs->{$bvm->{arch}},$sv_id);
		$schema->resultset('BinAssociation')->
		    insert_suite_bin_ver_association($suite_id,$bv_id);
	    }
	},
			@v
		       );
	$p->update($p->last_update()+
		   scalar @v) if defined $p;
    }
    if (@bin_to_del) {
        $it = natatime 1000, @bin_to_del;
        while (my @v = $it->()) {
            $schema->
                txn_do(sub {
                           $schema->resultset('BinAssociation')->
                               search_rs({id => \@v})->
                               delete();
                       });
        }
    }
    $schema->resultset('BinAssociation')->
	search_rs({suite => $suite_id})->
	update({modified => 'NOW()'});

}


=back

=cut

=head2 Suites

=over

=item load_suite

     load_suite($schema,$codename,$suite,$version,$active);

=cut

sub load_suite {
    my ($schema,$codename,$suite,$version,$active) = @_;
    if (ref($codename)) {
	($codename,$suite,$version) =
	    @{$codename}{qw(Codename Suite Version)};
	$active = 1;
    }
    my $s = $schema->resultset('Suite')->find_or_create({codename => $codename});
    $s->suite_name($suite);
    $s->version($version);
    $s->active($active);
    $s->update();
    return $s;

}

=back

=cut

1;


__END__
# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:

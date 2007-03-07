
package Debbugs::Status;

=head1 NAME

Debbugs::Status -- Routines for dealing with summary and status files

=head1 SYNOPSIS

use Debbugs::Status;


=head1 DESCRIPTION

This module is a replacement for the parts of errorlib.pl which write
and read status and summary files.

It also contains generic routines for returning information about the
status of a particular bug

=head1 FUNCTIONS

=cut

use warnings;
use strict;
use vars qw($VERSION $DEBUG %EXPORT_TAGS @EXPORT_OK @EXPORT);
use base qw(Exporter);

use Params::Validate qw(validate_with :types);
use Debbugs::Common qw(:util :lock :quit);
use Debbugs::Config qw(:config);
use Debbugs::MIME qw(decode_rfc1522 encode_rfc1522);
use Debbugs::Packages qw(makesourceversions getversions binarytosource);
use Debbugs::Versions;
use Debbugs::Versions::Dpkg;
use POSIX qw(ceil);


BEGIN{
     $VERSION = 1.00;
     $DEBUG = 0 unless defined $DEBUG;

     @EXPORT = ();
     %EXPORT_TAGS = (status => [qw(splitpackages get_bug_status buggy bug_archiveable),
				qw(isstrongseverity),
			       ],
		     read   => [qw(readbug read_bug lockreadbug)],
		     write  => [qw(writebug makestatus unlockwritebug)],
		     versions => [qw(addfoundversions addfixedversions),
				  qw(removefoundversions)
				 ],
		    );
     @EXPORT_OK = ();
     Exporter::export_ok_tags(qw(status read write versions));
     $EXPORT_TAGS{all} = [@EXPORT_OK];
}


=head2 readbug

     readbug($bug_num,$location)
     readbug($bug_num)

Reads a summary file from the archive given a bug number and a bug
location. Valid locations are those understood by L</getbugcomponent>

=cut


my %fields = (originator     => 'submitter',
              date           => 'date',
              subject        => 'subject',
              msgid          => 'message-id',
              'package'      => 'package',
              keywords       => 'tags',
              done           => 'done',
              forwarded      => 'forwarded-to',
              mergedwith     => 'merged-with',
              severity       => 'severity',
              owner          => 'owner',
              found_versions => 'found-in',
	      found_date     => 'found-date',
              fixed_versions => 'fixed-in',
	      fixed_date     => 'fixed-date',
              blocks         => 'blocks',
              blockedby      => 'blocked-by',
             );

# Fields which need to be RFC1522-decoded in format versions earlier than 3.
my @rfc1522_fields = qw(originator subject done forwarded owner);

sub readbug {
     return read_bug(bug => $_[0],
		     (@_ > 1)?(location => $_[1]):()
		    );
}

=head2 read_bug

     read_bug(bug => $bug_num,
              location => 'archive',
             );
     read_bug(summary => 'path/to/bugnum.summary');
     read_bug($bug_num);

A more complete function than readbug; it enables you to pass a full
path to the summary file instead of the bug number and/or location.

=head3 Options

=over

=item bug -- the bug number

=item location -- optional location which is passed to getbugcomponent

=item summary -- complete path to the .summary file which will be read

=back

One of C<bug> or C<summary> must be passed. This function will return
undef on failure, and will die if improper arguments are passed.

=cut

sub read_bug{
    if (@_ == 1) {
	 unshift @_, 'bug';
    }
    my %param = validate_with(params => \@_,
			      spec   => {bug => {type => SCALAR,
						 optional => 1,
						 regex    => qr/^-?\d+/,
						},
					 location => {type => SCALAR|UNDEF,
						      optional => 1,
						     },
					 summary  => {type => SCALAR,
						      optional => 1,
						     },
					},
			     );
    die "One of bug or summary must be passed to read_bug"
	 if not exists $param{bug} and not exists $param{summary};
    my $status;
    if (not defined $param{summary}) {
	 my ($lref, $location) = @param{qw(bug location)};
	 if (not defined $location) {
	      $location = getbuglocation($lref,'summary');
	      return undef if not defined $location;
	 }
	 $status = getbugcomponent($lref, 'summary', $location);
	 return undef unless defined $status;
    }
    else {
	 $status = $param{summary};
    }
    my $status_fh = new IO::File $status, 'r' or
	 warn "Unable to open $status for reading: $!" and return undef;

    my %data;
    my @lines;
    my $version = 2;
    local $_;

    while (<$status_fh>) {
        chomp;
        push @lines, $_;
        $version = $1 if /^Format-Version: ([0-9]+)/i;
    }

    # Version 3 is the latest format version currently supported.
    return undef if $version > 3;

    my %namemap = reverse %fields;
    for my $line (@lines) {
        if ($line =~ /(\S+?): (.*)/) {
            my ($name, $value) = (lc $1, $2);
            $data{$namemap{$name}} = $value if exists $namemap{$name};
        }
    }
    for my $field (keys %fields) {
        $data{$field} = '' unless exists $data{$field};
    }

    $data{severity} = $config{default_severity} if $data{severity} eq '';
    for my $field (qw(found_versions fixed_versions found_date fixed_date)) {
	 $data{$field} = [split ' ', $data{$field}];
    }
    for my $field (qw(found fixed)) {
	 # create the found/fixed hashes which indicate when a
	 # particular version was marked found or marked fixed.
	 @{$data{$field}}{@{$data{"${field}_versions"}}} =
	      (('') x (@{$data{"${field}_date"}} - @{$data{"${field}_versions"}}),
	       @{$data{"${field}_date"}});
    }

    if ($version < 3) {
	for my $field (@rfc1522_fields) {
	    $data{$field} = decode_rfc1522($data{$field});
	}
    }

    return \%data;
}

=head2 lockreadbug

     lockreadbug($bug_num,$location)

Performs a filelock, then reads the bug; the bug is unlocked if the
return is undefined, otherwise, you need to call unfilelock or
unlockwritebug.

See readbug above for information on what this returns

=cut

sub lockreadbug {
    my ($lref, $location) = @_;
    &filelock("lock/$lref");
    my $data = read_bug(bug => $lref, location => $location);
    &unfilelock unless defined $data;
    return $data;
}

my @v1fieldorder = qw(originator date subject msgid package
                      keywords done forwarded mergedwith severity);

=head2 makestatus

     my $content = makestatus($status,$version)
     my $content = makestatus($status);

Creates the content for a status file based on the $status hashref
passed.

Really only useful for writebug

Currently defaults to version 2 (non-encoded rfc1522 names) but will
eventually default to version 3. If you care, you should specify a
version.

=cut

sub makestatus {
    my ($data,$version) = @_;
    $version = 2 unless defined $version;

    my $contents = '';

    my %newdata = %$data;
    for my $field (qw(found fixed)) {
	 if (exists $newdata{$field}) {
	      $newdata{"${field}_date"} =
		   [map {$newdata{$field}{$_}||''} keys %{$newdata{$field}}];
	 }
    }

    for my $field (qw(found_versions fixed_versions found_date fixed_date)) {
	 $newdata{$field} = join ' ', @{$newdata{$field}||[]};
    }

    if ($version < 3) {
        for my $field (@rfc1522_fields) {
            $newdata{$field} = encode_rfc1522($newdata{$field});
        }
    }

    if ($version == 1) {
        for my $field (@v1fieldorder) {
            if (exists $newdata{$field} and defined $newdata{$field}) {
                $contents .= "$newdata{$field}\n";
            } else {
                $contents .= "\n";
            }
        }
    } elsif ($version == 2 or $version == 3) {
        # Version 2 or 3. Add a file format version number for the sake of
        # further extensibility in the future.
        $contents .= "Format-Version: $version\n";
        for my $field (keys %fields) {
            if (exists $newdata{$field} and defined $newdata{$field}
		and $newdata{$field} ne '') {
                # Output field names in proper case, e.g. 'Merged-With'.
                my $properfield = $fields{$field};
                $properfield =~ s/(?:^|(?<=-))([a-z])/\u$1/g;
                $contents .= "$properfield: $newdata{$field}\n";
            }
        }
    }

    return $contents;
}

=head2 writebug

     writebug($bug_num,$status,$location,$minversion,$disablebughook)

Writes the bug status and summary files out.

Skips writting out a status file if minversion is 2

Does not call bughook if disablebughook is true.

=cut

sub writebug {
    my ($ref, $data, $location, $minversion, $disablebughook) = @_;
    my $change;

    my %outputs = (1 => 'status', 2 => 'summary');
    for my $version (keys %outputs) {
        next if defined $minversion and $version < $minversion;
        my $status = getbugcomponent($ref, $outputs{$version}, $location);
        &quit("can't find location for $ref") unless defined $status;
        open(S,"> $status.new") || &quit("opening $status.new: $!");
        print(S makestatus($data, $version)) ||
            &quit("writing $status.new: $!");
        close(S) || &quit("closing $status.new: $!");
        if (-e $status) {
            $change = 'change';
        } else {
            $change = 'new';
        }
        rename("$status.new",$status) || &quit("installing new $status: $!");
    }

    # $disablebughook is a bit of a hack to let format migration scripts use
    # this function rather than having to duplicate it themselves.
    &bughook($change,$ref,$data) unless $disablebughook;
}

=head2 unlockwritebug

     unlockwritebug($bug_num,$status,$location,$minversion,$disablebughook);

Writes a bug, then calls unfilelock; see writebug for what these
options mean.

=cut

sub unlockwritebug {
    writebug(@_);
    &unfilelock;
}

=head1 VERSIONS

The following functions are exported with the :versions tag

=head2 addfoundversions

     addfoundversions($status,$package,$version,$isbinary);



=cut


sub addfoundversions {
    my $data = shift;
    my $package = shift;
    my $version = shift;
    my $isbinary = shift;
    return unless defined $version;
    undef $package if $package =~ m[(?:\s|/)];
    my $source = $package;

    if (defined $package and $isbinary) {
        my @srcinfo = binarytosource($package, $version, undef);
        if (@srcinfo) {
            # We know the source package(s). Use a fully-qualified version.
            addfoundversions($data, $_->[0], $_->[1], '') foreach @srcinfo;
            return;
        }
        # Otherwise, an unqualified version will have to do.
	undef $source;
    }

    # Strip off various kinds of brain-damage.
    $version =~ s/;.*//;
    $version =~ s/ *\(.*\)//;
    $version =~ s/ +[A-Za-z].*//;

    foreach my $ver (split /[,\s]+/, $version) {
        my $sver = defined($source) ? "$source/$ver" : '';
        unless (grep { $_ eq $ver or $_ eq $sver } @{$data->{found_versions}}) {
            push @{$data->{found_versions}}, defined($source) ? $sver : $ver;
        }
        @{$data->{fixed_versions}} =
            grep { $_ ne $ver and $_ ne $sver } @{$data->{fixed_versions}};
    }
}

=head2 removefoundversions

     removefoundversions($data,$package,$versiontoremove)

Removes found versions from $data

If a version is fully qualified (contains /) only versions matching
exactly are removed. Otherwise, all versions matching the version
number are removed.

Currently $package and $isbinary are entirely ignored, but accepted
for backwards compatibilty.

=cut

sub removefoundversions {
    my $data = shift;
    my $package = shift;
    my $version = shift;
    my $isbinary = shift;
    return unless defined $version;

    foreach my $ver (split /[,\s]+/, $version) {
	 if ($ver =~ m{/}) {
	      # fully qualified version
	      @{$data->{found_versions}} =
		   grep {$_ ne $ver}
			@{$data->{found_versions}};
	 }
	 else {
	      # non qualified version; delete all matchers
	      @{$data->{found_versions}} =
		   grep {$_ !~ m[(?:^|/)\Q$ver\E$]}
			@{$data->{found_versions}};
	 }
    }
}


sub addfixedversions {
    my $data = shift;
    my $package = shift;
    my $version = shift;
    my $isbinary = shift;
    return unless defined $version;
    undef $package if $package =~ m[(?:\s|/)];
    my $source = $package;

    if (defined $package and $isbinary) {
        my @srcinfo = binarytosource($package, $version, undef);
        if (@srcinfo) {
            # We know the source package(s). Use a fully-qualified version.
            addfixedversions($data, $_->[0], $_->[1], '') foreach @srcinfo;
            return;
        }
        # Otherwise, an unqualified version will have to do.
        undef $source;
    }

    # Strip off various kinds of brain-damage.
    $version =~ s/;.*//;
    $version =~ s/ *\(.*\)//;
    $version =~ s/ +[A-Za-z].*//;

    foreach my $ver (split /[,\s]+/, $version) {
        my $sver = defined($source) ? "$source/$ver" : '';
        unless (grep { $_ eq $ver or $_ eq $sver } @{$data->{fixed_versions}}) {
            push @{$data->{fixed_versions}}, defined($source) ? $sver : $ver;
        }
        @{$data->{found_versions}} =
            grep { $_ ne $ver and $_ ne $sver } @{$data->{found_versions}};
    }
}

sub removefixedversions {
    my $data = shift;
    my $package = shift;
    my $version = shift;
    my $isbinary = shift;
    return unless defined $version;
    undef $package if $package =~ m[(?:\s|/)];
    my $source = $package;

    if (defined $package and $isbinary) {
        my @srcinfo = binarytosource($package, $version, undef);
        if (@srcinfo) {
            # We know the source package(s). Use a fully-qualified version.
            removefixedversions($data, $_->[0], $_->[1], '') foreach @srcinfo;
            return;
        }
        # Otherwise, an unqualified version will have to do.
        undef $source;
    }

    foreach my $ver (split /[,\s]+/, $version) {
        my $sver = defined($source) ? "$source/$ver" : '';
        @{$data->{fixed_versions}} =
            grep { $_ ne $ver and $_ ne $sver } @{$data->{fixed_versions}};
    }
}



=head2 splitpackages

     splitpackages($pkgs)

Split a package string from the status file into a list of package names.

=cut

sub splitpackages {
    my $pkgs = shift;
    return unless defined $pkgs;
    return map lc, split /[ \t?,()]+/, $pkgs;
}


=head2 bug_archiveable

     bug_archiveable(bug => $bug_num);

Options

=over

=item bug -- bug number (required)

=item status -- Status hashref returned by read_bug or get_bug_status (optional)

=item version -- Debbugs::Version information (optional)

=item days_until -- return days until the bug can be archived

=back

Returns 1 if the bug can be archived
Returns 0 if the bug cannot be archived

If days_until is true, returns the number of days until the bug can be
archived, -1 if it cannot be archived. 0 means that the bug can be
archived the next time the archiver runs.

Returns undef on failure.

=cut

# This will eventually need to be fixed before we start using mod_perl
my $version_cache = {};
sub bug_archiveable{
     my %param = validate_with(params => \@_,
			       spec   => {bug => {type => SCALAR,
						  regex => qr/^\d+$/,
						 },
					  status => {type => HASHREF,
						     optional => 1,
						    },
					  days_until => {type => BOOLEAN,
							 default => 0,
							},
					 },
			      );
     # This is what we return if the bug cannot be archived.
     my $cannot_archive = $param{days_until}?-1:0;
     # read the status information
     my $status = $param{status};
     if (not exists $param{status} or not defined $status) {
	  $status = read_bug(bug=>$param{bug});
	  return undef if not defined $status;
     }
     # Bugs can be archived if they are
     # 1. Closed
     return $cannot_archive if not defined $status->{done} or not length $status->{done};
     # If we just are checking if the bug can be archived, we'll not even bother
     # checking the versioning information if the bug has been -done for less than 28 days.
     if (not $param{days_until} and $config{remove_age} >
	 -M getbugcomponent($param{ref},'log')
	) {
	  return $cannot_archive;
     }
     # At this point, we have to get the versioning information for this bug.
     # We examine the set of distribution tags. If a bug has no distribution
     # tags set, we assume a default set, otherwise we use the tags the bug
     # has set.

     # There must be fixed_versions for us to look at the versioning
     # information
     if (@{$status->{fixed_versions}}) {
	  my %dist_tags;
	  @dist_tags{@{$config{removal_distribution_tags}}} =
	       (1) x @{$config{removal_distribution_tags}};
	  my %dists;
	  @dists{@{$config{removal_default_distribution_tags}}} = 
	       (1) x @{$config{removal_default_distribution_tags}};
	  for my $tag (split ' ', $status->{tags}) {
	       next unless $dist_tags{$tag};
	       $dists{$tag} = 1;
	  }
	  my %source_versions;
	  for my $dist (keys %dists){
	       my @versions;
	       @versions = getversions($status->{package},
				       $dist,
				       undef);
	       # TODO: This should probably be handled further out for efficiency and
	       # for more ease of distinguishing between pkg= and src= queries.
	       my @sourceversions = makesourceversions($status->{package},
						       $dist,
						       @versions);
	       @source_versions{@sourceversions} = (1) x @sourceversions;
	  }
	  if ('found' eq max_buggy(bug => $param{bug},
				   sourceversions => [keys %source_versions],
				   found          => $status->{found_versions},
				   fixed          => $status->{fixed_versions},
				   version_cache  => $version_cache,
				   package        => $status->{package},
				  )) {
	       return $cannot_archive;
	  }
     }
     # 6. at least 28 days have passed since the last action has occured or the bug was closed
     # XXX We still need some more work here before we actually can archive;
     # we really need to track when a bug was closed in a version.
     my $age = ceil($config{remove_age} - -M getbugcomponent($param{bug},'log'));
     if ($age > 0 ) {
	  return $param{days_until}?$age:0;
     }
     else {
	  return $param{days_until}?0:1;
     }
}


=head2 get_bug_status

     my $status = get_bug_status(bug => $nnn);

     my $status = get_bug_status($bug_num)

=head3 Options

=over

=item bug -- scalar bug number

=item status -- optional hashref of bug status as returned by readbug
(can be passed to avoid rereading the bug information)

=item bug_index -- optional tied index of bug status infomration;
currently not correctly implemented.

=item version -- optional version to check package status at

=item dist -- optional distribution to check package status at

=item arch -- optional architecture to check package status at

=item usertags -- optional hashref of usertags

=item sourceversion -- optional arrayref of source/version; overrides
dist, arch, and version. [The entries in this array must be in the
"source/version" format.] Eventually this can be used to for caching.

=back

Note: Currently the version information is cached; this needs to be
changed before using this function in long lived programs.

=cut

sub get_bug_status {
     if (@_ == 1) {
	  unshift @_, 'bug';
     }
     my %param = validate_with(params => \@_,
			       spec   => {bug       => {type => SCALAR,
							regex => qr/^\d+$/,
						       },
					  status    => {type => HASHREF,
						        optional => 1,
						       },
					  bug_index => {type => OBJECT,
							optional => 1,
						       },
					  version   => {type => SCALAR,
							optional => 1,
						       },
					  dist       => {type => SCALAR,
							 optional => 1,
							},
					  arch       => {type => SCALAR,
							 optional => 1,
							},
					  usertags   => {type => HASHREF,
							 optional => 1,
							},
					  sourceversions => {type => ARRAYREF,
							     optional => 1,
							    },
					 },
			      );
     my %status;

     if (defined $param{bug_index} and
	 exists $param{bug_index}{$param{bug}}) {
	  %status = %{ $param{bug_index}{$param{bug}} };
	  $status{pending} = $status{ status };
	  $status{id} = $param{bug};
	  return \%status;
     }
     if (defined $param{status}) {
	  %status = %{$param{status}};
     }
     else {
	  my $location = getbuglocation($param{bug}, 'summary');
	  return {} if not length $location;
	  %status = %{ readbug( $param{bug}, $location ) };
     }
     $status{id} = $param{bug};

     if (defined $param{usertags}{$param{bug}}) {
	  $status{keywords} = "" unless defined $status{keywords};
	  $status{keywords} .= " " unless $status{keywords} eq "";
	  $status{keywords} .= join(" ", @{$param{usertags}{$param{bug}}});
     }
     $status{tags} = $status{keywords};
     my %tags = map { $_ => 1 } split ' ', $status{tags};

     $status{"package"} =~ s/\s*$//;
     $status{"package"} = 'unknown' if ($status{"package"} eq '');
     $status{"severity"} = 'normal' if ($status{"severity"} eq '');

     $status{"pending"} = 'pending';
     $status{"pending"} = 'forwarded'	    if (length($status{"forwarded"}));
     $status{"pending"} = 'pending-fixed'    if ($tags{pending});
     $status{"pending"} = 'fixed'	    if ($tags{fixed});

     my @sourceversions;
     if (not exists $param{sourceversions}) {
	  my @versions;
	  if (defined $param{version}) {
	       @versions = ($param{version});
	  } elsif (defined $param{dist}) {
	       @versions = getversions($status{package}, $param{dist}, $param{arch});
	  }

	  # TODO: This should probably be handled further out for efficiency and
	  # for more ease of distinguishing between pkg= and src= queries.
	  @sourceversions = makesourceversions($status{package},
					       $param{arch},
					       @versions);
     }
     else {
	  @sourceversions = @{$param{sourceversions}};
     }
     if (@sourceversions) {
	  my $maxbuggy = max_buggy(bug => $param{bug},
				   sourceversions => \@sourceversions,
				   found => $status{found_versions},
				   fixed => $status{fixed_versions},
				   package => $status{package},
				   version_cache => $version_cache,
				  );
	  if ($maxbuggy eq 'absent') {
	       $status{pending} = 'absent';
	  }
	  elsif ($maxbuggy eq 'fixed' ) {
	       $status{pending} = 'done';
	  }
     }
     if (length($status{done}) and
	 (not @sourceversions or not @{$status{fixed_versions}})) {
	  $status{"pending"} = 'done';
     }

     return \%status;
}


=head2 max_buggy

     max_buggy()

=head3 Options

=over

=item bug -- scalar bug number

=item sourceversion -- optional arrayref of source/version; overrides
dist, arch, and version. [The entries in this array must be in the
"source/version" format.] Eventually this can be used to for caching.

=back

Note: Currently the version information is cached; this needs to be
changed before using this function in long lived programs.


=cut
sub max_buggy{
     my %param = validate_with(params => \@_,
			       spec   => {bug       => {type => SCALAR,
							regex => qr/^\d+$/,
						       },
					  sourceversions => {type => ARRAYREF,
							     default => [],
							    },
					  found          => {type => ARRAYREF,
							     default => [],
							    },
					  fixed          => {type => ARRAYREF,
							     default => [],
							    },
					  package        => {type => SCALAR,
							    },
					  version_cache  => {type => HASHREF,
							     default => {},
							    },
					 },
			      );
     # Resolve bugginess states (we might be looking at multiple
     # architectures, say). Found wins, then fixed, then absent.
     my $maxbuggy = 'absent';
     for my $version (@{$param{sourceversions}}) {
	  my $buggy = buggy(bug => $param{bug},
			    version => $version,
			    found => $param{found},
			    fixed => $param{fixed},
			    version_cache => $param{version_cache},
			    package => $param{package},
			   );
	  if ($buggy eq 'found') {
	       return 'found';
	  } elsif ($buggy eq 'fixed') {
	       $maxbuggy = 'fixed';
	  }
     }
     return $maxbuggy;
}


=head2 buggy

     buggy(bug => nnn,
           found => \@found,
           fixed => \@fixed,
           package => 'foo',
           version => '1.0',
          );

Returns the output of Debbugs::Versions::buggy for a particular
package, version and found/fixed set. Automatically turns found, fixed
and version into source/version strings.

Caching can be had by using the version_cache, but no attempt to check
to see if the on disk information is more recent than the cache is
made. [This will need to be fixed for long-lived processes.]

=cut

sub buggy {
     my %param = validate_with(params => \@_,
			       spec   => {bug => {type => SCALAR,
						  regex => qr/^\d+$/,
						 },
					  found => {type => ARRAYREF,
						    default => [],
						   },
					  fixed => {type => ARRAYREF,
						    default => [],
						   },
					  version_cache => {type => HASHREF,
							    optional => 1,
							   },
					  package => {type => SCALAR,
						     },
					  version => {type => SCALAR,
						     },
					 },
			      );
     my @found = @{$param{found}};
     my @fixed = @{$param{fixed}};
     if (grep {$_ !~ m{/}} (@{$param{found}}, @{$param{fixed}})) {
	  # We have non-source version versions
	  @found = makesourceversions($param{package},undef,
				      @found
				     );
	  @fixed = makesourceversions($param{package},undef,
				      @fixed
				     );
     }
     if ($param{version} !~ m{/}) {
	  $param{version} = makesourceversions($param{package},undef,
					       $param{version}
					      );
     }
     # Figure out which source packages we need
     my %sources;
     @sources{map {m{(.+)/}; $1} @found} = (1) x @found;
     @sources{map {m{(.+)/}; $1} @fixed} = (1) x @fixed;
     @sources{map {m{(.+)/}; $1} $param{version}} = 1;
     my $version;
     if (not defined $param{version_cache} or
	 not exists $param{version_cache}{join(',',sort keys %sources)}) {
	  $version = Debbugs::Versions->new(\&Debbugs::Versions::Dpkg::vercmp);
	  foreach my $source (keys %sources) {
	       my $srchash = substr $source, 0, 1;
	       my $version_fh = new IO::File "$config{version_packages_dir}/$srchash/$source", 'r' or
		    warn "Unable to open $config{version_packages_dir}/$srchash/$source: $!" and next;
	       $version->load($version_fh);
	  }
	  if (defined $param{version_cache}) {
	       $param{version_cache}{join(',',sort keys %sources)} = $version;
	  }
     }
     else {
	  $version = $param{version_cache}{join(',',sort keys %sources)};
     }
     return $version->buggy($param{version},\@found,\@fixed);
}

sub isstrongseverity {
    my $severity = shift;
    $severity = $config{default_severity} if $severity eq '';
    return grep { $_ eq $severity } @{$config{strong_severities}};
}


=head1 PRIVATE FUNCTIONS

=cut

sub update_realtime {
	my ($file, $bug, $new) = @_;

	# update realtime index.db

	open(IDXDB, "<$file") or die "Couldn't open $file";
	open(IDXNEW, ">$file.new");

	my $line;
	my @line;
	while($line = <IDXDB>) {
		@line = split /\s/, $line;
		last if ($line[1] >= $bug);
		print IDXNEW $line;
		$line = "";
	}

	if ($new eq "NOCHANGE") {
		print IDXNEW $line if ($line ne ""  and $line[1] == $bug);
	} elsif ($new eq "REMOVE") {
		0;
	} else {
		print IDXNEW $new;
	}
	if (defined $line and $line ne "" and  @line and $line[1] > $bug) {
		print IDXNEW $line;
		$line = "";
	}

	print IDXNEW while(<IDXDB>);

	close(IDXNEW);
	close(IDXDB);

	rename("$file.new", $file);

	return $line;
}

sub bughook_archive {
	my $ref = shift;
	&filelock("debbugs.trace.lock");
	&appendfile("debbugs.trace","archive $ref\n");
	my $line = update_realtime(
		"$config{spool_dir}/index.db.realtime", 
		$ref,
		"REMOVE");
	update_realtime("$config{spool_dir}/index.archive.realtime",
		$ref, $line);
	&unfilelock;
}

sub bughook {
	my ( $type, $ref, $data ) = @_;
	&filelock("debbugs.trace.lock");

	&appendfile("debbugs.trace","$type $ref\n",makestatus($data, 1));

	my $whendone = "open";
	my $severity = $config{default_severity};
	(my $pkglist = $data->{package}) =~ s/[,\s]+/,/g;
	$pkglist =~ s/^,+//;
	$pkglist =~ s/,+$//;
	$whendone = "forwarded" if defined $data->{forwarded} and length $data->{forwarded};
	$whendone = "done" if defined $data->{done} and length $data->{done};
	$severity = $data->{severity} if length $data->{severity};

	my $k = sprintf "%s %d %d %s [%s] %s %s\n",
			$pkglist, $ref, $data->{date}, $whendone,
			$data->{originator}, $severity, $data->{keywords};

	update_realtime("$config{spool_dir}/index.db.realtime", $ref, $k);

	&unfilelock;
}


1;

__END__

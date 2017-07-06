# This module is part of debbugs, and is released
# under the terms of the GPL version 2, or any later
# version at your option.
# See the file README and COPYING for more information.
#
# [Other people have contributed to this file; their copyrights should
# go here too.]
# Copyright 2007-9 by Don Armstrong <don@donarmstrong.com>.

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
use Exporter qw(import);

use Params::Validate qw(validate_with :types);
use Debbugs::Common qw(:util :lock :quit :misc);
use Debbugs::UTF8;
use Debbugs::Config qw(:config);
use Debbugs::MIME qw(decode_rfc1522 encode_rfc1522);
use Debbugs::Packages qw(makesourceversions make_source_versions getversions get_versions binary_to_source);
use Debbugs::Versions;
use Debbugs::Versions::Dpkg;
use POSIX qw(ceil);
use File::Copy qw(copy);
use Encode qw(decode encode is_utf8);

use Storable qw(dclone);
use List::AllUtils qw(min max);

use Carp qw(croak);

BEGIN{
     $VERSION = 1.00;
     $DEBUG = 0 unless defined $DEBUG;

     @EXPORT = ();
     %EXPORT_TAGS = (status => [qw(splitpackages get_bug_status buggy bug_archiveable),
				qw(isstrongseverity bug_presence split_status_fields),
			       ],
		     read   => [qw(readbug read_bug lockreadbug lockreadbugmerge),
				qw(lock_read_all_merged_bugs),
			       ],
		     write  => [qw(writebug makestatus unlockwritebug)],
		     new => [qw(new_bug)],
		     versions => [qw(addfoundversions addfixedversions),
				  qw(removefoundversions removefixedversions)
				 ],
		     hook     => [qw(bughook bughook_archive)],
                     indexdb  => [qw(generate_index_db_line)],
		     fields   => [qw(%fields)],
		    );
     @EXPORT_OK = ();
     Exporter::export_ok_tags(keys %EXPORT_TAGS);
     $EXPORT_TAGS{all} = [@EXPORT_OK];
}


=head2 readbug

     readbug($bug_num,$location)
     readbug($bug_num)

Reads a summary file from the archive given a bug number and a bug
location. Valid locations are those understood by L</getbugcomponent>

=cut

# these probably shouldn't be imported by most people, but
# Debbugs::Control needs them, so they're now exportable
our %fields = (originator     => 'submitter',
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
	      unarchived     => 'unarchived',
	      summary        => 'summary',
	      outlook        => 'outlook',
	      affects        => 'affects',
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

=item lock -- whether to obtain a lock for the bug to prevent
something modifying it while the bug has been read. You B<must> call
C<unfilelock();> if something not undef is returned from read_bug.

=item locks -- hashref of already obtained locks; incremented as new
locks are needed, and decremented as locks are released on particular
files.

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
						 # something really
						 # stupid passes
						 # negative bugnumbers
						 regex    => qr/^-?\d+/,
						},
					 location => {type => SCALAR|UNDEF,
						      optional => 1,
						     },
					 summary  => {type => SCALAR,
						      optional => 1,
						     },
					 lock     => {type => BOOLEAN,
						      optional => 1,
						     },
					 locks    => {type => HASHREF,
						      optional => 1,
						     },
					},
			     );
    die "One of bug or summary must be passed to read_bug"
	 if not exists $param{bug} and not exists $param{summary};
    my $status;
    my $log;
    my $location;
    if (not defined $param{summary}) {
	 my $lref;
	 ($lref,$location) = @param{qw(bug location)};
	 if (not defined $location) {
	      $location = getbuglocation($lref,'summary');
	      return undef if not defined $location;
	 }
	 $status = getbugcomponent($lref, 'summary', $location);
	 $log    = getbugcomponent($lref, 'log'    , $location);
	 return undef unless defined $status;
	 return undef if not -e $status;
    }
    else {
	 $status = $param{summary};
	 $log = $status;
	 $log =~ s/\.summary$/.log/;
	 ($location) = $status =~ m/(db-h|db|archive)/;
         ($param{bug}) = $status =~ m/(\d+)\.summary$/;
    }
    if ($param{lock}) {
	filelock("$config{spool_dir}/lock/$param{bug}",exists $param{locks}?$param{locks}:());
    }
    my $status_fh = IO::File->new($status, 'r');
    if (not defined $status_fh) {
	warn "Unable to open $status for reading: $!";
	if ($param{lock}) {
		unfilelock(exists $param{locks}?$param{locks}:());
	}
	return undef;
    }
    binmode($status_fh,':encoding(UTF-8)');

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
    if ($version > 3) {
	 warn "Unsupported status version '$version'";
	 if ($param{lock}) {
	     unfilelock(exists $param{locks}?$param{locks}:());
	 }
	 return undef;
    }

    my %namemap = reverse %fields;
    for my $line (@lines) {
        if ($line =~ /(\S+?): (.*)/) {
            my ($name, $value) = (lc $1, $2);
	    # this is a bit of a hack; we should never, ever have \r
	    # or \n in the fields of status. Kill them off here.
	    # [Eventually, this should be superfluous.]
	    $value =~ s/[\r\n]//g;
	    $data{$namemap{$name}} = $value if exists $namemap{$name};
        }
    }
    for my $field (keys %fields) {
	$data{$field} = '' unless exists $data{$field};
    }
    if ($version < 3) {
	for my $field (@rfc1522_fields) {
	    $data{$field} = decode_rfc1522($data{$field});
	}
    }
    $data{severity} = $config{default_severity} if $data{severity} eq '';
    for my $field (qw(found_versions fixed_versions found_date fixed_date)) {
	 $data{$field} = [split ' ', $data{$field}];
    }
    for my $field (qw(found fixed)) {
	 # create the found/fixed hashes which indicate when a
	 # particular version was marked found or marked fixed.
	 @{$data{$field}}{@{$data{"${field}_versions"}}} =
	      (('') x (@{$data{"${field}_versions"}} - @{$data{"${field}_date"}}),
	       @{$data{"${field}_date"}});
    }

    my $status_modified = (stat($status))[9];
    # Add log last modified time
    $data{log_modified} = (stat($log))[9] // (stat("${log}.gz"))[9];
    $data{last_modified} = max($status_modified,$data{log_modified});
    $data{location} = $location;
    $data{archived} = (defined($location) and ($location eq 'archive'))?1:0;
    $data{bug_num} = $param{bug};

    # mergedwith occasionally is sorted badly. Fix it to always be sorted by <=>
    # and not include this bug
    if (defined $data{mergedwith} and
       $data{mergedwith}) {
	$data{mergedwith} =
	    join(' ',
		 grep { $_ != $data{bug_num}}
		 sort { $a <=> $b }
		 split / /, $data{mergedwith}
		);
    }
    return \%data;
}

=head2 split_status_fields

     my @data = split_status_fields(@data);

Splits splittable status fields (like package, tags, blocks,
blockedby, etc.) into arrayrefs (use make_list on these). Keeps the
passed @data intact using dclone.

In scalar context, returns only the first element of @data.

=cut

our $ditch_empty = sub{
    my @t = @_;
    my $splitter = shift @t;
    return grep {length $_} map {split $splitter} @t;
};

my $ditch_empty_space = sub {return &{$ditch_empty}(' ',@_)};
my %split_fields =
    (package        => \&splitpackages,
     affects        => \&splitpackages,
     # Ideally we won't have to split source, but because some consumers of
     # get_bug_status cannot handle arrayref, we will split it here.
     source         => \&splitpackages,
     blocks         => $ditch_empty_space,
     blockedby      => $ditch_empty_space,
     # this isn't strictly correct, but we'll split both of them for
     # the time being until we ditch all use of keywords everywhere
     # from the code
     keywords       => $ditch_empty_space,
     tags           => $ditch_empty_space,
     found_versions => $ditch_empty_space,
     fixed_versions => $ditch_empty_space,
     mergedwith     => $ditch_empty_space,
    );

sub split_status_fields {
    my @data = @{dclone(\@_)};
    for my $data (@data) {
	next if not defined $data;
	croak "Passed an element which is not a hashref to split_status_field".ref($data) if
	    not (ref($data) and ref($data) eq 'HASH');
	for my $field (keys %{$data}) {
	    next unless defined $data->{$field};
	    if (exists $split_fields{$field}) {
		next if ref($data->{$field});
		my @elements;
		if (ref($split_fields{$field}) eq 'CODE') {
		    @elements = &{$split_fields{$field}}($data->{$field});
		}
		elsif (not ref($split_fields{$field}) or
		       UNIVERSAL::isa($split_fields{$field},'Regex')
		      ) {
		    @elements = split $split_fields{$field}, $data->{$field};
		}
		$data->{$field} = \@elements;
	    }
	}
    }
    return wantarray?@data:$data[0];
}

=head2 join_status_fields

     my @data = join_status_fields(@data);

Handles joining the splitable status fields. (Basically, the inverse
of split_status_fields.

Primarily called from makestatus, but may be useful for other
functions after calling split_status_fields (or for legacy functions
if we transition to split fields by default).

=cut

sub join_status_fields {
    my %join_fields =
	(package        => ', ',
	 affects        => ', ',
	 blocks         => ' ',
	 blockedby      => ' ',
	 tags           => ' ',
	 found_versions => ' ',
	 fixed_versions => ' ',
	 found_date     => ' ',
	 fixed_date     => ' ',
	 mergedwith     => ' ',
	);
    my @data = @{dclone(\@_)};
    for my $data (@data) {
	next if not defined $data;
	croak "Passed an element which is not a hashref to split_status_field: ".
	    ref($data)
		if ref($data) ne 'HASH';
	for my $field (keys %{$data}) {
	    next unless defined $data->{$field};
	    next unless ref($data->{$field}) eq 'ARRAY';
	    next unless exists $join_fields{$field};
	    $data->{$field} = join($join_fields{$field},@{$data->{$field}});
	}
    }
    return wantarray?@data:$data[0];
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
    return read_bug(bug => $lref, location => $location, lock => 1);
}

=head2 lockreadbugmerge

     my ($locks, $data) = lockreadbugmerge($bug_num,$location);

Performs a filelock, then reads the bug. If the bug is merged, locks
the merge lock. Returns a list of the number of locks and the bug
data.

=cut

sub lockreadbugmerge {
     my $data = lockreadbug(@_);
     if (not defined $data) {
	  return (0,undef);
     }
     if (not length $data->{mergedwith}) {
	  return (1,$data);
     }
     unfilelock();
     filelock("$config{spool_dir}/lock/merge");
     $data = lockreadbug(@_);
     if (not defined $data) {
	  unfilelock();
	  return (0,undef);
     }
     return (2,$data);
}

=head2 lock_read_all_merged_bugs

     my ($locks,@bug_data) = lock_read_all_merged_bugs($bug_num,$location);

Performs a filelock, then reads the bug passed. If the bug is merged,
locks the merge lock, then reads and locks all of the other merged
bugs. Returns a list of the number of locks and the bug data for all
of the merged bugs.

Will also return undef if any of the merged bugs failed to be read,
even if all of the others were read properly.

=cut

sub lock_read_all_merged_bugs {
    my %param = validate_with(params => \@_,
			      spec   => {bug => {type => SCALAR,
						 regex => qr/^\d+$/,
						},
					 location => {type => SCALAR,
						      optional => 1,
						     },
					 locks    => {type => HASHREF,
						      optional => 1,
						     },
					},
			     );
    my $locks = 0;
    my @data = read_bug(bug => $param{bug},
			lock => 1,
			exists $param{location} ? (location => $param{location}):(),
			exists $param{locks} ? (locks => $param{locks}):(),
		       );
    if (not @data or not defined $data[0]) {
	return ($locks,());
    }
    $locks++;
    if (not length $data[0]->{mergedwith}) {
	return ($locks,@data);
    }
    unfilelock(exists $param{locks}?$param{locks}:());
    $locks--;
    filelock("$config{spool_dir}/lock/merge",exists $param{locks}?$param{locks}:());
    $locks++;
    @data = read_bug(bug => $param{bug},
		     lock => 1,
		     exists $param{location} ? (location => $param{location}):(),
		     exists $param{locks} ? (locks => $param{locks}):(),
		    );
    if (not @data or not defined $data[0]) {
	unfilelock(exists $param{locks}?$param{locks}:()); #for merge lock above
	$locks--;
	return ($locks,());
    }
    $locks++;
    my @bugs = split / /, $data[0]->{mergedwith};
    push @bugs, $param{bug};
    for my $bug (@bugs) {
	my $newdata = undef;
	if ($bug != $param{bug}) {
	    $newdata =
		read_bug(bug => $bug,
			 lock => 1,
			 exists $param{location} ? (location => $param{location}):(),
			 exists $param{locks} ? (locks => $param{locks}):(),
			);
	    if (not defined $newdata) {
		for (1..$locks) {
		    unfilelock(exists $param{locks}?$param{locks}:());
		}
		$locks = 0;
		warn "Unable to read bug: $bug while handling merged bug: $param{bug}";
		return ($locks,());
	    }
	    $locks++;
	    push @data,$newdata;
	    # perform a sanity check to make sure that the merged bugs
	    # are all merged with eachother
        # We do a cmp sort instead of an <=> sort here, because that's
        # what merge does
	    my $expectmerge=
		join(' ',grep {$_ != $bug }
		     sort { $a <=> $b }
		     @bugs);
	    if ($newdata->{mergedwith} ne $expectmerge) {
		for (1..$locks) {
		    unfilelock(exists $param{locks}?$param{locks}:());
		}
		die "Bug $param{bug} mergedwith differs from bug $bug: ($newdata->{bug_num}: '$newdata->{mergedwith}') vs. ('$expectmerge') (".join(' ',@bugs).")";
	    }
	}
    }
    return ($locks,@data);
}

=head2 new_bug

	my $new_bug_num = new_bug(copy => $data->{bug_num});

Creates a new bug and returns the new bug number upon success.

Dies upon failures.

=cut

sub new_bug {
    my %param =
	validate_with(params => \@_,
		      spec => {copy => {type => SCALAR,
				        regex => qr/^\d+/,
				        optional => 1,
				       },
			      },
		     );
    filelock("nextnumber.lock");
    my $nn_fh = IO::File->new("nextnumber",'r') or
	die "Unable to open nextnuber for reading: $!";
    local $\;
    my $nn = <$nn_fh>;
    ($nn) = $nn =~ m/^(\d+)\n$/ or die "Bad format of nextnumber; is not exactly ".'^\d+\n$';
    close $nn_fh;
    overwritefile("nextnumber",
		  ($nn+1)."\n");
    unfilelock();
    my $nn_hash = get_hashname($nn);
    if ($param{copy}) {
	my $c_hash = get_hashname($param{copy});
	for my $file (qw(log status summary report)) {
	    copy("db-h/$c_hash/$param{copy}.$file",
		 "db-h/$nn_hash/${nn}.$file")
	}
    }
    else {
	for my $file (qw(log status summary report)) {
	    overwritefile("db-h/$nn_hash/${nn}.$file",
			   "");
	}
    }

    # this probably needs to be munged to do something more elegant
#    &bughook('new', $clone, $data);

    return($nn);
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
    $version = 3 unless defined $version;

    my $contents = '';

    my %newdata = %$data;
    for my $field (qw(found fixed)) {
	 if (exists $newdata{$field}) {
	      $newdata{"${field}_date"} =
		   [map {$newdata{$field}{$_}||''} keys %{$newdata{$field}}];
	 }
    }
    %newdata = %{join_status_fields(\%newdata)};

    %newdata = encode_utf8_structure(%newdata);

    if ($version < 3) {
        for my $field (@rfc1522_fields) {
            $newdata{$field} = encode_rfc1522($newdata{$field});
        }
    }

    # this is a bit of a hack; we should never, ever have \r or \n in
    # the fields of status. Kill them off here. [Eventually, this
    # should be superfluous.]
    for my $field (keys %newdata) {
	$newdata{$field} =~ s/[\r\n]//g if defined $newdata{$field};
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
		my $data = $newdata{$field};
                $contents .= "$properfield: $data\n";
            }
        }
    }
    return $contents;
}

=head2 writebug

     writebug($bug_num,$status,$location,$minversion,$disablebughook)

Writes the bug status and summary files out.

Skips writing out a status file if minversion is 2

Does not call bughook if disablebughook is true.

=cut

sub writebug {
    my ($ref, $data, $location, $minversion, $disablebughook) = @_;
    my $change;

    my %outputs = (1 => 'status', 3 => 'summary');
    for my $version (keys %outputs) {
        next if defined $minversion and $version < $minversion;
        my $status = getbugcomponent($ref, $outputs{$version}, $location);
        die "can't find location for $ref" unless defined $status;
	my $sfh;
	if ($version >= 3) {
	    open $sfh,">","$status.new"  or
		die "opening $status.new: $!";
	}
	else {
	    open $sfh,">","$status.new"  or
		die "opening $status.new: $!";
	}
        print {$sfh} makestatus($data, $version) or
            die "writing $status.new: $!";
        close($sfh) or die "closing $status.new: $!";
        if (-e $status) {
            $change = 'change';
        } else {
            $change = 'new';
        }
        rename("$status.new",$status) || die "installing new $status: $!";
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
    unfilelock();
}

=head1 VERSIONS

The following functions are exported with the :versions tag

=head2 addfoundversions

     addfoundversions($status,$package,$version,$isbinary);

All use of this should be phased out in favor of Debbugs::Control::fixed/found

=cut


sub addfoundversions {
    my $data = shift;
    my $package = shift;
    my $version = shift;
    my $isbinary = shift;
    return unless defined $version;
    undef $package if defined $package and $package =~ m[(?:\s|/)];
    my $source = $package;
    if (defined $package and $package =~ s/^src://) {
	$isbinary = 0;
	$source = $package;
    }

    if (defined $package and $isbinary) {
        my @srcinfo = binary_to_source(binary => $package,
				       version => $version);
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
for backwards compatibility.

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
    undef $package if defined $package and $package =~ m[(?:\s|/)];
    my $source = $package;

    if (defined $package and $isbinary) {
        my @srcinfo = binary_to_source(binary => $package,
				       version => $version);
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

    foreach my $ver (split /[,\s]+/, $version) {
	 if ($ver =~ m{/}) {
	      # fully qualified version
	      @{$data->{fixed_versions}} =
		   grep {$_ ne $ver}
			@{$data->{fixed_versions}};
	 }
	 else {
	      # non qualified version; delete all matchers
	      @{$data->{fixed_versions}} =
		   grep {$_ !~ m[(?:^|/)\Q$ver\E$]}
			@{$data->{fixed_versions}};
	 }
    }
}



=head2 splitpackages

     splitpackages($pkgs)

Split a package string from the status file into a list of package names.

=cut

sub splitpackages {
    my $pkgs = shift;
    return unless defined $pkgs;
    return grep {length $_} map lc, split /[\s,()?]+/, $pkgs;
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
our $version_cache = {};
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
					  ignore_time => {type => BOOLEAN,
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
	  if (not defined $status) {
	       print STDERR "Cannot archive $param{bug} because it does not exist\n" if $DEBUG;
	       return undef;
	  }
     }
     # Bugs can be archived if they are
     # 1. Closed
     if (not defined $status->{done} or not length $status->{done}) {
	  print STDERR "Cannot archive $param{bug} because it is not done\n" if $DEBUG;
	  return $cannot_archive
     }
     # Check to make sure that the bug has none of the unremovable tags set
     if (@{$config{removal_unremovable_tags}}) {
	  for my $tag (split ' ', ($status->{keywords}||'')) {
	       if (grep {$tag eq $_} @{$config{removal_unremovable_tags}}) {
		    print STDERR "Cannot archive $param{bug} because it has an unremovable tag '$tag'\n" if $DEBUG;
		    return $cannot_archive;
	       }
	  }
     }

     # If we just are checking if the bug can be archived, we'll not even bother
     # checking the versioning information if the bug has been -done for less than 28 days.
     my $log_file = getbugcomponent($param{bug},'log');
     if (not defined $log_file) {
	  print STDERR "Cannot archive $param{bug} because the log doesn't exist\n" if $DEBUG;
	  return $cannot_archive;
     }
     my $max_log_age = max(map {$config{remove_age} - -M $_}
			   $log_file, map {my $log = getbugcomponent($_,'log');
					   defined $log ? ($log) : ();
				      }
			   split / /, $status->{mergedwith}
		       );
     if (not $param{days_until} and not $param{ignore_time}
	 and $max_log_age > 0
	) {
	  print STDERR "Cannot archive $param{bug} because of time\n" if $DEBUG;
	  return $cannot_archive;
     }
     # At this point, we have to get the versioning information for this bug.
     # We examine the set of distribution tags. If a bug has no distribution
     # tags set, we assume a default set, otherwise we use the tags the bug
     # has set.

     # In cases where we are assuming a default set, if the severity
     # is strong, we use the strong severity default; otherwise, we
     # use the normal default.

     # There must be fixed_versions for us to look at the versioning
     # information
     my $min_fixed_time = time;
     my $min_archive_days = 0;
     if (@{$status->{fixed_versions}}) {
	  my %dist_tags;
	  @dist_tags{@{$config{removal_distribution_tags}}} =
	       (1) x @{$config{removal_distribution_tags}};
	  my %dists;
	  for my $tag (split ' ', ($status->{keywords}||'')) {
	       next unless exists $config{distribution_aliases}{$tag};
	       next unless $dist_tags{$config{distribution_aliases}{$tag}};
	       $dists{$config{distribution_aliases}{$tag}} = 1;
	  }
	  if (not keys %dists) {
	       if (isstrongseverity($status->{severity})) {
		    @dists{@{$config{removal_strong_severity_default_distribution_tags}}} =
			 (1) x @{$config{removal_strong_severity_default_distribution_tags}};
	       }
	       else {
		    @dists{@{$config{removal_default_distribution_tags}}} =
			 (1) x @{$config{removal_default_distribution_tags}};
	       }
	  }
	  my %source_versions;
	  my @sourceversions = get_versions(package => $status->{package},
					    dist => [keys %dists],
					    source => 1,
					   );
	  @source_versions{@sourceversions} = (1) x @sourceversions;
	  # If the bug has not been fixed in the versions actually
	  # distributed, then it cannot be archived.
	  if ('found' eq max_buggy(bug => $param{bug},
				   sourceversions => [keys %source_versions],
				   found          => $status->{found_versions},
				   fixed          => $status->{fixed_versions},
				   version_cache  => $version_cache,
				   package        => $status->{package},
				  )) {
	       print STDERR "Cannot archive $param{bug} because it's found\n" if $DEBUG;
	       return $cannot_archive;
	  }
	  # Since the bug has at least been fixed in the architectures
	  # that matters, we check to see how long it has been fixed.

	  # If $param{ignore_time}, then we should ignore time.
	  if ($param{ignore_time}) {
	       return $param{days_until}?0:1;
	  }

	  # To do this, we order the times from most recent to oldest;
	  # when we come to the first found version, we stop.
	  # If we run out of versions, we only report the time of the
	  # last one.
	  my %time_versions = get_versions(package => $status->{package},
					   dist    => [keys %dists],
					   source  => 1,
					   time    => 1,
					  );
	  for my $version (sort {$time_versions{$b} <=> $time_versions{$a}} keys %time_versions) {
	       my $buggy = buggy(bug => $param{bug},
				 version        => $version,
				 found          => $status->{found_versions},
				 fixed          => $status->{fixed_versions},
				 version_cache  => $version_cache,
				 package        => $status->{package},
				);
	       last if $buggy eq 'found';
	       $min_fixed_time = min($time_versions{$version},$min_fixed_time);
	  }
	  $min_archive_days = max($min_archive_days,ceil($config{remove_age} - (time - $min_fixed_time)/(60*60*24)))
	       # if there are no versions in the archive at all, then
	       # we can archive if enough days have passed
	       if @sourceversions;
     }
     # If $param{ignore_time}, then we should ignore time.
     if ($param{ignore_time}) {
	  return $param{days_until}?0:1;
     }
     # 6. at least 28 days have passed since the last action has occured or the bug was closed
     my $age = ceil($max_log_age);
     if ($age > 0 or $min_archive_days > 0) {
	  print STDERR "Cannot archive $param{bug} because not enough days have passed\n" if $DEBUG;
	  return $param{days_until}?max($age,$min_archive_days):0;
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

=item version -- optional version(s) to check package status at

=item dist -- optional distribution(s) to check package status at

=item arch -- optional architecture(s) to check package status at

=item bugusertags -- optional hashref of bugusertags

=item sourceversion -- optional arrayref of source/version; overrides
dist, arch, and version. [The entries in this array must be in the
"source/version" format.] Eventually this can be used to for caching.

=item indicatesource -- if true, indicate which source packages this
bug could belong to (or does belong to in the case of bugs assigned to
a source package). Defaults to true.

=back

Note: Currently the version information is cached; this needs to be
changed before using this function in long lived programs.

=head3 Returns

Currently returns a hashref of status with the following keys.

=over

=item id -- bug number

=item bug_num -- duplicate of id

=item keywords -- tags set on the bug, including usertags if bugusertags passed.

=item tags -- duplicate of keywords

=item package -- name of package that the bug is assigned to

=item severity -- severity of the bug

=item pending -- pending state of the bug; one of following possible
values; values listed later have precedence if multiple conditions are
satisifed:

=over

=item pending -- default state

=item forwarded -- bug has been forwarded

=item pending-fixed -- bug is tagged pending

=item fixed -- bug is tagged fixed

=item absent -- bug does not apply to this distribution/architecture

=item done -- bug is resolved in this distribution/architecture

=back

=item location -- db-h or archive; the location in the filesystem

=item subject -- title of the bug

=item last_modified -- epoch that the bug was last modified

=item date -- epoch that the bug was filed

=item originator -- bug reporter

=item log_modified -- epoch that the log file was last modified

=item msgid -- Message id of the original bug report

=back


Other key/value pairs are returned but are not currently documented here.

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
					  version   => {type => SCALAR|ARRAYREF,
							optional => 1,
						       },
					  dist       => {type => SCALAR|ARRAYREF,
							 optional => 1,
							},
					  arch       => {type => SCALAR|ARRAYREF,
							 optional => 1,
							},
					  bugusertags   => {type => HASHREF,
							    optional => 1,
							   },
					  sourceversions => {type => ARRAYREF,
							     optional => 1,
							    },
					  indicatesource => {type => BOOLEAN,
							     default => 1,
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
	  return {} if not defined $location or not length $location;
	  %status = %{ readbug( $param{bug}, $location ) };
     }
     $status{id} = $param{bug};

     if (defined $param{bugusertags}{$param{bug}}) {
	  $status{keywords} = "" unless defined $status{keywords};
	  $status{keywords} .= " " unless $status{keywords} eq "";
	  $status{keywords} .= join(" ", @{$param{bugusertags}{$param{bug}}});
     }
     $status{tags} = $status{keywords};
     my %tags = map { $_ => 1 } split ' ', $status{tags};

     $status{package} = '' if not defined $status{package};
     $status{"package"} =~ s/\s*$//;

     $status{source} = binary_to_source(binary=>[split /\s*,\s*/, $status{package}],
					source_only => 1,
				       );

     $status{"package"} = 'unknown' if ($status{"package"} eq '');
     $status{"severity"} = 'normal' if (not defined $status{severity} or $status{"severity"} eq '');

     $status{"pending"} = 'pending';
     $status{"pending"} = 'forwarded'	    if (length($status{"forwarded"}));
     $status{"pending"} = 'pending-fixed'    if ($tags{pending});
     $status{"pending"} = 'fixed'	    if ($tags{fixed});


     my $presence = bug_presence(status => \%status,
				 map{(exists $param{$_})?($_,$param{$_}):()}
				 qw(bug sourceversions arch dist version found fixed package)
				);
     if (defined $presence) {
	  if ($presence eq 'fixed') {
	       $status{pending} = 'done';
	  }
	  elsif ($presence eq 'absent') {
	       $status{pending} = 'absent';
	  }
     }
     return \%status;
}

=head2 bug_presence

     my $precence = bug_presence(bug => nnn,
                                 ...
                                );

Returns 'found', 'absent', 'fixed' or undef based on whether the bug
is found, absent, fixed, or no information is available in the
distribution (dist) and/or architecture (arch) specified.


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

=item sourceversion -- optional arrayref of source/version; overrides
dist, arch, and version. [The entries in this array must be in the
"source/version" format.] Eventually this can be used to for caching.

=back

=cut

sub bug_presence {
     my %param = validate_with(params => \@_,
			       spec   => {bug       => {type => SCALAR,
							regex => qr/^\d+$/,
						       },
					  status    => {type => HASHREF,
						        optional => 1,
						       },
					  version   => {type => SCALAR|ARRAYREF,
							optional => 1,
						       },
					  dist       => {type => SCALAR|ARRAYREF,
							 optional => 1,
							},
					  arch       => {type => SCALAR|ARRAYREF,
							 optional => 1,
							},
					  sourceversions => {type => ARRAYREF,
							     optional => 1,
							    },
					 },
			      );
     my %status;
     if (defined $param{status}) {
	 %status = %{$param{status}};
     }
     else {
	  my $location = getbuglocation($param{bug}, 'summary');
	  return {} if not length $location;
	  %status = %{ readbug( $param{bug}, $location ) };
     }

     my @sourceversions;
     my $pseudo_desc = getpseudodesc();
     if (not exists $param{sourceversions}) {
	  my %sourceversions;
	  # pseudopackages do not have source versions by definition.
	  if (exists $pseudo_desc->{$status{package}}) {
	       # do nothing.
	  }
	  elsif (defined $param{version}) {
	       foreach my $arch (make_list($param{arch})) {
		    for my $package (split /\s*,\s*/, $status{package}) {
			 my @temp = makesourceversions($package,
						       $arch,
						       make_list($param{version})
						      );
			 @sourceversions{@temp} = (1) x @temp;
		    }
	       }
	  } elsif (defined $param{dist}) {
	       my %affects_distribution_tags;
	       @affects_distribution_tags{@{$config{affects_distribution_tags}}} =
		    (1) x @{$config{affects_distribution_tags}};
	       my $some_distributions_disallowed = 0;
	       my %allowed_distributions;
	       for my $tag (split ' ', ($status{keywords}||'')) {
		   if (exists $config{distribution_aliases}{$tag} and
			exists $affects_distribution_tags{$config{distribution_aliases}{$tag}}) {
		       $some_distributions_disallowed = 1;
		       $allowed_distributions{$config{distribution_aliases}{$tag}} = 1;
		   }
		   elsif (exists $affects_distribution_tags{$tag}) {
		       $some_distributions_disallowed = 1;
		       $allowed_distributions{$tag} = 1;
		   }
	       }
	       my @archs = make_list(exists $param{arch}?$param{arch}:());
	   GET_SOURCE_VERSIONS:
	       foreach my $arch (@archs) {
		   for my $package (split /\s*,\s*/, $status{package}) {
			 my @versions = ();
			 my $source = 0;
			 if ($package =~ /^src:(.+)$/) {
			     $source = 1;
			     $package = $1;
			 }
			 foreach my $dist (make_list(exists $param{dist}?$param{dist}:[])) {
			      # if some distributions are disallowed,
			      # and this isn't an allowed
			      # distribution, then we ignore this
			      # distribution for the purposees of
			      # finding versions
			      if ($some_distributions_disallowed and
				  not exists $allowed_distributions{$dist}) {
				   next;
			      }
			      push @versions, get_versions(package => $package,
							   dist    => $dist,
							   ($source?(arch => 'source'):
							    (defined $arch?(arch => $arch):())),
							  );
			 }
			 next unless @versions;
			 my @temp = make_source_versions(package => $package,
							 arch => $arch,
							 versions => \@versions,
							);
			 @sourceversions{@temp} = (1) x @temp;
		    }
	       }
	       # this should really be split out into a subroutine,
	       # but it'd touch so many things currently, that we fake
	       # it; it's needed to properly handle bugs which are
	       # erroneously assigned to the binary package, and we'll
	       # probably have it go away eventually.
 	       if (not keys %sourceversions and (not @archs or defined $archs[0])) {
 		   @archs = (undef);
 		   goto GET_SOURCE_VERSIONS;
 	       }
	  }

	  # TODO: This should probably be handled further out for efficiency and
	  # for more ease of distinguishing between pkg= and src= queries.
	  # DLA: src= queries should just pass arch=source, and they'll be happy.
	  @sourceversions = keys %sourceversions;
     }
     else {
	  @sourceversions = @{$param{sourceversions}};
     }
     my $maxbuggy = 'undef';
     if (@sourceversions) {
	  $maxbuggy = max_buggy(bug => $param{bug},
				sourceversions => \@sourceversions,
				found => $status{found_versions},
				fixed => $status{fixed_versions},
				package => $status{package},
				version_cache => $version_cache,
			       );
     }
     elsif (defined $param{dist} and
	    not exists $pseudo_desc->{$status{package}}) {
	  return 'absent';
     }
     if (length($status{done}) and
	 (not @sourceversions or not @{$status{fixed_versions}})) {
	  return 'fixed';
     }
     return $maxbuggy;
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
     for my $package (split /\s*,\s*/, $param{package}) {
	  for my $version (@{$param{sourceversions}}) {
	       my $buggy = buggy(bug => $param{bug},
				 version => $version,
				 found => $param{found},
				 fixed => $param{fixed},
				 version_cache => $param{version_cache},
				 package => $package,
				);
	       if ($buggy eq 'found') {
		    return 'found';
	       } elsif ($buggy eq 'fixed') {
		    $maxbuggy = 'fixed';
	       }
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
	  my ($version) = makesourceversions($param{package},undef,
					     $param{version}
					    );
	  $param{version} = $version if defined $version;
     }
     # Figure out which source packages we need
     my %sources;
     @sources{map {m{(.+)/}; $1} @found} = (1) x @found;
     @sources{map {m{(.+)/}; $1} @fixed} = (1) x @fixed;
     @sources{map {m{(.+)/}; $1} $param{version}} = 1 if
	  $param{version} =~ m{/};
     my $version;
     if (not defined $param{version_cache} or
	 not exists $param{version_cache}{join(',',sort keys %sources)}) {
	  $version = Debbugs::Versions->new(\&Debbugs::Versions::Dpkg::vercmp);
	  foreach my $source (keys %sources) {
	       my $srchash = substr $source, 0, 1;
	       my $version_fh = IO::File->new("$config{version_packages_dir}/$srchash/$source", 'r');
	       if (not defined $version_fh) {
		    # We only want to warn if it's a package which actually has a maintainer
		    my $maints = getmaintainers();
		    next if not exists $maints->{$source};
		    warn "Bug $param{bug}: unable to open $config{version_packages_dir}/$srchash/$source: $!";
		    next;
	       }
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
    $severity = $config{default_severity} if
	 not defined $severity or $severity eq '';
    return grep { $_ eq $severity } @{$config{strong_severities}};
}

=head1 indexdb

=head2 generate_index_db_line

      	my $data = read_bug(bug => $bug,
			    location => $initialdir);
        # generate_index_db_line hasn't been written yet at all.
        my $line = generate_index_db_line($data);

Returns a line for a bug suitable to be written out to index.db.

=cut

sub generate_index_db_line {
    my ($data,$bug) = @_;

    # just in case someone has given us a split out data
    $data = join_status_fields($data);

    my $whendone = "open";
    my $severity = $config{default_severity};
    (my $pkglist = $data->{package}) =~ s/[,\s]+/,/g;
    $pkglist =~ s/^,+//;
    $pkglist =~ s/,+$//;
    $whendone = "forwarded" if defined $data->{forwarded} and length $data->{forwarded};
    $whendone = "done" if defined $data->{done} and length $data->{done};
    $severity = $data->{severity} if length $data->{severity};
    return sprintf "%s %d %d %s [%s] %s %s\n",
        $pkglist, $data->{bug_num}//$bug, $data->{date}, $whendone,
            $data->{originator}, $severity, $data->{keywords};
}



=head1 PRIVATE FUNCTIONS

=cut

sub update_realtime {
	my ($file, %bugs) = @_;

	# update realtime index.db

	return () unless keys %bugs;
	my $idx_old = IO::File->new($file,'r')
	     or die "Couldn't open ${file}: $!";
	my $idx_new = IO::File->new($file.'.new','w')
	     or die "Couldn't open ${file}.new: $!";

        binmode($idx_old,':raw:utf8');
        binmode($idx_new,':raw:encoding(UTF-8)');
	my $min_bug = min(keys %bugs);
	my $line;
	my @line;
	my %changed_bugs;
	while($line = <$idx_old>) {
	     @line = split /\s/, $line;
	     # Two cases; replacing existing line or adding new line
	     if (exists $bugs{$line[1]}) {
		  my $new = $bugs{$line[1]};
		  delete $bugs{$line[1]};
		  $min_bug = min(keys %bugs);
		  if ($new eq "NOCHANGE") {
		       print {$idx_new} $line;
		       $changed_bugs{$line[1]} = $line;
		  } elsif ($new eq "REMOVE") {
		       $changed_bugs{$line[1]} = $line;
		  } else {
		       print {$idx_new} $new;
		       $changed_bugs{$line[1]} = $line;
		  }
	     }
	     else {
		  while ($line[1] > $min_bug) {
		       print {$idx_new} $bugs{$min_bug};
		       delete $bugs{$min_bug};
		       last unless keys %bugs;
		       $min_bug = min(keys %bugs);
		  }
		  print {$idx_new} $line;
	     }
	     last unless keys %bugs;
	}
	print {$idx_new} map {$bugs{$_}} sort keys %bugs;

	print {$idx_new} <$idx_old>;

	close($idx_new);
	close($idx_old);

	rename("$file.new", $file);

	return %changed_bugs;
}

sub bughook_archive {
	my @refs = @_;
	filelock("$config{spool_dir}/debbugs.trace.lock");
	appendfile("$config{spool_dir}/debbugs.trace","archive ".join(',',@refs)."\n");
	my %bugs = update_realtime("$config{spool_dir}/index.db.realtime",
				   map{($_,'REMOVE')} @refs);
	update_realtime("$config{spool_dir}/index.archive.realtime",
			%bugs);
	unfilelock();
}

sub bughook {
	my ( $type, %bugs_temp ) = @_;
	filelock("$config{spool_dir}/debbugs.trace.lock");

	my %bugs;
	for my $bug (keys %bugs_temp) {
	     my $data = $bugs_temp{$bug};
	     appendfile("$config{spool_dir}/debbugs.trace","$type $bug\n",makestatus($data, 1));

	     $bugs{$bug} = generate_index_db_line($data,$bug);
	}
	update_realtime("$config{spool_dir}/index.db.realtime", %bugs);

	unfilelock();
}


1;

__END__

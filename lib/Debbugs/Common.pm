# This module is part of debbugs, and is released
# under the terms of the GPL version 2, or any later
# version at your option.
# See the file README and COPYING for more information.
#
# [Other people have contributed to this file; their copyrights should
# go here too.]
# Copyright 2007 by Don Armstrong <don@donarmstrong.com>.

package Debbugs::Common;

=head1 NAME

Debbugs::Common -- Common routines for all of Debbugs

=head1 SYNOPSIS

use Debbugs::Common qw(:url :html);


=head1 DESCRIPTION

This module is a replacement for the general parts of errorlib.pl.
subroutines in errorlib.pl will be gradually phased out and replaced
with equivalent (or better) functionality here.

=head1 FUNCTIONS

=cut

use warnings;
use strict;
use vars qw($VERSION $DEBUG %EXPORT_TAGS @EXPORT_OK @EXPORT);
use Exporter qw(import);
use v5.10;

BEGIN{
     $VERSION = 1.00;
     $DEBUG = 0 unless defined $DEBUG;

     @EXPORT = ();
     %EXPORT_TAGS = (util   => [qw(getbugcomponent getbuglocation getlocationpath get_hashname),
				qw(appendfile overwritefile buglog getparsedaddrs getmaintainers),
                                qw(getsourcemaintainers getsourcemaintainers_reverse),
				qw(bug_status),
				qw(getmaintainers_reverse),
				qw(getpseudodesc),
				qw(package_maintainer),
				qw(sort_versions),
				qw(open_compressed_file),
				qw(walk_bugs),
			       ],
		     misc   => [qw(make_list globify_scalar english_join checkpid),
				qw(cleanup_eval_fail),
				qw(hash_slice),
			       ],
		     date   => [qw(secs_to_english)],
		     quit   => [qw(quit)],
		     lock   => [qw(filelock unfilelock lockpid simple_filelock simple_unlockfile)],
		    );
     @EXPORT_OK = ();
     Exporter::export_ok_tags(keys %EXPORT_TAGS);
     $EXPORT_TAGS{all} = [@EXPORT_OK];
}

#use Debbugs::Config qw(:globals);

use Carp;
$Carp::Verbose = 1;

use Debbugs::Config qw(:config);
use IO::File;
use IO::Scalar;
use Debbugs::MIME qw(decode_rfc1522);
use Mail::Address;
use Cwd qw(cwd);
use Storable qw(dclone);
use Time::HiRes qw(usleep);
use File::Path qw(mkpath);
use File::Basename qw(dirname);
use MLDBM qw(DB_File Storable);
$MLDBM::DumpMeth='portable';
use List::AllUtils qw(natatime);

use Params::Validate qw(validate_with :types);

use Fcntl qw(:DEFAULT :flock);
use Encode qw(is_utf8 decode_utf8);

our $DEBUG_FH = \*STDERR if not defined $DEBUG_FH;

=head1 UTILITIES

The following functions are exported by the C<:util> tag

=head2 getbugcomponent

     my $file = getbugcomponent($bug_number,$extension,$location)

Returns the path to the bug file in location C<$location>, bug number
C<$bugnumber> and extension C<$extension>

=cut

sub getbugcomponent {
    my ($bugnum, $ext, $location) = @_;

    if (not defined $location) {
	$location = getbuglocation($bugnum, $ext);
	# Default to non-archived bugs only for now; CGI scripts want
	# archived bugs but most of the backend scripts don't. For now,
	# anything that is prepared to accept archived bugs should call
	# getbuglocation() directly first.
	return undef if defined $location and
			($location ne 'db' and $location ne 'db-h');
    }
    my $dir = getlocationpath($location);
    return undef if not defined $dir;
    if (defined $location and $location eq 'db') {
	return "$dir/$bugnum.$ext";
    } else {
	my $hash = get_hashname($bugnum);
	return "$dir/$hash/$bugnum.$ext";
    }
}

=head2 getbuglocation

     getbuglocation($bug_number,$extension)

Returns the the location in which a particular bug exists; valid
locations returned currently are archive, db-h, or db. If the bug does
not exist, returns undef.

=cut

sub getbuglocation {
    my ($bugnum, $ext) = @_;
    my $archdir = get_hashname($bugnum);
    return 'archive' if -r getlocationpath('archive')."/$archdir/$bugnum.$ext";
    return 'db-h' if -r getlocationpath('db-h')."/$archdir/$bugnum.$ext";
    return 'db' if -r getlocationpath('db')."/$bugnum.$ext";
    return undef;
}


=head2 getlocationpath

     getlocationpath($location)

Returns the path to a specific location

=cut

sub getlocationpath {
     my ($location) = @_;
     if (defined $location and $location eq 'archive') {
	  return "$config{spool_dir}/archive";
     } elsif (defined $location and $location eq 'db') {
	  return "$config{spool_dir}/db";
     } else {
	  return "$config{spool_dir}/db-h";
     }
}


=head2 get_hashname

     get_hashname

Returns the hash of the bug which is the location within the archive

=cut

sub get_hashname {
    return "" if ( $_[ 0 ] < 0 );
    return sprintf "%02d", $_[ 0 ] % 100;
}

=head2 buglog

     buglog($bugnum);

Returns the path to the logfile corresponding to the bug.

Returns undef if the bug does not exist.

=cut

sub buglog {
    my $bugnum = shift;
    my $location = getbuglocation($bugnum, 'log');
    return getbugcomponent($bugnum, 'log', $location) if ($location);
    $location = getbuglocation($bugnum, 'log.gz');
    return getbugcomponent($bugnum, 'log.gz', $location) if ($location);
    return undef;
}

=head2 bug_status

     bug_status($bugnum)


Returns the path to the summary file corresponding to the bug.

Returns undef if the bug does not exist.

=cut

sub bug_status{
    my ($bugnum) = @_;
    my $location = getbuglocation($bugnum, 'summary');
    return getbugcomponent($bugnum, 'summary', $location) if ($location);
    return undef;
}

=head2 appendfile

     appendfile($file,'data','to','append');

Opens a file for appending and writes data to it.

=cut

sub appendfile {
	my ($file,@data) = @_;
	my $fh = IO::File->new($file,'a') or
	     die "Unable top open $file for appending: $!";
	print {$fh} @data or die "Unable to write to $file: $!";
	close $fh or die "Unable to close $file: $!";
}

=head2 overwritefile

     ovewritefile($file,'data','to','append');

Opens file.new, writes data to it, then moves file.new to file.

=cut

sub overwritefile {
	my ($file,@data) = @_;
	my $fh = IO::File->new("${file}.new",'w') or
	     die "Unable top open ${file}.new for writing: $!";
	print {$fh} @data or die "Unable to write to ${file}.new: $!";
	close $fh or die "Unable to close ${file}.new: $!";
	rename("${file}.new",$file) or
	    die "Unable to rename ${file}.new to $file: $!";
}

=head2 open_compressed_file

     my $fh = open_compressed_file('foo.gz') or
          die "Unable to open compressed file: $!";


Opens a file; if the file ends in .gz, .xz, or .bz2, the appropriate
decompression program is forked and output from it is read.

This routine by default opens the file with UTF-8 encoding; if you want some
other encoding, specify it with the second option.

=cut
sub open_compressed_file {
    my ($file,$encoding) = @_;
    $encoding //= ':encoding(UTF-8)';
    my $fh;
    my $mode = "<$encoding";
    my @opts;
    if ($file =~ /\.gz$/) {
	$mode = "-|$encoding";
	push @opts,'gzip','-dc';
    }
    if ($file =~ /\.xz$/) {
	$mode = "-|$encoding";
	push @opts,'xz','-dc';
    }
    if ($file =~ /\.bz2$/) {
	$mode = "-|$encoding";
	push @opts,'bzip2','-dc';
    }
    open($fh,$mode,@opts,$file);
    return $fh;
}

=head2 walk_bugs

Walk through directories of bugs, calling a subroutine with a list of bugs
found.

C<walk_bugs(callback => sub {print map {qq($_\n)} @_},dirs => [qw(db-h)];>

=over

=item callback -- CODEREF of a subroutine to call with a list of bugs

=item dirs -- ARRAYREF of directories to get bugs from. Like C<[qw(db-h archive)]>.

=item bugs -- ARRAYREF of bugs to walk through. If both C<dirs> and C<bugs> are
provided, both are walked through.

=item bugs_per_call -- maximum number of bugs to provide to callback

=item progress_bar -- optional L<Term::ProgressBar>

=item bug_file -- bug file to look for (generally C<summary>)

=item logging -- optional filehandle to output logging information

=back

=cut

sub walk_bugs {
    state $spec =
       {dirs => {type => ARRAYREF,
		 default => [],
		},
	bugs => {type => ARRAYREF,
		 default => [],
		},
	progress_bar => {type => OBJECT|UNDEF,
			 optional => 1,
			},
	bug_file => {type => SCALAR,
		     default => 'summary',
		    },
	logging => {type => HANDLE,
		    optional => 1,
		   },
	callback => {type => CODEREF,
		    },
	bugs_per_call => {type => SCALAR,
			  default => 1,
			 },
       };
    my %param = validate_with(params => \@_,
			      spec => $spec
			     );
    my @dirs = @{$param{dirs}};
    my @initial_bugs = ();
    if (@{$param{bugs}}) {
	unshift @dirs,'';
	@initial_bugs = @{$param{bugs}};
    }
    my $tot_dirs = @dirs;
    my $done_dirs = 0;
    my $avg_subfiles = 0;
    my $completed_files = 0;
    my $dir;
    while ($dir = shift @dirs or defined $dir) {
	my @list;
	my @subdirs;
	if (not length $dir and @initial_bugs) {
	    push @list,@initial_bugs;
	    @initial_bugs = ();
	} else {
	    printf {$param{verbose}} "Doing dir %s ...\n", $dir
		if defined $param{verbose};
	    opendir(my $DIR, "$dir/.") or
		die "opendir $dir: $!";
	    @subdirs = readdir($DIR) or
		die "Unable to readdir $dir: $!";
	    closedir($DIR) or
		die "Unable to closedir $dir: $!";

	    @list = map { m/^(\d+)\.$param{bug_file}$/?($1):() } @subdirs;
	}
        $tot_dirs -= @dirs;
        push @dirs, map { m/^(\d+)$/ && -d "$dir/$1"?("$dir/$1"):() } @subdirs;
        $tot_dirs += @dirs;
	if ($param{progress_bar}) {
	    if ($avg_subfiles == 0) {
		$avg_subfiles = @list;
	    }
	    $param{progress_bar}->
		target($avg_subfiles*($tot_dirs-$done_dirs)+$completed_files+@list);
	    $avg_subfiles = ($avg_subfiles * $done_dirs + @list) / ($done_dirs+1);
	    $done_dirs += 1;
	}

	my $it = natatime $param{bugs_per_call},@list;
	while (my @bugs = $it->()) {
	    $param{callback}->(@bugs);
	    $completed_files += scalar @bugs;
	    if ($param{progress_bar}) {
		$param{progress_bar}->update($completed_files) if $param{progress_bar};
	    }
	    if ($completed_files % 100 == 0 and
		defined $param{verbose}) {
		print {$param{verbose}} "Up to $completed_files bugs...\n"
	    }
        }
    }
    $param{progress_bar}->remove() if $param{progress_bar};
}


=head2 getparsedaddrs

     my $address = getparsedaddrs($address);
     my @address = getparsedaddrs($address);

Returns the output from Mail::Address->parse, or the cached output if
this address has been parsed before. In SCALAR context returns the
first address parsed.

=cut


our %_parsedaddrs;
sub getparsedaddrs {
    my $addr = shift;
    return () unless defined $addr;
    return wantarray?@{$_parsedaddrs{$addr}}:$_parsedaddrs{$addr}[0]
	 if exists $_parsedaddrs{$addr};
    {
	 # don't display the warnings from Mail::Address->parse
	 local $SIG{__WARN__} = sub { };
	 @{$_parsedaddrs{$addr}} = Mail::Address->parse($addr);
    }
    return wantarray?@{$_parsedaddrs{$addr}}:$_parsedaddrs{$addr}[0];
}

=head2 getmaintainers

     my $maintainer = getmaintainers()->{debbugs}

Returns a hashref of package => maintainer pairs.

=cut

our $_maintainer = undef;
our $_maintainer_rev = undef;
sub getmaintainers {
    return $_maintainer if defined $_maintainer;
    package_maintainer(rehash => 1);
    return $_maintainer;
}

=head2 getmaintainers_reverse

     my @packages = @{getmaintainers_reverse->{'don@debian.org'}||[]};

Returns a hashref of maintainer => [qw(list of packages)] pairs.

=cut

sub getmaintainers_reverse{
     return $_maintainer_rev if defined $_maintainer_rev;
     package_maintainer(rehash => 1);
     return $_maintainer_rev;
}

=head2 getsourcemaintainers

     my $maintainer = getsourcemaintainers()->{debbugs}

Returns a hashref of src_package => maintainer pairs.

=cut

our $_source_maintainer = undef;
our $_source_maintainer_rev = undef;
sub getsourcemaintainers {
    return $_source_maintainer if defined $_source_maintainer;
    package_maintainer(rehash => 1);
    return $_source_maintainer;
}

=head2 getsourcemaintainers_reverse

     my @src_packages = @{getsourcemaintainers_reverse->{'don@debian.org'}||[]};

Returns a hashref of maintainer => [qw(list of source packages)] pairs.

=cut

sub getsourcemaintainers_reverse{
     return $_source_maintainer_rev if defined $_source_maintainer_rev;
     package_maintainer(rehash => 1);
     return $_source_maintainer_rev;
}

=head2 package_maintainer

     my @s = package_maintainer(source => [qw(foo bar baz)],
                                binary => [qw(bleh blah)],
                               );

=over

=item source -- scalar or arrayref of source package names to return
maintainers for, defaults to the empty arrayref.

=item binary -- scalar or arrayref of binary package names to return
maintainers for; automatically returns source package maintainer if
the package name starts with 'src:', defaults to the empty arrayref.

=item maintainer -- scalar or arrayref of maintainers to return source packages
for. If given, binary and source cannot be given.

=item rehash -- whether to reread the maintainer and source maintainer
files; defaults to 0

=item schema -- Debbugs::DB schema. If set, uses the database for maintainer
information.

=back

=cut

sub package_maintainer {
    my %param = validate_with(params => \@_,
			      spec   => {source => {type => SCALAR|ARRAYREF,
						    default => [],
						   },
					 binary => {type => SCALAR|ARRAYREF,
						    default => [],
						   },
					 maintainer => {type => SCALAR|ARRAYREF,
							default => [],
						       },
					 rehash => {type => BOOLEAN,
						    default => 0,
						   },
					 reverse => {type => BOOLEAN,
						     default => 0,
						    },
					 schema => {type => OBJECT,
						    optional => 1,
						   }
					},
			     );
    my @binary = make_list($param{binary});
    my @source = make_list($param{source});
    my @maintainers = make_list($param{maintainer});
    if ((@binary or @source) and @maintainers) {
	croak "It is nonsensical to pass both maintainers and source or binary";
    }
    if (@binary) {
	@source = grep {/^src:/} @binary;
	@binary = grep {!/^src:/} @binary;
    }
    # remove leading src: from source package names
    s/^src:// foreach @source;
    if ($param{schema}) {
	my $s = $param{schema};
	if (@maintainers) {
	    my $m_rs = $s->resultset('SrcPkg')->
		search({'correspondent.addr' => [@maintainers]},
		      {join => {src_vers =>
			       {maintainer =>
				'correspondent'},
			       },
		       columns => ['pkg'],
		       group_by => [qw(me.pkg)],
		       });
	    return $m_rs->get_column('pkg')->all();
	} elsif (@binary or @source) {
	    my $rs = $s->resultset('Maintainer');
	    if (@binary) {
		$rs =
		    $rs->search({'bin_pkg.pkg' => [@binary]},
			       {join => {src_vers =>
					{bin_vers => 'bin_pkg'},
					},
				columns => ['name'],
				group_by => [qw(me.name)],
			       }
			       );
	    }
	    if (@source) {
		$rs =
		    $rs->search({'src_pkg.pkg' => [@source]},
			       {join => {src_vers =>
					 'src_pkg',
					},
				columns => ['name'],
				group_by => [qw(me.name)],
			       }
			       );
	    }
	    return $rs->get_column('name')->all();
	}
	return ();
    }
    if ($param{rehash}) {
	$_source_maintainer = undef;
	$_source_maintainer_rev = undef;
	$_maintainer = undef;
	$_maintainer_rev = undef;
    }
    if (not defined $_source_maintainer or
	not defined $_source_maintainer_rev) {
	$_source_maintainer = {};
	$_source_maintainer_rev = {};
	if (-e $config{spool_dir}.'/source_maintainers.idx' and
	    -e $config{spool_dir}.'/source_maintainers_reverse.idx'
	   ) {
	    tie %{$_source_maintainer},
		MLDBM => $config{spool_dir}.'/source_maintainers.idx',
		O_RDONLY or
		die "Unable to tie source maintainers: $!";
	    tie %{$_source_maintainer_rev},
		MLDBM => $config{spool_dir}.'/source_maintainers_reverse.idx',
		O_RDONLY or
		die "Unable to tie source maintainers reverse: $!";
	} else {
	    for my $fn (@config{('source_maintainer_file',
				 'source_maintainer_file_override',
				 'pseudo_maint_file')}) {
		next unless defined $fn and length $fn;
		if (not -e $fn) {
		    warn "Missing source maintainer file '$fn'";
		    next;
		}
		__add_to_hash($fn,$_source_maintainer,
			      $_source_maintainer_rev);
	    }
	}
    }
    if (not defined $_maintainer or
	not defined $_maintainer_rev) {
	$_maintainer = {};
	$_maintainer_rev = {};
	if (-e $config{spool_dir}.'/binary_maintainers.idx' and
	    -e $config{spool_dir}.'/binary_maintainers_reverse.idx'
	   ) {
	    tie %{$_maintainer},
		MLDBM => $config{spool_dir}.'/binary_maintainers.idx',
		O_RDONLY or
		die "Unable to tie binary maintainers: $!";
	    tie %{$_maintainer_rev},
		MLDBM => $config{spool_dir}.'/binary_maintainers_reverse.idx',
		O_RDONLY or
		die "Unable to binary maintainers reverse: $!";
	} else {
	    for my $fn (@config{('maintainer_file',
				 'maintainer_file_override',
				 'pseudo_maint_file')}) {
		next unless defined $fn and length $fn;
		if (not -e $fn) {
		    warn "Missing maintainer file '$fn'";
		    next;
		}
		__add_to_hash($fn,$_maintainer,
			      $_maintainer_rev);
	    }
	}
    }
    my @return;
    for my $binary (@binary) {
	if ($binary =~ /^src:/) {
	    push @source,$binary;
	    next;
	}
	push @return,grep {defined $_} make_list($_maintainer->{$binary});
    }
    for my $source (@source) {
	$source =~ s/^src://;
	push @return,grep {defined $_} make_list($_source_maintainer->{$source});
    }
    for my $maintainer (grep {defined $_} @maintainers) {
	push @return,grep {defined $_}
	    make_list($_maintainer_rev->{$maintainer});
	push @return,map {$_ !~ /^src:/?'src:'.$_:$_} 
	    grep {defined $_}
		make_list($_source_maintainer_rev->{$maintainer});
    }
    return @return;
}

#=head2 __add_to_hash
#
#     __add_to_hash($file,$forward_hash,$reverse_hash,'address');
#
# Reads a maintainer/source maintainer/pseudo desc file and adds the
# maintainers from it to the forward and reverse hashref; assumes that
# the forward is unique; makes no assumptions of the reverse.
#
#=cut

sub __add_to_hash {
    my ($fn,$forward,$reverse,$type) = @_;
    if (ref($forward) ne 'HASH') {
	croak "__add_to_hash must be passed a hashref for the forward";
    }
    if (defined $reverse and not ref($reverse) eq 'HASH') {
	croak "if reverse is passed to __add_to_hash, it must be a hashref";
    }
    $type //= 'address';
    my $fh = IO::File->new($fn,'r') or
	croak "Unable to open $fn for reading: $!";
    binmode($fh,':encoding(UTF-8)');
    while (<$fh>) {
	chomp;
        next unless m/^(\S+)\s+(\S.*\S)\s*$/;
        my ($key,$value)=($1,$2);
	$key = lc $key;
	$forward->{$key}= $value;
	if (defined $reverse) {
	    if ($type eq 'address') {
		for my $m (map {lc($_->address)} (getparsedaddrs($value))) {
		    push @{$reverse->{$m}},$key;
		}
	    }
	    else {
		push @{$reverse->{$value}}, $key;
	    }
	}
    }
}


=head2 getpseudodesc

     my $pseudopkgdesc = getpseudodesc(...);

Returns the entry for a pseudo package from the
$config{pseudo_desc_file}. In cases where pseudo_desc_file is not
defined, returns an empty arrayref.

This function can be used to see if a particular package is a
pseudopackage or not.

=cut

our $_pseudodesc = undef;
sub getpseudodesc {
    return $_pseudodesc if defined $_pseudodesc;
    $_pseudodesc = {};
    __add_to_hash($config{pseudo_desc_file},$_pseudodesc) if
	defined $config{pseudo_desc_file} and
	length $config{pseudo_desc_file};
    return $_pseudodesc;
}

=head2 sort_versions

     sort_versions('1.0-2','1.1-2');

Sorts versions using AptPkg::Versions::compare if it is available, or
Debbugs::Versions::Dpkg::vercmp if it isn't.

=cut

our $vercmp;
BEGIN{
    use Debbugs::Versions::Dpkg;
    $vercmp=\&Debbugs::Versions::Dpkg::vercmp;

# eventually we'll use AptPkg:::Version or similar, but the current
# implementation makes this *super* difficult.

#     eval {
# 	use AptPkg::Version;
# 	$vercmp=\&AptPkg::Version::compare;
#     };
}

sub sort_versions{
    return sort {$vercmp->($a,$b)} @_;
}


=head1 DATE

    my $english = secs_to_english($seconds);
    my ($days,$english) = secs_to_english($seconds);

XXX This should probably be changed to use Date::Calc

=cut

sub secs_to_english{
     my ($seconds) = @_;

     my $days = int($seconds / 86400);
     my $years = int($days / 365);
     $days %= 365;
     my $result;
     my @age;
     push @age, "1 year" if ($years == 1);
     push @age, "$years years" if ($years > 1);
     push @age, "1 day" if ($days == 1);
     push @age, "$days days" if ($days > 1);
     $result .= join(" and ", @age);

     return wantarray?(int($seconds/86400),$result):$result;
}


=head1 LOCK

These functions are exported with the :lock tag

=head2 filelock

     filelock($lockfile);
     filelock($lockfile,$locks);

FLOCKs the passed file. Use unfilelock to unlock it.

Can be passed an optional $locks hashref, which is used to track which
files are locked (and how many times they have been locked) to allow
for cooperative locking.

=cut

our @filelocks;

use Carp qw(cluck);

sub filelock {
    # NB - NOT COMPATIBLE WITH `with-lock'
    my ($lockfile,$locks) = @_;
    if ($lockfile !~ m{^/}) {
	 $lockfile = cwd().'/'.$lockfile;
    }
    # This is only here to allow for relocking bugs inside of
    # Debbugs::Control. Nothing else should be using it.
    if (defined $locks and exists $locks->{locks}{$lockfile} and
	$locks->{locks}{$lockfile} >= 1) {
	if (exists $locks->{relockable} and
	    exists $locks->{relockable}{$lockfile}) {
	    $locks->{locks}{$lockfile}++;
	    # indicate that the bug for this lockfile needs to be reread
	    $locks->{relockable}{$lockfile} = 1;
	    push @{$locks->{lockorder}},$lockfile;
	    return;
	}
	else {
	    use Data::Dumper;
	    confess "Locking already locked file: $lockfile\n".Data::Dumper->Dump([$lockfile,$locks],[qw(lockfile locks)]);
	}
    }
    my ($fh,$t_lockfile,$errors) =
        simple_filelock($lockfile,10,1);
    if ($fh) {
        push @filelocks, {fh => $fh, file => $lockfile};
        if (defined $locks) {
            $locks->{locks}{$lockfile}++;
            push @{$locks->{lockorder}},$lockfile;
        }
    } else {
        use Data::Dumper;
        croak "failed to get lock on $lockfile -- $errors".
            (defined $locks?Data::Dumper->Dump([$locks],[qw(locks)]):'');
    }
}

=head2 simple_filelock

    my ($fh,$t_lockfile,$errors) =
        simple_filelock($lockfile,$count,$wait);

Does a flock of lockfile. If C<$count> is zero, does a blocking lock.
Otherwise, does a non-blocking lock C<$count> times, waiting C<$wait>
seconds in between.

In list context, returns the lockfile filehandle, lockfile name, and
any errors which occured.

When the lockfile filehandle is undef, locking failed.

These lockfiles must be unlocked manually at process end.


=cut

sub simple_filelock {
    my ($lockfile,$count,$wait) = @_;
    if (not defined $count) {
        $count = 10;
    }
    if ($count < 0) {
        $count = 0;
    }
    if (not defined $wait) {
        $wait = 1;
    }
    my $errors= '';
    my $fh;
    while (1) {
        $fh = eval {
	     my $fh2 = IO::File->new($lockfile,'w')
		  or die "Unable to open $lockfile for writing: $!";
             # Do a blocking lock if count is zero
	     flock($fh2,LOCK_EX|($count == 0?0:LOCK_NB))
		  or die "Unable to lock $lockfile $!";
	     return $fh2;
	};
	if ($@) {
	     $errors .= $@;
	}
        if ($fh) {
            last;
        }
        # use usleep for fractional wait seconds
        usleep($wait * 1_000_000);
    } continue {
        last unless (--$count > 0);
    } 
    if ($fh) {
        return wantarray?($fh,$lockfile,$errors):$fh
    }
    return wantarray?(undef,$lockfile,$errors):undef;
}

# clean up all outstanding locks at end time
END {
     while (@filelocks) {
	  unfilelock();
     }
}

=head2 simple_unlockfile

     simple_unlockfile($fh,$lockfile);


=cut

sub simple_unlockfile {
    my ($fh,$lockfile) = @_;
    flock($fh,LOCK_UN)
        or warn "Unable to unlock lockfile $lockfile: $!";
    close($fh)
        or warn "Unable to close lockfile $lockfile: $!";
    unlink($lockfile)
        or warn "Unable to unlink lockfile $lockfile: $!";
}


=head2 unfilelock

     unfilelock()
     unfilelock($locks);

Unlocks the file most recently locked.

Note that it is not currently possible to unlock a specific file
locked with filelock.

=cut

sub unfilelock {
    my ($locks) = @_;
    if (@filelocks == 0) {
        carp "unfilelock called with no active filelocks!\n";
        return;
    }
    if (defined $locks and ref($locks) ne 'HASH') {
	croak "hash not passsed to unfilelock";
    }
    if (defined $locks and exists $locks->{lockorder} and
	@{$locks->{lockorder}} and
	exists $locks->{locks}{$locks->{lockorder}[-1]}) {
	my $lockfile = pop @{$locks->{lockorder}};
	$locks->{locks}{$lockfile}--;
	if ($locks->{locks}{$lockfile} > 0) {
	    return
	}
	delete $locks->{locks}{$lockfile};
    }
    my %fl = %{pop(@filelocks)};
    simple_unlockfile($fl{fh},$fl{file});
}


=head2 lockpid

      lockpid('/path/to/pidfile');

Creates a pidfile '/path/to/pidfile' if one doesn't exist or if the
pid in the file does not respond to kill 0.

Returns 1 on success, false on failure; dies on unusual errors.

=cut

sub lockpid {
     my ($pidfile) = @_;
     if (-e $pidfile) {
	  my $pid = checkpid($pidfile);
	  die "Unable to read pidfile $pidfile: $!" if not defined $pid;
	  return 0 if $pid != 0;
	  unlink $pidfile or
	       die "Unable to unlink stale pidfile $pidfile $!";
     }
     mkpath(dirname($pidfile));
     my $pidfh = IO::File->new($pidfile,O_CREAT|O_EXCL|O_WRONLY) or
	  die "Unable to open $pidfile for writing: $!";
     print {$pidfh} $$ or die "Unable to write to $pidfile $!";
     close $pidfh or die "Unable to close $pidfile $!";
     return 1;
}

=head2 checkpid

     checkpid('/path/to/pidfile');

Checks a pid file and determines if the process listed in the pidfile
is still running. Returns the pid if it is, 0 if it isn't running, and
undef if the pidfile doesn't exist or cannot be read.

=cut

sub checkpid{
     my ($pidfile) = @_;
     if (-e $pidfile) {
	  my $pidfh = IO::File->new($pidfile, 'r') or
	       return undef;
	  local $/;
	  my $pid = <$pidfh>;
	  close $pidfh;
	  ($pid) = $pid =~ /(\d+)/;
	  if (defined $pid and kill(0,$pid)) {
	       return $pid;
	  }
	  return 0;
     }
     else {
	  return undef;
     }
}


=head1 QUIT

These functions are exported with the :quit tag.

=head2 quit

     quit()

Exits the program by calling die.

Usage of quit is deprecated; just call die instead.

=cut

sub quit {
     print {$DEBUG_FH} "quitting >$_[0]<\n" if $DEBUG;
     carp "quit() is deprecated; call die directly instead";
}


=head1 MISC

These functions are exported with the :misc tag

=head2 make_list

     LIST = make_list(@_);

Turns a scalar or an arrayref into a list; expands a list of arrayrefs
into a list.

That is, make_list([qw(a b c)]); returns qw(a b c); make_list([qw(a
b)],[qw(c d)] returns qw(a b c d);

=cut

sub make_list {
     return map {(ref($_) eq 'ARRAY')?@{$_}:$_} @_;
}


=head2 english_join

     print english_join(list => \@list);
     print english_join(\@list);

Joins list properly to make an english phrase.

=over

=item normal -- how to separate most values; defaults to ', '

=item last -- how to separate the last two values; defaults to ', and '

=item only_two -- how to separate only two values; defaults to ' and '

=item list -- ARRAYREF values to join; if the first argument is an
ARRAYREF, it's assumed to be the list of values to join

=back

In cases where C<list> is empty, returns ''; when there is only one
element, returns that element.

=cut

sub english_join {
    if (ref $_[0] eq 'ARRAY') {
	return english_join(list=>$_[0]);
    }
    my %param = validate_with(params => \@_,
			      spec  => {normal => {type => SCALAR,
						   default => ', ',
						  },
					last   => {type => SCALAR,
						   default => ', and ',
						  },
					only_two => {type => SCALAR,
						     default => ' and ',
						    },
					list     => {type => ARRAYREF,
						    },
				       },
			     );
    my @list = @{$param{list}};
    if (@list <= 1) {
	return @list?$list[0]:'';
    }
    elsif (@list == 2) {
	return join($param{only_two},@list);
    }
    my $ret = $param{last} . pop(@list);
    return join($param{normal},@list) . $ret;
}


=head2 globify_scalar

     my $handle = globify_scalar(\$foo);

if $foo isn't already a glob or a globref, turn it into one using
IO::Scalar. Gives a new handle to /dev/null if $foo isn't defined.

Will carp if given a scalar which isn't a scalarref or a glob (or
globref), and return /dev/null. May return undef if IO::Scalar or
IO::File fails. (Check $!)

The scalar will fill with octets, not perl's internal encoding, so you
must use decode_utf8() after on the scalar, and encode_utf8() on it
before. This appears to be a bug in the underlying modules.

=cut

our $_NULL_HANDLE;

sub globify_scalar {
     my ($scalar) = @_;
     my $handle;
     if (defined $scalar) {
	  if (defined ref($scalar)) {
	       if (ref($scalar) eq 'SCALAR' and
		   not UNIVERSAL::isa($scalar,'GLOB')) {
                   if (is_utf8(${$scalar})) {
                       ${$scalar} = decode_utf8(${$scalar});
                       carp(q(\$scalar must not be in perl's internal encoding));
                   }
		    open $handle, '>:scalar:utf8', $scalar;
		    return $handle;
	       }
	       else {
		    return $scalar;
	       }
	  }
	  elsif (UNIVERSAL::isa(\$scalar,'GLOB')) {
	       return $scalar;
	  }
	  else {
	       carp "Given a non-scalar reference, non-glob to globify_scalar; returning /dev/null handle";
	  }
      }
     if (not defined $_NULL_HANDLE or
	 not $_NULL_HANDLE->opened()
	) {
	 $_NULL_HANDLE =
	     IO::File->new('/dev/null','>:encoding(UTF-8)') or
		 die "Unable to open /dev/null for writing: $!";
     }
     return $_NULL_HANDLE;
}

=head2 cleanup_eval_fail()

     print "Something failed with: ".cleanup_eval_fail($@);

Does various bits of cleanup on the failure message from an eval (or
any other die message)

Takes at most two options; the first is the actual failure message
(usually $@ and defaults to $@), the second is the debug level
(defaults to $DEBUG).

If debug is non-zero, the code at which the failure occured is output.

=cut

sub cleanup_eval_fail {
    my ($error,$debug) = @_;
    if (not defined $error or not @_) {
	$error = $@ // 'unknown reason';
    }
    if (@_ <= 1) {
	$debug = $DEBUG // 0;
    }
    $debug = 0 if not defined $debug;

    if ($debug > 0) {
	return $error;
    }
    # ditch the "at foo/bar/baz.pm line 5"
    $error =~ s/\sat\s\S+\sline\s\d+//;
    # ditch croak messages
    $error =~ s/^\t+.+\n?//mg;
    # ditch trailing multiple periods in case there was a cascade of
    # die messages.
    $error =~ s/\.+$/\./;
    return $error;
}

=head2 hash_slice

     hash_slice(%hash,qw(key1 key2 key3))

For each key, returns matching values and keys of the hash if they exist

=cut


# NB: We use prototypes here SPECIFICALLY so that we can be passed a
# hash without uselessly making a reference to first. DO NOT USE
# PROTOTYPES USELESSLY ELSEWHERE.
sub hash_slice(\%@) {
    my ($hashref,@keys) = @_;
    return map {exists $hashref->{$_}?($_,$hashref->{$_}):()} @keys;
}


1;

__END__

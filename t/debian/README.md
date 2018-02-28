# Debian specific testing files

This directory contains two directories which have subsets of the Debian archive
and versioning information for glibc and debbugs packages, necessary to populate
the test databases and test various versioning and bug/found/fixed information.

## dist

This directory contains a truncated Debian archive created using `fake_ftpdist`.

To regenerate the contents of this directory, run:

    fake_ftpdist --progress --ftpdists ../../ftp.debian.org/ftp/dists

in this directory, where ftp.debian.org/ftp/dists is a full Debian mirror,
excluding the pool directories. You'll also need apt-ftparchive installed.

## debinfo

This directory contains debinfo files from glibc and debbugs; to rebuild it run
this command on bugs-master.debian.org:

    cd /srv/bugs.debian.org/versions/archive/ftp-master;
    find ./ -mindepth 2 \( -type d -not \( -name 'glibc' -o -name 'debbugs' \) \
       -prune \) -o -type f \( -iname '*_i386.debinfo' -o -iname '*_amd64.debinfo' \) \
       \( -ctime -$(( 5 * 365 )) -o -iname 'debbugs*' \) -print0| \
       xargs -0 tar -zcf ~/glibc_debbugs_debinfo.tar.gz

and unpack the resultant tarball into the `debinfo` directory.

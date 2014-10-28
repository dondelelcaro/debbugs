# Debbugs #

## Debian Bug-Tracking System ##

********************************

### Developers ###

This bug tracking system was developed by Ian Jackson from 1994-1997,
with assistance from nCipher Corporation Limited in 1997.  nCipher allowed
Ian to redistribute modifications he made to the system while working as an
employee of nCipher.

Since then, it has been developed by the various administrators of
bugs.debian.org, including Darren Benham, Adam Heath, Josip Rodin, Anthony
Towns, and Colin Watson.  As in the case of Ian, nCipher allowed Colin to
redistribute modifications he made while working as an employee of nCipher.

### System Requirements ###

 * GNU date
 * GNU gzip
 * Perl 5 (5.005 is known to work)
 * Mailtools and MIME-tools perl modules to manipulate email
 * Lynx 2.7 or later
 * The bug system requires its own mail domain. It comes with code
   which understands how exim, qmail and sendmail deliver mail for such a
   domain to a script.
 * A webserver. For the old system of static HTML pages generated for
   bug reports and index pages, this is easiest if the bug system can
   write directly to the webspace; for the new system of CGI scripts
   that generate web pages on the fly, write access is not required.
 * Somewhere to run CGI scripts (unless you don't need the web forms for
   searching for bugs by number, package, maintainer or submitter).

### Installation Instructions ###

Install the Debian package and read `/usr/share/doc/debbugs/README.Debian` file.

If you can't use the `.deb`, do the following:

1. Run `make install` from the source directory.

2. Edit the config files in `/etc/debbugs/` directory to suit your needs.
   Re-run debbugsconfig when you're finished to regenerate the documentation.

3. Set up the mail arrangements to deliver mail to the right place, and to set
   up a blackhole mail alias if you need one.  Ensure that `owner@bugs`, the
   address of the BTS owner, if that's what you're using, is handled by the MTA.
   All other email should be piped into the receive script.

4. Set up your HTTP server to point people looking for bug reports to
   `/var/lib/debbugs/www` and set `/var/lib/debbugs/www/cgi` as a valid CGI
   directory.

5. Test things a bit, by sending mail messages to the bug system and running
   `/usr/lib/debbugs/processall` and/or `/usr/lib/debbugs/rebuild`.  The latter
   updates index files used by the CGI scripts.  If you're feeling brave, you
   can link `/var/lib/debbugs/spool/index.db` to `index.db.realtime` and
   `.../index.archive` to `index.archive.realtime` to remove the need for the
   rebuild script; this is still semi-experimental.

6. If all seems well then install the crontab from
   `/usr/share/doc/debbugs/examples/crontab`.

Note that each line of `/etc/debbugs/Maintainers` file needs to be formatted as
follows: 

    package    maintainer name <email@address>

If you need a template, look in `/usr/share/doc/debbugs/examples/` directory.

### Contributing to Debbugs ###

#### Getting the Source Code ####

Debbugs is managed in git. You can clone the repository into your local
workspace as follows:

    git clone http://bugs-master.debian.org/debbugs-source/debbugs.git

Additional branches are available from:

 * [Don Armstrong](http://git.donarmstrong.com/debbugs.git/)

Make a working branch for your code and check it out to start working:

    git checkout -b example-branch

Stage and commit your changes using appropriate commit messages

    git add example-file

    git commit -m "Created an example file to demonstrate basic git commands."

#### Submitting a Patch ####

Submitting a patch can be done using git format-patch.

For example

    git format-patch origin/master

Creates `.patch` files for all commits since the branch diverged from master.

Debbugs bugs are tracked using debbugs (what else). Patches should therefore be
attached to the bug report for the issue. This can be done by emailing the
`.patch` files to `xxxx@bugs.debian.org` (where xxxx is the bug number).

Feature patches can also be emailed to the maintaining list at 
[Debugs mailing list](debian-debbugs@lists.debian.org)

### Further Information ###

#### Email ####

* Mailing List <debian-debbugs@lists.debian.org> 

* To subscribe to the mailing list, email
  <debian-debbugs-request@lists.debian.org> with the word "subscribe" in the
  subject line.

#### Website ####



### Copyright and Lack-of-Warranty Notice ###

 * Copyright 1999 Darren O. Benham
 * Copyright 1994-1997 Ian Jackson
 * Copyright 1997,2003 nCipher Corporation Limited

This bug system is free software; you can redistribute it and/or modify it
under the terms of the GNU General Public License as published by the Free
Software Foundation; version 2 of the License.

This program and documentation is distributed in the hope that it will be
useful, but without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose. See the GNU General
Public License for more details.

You should have received a copy of the GNU General Public License along
with this program, or one should be available above; if not, write to the
Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
02111-1307, USA.

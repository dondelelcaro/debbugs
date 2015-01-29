# Debbugs #

## Debian Bug-Tracking System ##

********************************

### What is Debbugs ###
Debbugs is a stable, scaleable bug reporting and issue tracking system. Debbugs has a web interface for viewing and searching issues in the database but unlike other bug tracking systems, Debbugs has no web interface for editing bug reports - all modification is done via email.

The most notable deployment of Debbugs is on the [Debian project](https://www.debian.org/Bugs/)

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

### Where do I get the Source? ###

Debbugs is managed in git. You can clone the repository into your local
workspace as follows:

    git clone http://bugs-master.debian.org/debbugs-source/debbugs.git

Additional branches are available from:

 * [Don Armstrong](http://git.donarmstrong.com/debbugs.git/)

### Installation Instructions ###

Install the Debian package and read `/usr/share/doc/debbugs/README.Debian` file.

If you can't use the `.deb`, do the following:

1.  Clone the repo

        git clone http://bugs-master.debian.org/debbugs-source/debbugs.git

2.  Create version and spool directory

        cd
        mkdir version spool

3.  Retrieve a partial database of bugs for testing

    Optional - It is useful to have some bugs in the database for testing our new Debbugs instance.

    1. Get a list of rsync targets from Debbugs

            rsync --list-only rsync://bugs-mirror.debian.org

    2. Grab bugs ending in 00

            mkdir -p splool/db-h/00;
            cd spool/db-h;
            rsync -av rsync://bugs-mirror.debian.org/bts-spool-db/00 .;

4.  Retrieve bts-versions directory for testing purposes

    Optional - Required for testing using test database retrieved at 3.

    1. Pull versions directory

            cd
            rsync -av rsync://bugs-mirror.debian.org/bts-versions/ versions/

    2. Pull index directory

            rsync -av rsync://bugs-mirror.debian.org/bts-spool-index index

5.  Configure Debbugs config

    1. Create a config directory for Debbugs

            sudo mkdir /etc/debbugs

    2. Copy sample configuration to config directory

            sudo cp ~/debbugs/scripts/config.debian /etc/debbugs/config

    3. Update the following variables
       * $gConfigDir
       * $gSpoolDir
       * $gIndicesDir
       * $gWebDir
       * $gDocDir

              70,72c70,72
              < $gConfigDir = "/org/bugs.debian.org/etc"; # directory where this file is
              < $gSpoolDir = "/org/bugs.debian.org/spool"; # working directory
              < $gIndicesDir = "/org/bugs.debian.org/indices"; # directory where the indices are
          ---
              > $gConfigDir = "/etc/debbugs"; # directory where this file is
              > $gSpoolDir = "/home/opw/spool"; # working directory
              > $gIndicesDir = "/home/opw/spool/indices"; # directory  where the indices are

              74,75c74,75
              < $gWebDir = "/org/bugs.debian.org/www"; # base location of web pages
              < $gDocDir = "/org/ftp.debian.org/ftp/doc"; # location of text doc files
          ---
              > $gWebDir = "/home/opw/debbugs/html"; # base location of web pages
              > $gDocDir = "/home/opw/debbugs/doc"; # location of text doc files

6.  Configure Webserver

    1. Copy example apache config

            sudo cp $HOME/debbugs/examples/apache.conf  /etc/apache2/sites-available/debbugs.conf

    2. Update the directory entries and the following variables
       * DocumentRoot
       * ScriptAlias

              5c5
              < DocumentRoot /var/lib/debbugs/www/
          ---
              > DocumentRoot /home/opw/debbugs/html/
              10c10
              < <Directory /var/lib/debbugs/www>
          ---
              > <Directory /home/opw/debbugs/html>
              16,17c16,17
              < ScriptAlias /cgi-bin/ /var/lib/debbugs/www/cgi/
              < <Directory "/var/lib/debbugs/www/cgi/">
          ---
              > ScriptAlias /cgi-bin/ /home/opw/debbugs/cgi/
              > <Directory "/home/opw/debbugs/cgi/">
    
    3. Enable required apache mods
       
            sudo a2enmod rewrite
            sudo a2enmod cgid
    
    4. Install site
       
            sudo a2ensite debbugs
            
7. Install dependencies

        sudo apt-get install libmailtools-perl ed libmime-tools-perl libio-stringy-perl libmldbm-perl liburi-perl libsoap-lite-perl libcgi-simple-perl libparams-validate-perl libtext-template-perl libsafe-hole-perl libmail-rfc822-address-perl liblist-moreutils-perl libtext-template-perl libfile-libmagic-perl libgravatar-url-perl libwww-perl imagemagick libapache2-mod-perl2
       
8. Set up libraries
   
    1. Create symlinks to link source to their expected locations
       
        sudo mkdir -p /usr/local/lib/site_perl
        sudo ln -s /home/opw/debbugs/Debbugs /usr/local/lib/site_perl/
    
        sudo mkdir -p /usr/share/debbugs/
        sudo ln -s /home/opw/debbugs/templates /usr/share/debbugs/

9. Create required files
       
    1. Create files
    
            touch /etc/debbugs/pseudo-packages.description
            touch /etc/debbugs/Source_maintainers
            touch /etc/debbugs/pseudo-packages.maintainers
            touch /etc/debbugs/Maintainers
            touch /etc/debbugs/Maintainers.override
            mkdir /etc/debbugs/indices
            touch /etc/debbugs/indices/sources
       
    2. Test
    
            cd $HOME/debbugs
            perl -c cgi/bugreport.cgi
            REQUEST_METHOD=GET QUERY_STRING="bug=775300" perl cgi/bugreport.cgi; 

10. Install MTA. See README.mail for details.

Note that each line of `/etc/debbugs/Maintainers` file needs to be formatted as
follows: 

    package    maintainer name <email@address>

If you need a template, look in `/usr/share/doc/debbugs/examples/` directory.

### How do I contribute to Debbugs? ###
 
#### Debbugs for Debbugs ####

Debbugs bugs are tracked using Debbugs. The web interface is available:
[Debbugs bugs](https://bugs.debian.org/cgi-bin/pkgreport.cgi?repeatmerged=no&src=debbugs)

#### Start contributing ####

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

### Further Information and Assistance ###

#### Email ####

* Mailing List <debian-debbugs@lists.debian.org> 

* To subscribe to the mailing list, email
  <debian-debbugs-request@lists.debian.org> with the word "subscribe" in the
  subject line.

#### Website ####

   * [Code](https://bugs.debian.org/debbugs-source/debbugs.git/)
   * [Debbugs Team](https://wiki.debian.org/Teams/Debbugs|Debbugs Team)

#### IRC ####

Join the #debbugs channel on [OFTC](irc.oftc.net)

### Developers ###

This bug tracking system was developed by Ian Jackson from 1994-1997,
with assistance from nCipher Corporation Limited in 1997. nCipher allowed
Ian to redistribute modifications he made to the system while working as an
employee of nCipher.

Since then, it has been developed by the various administrators of
bugs.debian.org, including Darren Benham, Adam Heath, Josip Rodin, Anthony
Towns, and Colin Watson. As in the case of Ian, nCipher allowed Colin to
redistribute modifications he made while working as an employee of nCipher.

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

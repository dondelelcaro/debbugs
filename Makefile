# top-level Makefile for debbugs
# probably requires GNU make to run properly

sbin_dir	:= $(DESTDIR)/usr/sbin
etc_dir		:= $(DESTDIR)/etc/debbugs
var_dir		:= $(DESTDIR)/var/lib/debbugs
scripts_dir	:= $(DESTDIR)/usr/lib/debbugs
doc_dir		:= $(DESTDIR)/usr/share/doc/debbugs
man_dir		:= $(DESTDIR)/usr/share/man
man8_dir	:= $(man_dir)/man8
examples_dir	:= $(doc_dir)/examples

scripts_in	:= $(filter-out scripts/config.in scripts/errorlib.in scripts/text.in, $(wildcard scripts/*.in))
htmls_in	:= $(wildcard html/*.html.in)
cgis		:= $(wildcard cgi/*.cgi cgi/*.pl)

install_exec	:= install -m755 -p
install_data	:= install -m644 -p

install: install_mostfiles
	# install basic debbugs documentation
	$(install_data) COPYING UPGRADE README debian/README.mail $(doc_dir)

	# configure debbugs
	$(sbin_dir)/debbugsconfig

install_mostfiles:
	# create the directories if they aren't there
	for dir in $(sbin_dir) $(etc_dir)/html $(etc_dir)/indices \
$(var_dir)/indices $(var_dir)/www/cgi $(var_dir)/www/db $(var_dir)/www/txt \
$(var_dir)/spool/lock $(var_dir)/spool/archive $(var_dir)/spool/incoming \
$(var_dir)/spool/db-h $(scripts_dir) $(examples_dir) $(man8_dir); \
          do test -d $$dir || $(install_exec) -d $$dir; done

	# install the scripts
	$(foreach script,$(scripts_in), $(install_exec) $(script) $(scripts_dir)/$(patsubst scripts/%.in,%,$(script));)
	$(install_data) scripts/errorlib.in $(scripts_dir)/errorlib

	# install examples
	$(install_data) scripts/config.in $(examples_dir)/config
	$(install_data) scripts/text.in $(examples_dir)/text
	$(install_data) debian/crontab misc/nextnumber misc/Maintainers \
	  misc/Maintainers.override misc/pseudo-packages.description \
	  misc/sources $(examples_dir)

	# install the HTML pages etc
	$(foreach html, $(htmls_in), $(install_data) $(html) $(etc_dir)/html;)
	$(install_data) html/lynx-cfg $(etc_dir)/html/lynx-cfg
	$(install_data) html/htaccess $(var_dir)/www/db/.htaccess

	# install the CGIs
	for cgi in $(cgis); do $(install_exec) $$cgi $(var_dir)/www/cgi; done
	$(install_exec) cgi/bugs-fetch2.pl.in $(var_dir)/www/cgi/bugs-fetch2.pl

	# install debbugsconfig
	$(install_exec) debian/debbugsconfig $(sbin_dir)
	# install the debbugs-dbhash migration tool
	$(install_exec) migrate/debbugs-dbhash $(sbin_dir)
	$(install_data) migrate/debbugs-dbhash.8 $(man8_dir)

	# install the updateseqs file
	$(install_data) misc/updateseqs $(var_dir)/spool

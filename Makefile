# A custom makefile for the check-db-links utility.
# Copyright (C) 2014 Jaromir Hradilek <jhradilek@gmail.com>

# This program is  free software:  you can redistribute it and/or modify it
# under  the terms  of the  GNU General Public License  as published by the
# Free Software Foundation, version 3 of the License.
#
# This program  is  distributed  in the hope  that it will  be useful,  but
# WITHOUT  ANY WARRANTY;  without  even the implied  warranty of MERCHANTA-
# BILITY  or  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public
# License for more details.
#
# You should have received a copy of the  GNU General Public License  along
# with this program. If not, see <http://www.gnu.org/licenses/>.

# General information about the utility:
NAME    = check-db-links
VERSION = 20140613

# General settings:
SHELL   = /bin/sh
INSTALL = /usr/bin/install -c
POD2MAN = /usr/bin/pod2man
SRCS    = check-db-links.sh
MAN1    = check-db-links.1
DOCS    = AUTHORS COPYING INSTALL README TODO

# Target directories:
prefix  = /usr/local
bindir  = $(prefix)/bin
docdir  = $(prefix)/share/doc/$(NAME)-$(VERSION)
mandir  = $(prefix)/share/man/man1

# The following are the make rules. Do not edit the rules unless you really
# know what you are doing:
.PHONY: all
all: $(MAN1)

.PHONY: clean
clean:
	-rm -f $(MAN1)

.PHONY: install
install: $(SRCS) $(MAN1) $(DOCS)
	@echo "Creating target directories:"
	$(INSTALL) -d $(bindir)
	$(INSTALL) -d $(mandir)
	$(INSTALL) -d $(docdir)
	@echo "Installing the utility:"
	$(INSTALL) -m 755 check-db-links.sh $(bindir)/check-db-links
	@echo "Installing the manual page:"
	$(INSTALL) -m 644 check-db-links.1 $(mandir)
	@echo "Installing the documentation:"
	$(INSTALL) -m 644 AUTHORS $(docdir)
	$(INSTALL) -m 644 COPYING $(docdir)
	$(INSTALL) -m 644 INSTALL $(docdir)
	$(INSTALL) -m 644 README $(docdir)
	$(INSTALL) -m 644 TODO $(docdir)
	-$(INSTALL) -m 644 ChangeLog $(docdir)
	@echo "Done."

.PHONY: uninstall
uninstall:
	@echo "Removing the utility:"
	-rm -f $(bindir)/check-db-links
	@echo "Removing the manual page:"
	-rm -f $(mandir)/check-db-links.1
	@echo "Removing the documentation:"
	-rm -f $(docdir)/AUTHORS
	-rm -f $(docdir)/COPYING
	-rm -f $(docdir)/INSTALL
	-rm -f $(docdir)/README
	-rm -f $(docdir)/TODO
	-rm -f $(docdir)/ChangeLog
	@echo "Removing empty directories:"
	-rmdir $(bindir)
	-rmdir $(mandir)
	-rmdir $(docdir)
	@echo "Done."

%.1: %.sh
	$(POD2MAN) --section=1 --name="$(basename $^)" \
	                       --release="Version $(VERSION)" $^ $@

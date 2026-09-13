PREFIX      ?= /usr
LIBDIR      ?= $(PREFIX)/lib
DINITSRVDIR ?= $(LIBDIR)/dinit.d

SCRIPTS = zfs-mount

SERVICES_IN = zfs-mount

SERVICES = \
	zed \
	zfs-share \
	zfs-zvol

all:

install:
	install -d $(DESTDIR)$(LIBDIR)/dinit
	install -d $(DESTDIR)$(DINITSRVDIR)
	for script in $(SCRIPTS); do \
		install -m 755 scripts/$$script $(DESTDIR)$(LIBDIR)/dinit; \
	done
	for srv in $(SERVICES_IN); do \
		sed "s|@LIBDIR[@]|$(LIBDIR)|g" services/$$srv.in > $(DESTDIR)$(DINITSRVDIR)/$$srv; \
		chmod 644 $(DESTDIR)$(DINITSRVDIR)/$$srv; \
	done
	for srv in $(SERVICES); do \
		install -m 644 services/$$srv $(DESTDIR)$(DINITSRVDIR); \
	done

uninstall:
	for script in $(SCRIPTS); do \
		rm -f $(DESTDIR)$(LIBDIR)/dinit/$$script; \
	done
	for srv in $(SERVICES_IN) $(SERVICES); do \
		rm -f $(DESTDIR)$(DINITSRVDIR)/$$srv; \
	done

.PHONY: all install uninstall

PREFIX      ?= /usr
LIBDIR      ?= $(PREFIX)/lib
SYSCONFDIR  ?= /etc
DINITSRVDIR ?= $(LIBDIR)/dinit.d
RUNITSVDIR  ?= $(SYSCONFDIR)/runit/sv
RCSYSINIT   ?= $(SYSCONFDIR)/rc/sysinit
S6DIR       ?= $(SYSCONFDIR)/s6

SCRIPTS = zfs-mount

SERVICES_IN = zfs-mount

SERVICES = \
	zed \
	zfs-share \
	zfs-zvol

RUNIT_SERVICES = \
	zed \
	zfs-share

S6_SERVICES = \
	mount \
	zed-log \
	zed-srv \
	zfs-mount \
	zfs-share \
	zfs-zvol

all:

install: install-dinit

install-dinit:
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

install-runit:
	install -d $(DESTDIR)$(LIBDIR)/rc/sv.d $(DESTDIR)$(RCSYSINIT)
	install -m 755 scripts/zfs-mount $(DESTDIR)$(LIBDIR)/rc/zfs-mount
	sed "s|@LIBDIR[@]|$(LIBDIR)|g" runit/sv.d/zfs-mount.in > $(DESTDIR)$(LIBDIR)/rc/sv.d/zfs-mount
	chmod 755 $(DESTDIR)$(LIBDIR)/rc/sv.d/zfs-mount
	install -m 755 runit/sv.d/zfs-zvol $(DESTDIR)$(LIBDIR)/rc/sv.d/zfs-zvol
	ln -sf $(LIBDIR)/rc/sv.d/zfs-mount $(DESTDIR)$(RCSYSINIT)/57-zfs-mount
	for srv in $(RUNIT_SERVICES); do \
		install -d $(DESTDIR)$(RUNITSVDIR)/$$srv; \
		for f in runit/sv/$$srv/*; do \
			install -m 755 $$f $(DESTDIR)$(RUNITSVDIR)/$$srv; \
		done; \
	done

install-s6:
	install -d $(DESTDIR)$(S6DIR)/sv $(DESTDIR)$(S6DIR)/config
	cp -R --no-preserve=ownership $(addprefix s6/sv/,$(S6_SERVICES)) $(DESTDIR)$(S6DIR)/sv
	install -m 755 scripts/zfs-mount $(DESTDIR)$(S6DIR)/sv/zfs-mount/shell_up
	install -m 644 s6/config/zed.conf $(DESTDIR)$(S6DIR)/config/zed.conf

uninstall: uninstall-dinit

uninstall-dinit:
	for script in $(SCRIPTS); do \
		rm -f $(DESTDIR)$(LIBDIR)/dinit/$$script; \
	done
	for srv in $(SERVICES_IN) $(SERVICES); do \
		rm -f $(DESTDIR)$(DINITSRVDIR)/$$srv; \
	done

uninstall-runit:
	rm -f $(DESTDIR)$(RCSYSINIT)/57-zfs-mount
	rm -f $(DESTDIR)$(LIBDIR)/rc/zfs-mount
	rm -f $(DESTDIR)$(LIBDIR)/rc/sv.d/zfs-mount $(DESTDIR)$(LIBDIR)/rc/sv.d/zfs-zvol
	for srv in $(RUNIT_SERVICES); do \
		rm -rf $(DESTDIR)$(RUNITSVDIR)/$$srv; \
	done

uninstall-s6:
	rm -f $(DESTDIR)$(S6DIR)/sv/mount/contents.d/zfs-mount
	for srv in zed-log zed-srv zfs-mount zfs-share zfs-zvol; do \
		rm -rf $(DESTDIR)$(S6DIR)/sv/$$srv; \
	done
	rm -f $(DESTDIR)$(S6DIR)/config/zed.conf

.PHONY: all install install-dinit install-runit install-s6 \
	uninstall uninstall-dinit uninstall-runit uninstall-s6

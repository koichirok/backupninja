
EXTRA_DIST = backupninja.timer backupninja.service.in

GENERATED_FILES = backupninja.service

CLEANFILES = $(GENERATED_FILES)

edit = sed \
    -e "s,@sbindir\@,$(sbindir),g"

backupninja.service: backupninja.service.in
	rm -f backupninja.service
	$(edit) backupninja.service.in > backupninja.service
	chmod 644 backupninja.service

if HAVE_SYSTEMD
systemdsystemunit_DATA = \
  backupninja.service \
  backupninja.timer
endif

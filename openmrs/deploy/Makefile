# Reproducible build of the FIB-4 widget OMOD (#28).
#
# The widget lives in git as a single GSP (../widget/fib4screening.gsp). The
# deployable artifact is that GSP surgically patched into a base coreapps OMOD.
# The base carries the dashboard-widget *registration* (which is not in the GSP),
# so it must be the widget-registered coreapps extracted from the running,
# digest-pinned distro container:
#
#   docker cp mash-openmrs-app:/usr/local/tomcat/webapps/openmrs/WEB-INF/\
#     bundledModules/coreapps-1.34.0.omod openmrs/deploy/coreapps-1.34.0.omod
#
# Then `make omod` reproduces a versioned artifact deterministically. The base
# OMOD is a build input (gitignored), not committed.

BASE_OMOD ?= coreapps-1.34.0.omod
GSP        = ../widget/fib4screening.gsp
VERSION   := $(shell cat ../widget/VERSION)
OUT        = coreapps-1.34.0+mashfib4-$(VERSION).omod

.PHONY: omod clean
omod: $(OUT)

$(OUT): $(BASE_OMOD) $(GSP) repack-omod.py
	python3 repack-omod.py $(BASE_OMOD) $(GSP) $(OUT)
	@echo "built reproducible artifact: $(OUT)"

clean:
	rm -f coreapps-1.34.0+mashfib4-*.omod

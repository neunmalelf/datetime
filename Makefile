SHELL = /bin/sh

# Detect OS
UNAME_S := $(shell uname -s 2>/dev/null || echo Unknown)

# Standard GNU installation directories (5.4) - Unix defaults
prefix = /usr/local
exec_prefix = $(prefix)
bindir = $(exec_prefix)/bin
libdir = $(exec_prefix)/lib
datadir = $(prefix)/lib
includedir = $(prefix)/include
oldincludedir = /usr/include
mandir = $(prefix)/share/man
man1dir = $(mandir)/man1
manext = .1
infodir = $(prefix)/share/info
# bash-completion's pkg-config path when available, standard fallback else.
completionsdir = $(shell pkg-config --variable=completionsdir bash-completion 2>/dev/null || echo $(prefix)/share/bash-completion/completions)
srcdir = .

# OS-specific overrides
ifeq ($(OS),Windows_NT)
prefix = $(HOME)
bindir = $(HOME)/sbin
mandir = $(HOME)/.local/share/man
man1dir = $(mandir)/man1
TARGET  := datetime.exe
else
TARGET  ?= datetime
endif

ifeq ($(UNAME_S),Darwin)
# macOS - Homebrew on Apple Silicon uses /opt/homebrew, Intel uses /usr/local
ifeq ($(shell test -d /opt/homebrew && echo yes),yes)
prefix = /opt/homebrew
else
prefix = /usr/local
endif
bindir = $(prefix)/bin
endif

# Command-line override: PREFIX=$$HOME/sbin make install
# (GNU convention: prefix defaults to /usr/local; exec_prefix/bindir follow it)
ifneq ($(strip $(PREFIX)),)
prefix = $(PREFIX)
endif

CC      ?= gcc
CFLAGS  ?= -O2 -Wall -Wextra -std=c99
CPPFLAGS ?=
LDFLAGS ?=
ALL_CFLAGS = $(CFLAGS) -I. -I$(srcdir)

# Installation programs (5.3) - portable: BSD install has no -D
INSTALL = install
INSTALL_PROGRAM = $(INSTALL)
INSTALL_DATA = $(INSTALL) -m 644
# For mkdir -p portability
MKDIR_P = mkdir -p

# Texinfo programs (used by the `info' and `dvi' targets)
MAKEINFO = makeinfo
TEXI2DVI = texi2dvi
PYTHON3 ?= python3

SRC     := $(srcdir)/datetime.c
TIMESTAMP := $(if $(filter Windows_NT,$(OS)),timestamp.exe,timestamp)
TARGETS := $(TARGET) $(TIMESTAMP)

# Version: the single source of truth is __version__ in datetime.c
# (x.y.micro).  dist/extract it with grep; no -DVERSION_BUILD plumbing.
VERSION := $(shell grep -oE '"[0-9]+\.[0-9]+\.[0-9]+"' $(srcdir)/datetime.c | head -1 | tr -d '"')

all: $(TARGETS)

$(TARGET): $(SRC)
	$(CC) $(ALL_CFLAGS) $(CPPFLAGS) -o $@ $(SRC) $(LDFLAGS)

# Print the bare version (used by ./_make push for the release tag).
# (Placed after 'all' - the first rule in the file is the default goal.)
dist-version:
	@echo $(VERSION)
.PHONY: dist-version

# The 'timestamp' command: same source compiled with DATETIME_TIMESTAMP_BUILD.
# It is a plain variant, not argv[0] magic: the macro only changes the
# default output to the UTC YYYYMMDDhhmmssZ stamp (run-time --timestamp
# still selects that format in every build).
# (Keep this rule AFTER the 'all' target: GNU make uses the first rule of
# the file as the default goal.)
$(TIMESTAMP): $(SRC)
	$(CC) $(ALL_CFLAGS) $(CPPFLAGS) -DDATETIME_TIMESTAMP_BUILD -o $@ $(SRC) $(LDFLAGS)

# Implicit rule for .c.o to support VPATH (5.1)
.c.o:
	$(CC) -c $(ALL_CFLAGS) $(CPPFLAGS) $< -o $@

# Standard targets for users (5.2)
info: datetime.info

datetime.info: $(srcdir)/manual.texi
	-$(MAKEINFO) -o $@ $(srcdir)/manual.texi

dvi: datetime.dvi

datetime.dvi: $(srcdir)/manual.texi
	-$(TEXI2DVI) $(srcdir)/manual.texi

# Documentation that must mirror the binary (README format table, tldr
# page, man-page option parity).  The generator treats ./datetime as the
# single source of truth and hardcodes nothing.
#
# Trigger points:
#   make docs        - regenerate by hand after changing --help/formats
#   make check-docs  - verify current; fails on drift (part of `make check`)
#   dist: docs       - a release tarball can never ship stale docs
# `all` deliberately does NOT depend on docs: `make` must not rewrite
# tracked files as a side effect.
docs: $(TARGETS)
	$(PYTHON3) $(srcdir)/scripts/gen-docs.py

check-docs: $(TARGETS)
	$(PYTHON3) $(srcdir)/scripts/gen-docs.py --check

.PHONY: docs check-docs

install: $(TARGETS)
	@$(MKDIR_P) "$(DESTDIR)$(bindir)"
	-@$(MKDIR_P) "$(DESTDIR)$(man1dir)" 2>/dev/null || true
	-@$(MKDIR_P) "$(DESTDIR)$(completionsdir)" 2>/dev/null || true
	$(INSTALL_PROGRAM) $(TARGET) "$(DESTDIR)$(bindir)/$(TARGET)"
	$(INSTALL_PROGRAM) $(TIMESTAMP) "$(DESTDIR)$(bindir)/$(TIMESTAMP)"
	$(INSTALL_DATA) $(srcdir)/man/man1/datetime.1 "$(DESTDIR)$(man1dir)/datetime$(manext)"
	-$(INSTALL_DATA) $(srcdir)/shell/datetime.bash "$(DESTDIR)$(completionsdir)/datetime" 2>/dev/null || true
	-$(INSTALL_DATA) $(srcdir)/shell/datetime.bash "$(DESTDIR)$(completionsdir)/timestamp" 2>/dev/null || true
ifeq ($(OS),Windows_NT)
	-@mkdir -p "$(HOME)/sbin" 2>/dev/null || true
	-$(INSTALL_PROGRAM) $(TARGET) "$(HOME)/sbin/$(TARGET)" 2>/dev/null || true
endif

install-strip: $(TARGETS)
	@$(MKDIR_P) "$(DESTDIR)$(bindir)"
	-@$(MKDIR_P) "$(DESTDIR)$(man1dir)" 2>/dev/null || true
	-@$(MKDIR_P) "$(DESTDIR)$(completionsdir)" 2>/dev/null || true
	$(INSTALL_PROGRAM) -s $(TARGET) "$(DESTDIR)$(bindir)/$(TARGET)"
	$(INSTALL_PROGRAM) -s $(TIMESTAMP) "$(DESTDIR)$(bindir)/$(TIMESTAMP)"
	$(INSTALL_DATA) $(srcdir)/man/man1/datetime.1 "$(DESTDIR)$(man1dir)/datetime$(manext)"
	-$(INSTALL_DATA) $(srcdir)/shell/datetime.bash "$(DESTDIR)$(completionsdir)/datetime" 2>/dev/null || true
	-$(INSTALL_DATA) $(srcdir)/shell/datetime.bash "$(DESTDIR)$(completionsdir)/timestamp" 2>/dev/null || true

uninstall:
	rm -f "$(DESTDIR)$(bindir)/$(TARGET)"
	rm -f "$(DESTDIR)$(bindir)/$(TIMESTAMP)"
	rm -f "$(DESTDIR)$(completionsdir)/datetime" "$(DESTDIR)$(completionsdir)/timestamp"
	# Remove legacy ~/sbin install if different from bindir
	@case "$(bindir)" in "$(HOME)/sbin") true;; *) rm -f "$(PREFIX)/$(TARGET)" 2>/dev/null || true;; esac
ifeq ($(OS),Windows_NT)
	rm -f "$(HOME)/sbin/$(TARGET)" 2>/dev/null || true
endif

clean:
	rm -f $(TARGETS) *.o
	rm -f datetime.exe timestamp.exe
	rm -f datetime.1.gz

mostlyclean: clean
	rm -f *.dvi

distclean: clean
	rm -f config.status config.log
	rm -f datetime.info datetime.dvi
	rm -f datetime.log datetime.aux

realclean: distclean
	rm -f TAGS tags
	rm -f *.tar *.tar.gz

TAGS: $(SRC) $(srcdir)/manual.texi
	-etags $(SRC) $(srcdir)/manual.texi

tags: TAGS

dist: docs $(SRC) $(srcdir)/scripts/check-security.sh $(srcdir)/scripts/gen-docs.py $(srcdir)/manual.texi $(srcdir)/README.md $(srcdir)/man/man1/datetime.1
	@dir=datetime-$(VERSION); \
	rm -rf $$dir; mkdir -p $$dir; \
	cp -p $(SRC) $(srcdir)/Makefile $(srcdir)/README.md $(srcdir)/project.toml $(srcdir)/manual.texi $(srcdir)/NEWS $(srcdir)/ChangeLog $$dir/ 2>/dev/null || true; \
	mkdir -p $$dir/man/man1 $$dir/tldr $$dir/shell $$dir/scripts; cp -p $(srcdir)/man/man1/datetime.1 $$dir/man/man1/ 2>/dev/null || true; cp -p $(srcdir)/tldr/datetime.md $$dir/tldr/ 2>/dev/null || true; cp -p $(srcdir)/shell/datetime.bash $$dir/shell/ 2>/dev/null || true; cp -p $(srcdir)/scripts/gen-docs.py $$dir/scripts/ 2>/dev/null || true; \
	tar -czf $$dir.tar.gz $$dir; rm -rf $$dir; echo "Created $$dir.tar.gz"

# Syntax check only (no code generation).
check-syntax:
	$(CC) $(ALL_CFLAGS) $(CPPFLAGS) -fsyntax-only $(SRC)

# GNU style check (8 Formatting Your Source Code) - indent -gnu or clang-format --style=GNU
check-style: $(SRC)
	@if command -v indent >/dev/null 2>&1; then \
		echo "check-style: indent -gnu"; \
		indent -gnu -st $(SRC) | diff -u $(SRC) - || { echo "error: GNU style violations (indent -gnu)"; exit 1; }; \
	elif command -v clang-format >/dev/null 2>&1; then \
		echo "check-style: clang-format --style=GNU"; \
		clang-format --dry-run --Werror --style=GNU $(SRC) 2>&1 || { echo "error: GNU style violations (clang-format)"; exit 1; }; \
	else \
		echo "warning: indent nor clang-format found, skipping GNU style check (install indent or clang-format)"; \
	fi

# Security battery: banned libc API scan, gcc -fanalyzer, ASan/LSan
# runtime paths, best-effort UBSan (see scripts/check-security.sh).
check-security: $(TARGETS)
	@bash $(srcdir)/scripts/check-security.sh

# Memory leak check via valgrind.
check-mem: $(TARGETS)
	@command -v valgrind >/dev/null 2>&1 || { \
		if [ "$$(uname -s)" = "Darwin" ]; then \
			echo "notice: valgrind not available on macOS, skipping memory check"; \
			exit 0; \
		else \
			echo "error: valgrind not found (install it, e.g. 'dnf install valgrind')"; \
			exit 1; \
		fi; \
	}
	valgrind --leak-check=full --show-leak-kinds=all --error-exitcode=1 ./$(TARGET)
	valgrind --leak-check=full --show-leak-kinds=all --error-exitcode=1 ./$(TARGET) --timestamp
	@echo "check-mem: error paths (cleanup/free on failure)"
	@for c in "--bogus-flag" "-d not-a-date" "-r /no/such/file" "-d now --file -"; do \
		valgrind --leak-check=full --show-leak-kinds=all --error-exitcode=99 ./$(TARGET) $$c >/dev/null 2>&1; \
		rc=$$?; \
		if [ $$rc -ne 0 ] && [ $$rc -ne 1 ]; then \
			echo "error: valgrind reported errors (rc=$$rc) on: $$c"; exit 1; \
		fi; \
	done

# Test suites execution
check-test: $(TARGETS)
	@echo "Running all test suites (via ./_tests)..."
	@./_tests

check: check-syntax check-mem check-security check-style check-test check-docs

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
mandir = $(prefix)/man
man1dir = $(mandir)/man1
manext = .1
infodir = $(prefix)/info
srcdir = .

# OS-specific overrides
ifeq ($(OS),Windows_NT)
prefix = $(HOME)
bindir = $(HOME)/sbin
mandir = $(HOME)/.local/share/man
man1dir = $(mandir)/man1
TARGET  := datetime.exe
TARGET2 := timestamp.exe
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

# Project-specific install destination (defaults to ~/sbin for user-local install)
PREFIX ?= $(HOME)/sbin
ifeq ($(PREFIX),$(HOME)/sbin)
bindir = $(HOME)/sbin
mandir = $(HOME)/.local/share/man
man1dir = $(mandir)/man1
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

# Targets (handle Windows .exe)
ifndef OS
TARGET  ?= datetime
TARGET2 ?= timestamp
endif
SRC     := $(srcdir)/datetime.c
TARGETS := $(TARGET) $(TARGET2)

# Build number (YYYYMMDDHHMMSSZ, UTC), regenerated before every compilation.
# Microversion x.x.<timestamp> must use timestamp (UTC compact seconds).
# Try local ./timestamp first (freshly built), then ~/sbin/timestamp, then date -u fallback
# so first build on clean system still works. `version.h` is regenerated on every build via FORCE.
all: $(TARGETS)

# Regenerate the build number before every compilation.
version.h: FORCE
	@BUILD=$$(./timestamp 2>/dev/null || ~/sbin/timestamp 2>/dev/null || date -u +"%Y%m%d%H%M%SZ" 2>/dev/null || echo "20260909000000Z"); printf '#define VERSION_BUILD "%s"\n' "$$BUILD" > $@

$(TARGET): $(SRC) version.h
	$(CC) $(ALL_CFLAGS) $(CPPFLAGS) -o $@ $(SRC) $(LDFLAGS)

$(TARGET2): $(SRC) version.h
	$(CC) $(ALL_CFLAGS) $(CPPFLAGS) -DTIMESTAMP -o $@ $(SRC) $(LDFLAGS)

# Implicit rule for .c.o to support VPATH (5.1)
.c.o:
	$(CC) -c $(ALL_CFLAGS) $(CPPFLAGS) $< -o $@

FORCE:

# Standard targets for users (5.2)
info: datetime.info

datetime.info: $(srcdir)/manual.texi
	-$(MAKEINFO) -o $@ $(srcdir)/manual.texi

dvi: datetime.dvi

datetime.dvi: $(srcdir)/manual.texi
	-$(TEXI2DVI) $(srcdir)/manual.texi

install: $(TARGETS)
	@$(MKDIR_P) "$(DESTDIR)$(bindir)"
	-@$(MKDIR_P) "$(DESTDIR)$(man1dir)" 2>/dev/null || true
	$(INSTALL_PROGRAM) $(TARGET) "$(DESTDIR)$(bindir)/$(TARGET)"
	$(INSTALL_PROGRAM) $(TARGET2) "$(DESTDIR)$(bindir)/$(TARGET2)"
	-$(INSTALL_DATA) $(srcdir)/man/man1/datetime.1 "$(DESTDIR)$(man1dir)/datetime$(manext)" 2>/dev/null || true
ifeq ($(OS),Windows_NT)
	-@mkdir -p "$(HOME)/sbin" 2>/dev/null || true
	-$(INSTALL_PROGRAM) $(TARGET) "$(HOME)/sbin/$(TARGET)" 2>/dev/null || true
	-$(INSTALL_PROGRAM) $(TARGET2) "$(HOME)/sbin/$(TARGET2)" 2>/dev/null || true
endif

install-strip: $(TARGETS)
	@$(MKDIR_P) "$(DESTDIR)$(bindir)"
	-@$(MKDIR_P) "$(DESTDIR)$(man1dir)" 2>/dev/null || true
	$(INSTALL_PROGRAM) -s $(TARGET) "$(DESTDIR)$(bindir)/$(TARGET)"
	$(INSTALL_PROGRAM) -s $(TARGET2) "$(DESTDIR)$(bindir)/$(TARGET2)"
	-$(INSTALL_DATA) $(srcdir)/man/man1/datetime.1 "$(DESTDIR)$(man1dir)/datetime$(manext)" 2>/dev/null || true

uninstall:
	rm -f "$(DESTDIR)$(bindir)/$(TARGET)" "$(DESTDIR)$(bindir)/$(TARGET2)"
	rm -f "$(DESTDIR)$(man1dir)/datetime$(manext)"
	# Remove legacy ~/sbin install if different from bindir
	@case "$(bindir)" in "$(HOME)/sbin") true;; *) rm -f "$(PREFIX)/$(TARGET)" "$(PREFIX)/$(TARGET2)" 2>/dev/null || true;; esac
ifeq ($(OS),Windows_NT)
	rm -f "$(HOME)/sbin/$(TARGET)" "$(HOME)/sbin/$(TARGET2)" 2>/dev/null || true
endif

clean:
	rm -f $(TARGETS) version.h *.o
	rm -f datetime.exe timestamp.exe

mostlyclean: clean
	rm -f *.dvi

distclean: clean
	rm -f config.status config.log
	rm -f datetime.info datetime.dvi

realclean: distclean
	rm -f TAGS tags
	rm -f *.tar *.tar.gz

TAGS: $(SRC) $(srcdir)/manual.texi
	-etags $(SRC) $(srcdir)/manual.texi

tags: TAGS

dist: version.h $(SRC) $(srcdir)/manual.texi $(srcdir)/README.md $(srcdir)/man/man1/datetime.1
	@ver=`grep '^#define VERSION_MINOR' $(srcdir)/datetime.c | sed 's/.*"\([0-9]*\)".*/\1/'`; \
	maj=`grep '^#define VERSION_MAJOR' $(srcdir)/datetime.c | sed 's/.*"\([0-9]*\)".*/\1/'`; \
	build=`cat version.h 2>/dev/null | sed 's/.*"\([0-9A-Z]*\)".*/\1/'`; \
	dir=datetime-$$maj.$$ver.$$build; \
	rm -rf $$dir; mkdir -p $$dir; \
	cp -p $(SRC) $(srcdir)/Makefile $(srcdir)/README.md $(srcdir)/project.toml $(srcdir)/manual.texi $(srcdir)/NEWS $(srcdir)/ChangeLog $$dir/ 2>/dev/null || true; \
	mkdir -p $$dir/man/man1 $$dir/tldr; cp -p $(srcdir)/man/man1/datetime.1 $$dir/man/man1/ 2>/dev/null || true; cp -p $(srcdir)/tldr/datetime.md $$dir/tldr/ 2>/dev/null || true; \
	tar -czf $$dir.tar.gz $$dir; rm -rf $$dir; echo "Created $$dir.tar.gz"

# Syntax check only (no code generation).
check-syntax: version.h
	$(CC) $(ALL_CFLAGS) $(CPPFLAGS) -fsyntax-only $(SRC)

# GNU style check (8 Formatting Your Source Code) – indent -gnu or clang-format --style=GNU
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
	valgrind --leak-check=full --show-leak-kinds=all --error-exitcode=1 ./$(TARGET2)
	valgrind --leak-check=full --show-leak-kinds=all --error-exitcode=1 ./$(TARGET) --timestamp
	valgrind --leak-check=full --show-leak-kinds=all --error-exitcode=1 ./$(TARGET2) --timestamp

# Test suites execution
check-test: $(TARGETS)
	@echo "Running bash test suites..."
	@./tests/_test_datetime
	@./tests/_test_combinatorial
	@if command -v python3 >/dev/null 2>&1; then \
		echo "Running Python pytest suites..."; \
		python3 -m pytest tests/test_granular.py tests/test_exhaustive.py -v; \
	fi

check: check-syntax check-mem check-style check-test

.PHONY: all info dvi install install-strip uninstall clean mostlyclean distclean realclean TAGS tags dist check-syntax check-mem check-style check-test check FORCE

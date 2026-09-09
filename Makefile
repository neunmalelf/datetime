CC      ?= gcc
CFLAGS  ?= -O2 -Wall -Wextra -std=c99
LDFLAGS ?=

TARGET  := datetime
TARGET2 := timestamp
SRC     := datetime.c
PREFIX  := $(HOME)/sbin
TARGETS := $(TARGET) $(TARGET2)

# Build number (YYYYMMDDHHMMSSZ, UTC), regenerated before every compilation.
# Microversion x.x.<timestamp> must use timestamp (UTC compact seconds).
# Try local ./timestamp first (freshly built), then ~/sbin/timestamp, then date -u fallback
# so first build on clean system still works. `version.h` is regenerated on every build via FORCE.
BUILD ?= $(shell ./timestamp 2>/dev/null || ~/sbin/timestamp 2>/dev/null || date -u +"%Y%m%d%H%M%SZ")

all: $(TARGETS) install

# Regenerate the build number before every compilation.
version.h: FORCE
	@BUILD=$$(./timestamp 2>/dev/null || ~/sbin/timestamp 2>/dev/null || date -u +"%Y%m%d%H%M%SZ"); printf '#define VERSION_BUILD "%s"\n' "$$BUILD" > $@

$(TARGET): $(SRC) version.h
	$(CC) $(CFLAGS) -o $@ $< $(LDFLAGS)

$(TARGET2): $(SRC) version.h
	$(CC) $(CFLAGS) -o $@ $< $(LDFLAGS)

FORCE:

# Syntax check only (no code generation).
check-syntax: version.h
	$(CC) $(CFLAGS) -fsyntax-only $(SRC)

# Memory leak check via valgrind.
check-mem: $(TARGETS)
	@command -v valgrind >/dev/null 2>&1 || { \
		echo "error: valgrind not found (install it, e.g. 'dnf install valgrind')"; \
		exit 1; \
	}
	valgrind --leak-check=full --show-leak-kinds=all --error-exitcode=1 ./$(TARGET)
	valgrind --leak-check=full --show-leak-kinds=all --error-exitcode=1 ./$(TARGET2)
	valgrind --leak-check=full --show-leak-kinds=all --error-exitcode=1 ./$(TARGET) --timestamp
	valgrind --leak-check=full --show-leak-kinds=all --error-exitcode=1 ./$(TARGET2) --timestamp

check: check-syntax check-mem

# Copy the binaries to ~/sbin, overwriting any existing versions.
install: $(TARGETS)
	install -D -m 0755 $(TARGET) $(PREFIX)/$(TARGET)
	install -D -m 0755 $(TARGET2) $(PREFIX)/$(TARGET2)

uninstall:
	rm -f $(PREFIX)/$(TARGET) $(PREFIX)/$(TARGET2)

clean:
	rm -f $(TARGETS) version.h

.PHONY: all check-syntax check-mem check install uninstall clean FORCE

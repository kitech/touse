CC       ?= cc
CSTD     ?= -std=c11
WARN     ?= -Wall -Wextra -Wpedantic
OPT      ?= -O2
CFLAGS   ?= $(CSTD) $(WARN) $(OPT)
CPPFLAGS ?=
LDFLAGS  ?=

OBJ := leakybucket.o
BIN := example tests

# Optional language toolchains. Targets are skipped when not installed.
HAVE_V   := $(shell command -v v   2>/dev/null)
HAVE_ZIG := $(shell command -v zig 2>/dev/null)
HAVE_C3  := $(shell command -v c3c 2>/dev/null)

BINDING_TARGETS := $(if $(HAVE_V),v-check) $(if $(HAVE_ZIG),zig-check) $(if $(HAVE_C3),c3-check)

.PHONY: all clean test asan tsan c-only bindings v-check zig-check c3-check

all: c-only bindings

c-only: $(BIN)

bindings: $(BINDING_TARGETS)
ifndef HAVE_V
	@echo "skip: v not found"
endif
ifndef HAVE_ZIG
	@echo "skip: zig not found"
endif
ifndef HAVE_C3
	@echo "skip: c3c not found"
endif

leakybucket.o: leakybucket.c leakybucket.h
	$(CC) $(CPPFLAGS) $(CFLAGS) -c leakybucket.c -o $@

example: example.c $(OBJ) leakybucket.h
	$(CC) $(CPPFLAGS) $(CFLAGS) example.c $(OBJ) -o $@ $(LDFLAGS)

tests: lkbkt_test.c $(OBJ) leakybucket.h
	$(CC) $(CPPFLAGS) $(CFLAGS) lkbkt_test.c $(OBJ) -o $@ $(LDFLAGS)

test: tests
	./tests

# V: module `lkbkt` (matching C3) + tests in demo.vsh. Build a static lib
# and run the script from the parent so `import lkbkt` resolves.
v-check:
ifeq ($(HAVE_V),)
	@echo "skip: v not found"
else
	@mkdir -p build/v
	@$(CC) $(CSTD) -c leakybucket.c -o build/v/leakybucket.o
	@ar rcs build/v/liblkbkt.a build/v/leakybucket.o
	@cd $(CURDIR)/.. && v -o lkbkt/build/v/lkbkt \
		-ldflags "-L$(CURDIR)/build/v -llkbkt" run lkbkt/demo.vsh
endif

zig-check:
ifeq ($(HAVE_ZIG),)
	@echo "skip: zig not found"
else
	@mkdir -p build/zig
	@zig build-exe lkbkt.zig -lc -OReleaseSafe \
		-femit-bin=build/zig/lkbkt \
		-cflags -std=c11 -I. -- leakybucket.c
	@./build/zig/lkbkt
	@zig test lkbkt.zig -lc -cflags -std=c11 -I. -- leakybucket.c
endif

c3-check:
ifeq ($(HAVE_C3),)
	@echo "skip: c3c not found"
else
	@mkdir -p build/c3
	@$(CC) $(CSTD) -I. -c leakybucket.c -o build/c3/leakybucket.o
	@ar rcs build/c3/liblkbkt.a build/c3/leakybucket.o
	@c3c compile lkbkt.c3 -L build/c3 -l lkbkt -o build/c3/lkbkt
	@./build/c3/lkbkt
endif

# Sanitizer builds (not part of `all`).
asan: clean
	$(MAKE) CFLAGS="$(CSTD) $(WARN) -O1 -g -fsanitize=address,undefined -fno-omit-frame-pointer" \
	        LDFLAGS="-fsanitize=address,undefined" c-only
	./tests

tsan: clean
	$(MAKE) CPPFLAGS="-DLKBKT_THREAD_SAFE" \
	        CFLAGS="$(CSTD) $(WARN) -O1 -g -fsanitize=thread -pthread" \
	        LDFLAGS="-fsanitize=thread -pthread" c-only
	./tests

clean:
	rm -rf $(OBJ) $(BIN) build

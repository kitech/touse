CC       ?= cc
CSTD     ?= -std=c11
WARN     ?= -Wall -Wextra -Wpedantic
OPT      ?= -O2
CFLAGS   ?= $(CSTD) $(WARN) $(OPT)
CPPFLAGS ?=
LDFLAGS  ?=

OBJ := leakybucket.o
BIN := example tests

.PHONY: all clean test asan tsan

all: $(BIN)

leakybucket.o: leakybucket.c leakybucket.h
	$(CC) $(CPPFLAGS) $(CFLAGS) -c leakybucket.c -o $@

example: example.c $(OBJ) leakybucket.h
	$(CC) $(CPPFLAGS) $(CFLAGS) example.c $(OBJ) -o $@ $(LDFLAGS)

tests: lkbkt_test.c $(OBJ) leakybucket.h
	$(CC) $(CPPFLAGS) $(CFLAGS) lkbkt_test.c $(OBJ) -o $@ $(LDFLAGS)

test: tests
	./tests

# Sanitizer builds (not part of `all`).
asan: clean
	$(MAKE) CFLAGS="$(CSTD) $(WARN) -O1 -g -fsanitize=address,undefined -fno-omit-frame-pointer" \
	        LDFLAGS="-fsanitize=address,undefined" all
	./tests

tsan: clean
	$(MAKE) CPPFLAGS="-DLKBKT_THREAD_SAFE" \
	        CFLAGS="$(CSTD) $(WARN) -O1 -g -fsanitize=thread -pthread" \
	        LDFLAGS="-fsanitize=thread -pthread" all
	./tests

clean:
	rm -f $(OBJ) $(BIN)

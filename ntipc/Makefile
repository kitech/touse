CC ?= cc
CFLAGS ?= -std=c11 -Wall -Wextra -Wpedantic -D_POSIX_C_SOURCE=200809L -Iinclude
PICFLAGS ?= -fPIC
LDFLAGS ?= -lpthread -lrt
OUTDIR ?= .

SRC = src/common.c src/pipe_posix.c
HDR = include/ntipc.h src/internal.h
OBJ = $(OUTDIR)/common.o $(OUTDIR)/pipe_posix.o
PICOBJ = $(OUTDIR)/common.pic.o $(OUTDIR)/pipe_posix.pic.o
STATIC_LIB = $(OUTDIR)/libntipc.a

UNAME_S := $(shell uname -s 2>/dev/null || echo Unknown)
ifeq ($(UNAME_S),Darwin)
SHARED_LIB = $(OUTDIR)/libntipc.dylib
SHARED_LDFLAGS = -dynamiclib -lpthread
else
SHARED_LIB = $(OUTDIR)/libntipc.so
SHARED_LDFLAGS = -shared -lpthread -lrt
endif

all: $(STATIC_LIB) $(SHARED_LIB) $(OUTDIR)/ntipc-test

lib: $(STATIC_LIB) $(SHARED_LIB)

$(OUTDIR)/common.o: src/common.c $(HDR)
	@mkdir -p $(OUTDIR)
	$(CC) $(CFLAGS) -c -o $@ src/common.c

$(OUTDIR)/pipe_posix.o: src/pipe_posix.c $(HDR)
	@mkdir -p $(OUTDIR)
	$(CC) $(CFLAGS) -c -o $@ src/pipe_posix.c

$(OUTDIR)/common.pic.o: src/common.c $(HDR)
	@mkdir -p $(OUTDIR)
	$(CC) $(CFLAGS) $(PICFLAGS) -c -o $@ src/common.c

$(OUTDIR)/pipe_posix.pic.o: src/pipe_posix.c $(HDR)
	@mkdir -p $(OUTDIR)
	$(CC) $(CFLAGS) $(PICFLAGS) -c -o $@ src/pipe_posix.c

$(STATIC_LIB): $(OBJ)
	ar rcs $@ $(OBJ)

$(SHARED_LIB): $(PICOBJ)
	$(CC) $(CFLAGS) $(PICFLAGS) -o $@ $(PICOBJ) $(SHARED_LDFLAGS)

$(OUTDIR)/ntipc-test: $(SRC) $(HDR) tests/test_ntipc.c
	@mkdir -p $(OUTDIR)
	$(CC) $(CFLAGS) -o $@ src/common.c src/pipe_posix.c tests/test_ntipc.c $(LDFLAGS)

test: $(OUTDIR)/ntipc-test
	$(OUTDIR)/ntipc-test

clean:
	rm -f $(OUTDIR)/ntipc-test $(STATIC_LIB) $(SHARED_LIB) $(OBJ) $(PICOBJ)

.PHONY: all lib test clean

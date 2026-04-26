CC = gcc
CFLAGS = -Wall -Wextra -O2 -I.
LDFLAGS = $(shell pkg-config --libs libcurl json-c)
CFLAGS += $(shell pkg-config --cflags libcurl json-c)

TARGET = nixpkgut
SRCS = nixse.c nardl.c cmd/main.c
OBJS = $(SRCS:.c=.o)

all: $(TARGET)

$(TARGET): $(OBJS)
	$(CC) $(CFLAGS) -o $@ $(OBJS) $(LDFLAGS)

%.o: %.c nixse.h nardl.h
	$(CC) $(CFLAGS) -c $< -o $@

clean:
	rm -f $(TARGET) *.o cmd/*.o

.PHONY: all clean

.SILENT: clean
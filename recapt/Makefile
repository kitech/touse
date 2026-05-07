CC      ?= gcc
CFLAGS  ?= -Wall -Wextra -O2 -lm
LDFLAGS ?= -lm

all: recapt

recapt: main.c recapt.c recapt.h stb_truetype.h stb_image_write.h
	$(CC) $(CFLAGS) main.c recapt.c -o recapt $(LDFLAGS)

clean:
	rm -f recapt *.png

.PHONY: all clean

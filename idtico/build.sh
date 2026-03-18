
set -x

gcc -std=c99 -o test identicon.c md5.c main.c -lpng -lz -lm

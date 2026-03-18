CC = gcc
CFLAGS = -Wall -Wextra -I./src -O2
LDFLAGS = -lcurl
TARGET = misskey_example
SRC_DIR = src

SOURCES = $(SRC_DIR)/misskey_client.c $(SRC_DIR)/examples.c $(SRC_DIR)/cJSON/cJSON.c
HEADERS = $(SRC_DIR)/misskey_client.h $(SRC_DIR)/cJSON/cJSON.h

.PHONY: all clean run run-tracked

all: $(TARGET)

$(TARGET): $(SOURCES) $(HEADERS)
	$(CC) $(CFLAGS) -o $@ $(SOURCES) $(LDFLAGS)

clean:
	rm -f $(TARGET)

run: $(TARGET)
	./$(TARGET) $(HOST) $(TOKEN)

run-tracked: $(TARGET)
	./$(TARGET) $(HOST) $(TOKEN) --track-alloc

help:
	@echo "Misskey C Client Example"
	@echo ""
	@echo "Usage:"
	@echo "  make all            - Build the example"
	@echo "  make clean          - Remove build artifacts"
	@echo "  make run HOST=<host> TOKEN=<token> - Run with default allocator"
	@echo "  make run-tracked HOST=<host> TOKEN=<token> - Run with memory tracking"
	@echo ""
	@echo "Examples:"
	@echo "  make run HOST=misskey.io TOKEN=your_token"
	@echo "  make run-tracked HOST=misskey.io TOKEN=your_token"

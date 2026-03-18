CC = gcc
CFLAGS = -Wall -Wextra -I./src -O2
LDFLAGS = -lcurl
TARGET = misskey_example
LIB = libmisskey.a
SRC_DIR = src

SOURCES = $(SRC_DIR)/misskey_client.c $(SRC_DIR)/cJSON/cJSON.c
HEADERS = $(SRC_DIR)/misskey_client.h $(SRC_DIR)/cJSON/cJSON.h

.PHONY: all clean run run-tracked lib

all: $(LIB) $(TARGET)

$(LIB): $(SOURCES) $(HEADERS)
	$(CC) $(CFLAGS) -c $(SOURCES)
	ar rcs $(LIB) misskey_client.o cJSON.o

$(TARGET): $(SOURCES) $(HEADERS)
	$(CC) $(CFLAGS) -o $@ $(SOURCES) src/examples.c $(LDFLAGS)

clean:
	rm -f $(TARGET) $(LIB) *.o

run: $(TARGET)
	./$(TARGET) $(HOST) $(TOKEN)

run-tracked: $(TARGET)
	./$(TARGET) $(HOST) $(TOKEN) --track-alloc

mock-server:
	/opt/pyenv/bin/python mock_server.py

mock-test: $(TARGET)
	@echo "Starting mock server..."
	@/opt/pyenv/bin/python mock_server.py &
	@sleep 2
	@echo "Running tests..."
	@./$(TARGET) localhost:3000 $(TOKEN)
	@pkill -f mock_server.py

help:
	@echo "Misskey C Client"
	@echo ""
	@echo "Usage:"
	@echo "  make all             - Build the example"
	@echo "  make clean           - Remove build artifacts"
	@echo "  make run HOST=<host> TOKEN=<token> - Run with default allocator"
	@echo "  make run-tracked HOST=<host> TOKEN=<token> - Run with memory tracking"
	@echo "  make mock-server     - Start mock server (requires flask)"
	@echo "  make mock-test TOKEN=<token> - Run tests against mock server"
	@echo ""
	@echo "Examples:"
	@echo "  make run HOST=misskey.io TOKEN=your_token"
	@echo "  make run-tracked HOST=misskey.io TOKEN=your_token"
	@echo "  make mock-test TOKEN=test_token_12345"

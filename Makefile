CC = gcc
CXX = g++
CFLAGS = -Wall -Wextra -I./src -O2
CXXFLAGS = -Wall -Wextra -I./src -O2 -std=c++17
LDFLAGS = -lcurl
TARGET = misskey_example
CPP_TARGET = misskey_cpp_test
LIB = libmisskey.a
SRC_DIR = src

SOURCES = $(SRC_DIR)/misskey_client.c $(SRC_DIR)/cJSON/cJSON.c
HEADERS = $(SRC_DIR)/misskey_client.h $(SRC_DIR)/cJSON/cJSON.h $(SRC_DIR)/misskey.hpp

.PHONY: all clean run run-tracked lib cpp cpp-test mock-server mock-test

all: $(LIB) $(TARGET)

$(LIB): $(SOURCES) $(HEADERS)
	$(CC) $(CFLAGS) -c $(SOURCES)
	ar rcs $(LIB) misskey_client.o cJSON.o

$(TARGET): $(SOURCES) $(HEADERS)
	$(CC) $(CFLAGS) -o $@ $(SOURCES) src/examples.c $(LDFLAGS)

cpp: $(LIB)
	$(CXX) $(CXXFLAGS) -o $(CPP_TARGET) src/test_cpp.cpp -L. -lmisskey $(LDFLAGS)

clean:
	rm -f $(TARGET) $(CPP_TARGET) $(LIB) *.o

run: $(TARGET)
	./$(TARGET) $(HOST) $(TOKEN)

run-tracked: $(TARGET)
	./$(TARGET) $(HOST) $(TOKEN) --track-alloc

cpp-test: cpp
	./$(CPP_TARGET) $(HOST) $(TOKEN)

mock-server:
	/opt/pyenv/bin/python mock_server.py

mock-test: $(TARGET)
	@echo "Starting mock server..."
	@/opt/pyenv/bin/python mock_server.py &
	@sleep 2
	@echo "Running tests..."
	@./$(TARGET) localhost:3000 $(TOKEN)
	@pkill -f mock_server.py

mock-cpp-test: cpp
	@echo "Starting mock server..."
	@/opt/pyenv/bin/python mock_server.py &
	@sleep 2
	@echo "Running C++ tests..."
	@./$(CPP_TARGET) localhost:3000 $(TOKEN)
	@pkill -f mock_server.py

help:
	@echo "Misskey Client"
	@echo ""
	@echo "Usage:"
	@echo "  make all              - Build C library and example"
	@echo "  make clean            - Remove build artifacts"
	@echo "  make run HOST=<host> TOKEN=<token> - Run C example"
	@echo "  make cpp              - Build C++ example"
	@echo "  make cpp-test HOST=<host> TOKEN=<token> - Run C++ example"
	@echo "  make mock-server       - Start mock server"
	@echo "  make mock-test        - Run C tests against mock server"
	@echo "  make mock-cpp-test    - Run C++ tests against mock server"
	@echo ""
	@echo "Examples:"
	@echo "  make run HOST=misskey.io TOKEN=your_token"
	@echo "  make cpp-test HOST=localhost:3000 TOKEN=test_token"

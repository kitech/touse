CXX ?= g++
CC ?= gcc
AR ?= ar
CXXFLAGS ?= -O1 -Wall -Wextra
CFLAGS ?= -O1 -Wall -Wextra
CPPFLAGS += -Iinclude
CXXSTD := -std=c++11
CSTD := -std=c11

LIB := librscabi.a
CORE_OBJS := src/core/core.o src/model/abi_type.o src/capi/rscabi_capi.o
ABI_OBJS := src/abi/ty_interface.o src/abi/callconv.o src/abi/canon_abi.o \
            src/abi/extern_abi.o src/abi/abi_query.o

.PHONY: all check clean

all: $(LIB) rscabi_dump

$(LIB): $(CORE_OBJS) $(ABI_OBJS)
	$(AR) rcs $@ $^

src/core/core.o: src/core/core.cpp src/core/core.hpp
	$(CXX) $(CXXSTD) $(CXXFLAGS) $(CPPFLAGS) -c $< -o $@

src/model/abi_type.o: src/model/abi_type.cpp src/model/abi_type.hpp src/core/core.hpp
	$(CXX) $(CXXSTD) $(CXXFLAGS) $(CPPFLAGS) -c $< -o $@

src/abi/ty_interface.o: src/abi/ty_interface.cpp src/abi/ty_interface.hpp \
                        src/abi/callconv.hpp src/core/core.hpp src/model/abi_type.hpp
	$(CXX) $(CXXSTD) $(CXXFLAGS) $(CPPFLAGS) -c $< -o $@

src/abi/callconv.o: src/abi/callconv.cpp src/abi/callconv.hpp src/core/core.hpp
	$(CXX) $(CXXSTD) $(CXXFLAGS) $(CPPFLAGS) -c $< -o $@

src/abi/canon_abi.o: src/abi/canon_abi.cpp src/abi/canon_abi.hpp src/abi/extern_abi.hpp
	$(CXX) $(CXXSTD) $(CXXFLAGS) $(CPPFLAGS) -c $< -o $@

src/abi/extern_abi.o: src/abi/extern_abi.cpp src/abi/extern_abi.hpp
	$(CXX) $(CXXSTD) $(CXXFLAGS) $(CPPFLAGS) -c $< -o $@

src/abi/abi_query.o: src/abi/abi_query.cpp src/abi/abi_query.hpp \
                     src/abi/callconv.hpp src/abi/canon_abi.hpp \
                     src/abi/extern_abi.hpp src/abi/ty_interface.hpp \
                     src/model/abi_type.hpp
	$(CXX) $(CXXSTD) $(CXXFLAGS) $(CPPFLAGS) -c $< -o $@

src/capi/rscabi_capi.o: src/capi/rscabi_capi.cpp src/model/abi_type.hpp include/rscabi.h \
                        src/abi/abi_query.hpp src/abi/callconv.hpp \
                        src/abi/canon_abi.hpp src/abi/extern_abi.hpp
	$(CXX) $(CXXSTD) $(CXXFLAGS) $(CPPFLAGS) -c $< -o $@

rscabi_dump: cli/rscabi_dump.cpp $(LIB)
	$(CXX) $(CXXSTD) $(CXXFLAGS) $(CPPFLAGS) $< $(LIB) -o $@

tests/unit/test_core: tests/unit/test_core.cpp $(LIB)
	$(CXX) $(CXXSTD) $(CXXFLAGS) $(CPPFLAGS) $< $(LIB) -o $@

tests/unit/test_abi: tests/unit/test_abi.cpp $(LIB)
	$(CXX) $(CXXSTD) $(CXXFLAGS) $(CPPFLAGS) $< $(LIB) -o $@

tests/capi/test_capi: tests/capi/test_capi.c $(LIB)
	$(CC) $(CSTD) $(CFLAGS) $(CPPFLAGS) $< $(LIB) -lstdc++ -o $@

tests/capi/test_abi: tests/capi/test_abi.c $(LIB)
	$(CC) $(CSTD) $(CFLAGS) $(CPPFLAGS) $< $(LIB) -lstdc++ -o $@

check: tests/unit/test_core tests/unit/test_abi tests/capi/test_capi tests/capi/test_abi
	./tests/unit/test_core
	./tests/unit/test_abi
	./tests/capi/test_capi
	./tests/capi/test_abi
	./rscabi_dump --type 'option(ref(u8))'
	./rscabi_dump --type 'u32' --target-triple 'aarch64-unknown-linux-gnu' --extern-abi aapcs

clean:
	rm -f $(CORE_OBJS) $(ABI_OBJS) $(LIB) rscabi_dump \
		tests/unit/test_core tests/unit/test_abi \
		tests/capi/test_capi tests/capi/test_abi

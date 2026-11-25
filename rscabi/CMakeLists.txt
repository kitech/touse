cmake_minimum_required(VERSION 3.10)
project(rscabi CXX C)

set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)

add_library(rscabi STATIC
  src/core/core.cpp
  src/model/abi_type.cpp
  src/abi/ty_interface.cpp
  src/abi/callconv.cpp
  src/abi/canon_abi.cpp
  src/abi/extern_abi.cpp
  src/abi/abi_query.cpp
  src/capi/rscabi_capi.cpp
)
target_include_directories(rscabi PUBLIC include)
target_include_directories(rscabi PRIVATE src)

add_executable(rscabi_dump cli/rscabi_dump.cpp)
target_link_libraries(rscabi_dump PRIVATE rscabi)
target_include_directories(rscabi_dump PRIVATE src)

enable_testing()

add_executable(rscabi_test_core tests/unit/test_core.cpp)
target_link_libraries(rscabi_test_core PRIVATE rscabi)
target_include_directories(rscabi_test_core PRIVATE src)
add_test(NAME core COMMAND rscabi_test_core)

add_executable(rscabi_test_capi tests/capi/test_capi.c)
target_link_libraries(rscabi_test_capi PRIVATE rscabi)
add_test(NAME capi COMMAND rscabi_test_capi)

add_executable(rscabi_test_abi tests/unit/test_abi.cpp)
target_link_libraries(rscabi_test_abi PRIVATE rscabi)
target_include_directories(rscabi_test_abi PRIVATE src)
add_test(NAME abi COMMAND rscabi_test_abi)

add_executable(rscabi_test_capi_abi tests/capi/test_abi.c)
target_link_libraries(rscabi_test_capi_abi PRIVATE rscabi)
add_test(NAME capi_abi COMMAND rscabi_test_capi_abi)

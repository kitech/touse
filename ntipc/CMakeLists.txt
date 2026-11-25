cmake_minimum_required(VERSION 3.16)
project(ntipc LANGUAGES C)

option(NTIPC_BUILD_SHARED "Build shared library" ON)
option(NTIPC_BUILD_TESTING "Build tests" ON)

set(NTIPC_SOURCES
	src/common.c
	src/pipe_posix.c
	src/pipe_windows.c)

add_library(ntipc_static STATIC ${NTIPC_SOURCES})
target_include_directories(ntipc_static PUBLIC include)
target_compile_features(ntipc_static PUBLIC c_std_11)
set_target_properties(ntipc_static PROPERTIES OUTPUT_NAME ntipc)

if(WIN32)
	target_link_libraries(ntipc_static PUBLIC advapi32)
else()
	find_package(Threads REQUIRED)
	target_link_libraries(ntipc_static PUBLIC Threads::Threads)
	if(UNIX AND NOT APPLE)
		target_link_libraries(ntipc_static PUBLIC rt)
	endif()
endif()

if(NTIPC_BUILD_SHARED AND NOT WIN32)
	add_library(ntipc_shared SHARED ${NTIPC_SOURCES})
	target_include_directories(ntipc_shared PUBLIC include)
	target_compile_features(ntipc_shared PUBLIC c_std_11)
	set_target_properties(ntipc_shared PROPERTIES OUTPUT_NAME ntipc POSITION_INDEPENDENT_CODE ON)
	find_package(Threads REQUIRED)
	target_link_libraries(ntipc_shared PUBLIC Threads::Threads)
	if(UNIX AND NOT APPLE)
		target_link_libraries(ntipc_shared PUBLIC rt)
	endif()
endif()

add_library(ntipc ALIAS ntipc_static)

include(CTest)
if(NTIPC_BUILD_TESTING AND BUILD_TESTING)
	add_executable(ntipc_tests tests/test_ntipc.c)
	target_link_libraries(ntipc_tests PRIVATE ntipc)
	add_test(NAME ntipc COMMAND ntipc_tests)
	set_tests_properties(ntipc PROPERTIES TIMEOUT 120)
endif()

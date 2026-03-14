cmake_minimum_required(VERSION 3.10)
project(drake LANGUAGES NONE)

# Paths
set(DRAKE_SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR})
set(DRAKE_BINARY_DIR ${CMAKE_CURRENT_BINARY_DIR})

# Find Emacs
find_program(EMACS_EXECUTABLE NAMES emacs)
if(NOT EMACS_EXECUTABLE)
    message(WARNING "Emacs not found. Some targets will be unavailable.")
endif()

# Find Cargo
find_program(CARGO_EXECUTABLE NAMES cargo)
if(NOT CARGO_EXECUTABLE)
    message(FATAL_ERROR "Cargo not found. Cannot build Rust module.")
endif()

# ASAN Support
option(ENABLE_ASAN "Enable Address Sanitizer" OFF)
if(ENABLE_ASAN)
    message(STATUS "Address Sanitizer (ASAN) enabled for Rust module")
    set(CARGO_ASAN_FLAGS "-Zsanitizer=address")
    set(ENV{RUSTFLAGS} "${CARGO_ASAN_FLAGS}")
    # Note: ASAN in Rust often requires nightly or specific toolchain setup, 
    # but we'll set the environment variable as a standard way to pass it.
endif()

# Platform-specific library extension
if(APPLE)
    set(CARGO_LIB_SUFFIX "dylib")
elseif(WIN32)
    set(CARGO_LIB_SUFFIX "dll")
else()
    set(CARGO_LIB_SUFFIX "so")
endif()

# Rust module build
set(RUST_LIB_NAME "libdrake_rust_module.${CARGO_LIB_SUFFIX}")
if(WIN32)
    set(RUST_LIB_NAME "drake_rust_module.${CARGO_LIB_SUFFIX}")
endif()

set(RUST_TARGET_DIR "${DRAKE_SOURCE_DIR}/rust/target/release")
set(OUTPUT_LIB "${DRAKE_SOURCE_DIR}/drake-rust-module.so")

add_custom_command(
    OUTPUT "${OUTPUT_LIB}"
    COMMAND ${CARGO_EXECUTABLE} build --release
    COMMAND ${CMAKE_COMMAND} -E copy "${RUST_TARGET_DIR}/${RUST_LIB_NAME}" "${OUTPUT_LIB}"
    WORKING_DIRECTORY "${DRAKE_SOURCE_DIR}/rust"
    COMMENT "Building and copying Rust module..."
    VERBATIM
)

add_custom_target(module ALL DEPENDS "${OUTPUT_LIB}")
add_custom_target(build DEPENDS module)

# Testing
if(EMACS_EXECUTABLE)
    enable_testing()

    set(LOAD_PATH -L . -L tests)
    
    # Discover all test files
    file(GLOB_RECURSE TEST_FILES "tests/*-tests.el" "tests/*-test.el")
    
    foreach(test_file ${TEST_FILES})
        get_filename_component(test_name ${test_file} NAME_WE)
        
        # Exclude helper files if they match the pattern (though they shouldn't with -tests.el/-test.el)
        if(NOT test_name STREQUAL "test-helper")
            add_test(NAME ${test_name}
                COMMAND ${EMACS_EXECUTABLE} -batch ${LOAD_PATH} -l tests/test-helper.el -l "${test_file}" -f ert-run-tests-batch-and-exit
                WORKING_DIRECTORY "${DRAKE_SOURCE_DIR}"
            )
        endif()
    endforeach()

    # Performance benchmarks
    add_test(NAME bench-normalization
        COMMAND ${EMACS_EXECUTABLE} -batch ${LOAD_PATH} -l tests/benchmarks.el
        WORKING_DIRECTORY "${DRAKE_SOURCE_DIR}"
    )
    set_tests_properties(bench-normalization PROPERTIES LABELS BENCHMARK)

    add_test(NAME bench-rendering
        COMMAND ${EMACS_EXECUTABLE} -batch ${LOAD_PATH} -l examples/performance-bench.el
        WORKING_DIRECTORY "${DRAKE_SOURCE_DIR}"
    )
    set_tests_properties(bench-rendering PROPERTIES LABELS BENCHMARK)

    # Custom target to run all tests (excluding benchmarks)
    add_custom_target(check
        COMMAND ${CMAKE_CTEST_COMMAND} -E "bench-" --output-on-failure
        DEPENDS module
        COMMENT "Running all tests..."
    )

    # Custom target to run benchmarks
    add_custom_target(bench
        COMMAND ${CMAKE_CTEST_COMMAND} -L BENCHMARK --output-on-failure
        DEPENDS module
        COMMENT "Running all benchmarks..."
    )

    add_custom_target(demo
        COMMAND ${EMACS_EXECUTABLE} -batch ${LOAD_PATH} -l tests/test-helper.el -l examples/stage2-demo.el
        DEPENDS module
        WORKING_DIRECTORY "${DRAKE_SOURCE_DIR}"
        COMMENT "Running demo..."
    )
endif()

# Clean
# CMake's default clean target won't remove drake-rust-module.so because it's a manual copy outside the build dir.
set_property(DIRECTORY . APPEND PROPERTY ADDITIONAL_CLEAN_FILES "${OUTPUT_LIB}")

# Custom clean target to match Makefile behavior
add_custom_target(clean-all
    COMMAND ${CMAKE_COMMAND} -E remove -f "${OUTPUT_LIB}"
    COMMAND ${CMAKE_COMMAND} -E remove -f *.elc tests/*.elc examples/*.elc
    COMMAND ${CARGO_EXECUTABLE} clean
    WORKING_DIRECTORY "${DRAKE_SOURCE_DIR}/rust"
    COMMENT "Cleaning up all build artifacts and compiled Lisp files..."
)

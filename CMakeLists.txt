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
    set(TEST_FILES 
        tests/drake-tests.el
        tests/drake-svg-tests.el
        tests/stage3-tests.el
        tests/stage4-tests.el
        tests/drake-gnuplot-tests.el
        tests/uncertainty-tests.el
    )

    # Convert TEST_FILES to include -l before each file
    set(EMACS_TEST_ARGS "")
    foreach(test_file ${TEST_FILES})
        list(APPEND EMACS_TEST_ARGS -l "${test_file}")
    endforeach()

    add_test(NAME basic_tests
        COMMAND ${EMACS_EXECUTABLE} -batch ${LOAD_PATH} ${EMACS_TEST_ARGS} -f ert-run-tests-batch-and-exit
        WORKING_DIRECTORY "${DRAKE_SOURCE_DIR}"
    )

    add_test(NAME all_tests
        COMMAND ${EMACS_EXECUTABLE} -batch ${LOAD_PATH} ${EMACS_TEST_ARGS} -l tests/duckdb-drake-tests.el -f ert-run-tests-batch-and-exit
        WORKING_DIRECTORY "${DRAKE_SOURCE_DIR}"
    )

    add_test(NAME rust_tests
        COMMAND ${EMACS_EXECUTABLE} -batch ${LOAD_PATH} ${EMACS_TEST_ARGS} -l tests/drake-rust-tests.el -f ert-run-tests-batch-and-exit
        WORKING_DIRECTORY "${DRAKE_SOURCE_DIR}"
    )

    # Custom targets for convenience (similar to Makefile)
    add_custom_target(drake-test
        COMMAND ${CMAKE_CTEST_COMMAND} -R basic_tests --output-on-failure
        DEPENDS module
        COMMENT "Running basic tests..."
    )

    add_custom_target(test-all
        COMMAND ${CMAKE_CTEST_COMMAND} -R all_tests --output-on-failure
        DEPENDS module
        COMMENT "Running all tests..."
    )

    add_custom_target(test-rust
        COMMAND ${CMAKE_CTEST_COMMAND} -R rust_tests --output-on-failure
        DEPENDS module
        COMMENT "Running Rust-specific tests..."
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

# Makefile for drake

ifeq ($(OS),Darwin)
LIB_SUFFIX := dylib
else
LIB_SUFFIX := so
endif

EMACS ?= emacs
LOAD_PATH = -L . -L tests

TEST_FILES = tests/drake-tests.el \
             tests/drake-svg-tests.el \
             tests/stage3-tests.el \
             tests/stage4-tests.el \
             tests/drake-gnuplot-tests.el \
             tests/uncertainty-tests.el

.PHONY: test demo clean test-all build module

test:
	$(EMACS) -batch $(LOAD_PATH) $(foreach file,$(TEST_FILES),-l $(file)) -f ert-run-tests-batch-and-exit

test-all:
	$(EMACS) -batch $(LOAD_PATH) $(foreach file,$(TEST_FILES) tests/duckdb-drake-tests.el,-l $(file)) -f ert-run-tests-batch-and-exit

test-rust:
	$(EMACS) -batch $(LOAD_PATH) $(foreach file,$(TEST_FILES) tests/drake-rust-tests.el,-l $(file)) -f ert-run-tests-batch-and-exit

demo:
	$(EMACS) -batch $(LOAD_PATH) -l tests/test-helper.el -l examples/stage2-demo.el

build: module

module:
	cd rust && cargo build --release
	cp rust/target/release/libdrake_rust_module.$(LIB_SUFFIX) drake-rust-module.so

clean:
	rm -f *.elc tests/*.elc examples/*.elc
	rm -f drake-rust-module.so
	cd rust && cargo clean

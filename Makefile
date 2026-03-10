# Makefile for drake

EMACS ?= emacs
LOAD_PATH = -L . -L tests

TEST_FILES = tests/drake-tests.el \
             tests/drake-svg-tests.el \
             tests/stage3-tests.el \
             tests/stage4-tests.el \
             tests/drake-gnuplot-tests.el

.PHONY: test demo clean test-all

test:
	$(EMACS) -batch $(LOAD_PATH) $(foreach file,$(TEST_FILES),-l $(file)) -f ert-run-tests-batch-and-exit

test-all:
	$(EMACS) -batch $(LOAD_PATH) $(foreach file,$(TEST_FILES) tests/duckdb-drake-tests.el,-l $(file)) -f ert-run-tests-batch-and-exit

demo:
	$(EMACS) -batch $(LOAD_PATH) -l tests/test-helper.el -l examples/stage2-demo.el

clean:
	rm -f *.elc tests/*.elc examples/*.elc

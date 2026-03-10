# Makefile for drake

EMACS ?= emacs
LOAD_PATH = -L . -L tests

.PHONY: test demo clean

test:
	$(EMACS) -batch $(LOAD_PATH) -l tests/drake-tests.el -f ert-run-tests-batch-and-exit

demo:
	$(EMACS) -batch $(LOAD_PATH) -l tests/test-helper.el -l examples/stage2-demo.el

clean:
	rm -f *.elc tests/*.elc examples/*.elc

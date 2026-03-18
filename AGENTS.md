# Agent Guide: emacs drake Development

This document serves as the authoritative guide for an AI agent to
assist in the development of the emacs `drake` package.

## 1. Project Goals
- **Ease of use:** Easy to use statistical plots in Emacs.
- **Ergonomics:** Provide an Elisp API that feels native to Emacs.
- **Performance:** To balance ease-of-use (from within Emacs) and
  performance we might wrap a Rust or C plotting library (like
  plotters).  The C module coding convention refers to this possible
  dynamic module.

## 2. Directory Structure
Adhere to the standard layout for Emacs dynamic modules to ensure ease of compilation and packaging.

```text
drake/
├── README.md              # Project overview
├── AGENTS.md              # This file (AI instructions)
├── drake.el               # Elisp , high-level API, and declarations
├── drake-svg.el           # A backend for svg.el
├── ...                    # Other backends (for performance)
├── lib/                   # Local copies of duckdb.h if not system-wide
└── tests/
    ├── test-helper.el     # Test environment setup
    ├── drake-tests.el     # ERT (Emacs Lisp Regression Tool) suites
    ├── drake-svg-tests.el # ERT (Emacs Lisp Regression Tool) suites
    └── ...                # ERT (Emacs Lisp Regression Tool) suites

```

## 3. Coding Conventions

Do not use emoji in any files.

### 3.1 C (Module) Conventions

* **Naming:** Prefix all internal C functions with `drake_` and Lisp-exposed functions with `Fdrake_`.
* **GPL:** Every module must include `int plugin_is_GPL_compatible;`.
* **Error Handling:** Never use `exit()`. Use `env->non_local_exit_signal` to pass errors back to Elisp. Use the `SIGNAL_ERROR` macro from `duckdb-api.h`.
* **Memory:** Every `duckdb_database`, `duckdb_connection`, and `duckdb_result` must be wrapped in a `user_ptr` with a custom finalizer.
* **Type Safety:** Explicitly check types of `emacs_value` arguments using `env->type_of` before processing.

### 3.2 Emacs Lisp Conventions

* **Prefix:** All functions, variables, and faces must start with `drake-`.
* **Documentation:** Every function must have a docstring explaining arguments and return types.
* **Dependencies:** Use `(require 'cl-lib)` for modern list/struct manipulation.
* **Safety:** Use `unwind-protect` in macros to ensure resources are freed if Lisp code signals an error.

## 4. Key Implementation Details (For Future Agents)

### 4.1 Columnar Data Format
The library is optimized for use with the duckdb Emacs package.
* `duckdb-select-columns` returns a plist: `(:data (:col1 [v1 v2 ...] :col2 [v3 v4 ...]) :types (:col1 "VARCHAR" :col2 "INTEGER"))`.
* Data columns are Emacs vectors (`[v1 v2 ...]`). This format is optimized for `vtable` and large dataset processing.

### 4.3 Flexible Data Source

### 4.4 Flexible Backend
* The results of the high-level API is a drak-plot object that can be
  passed to a variety of backend.  The simples backend is built using `svg.el`.

## 5. Testing Strategy

We follow a "Lisp-Driven Testing" approach. Since the C code is an extension of the Lisp environment, we test it via Elisp.

* **Framework:** Use **ERT** (Emacs Lisp Regression Test).
* **Coverage:**
  * **Resource Lifecycle:** Verify that rendering charts doesn't leak memory.
  * **Type Fidelity:** Ensure large integers and floats retain precision across the C/Elisp boundary.
  * **Error States:** Pass malformed plot arguments to C and verify that a Lisp-level `drake-error` is signaled.

* **Address Sanitizer:** Use address sanitizer to ensure there are no memory bugs. Enable ASAN in CMake using `-DENABLE_ASAN=ON`, rebuild, and run the tests. Always run the asan tests before declaring work completed.

## 6. Development Workflow (Agent Protocol)

1. **Reproduction:** Before fixing a bug, add a test case to
   `tests/drake-tests.el` (or simialr file) that fails.
2. **Build:** Use `cmake ..` and `make` (with `-DENABLE_ASAN=ON` if needed) to compile.
3. **Verification:** Ensure `ctest` passes and that no memory leaks are reported by ASAN.
4. **Documentation:** Update docstrings in `drake.el` and `README.md` if the public API changes.

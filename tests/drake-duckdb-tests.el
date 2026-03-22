(require 'ert)
(add-to-list 'load-path default-directory)
(add-to-list 'load-path "/root/src/duckdb-el")

(ert-deftest drake-duckdb-load-test ()
  (skip-unless (require 'duckdb nil t))
  (should (require 'drake-duckdb nil t))
  (should (fboundp 'drake-duckdb-transient))
  (should (fboundp 'drake-duckdb-generate))
  (should (boundp 'drake-duckdb-chart-type)))

(ert-deftest drake-duckdb-columns-mock-test ()
  (skip-unless (require 'duckdb nil t))
  (require 'drake-duckdb)
  (with-temp-buffer
    (duckdb-query-results-mode)
    (setq tabulated-list-format [("col1" 20 t) ("col2" 20 t)])
    (should (equal (drake-duckdb--get-columns) '("col1" "col2")))))

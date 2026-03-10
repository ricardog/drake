;;; duckdb-drake-tests.el --- Tests for drake using duckdb data -*- lexical-binding: t; -*-

(require 'test-helper)
(require 'duckdb)

(ert-deftest drake-duckdb-integration-test ()
  (let* ((db (duckdb-open ":memory:"))
         (conn (duckdb-connect db)))
    (duckdb-execute conn "CREATE TABLE iris AS SELECT * FROM read_csv_auto('/root/src/duckdb-el/iris.csv')")
    (let* ((res (duckdb-select-columns conn "SELECT sepal_length, sepal_width FROM iris LIMIT 10"))
           (plot (drake-plot-scatter :data res :x :sepal_length :y :sepal_width :title "Iris Data")))
      (should (drake-plot-p plot))
      (should (equal (length (plist-get (drake-plot-data-internal plot) :x)) 10))
      (duckdb-disconnect conn)
      (duckdb-close db))))

(provide 'duckdb-drake-tests)

;;; duckdb-drake-tests.el --- Tests for drake using duckdb data -*- lexical-binding: t; -*-

(require 'test-helper)

(ert-deftest drake-duckdb-integration-test ()
  (drake-skip-unless-duckdb)
  (require 'duckdb)
  (let* ((db (duckdb-open ":memory:"))
         (conn (duckdb-connect db))
         (drake-dir (file-name-directory (locate-library "drake.el" t)))
         (iris-file (expand-file-name "datasets/iris.csv.gz" drake-dir)))
    (duckdb-execute conn (format "CREATE TABLE iris AS SELECT * FROM read_csv_auto('%s')" iris-file))
    (let* ((res (duckdb-select-columns conn "SELECT sepal_length, sepal_width FROM iris LIMIT 10"))
           (plot (drake-plot-scatter :data res :x :sepal_length :y :sepal_width :title "Iris Data")))
      (should (drake-plot-p plot))
      (should (equal (length (plist-get (drake-plot-data-internal plot) :x)) 10))
      (duckdb-disconnect conn)
      (duckdb-close db))))

(provide 'duckdb-drake-tests)

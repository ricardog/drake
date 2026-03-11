;;; iris-scatter.el --- Example: Iris Scatter Plot -*- lexical-binding: t; -*-

;; Ensure we can find the drake package
(add-to-list 'load-path (expand-file-name ".." (file-name-directory (or load-file-name (buffer-file-name)))))
;; Ensure duckdb-el is in load-path
(add-to-list 'load-path "/root/src/duckdb-el")

(require 'drake)
(require 'drake-svg)
(require 'duckdb)

(let* ((db (duckdb-open ":memory:"))
       (conn (duckdb-connect db))
       (drake-dir (file-name-directory (locate-library "drake.el" t)))
       (dataset-dir (expand-file-name "datasets" drake-dir))
       (data-file (expand-file-name "iris.csv.gz" dataset-dir))
       (sql (format "CREATE TABLE iris AS SELECT * FROM read_csv_auto('%s')"
		    data-file)))
  (duckdb-execute conn sql)
  (let ((data (duckdb-select-columns conn "SELECT sepal_length, sepal_width FROM iris")))
    (drake-plot-scatter :data data :x :sepal_length :y :sepal_width :title "Iris: Sepal Length vs Width"))
  (duckdb-disconnect conn)
  (duckdb-close db))

(message "Plot rendered in *drake-plot* buffer.")

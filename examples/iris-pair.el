;;; iris-pair.el --- Example: Pair Plot -*- lexical-binding: t; -*-

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

  ;; Example 1: Basic pair plot
  (let ((data (duckdb-select-columns conn "SELECT sepal_length, sepal_width, petal_length FROM iris")))
    (drake-plot-pair :data data
                    :vars '(:sepal_length :sepal_width :petal_length)
                    :title "Iris Pair Plot"
                    :buffer "*drake-pair-1*"))

  ;; Example 2: Pair plot with species coloring
  (let ((data (duckdb-select-columns conn "SELECT sepal_length, sepal_width, petal_length, species FROM iris")))
    (drake-plot-pair :data data
                    :vars '(:sepal_length :sepal_width :petal_length)
                    :hue :species
                    :palette 'set1
                    :title "Iris by Species"
                    :buffer "*drake-pair-2*"))

  ;; Example 3: Corner mode (lower triangle only)
  (let ((data (duckdb-select-columns conn "SELECT sepal_length, sepal_width, petal_length, species FROM iris")))
    (drake-plot-pair :data data
                    :vars '(:sepal_length :sepal_width :petal_length)
                    :hue :species
                    :corner t
                    :title "Iris Correlation (Corner)"
                    :buffer "*drake-pair-3*"))

  (duckdb-disconnect conn)
  (duckdb-close db))

(message "Pair plots rendered in *drake-pair-** buffers.")

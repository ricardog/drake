;;; tips-count.el --- Example: Count Plot -*- lexical-binding: t; -*-

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
       (data-file (expand-file-name "tips.csv.gz" dataset-dir))
       (sql (format "CREATE TABLE tips AS SELECT * FROM read_csv_auto('%s')"
                   data-file)))
  (duckdb-execute conn sql)

  ;; Example 1: Simple count plot
  (let ((data (duckdb-select-columns conn "SELECT day FROM tips")))
    (drake-plot-count :data data :x :day
                     :title "Restaurant Visits by Day"
                     :buffer "*drake-count-1*"))

  ;; Example 2: Count plot with hue grouping
  (let ((data (duckdb-select-columns conn "SELECT day, time FROM tips")))
    (drake-plot-count :data data :x :day :hue :time
                     :palette 'set2
                     :title "Lunch vs Dinner by Day"
                     :buffer "*drake-count-2*"))

  ;; Example 3: Ordered by frequency
  (let ((data (duckdb-select-columns conn "SELECT day FROM tips")))
    (drake-plot-count :data data :x :day
                     :order 'value-desc
                     :palette 'dark2
                     :title "Most Popular Days"
                     :buffer "*drake-count-3*"))

  (duckdb-disconnect conn)
  (duckdb-close db))

(message "Count plots rendered in *drake-count-** buffers.")

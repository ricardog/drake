;;; tips-regression.el --- Example: Linear Regression Plot -*- lexical-binding: t; -*-

;; Ensure we can find the drake package
(add-to-list 'load-path (expand-file-name ".." (file-name-directory (or load-file-name (buffer-file-name)))))
;; Ensure duckdb-el is in load-path (optional, but often needed in this environment)
(add-to-list 'load-path "/root/src/duckdb-el")

(require 'drake)
(require 'drake-svg)
(require 'duckdb)

;; Mock imagep if not defined (e.g. in batch mode)
(unless (fboundp 'imagep)
  (defun imagep (_) t))

(defun examples-tips-regression ()
  "Render a linear regression plot for the Tips dataset."
  (let* ((db (duckdb-open ":memory:"))
         (conn (duckdb-connect db))
         ;; Find the dataset directory relative to this file
         (current-dir (file-name-directory (or load-file-name (buffer-file-name) default-directory)))
         (dataset-dir (expand-file-name "../datasets" current-dir))
         (data-file (expand-file-name "tips.csv.gz" dataset-dir))
         (sql (format "CREATE TABLE tips AS SELECT * FROM read_csv_auto('%s')"
		      data-file)))
    (message "Loading dataset from %s..." data-file)
    (duckdb-execute conn sql)

    ;; 1. Standard Linear Regression (Overall)
    (let ((data (duckdb-select-columns conn "SELECT total_bill, tip FROM tips")))
      (drake-plot-lm :data data :x :total_bill :y :tip 
                     :title "Overall Linear Regression: Total Bill vs Tip"
                     :buffer "*drake-lm-overall*"
                     :xlabel "Total Bill ($)"
                     :ylabel "Tip ($)"))

    ;; 2. Grouped Linear Regression (By Sex)
    (let ((data (duckdb-select-columns conn "SELECT total_bill, tip, sex FROM tips")))
      (drake-plot-lm :data data :x :total_bill :y :tip :hue :sex
                     :title "Grouped Linear Regression: Total Bill vs Tip by Sex"
                     :buffer "*drake-lm-sex*"
                     :xlabel "Total Bill ($)"
                     :ylabel "Tip ($)"
                     :palette 'set1))

    ;; 3. Grouped Linear Regression (By Time of Day)
    (let ((data (duckdb-select-columns conn "SELECT total_bill, tip, time FROM tips")))
      (drake-plot-lm :data data :x :total_bill :y :tip :hue :time
                     :title "Grouped Linear Regression: Total Bill vs Tip by Time"
                     :buffer "*drake-lm-time*"
                     :xlabel "Total Bill ($)"
                     :ylabel "Tip ($)"
                     :palette 'dark2))

    (duckdb-disconnect conn)
    (duckdb-close db)
    (message "Three plots rendered: *drake-lm-overall*, *drake-lm-sex*, and *drake-lm-time*.")))

(examples-tips-regression)

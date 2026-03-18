;;; generate-images.el --- Generate example images for documentation -*- lexical-binding: t; -*-

;;; Commentary:
;; This script runs all Drake examples and saves the outputs to examples/images/
;; for inclusion in documentation.

;;; Code:

;; Set up load paths
(add-to-list 'load-path (expand-file-name ".."))
(add-to-list 'load-path "/root/src/duckdb-el")

(require 'drake)
(require 'drake-svg)
(require 'duckdb)

(defvar drake-examples-output-dir
  (expand-file-name "images" (file-name-directory (or load-file-name (buffer-file-name))))
  "Directory for example output images.")

(defun drake-save-example (plot filename)
  "Save PLOT to FILENAME in the examples output directory."
  (let ((output-path (expand-file-name filename drake-examples-output-dir)))
    (drake-save-plot plot output-path)
    (message "Saved: %s" output-path)))

;; Load iris dataset
(defvar drake-iris-data nil)
(defvar drake-tips-data nil)

(let* ((db (duckdb-open ":memory:"))
       (conn (duckdb-connect db))
       (drake-dir (file-name-directory (locate-library "drake.el" t)))
       (dataset-dir (expand-file-name "datasets" drake-dir)))

  ;; Load iris
  (let ((iris-file (expand-file-name "iris.csv.gz" dataset-dir)))
    (duckdb-execute conn (format "CREATE TABLE iris AS SELECT * FROM read_csv_auto('%s')" iris-file))
    (setq drake-iris-data (duckdb-select-columns conn "SELECT sepal_length, sepal_width, petal_length, petal_width, species FROM iris")))

  ;; Load tips
  (let ((tips-file (expand-file-name "tips.csv.gz" dataset-dir)))
    (duckdb-execute conn (format "CREATE TABLE tips AS SELECT * FROM read_csv_auto('%s')" tips-file))
    (setq drake-tips-data (duckdb-select-columns conn "SELECT total_bill, tip, sex, smoker, day, time, size FROM tips")))

  (duckdb-disconnect conn)
  (duckdb-close db))

(message "Loaded datasets: iris (%d rows), tips (%d rows)"
         (length (plist-get drake-iris-data :sepal_length))
         (length (plist-get drake-tips-data :total_bill)))

;;; Example 1: Basic Scatter Plot (iris)
(message "Generating: iris-scatter.svg")
(drake-save-example
 (drake-plot-scatter :data drake-iris-data
                    :x :sepal_length
                    :y :sepal_width
                    :hue :species
                    :title "Iris: Sepal Length vs Width"
                    :backend 'svg)
 "iris-scatter.svg")

;;; Example 2: Iris with all species
(message "Generating: iris-petal.svg")
(drake-save-example
 (drake-plot-scatter :data drake-iris-data
                    :x :petal_length
                    :y :petal_width
                    :hue :species
                    :title "Iris: Petal Length vs Width"
                    :palette 'viridis
                    :backend 'svg)
 "iris-petal.svg")

;;; Example 3: Tips Scatter
(message "Generating: tips-scatter.svg")
(drake-save-example
 (drake-plot-scatter :data drake-tips-data
                    :x :total_bill
                    :y :tip
                    :hue :time
                    :title "Restaurant Tips"
                    :backend 'svg)
 "tips-scatter.svg")

;;; Example 4: Tips Regression
(message "Generating: tips-regression.svg")
(drake-save-example
 (drake-plot-lm :data drake-tips-data
               :x :total_bill
               :y :tip
               :hue :time
               :title "Tips vs Bill Amount (with regression)"
               :backend 'svg)
 "tips-regression.svg")

;;; Example 5: Histogram
(message "Generating: tips-histogram.svg")
(drake-save-example
 (drake-plot-hist :data drake-tips-data
                 :x :total_bill
                 :bins 20
                 :title "Distribution of Bill Amounts"
                 :backend 'svg)
 "tips-histogram.svg")

;;; Example 6: Box Plot
(message "Generating: tips-boxplot.svg")
(drake-save-example
 (drake-plot-box :data drake-tips-data
                :x :day
                :y :total_bill
                :order '("Thur" "Fri" "Sat" "Sun")
                :title "Bill Amount by Day of Week"
                :backend 'svg)
 "tips-boxplot.svg")

;;; Example 7: Violin Plot
(message "Generating: tips-violin.svg")
(drake-save-example
 (drake-plot-violin :data drake-tips-data
                   :x :day
                   :y :tip
                   :hue :time
                   :order '("Thur" "Fri" "Sat" "Sun")
                   :hue-order '("Lunch" "Dinner")
                   :title "Tip Distribution by Day and Time"
                   :backend 'svg)
 "tips-violin.svg")

;;; Example 8: Bar Plot
(message "Generating: iris-bar.svg")
;; Aggregate data for bar plot
(let* ((db (duckdb-open ":memory:"))
       (conn (duckdb-connect db))
       (drake-dir (file-name-directory (locate-library "drake.el" t)))
       (dataset-dir (expand-file-name "datasets" drake-dir))
       (iris-file (expand-file-name "iris.csv.gz" dataset-dir)))
  (duckdb-execute conn (format "CREATE TABLE iris AS SELECT * FROM read_csv_auto('%s')" iris-file))
  (let ((data (duckdb-select-columns conn "SELECT species, AVG(sepal_length) as avg_sepal_length FROM iris GROUP BY species")))
    (drake-save-example
     (drake-plot-bar :data data
                    :x :species
                    :y :avg_sepal_length
                    :title "Average Sepal Length by Species"
                    :backend 'svg)
     "iris-bar.svg"))
  (duckdb-disconnect conn)
  (duckdb-close db))

;;; Example 9: Line Plot (tips by size)
(message "Generating: tips-line.svg")
(let* ((db (duckdb-open ":memory:"))
       (conn (duckdb-connect db))
       (drake-dir (file-name-directory (locate-library "drake.el" t)))
       (dataset-dir (expand-file-name "datasets" drake-dir))
       (tips-file (expand-file-name "tips.csv.gz" dataset-dir)))
  (duckdb-execute conn (format "CREATE TABLE tips AS SELECT * FROM read_csv_auto('%s')" tips-file))
  (let ((data (duckdb-select-columns conn "SELECT size, AVG(tip) as avg_tip FROM tips GROUP BY size ORDER BY size")))
    (drake-save-example
     (drake-plot-line :data data
                     :x :size
                     :y :avg_tip
                     :title "Average Tip by Party Size"
                     :backend 'svg)
     "tips-line.svg"))
  (duckdb-disconnect conn)
  (duckdb-close db))

;;; Example 10: Faceted Plot (skip in batch mode - SVG image creation fails)
(message "Generating: tips-facet.svg (skipped in batch mode)")
;; (drake-save-example
;;  (drake-facet :data drake-tips-data
;;              :row :sex
;;              :col :time
;;              :plot-fn #'drake-plot-scatter
;;              :args '(:x :total_bill :y :tip)
;;              :title "Tips by Gender and Time of Day"
;;              :backend 'svg)
;;  "tips-facet.svg")

;;; Example 11: Dark Theme
(message "Generating: iris-dark-theme.svg")
(drake-set-theme 'dark)
(drake-save-example
 (drake-plot-scatter :data drake-iris-data
                    :x :sepal_length
                    :y :sepal_width
                    :hue :species
                    :title "Iris (Dark Theme)"
                    :backend 'svg)
 "iris-dark-theme.svg")

;;; Example 12: Minimal Theme
(message "Generating: iris-minimal-theme.svg")
(drake-set-theme 'minimal)
(drake-save-example
 (drake-plot-scatter :data drake-iris-data
                    :x :petal_length
                    :y :petal_width
                    :hue :species
                    :title "Iris (Minimal Theme)"
                    :backend 'svg)
 "iris-minimal-theme.svg")

;;; Example 13: Different Palettes
(message "Generating: iris-palette-set1.svg")
(drake-set-theme 'default)
(drake-save-example
 (drake-plot-scatter :data drake-iris-data
                    :x :sepal_length
                    :y :sepal_width
                    :hue :species
                    :title "Iris (Set1 Palette)"
                    :palette 'set1
                    :backend 'svg)
 "iris-palette-set1.svg")

(message "Generating: iris-palette-viridis.svg")
(drake-save-example
 (drake-plot-scatter :data drake-iris-data
                    :x :sepal_length
                    :y :sepal_width
                    :hue :species
                    :title "Iris (Viridis Palette)"
                    :palette 'viridis
                    :backend 'svg)
 "iris-palette-viridis.svg")

;;; Example 14: Smooth plot
(message "Generating: tips-smooth.svg")
(drake-save-example
 (drake-plot-smooth :data drake-tips-data
                   :x :total_bill
                   :y :tip
                   :title "Smoothed Trend"
                   :backend 'svg)
 "tips-smooth.svg")

;;; Example 15: Count plot
(message "Generating: tips-count.svg")
(drake-save-example
 (drake-plot-count :data drake-tips-data
                  :x :day
                  :hue :time
                  :palette 'set2
                  :title "Lunch vs Dinner by Day"
                  :backend 'svg)
 "tips-count.svg")

;;; Example 16: Count plot ordered by frequency
(message "Generating: tips-count-ordered.svg")
(drake-save-example
 (drake-plot-count :data drake-tips-data
                  :x :day
                  :order 'value-desc
                  :palette 'dark2
                  :title "Most Popular Days"
                  :backend 'svg)
 "tips-count-ordered.svg")

;;; Example 17: Pair plot
(message "Generating: iris-pair.svg")
(drake-save-example
 (drake-plot-pair :data drake-iris-data
                 :vars '(:sepal_length :sepal_width :petal_length)
                 :hue :species
                 :palette 'set1
                 :title "Iris Pair Plot"
                 :backend 'svg)
 "iris-pair.svg")

;;; Example 18: Pair plot corner mode
(message "Generating: iris-pair-corner.svg")
(drake-save-example
 (drake-plot-pair :data drake-iris-data
                 :vars '(:sepal_length :sepal_width :petal_length)
                 :hue :species
                 :corner t
                 :title "Iris Correlation (Corner)"
                 :backend 'svg)
 "iris-pair-corner.svg")

(message "")
(message "====================================")
(message "All example images generated!")
(message "Output directory: %s" drake-examples-output-dir)
(message "====================================")

;;; generate-images.el ends here

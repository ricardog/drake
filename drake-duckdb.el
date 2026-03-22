;;; drake-duckdb.el --- DuckDB integration for drake -*- lexical-binding: t; -*-

;; Keywords: data, visualization, duckdb
;; Package-Requires: ((emacs "28.1") (drake "0.1") (duckdb "0.1") (transient "0.3.0"))

;;; Commentary:
;; This module provides a Transient UI for creating drake charts directly
;; from DuckDB query results.

;;; Code:

(require 'drake)
(require 'duckdb)
(require 'transient)
(require 'cl-lib)

(defvar drake-duckdb-chart-type "scatter")
(defvar drake-duckdb-x-axis nil)
(defvar drake-duckdb-y-axis nil)
(defvar drake-duckdb-hue nil)
(defvar drake-duckdb-theme 'default)
(defvar drake-duckdb-palette 'default)
(defvar drake-duckdb-source "buffer")

(defun drake-duckdb--get-columns ()
  "Get column names from current DuckDB results buffer."
  (if (derived-mode-p 'duckdb-query-results-mode)
      (let ((fmt tabulated-list-format))
        (cond
         ((vectorp fmt)
          (mapcar (lambda (col)
                    (if (listp col) (car col) col))
                  (append fmt nil)))
         ((and (fboundp 'vtable-current-table) (vtable-current-table))
          (mapcar (lambda (col)
                    (if (stringp col) col (vtable-column-name col)))
                  (vtable-columns (vtable-current-table))))
         (t nil)))
    (error "Not in duckdb-query-results-mode")))

(transient-define-infix drake-duckdb--chart-type ()
  :description "Chart Type"
  :class 'transient-lisp-variable
  :variable 'drake-duckdb-chart-type
  :reader (lambda (prompt _initial-input _history)
            (completing-read prompt '("scatter" "line" "bar" "hist" "lm" "box" "violin" "count"))))

(transient-define-infix drake-duckdb--x-axis ()
  :description "X Axis"
  :class 'transient-lisp-variable
  :variable 'drake-duckdb-x-axis
  :reader (lambda (prompt _initial-input _history)
            (completing-read prompt (drake-duckdb--get-columns))))

(transient-define-infix drake-duckdb--y-axis ()
  :description "Y Axis"
  :class 'transient-lisp-variable
  :variable 'drake-duckdb-y-axis
  :reader (lambda (prompt _initial-input _history)
            (completing-read prompt (drake-duckdb--get-columns))))

(transient-define-infix drake-duckdb--hue ()
  :description "Hue"
  :class 'transient-lisp-variable
  :variable 'drake-duckdb-hue
  :reader (lambda (prompt _initial-input _history)
            (let ((cols (cons "None" (drake-duckdb--get-columns))))
              (let ((res (completing-read prompt cols)))
                (if (string= res "None") nil res)))))

(transient-define-infix drake-duckdb--theme ()
  :description "Theme"
  :class 'transient-lisp-variable
  :variable 'drake-duckdb-theme
  :reader (lambda (prompt _initial-input _history)
            (intern (completing-read prompt '(default light dark minimal seaborn high-contrast solarized-light solarized-dark)))))

(transient-define-infix drake-duckdb--palette ()
  :description "Palette"
  :class 'transient-lisp-variable
  :variable 'drake-duckdb-palette
  :reader (lambda (prompt _initial-input _history)
            (intern (completing-read prompt '(viridis magma inferno plasma set1 set2 dark2 paired rdbu spectral blues default)))))

(transient-define-infix drake-duckdb--source ()
  :description "Data Source"
  :class 'transient-lisp-variable
  :variable 'drake-duckdb-source
  :reader (lambda (prompt _initial-input _history)
            (completing-read prompt '("buffer" "full"))))

;;;###autoload
(transient-define-prefix drake-duckdb-transient ()
  "Transient for creating charts from DuckDB results."
  [:description
   (lambda ()
     (if (not (derived-mode-p 'duckdb-query-results-mode))
         "Error: Not in a DuckDB Results buffer!"
       (format "Drake Chart from DuckDB Results\nQuery: %s"
               (truncate-string-to-width (or (bound-and-true-p duckdb--query-sql) "None") 60))))]
  ["Parameters"
   ("t" "Type" drake-duckdb--chart-type)
   ("x" "X Axis" drake-duckdb--x-axis)
   ("y" "Y Axis" drake-duckdb--y-axis)
   ("h" "Hue" drake-duckdb--hue)]
  ["Style"
   ("T" "Theme" drake-duckdb--theme)
   ("p" "Palette" drake-duckdb--palette)]
  ["Source"
   ("s" "Source" drake-duckdb--source)]
  ["Actions"
   ("g" "Generate Chart" drake-duckdb-generate)])

;;;###autoload
(defun drake-duckdb-generate ()
  "Generate a chart from DuckDB results based on transient settings."
  (interactive)
  (let ((sql (bound-and-true-p duckdb--query-sql))
        (conn (bound-and-true-p duckdb-current-connection))
        (offset (or (bound-and-true-p duckdb--query-offset) 0))
        (limit (or (bound-and-true-p duckdb-query-limit) 1000)))
    (unless (and sql conn)
      (error "No active DuckDB query or connection found in this buffer"))
    
    (let ((final-sql (if (string= drake-duckdb-source "buffer")
                         (format "%s LIMIT %d OFFSET %d" sql limit offset)
                       sql)))
      (message "Fetching data for chart...")
      (condition-case err
          (let* ((results (duckdb-select-columns conn final-sql))
                 (data (plist-get results :data))
                 (plot-fn (intern (format "drake-plot-%s" drake-duckdb-chart-type)))
                 (x-key (when drake-duckdb-x-axis (intern (concat ":" drake-duckdb-x-axis))))
                 (y-key (when (and drake-duckdb-y-axis (not (string-empty-p drake-duckdb-y-axis)))
                          (intern (concat ":" drake-duckdb-y-axis))))
                 (hue-key (when (and drake-duckdb-hue (not (string-empty-p drake-duckdb-hue)))
                            (intern (concat ":" drake-duckdb-hue))))
                 (args (list :data data
                             :x x-key
                             :y y-key
                             :hue hue-key
                             :palette drake-duckdb-palette
                             :title (format "DuckDB Result: %s" drake-duckdb-chart-type))))
            
            ;; Handle themes
            (let ((old-theme drake-current-theme))
              (drake-set-theme drake-duckdb-theme)
              (unwind-protect
                  (apply plot-fn args)
                ;; Restore theme
                (drake-set-theme old-theme))))
        (error (message "Error generating chart: %s" (error-message-string err)))))))

(provide 'drake-duckdb)
;;; drake-duckdb.el ends here

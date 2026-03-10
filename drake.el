;;; drake.el --- High-level statistical visualization library -*- lexical-binding: t; -*-

;; Author: Ricardo G. <ricardo@example.com>
;; Keywords: data, visualization, plotting
;; Package-Requires: ((emacs "28.1") (cl-lib "0.5") (duckdb "0.1"))

;;; Commentary:
;; `drake` is a declarative plotting library for Emacs, inspired by Seaborn.
;; It supports multiple backends, including a native SVG backend.

;;; Code:

(require 'cl-lib)

(defgroup drake nil
  "High-level statistical visualization."
  :group 'data
  :prefix "drake-")

(defcustom drake-default-backend 'svg
  "The default backend to use for rendering plots."
  :type 'symbol
  :group 'drake)

(defcustom drake-default-width 600
  "Default width for plots in pixels."
  :type 'number
  :group 'drake)

(defcustom drake-default-height 400
  "Default height for plots in pixels."
  :type 'number
  :group 'drake)

;;; Structs

(cl-defstruct drake-plot
  spec           ;; The original plist of arguments passed to the function
  data-internal  ;; Normalized columnar vectors (plist of vectors)
  scales         ;; Mapping functions/data from data-space to pixel-space
  image          ;; The actual Emacs image object (SVG or Bitmap)
  buffer         ;; The buffer where the plot was rendered
  )

(cl-defstruct drake-backend
  name             ;; Symbol identifying the backend (e.g., 'svg)
  render-fn        ;; Function (plot) -> emacs-image
  supported-types  ;; List of plot types (e.g., '(scatter line))
  capabilities     ;; Plist of features
  )

(defvar drake--backends (make-hash-table :test 'eq)
  "Registry of available backends.")

(defun drake-register-backend (backend)
  "Register a new drake BACKEND."
  (puthash (drake-backend-name backend) backend drake--backends))

;;; Core API

(defun drake-plot-scatter (&rest args)
  "Create a scatter plot.
ARGS is a plist containing:
:data    - Columnar data (plist of vectors) or row-based data.
:x       - X-axis column identifier (keyword or index).
:y       - Y-axis column identifier (keyword or index).
:title   - Plot title.
:buffer  - Target buffer name.
:width   - Plot width (pixels).
:height  - Plot height (pixels).
:backend - Backend to use (symbol)."
  (let* ((data (plist-get args :data))
         (x-key (plist-get args :x))
         (y-key (plist-get args :y))
         ;; 1. Normalize data to columnar format
         (normalized (drake--normalize-data data x-key y-key))
         (x-vec (plist-get normalized :x))
         (y-vec (plist-get normalized :y))
         ;; 2. Calculate raw ranges for scales
         (x-range (drake--get-range x-vec))
         (y-range (drake--get-range y-vec))
         ;; 3. Scale data to 0.0-1.0 (Front-end responsibility)
         (x-scaled (drake--scale-vector x-vec x-range))
         (y-scaled (drake--scale-vector y-vec y-range))
         (backend-sym (or (plist-get args :backend) drake-default-backend))
         (backend (gethash backend-sym drake--backends))
         (plot (make-drake-plot
                :spec args
                :data-internal (list :x x-scaled :y y-scaled)
                :scales (list :x x-range :y y-range))))

    (unless backend
      (error "Backend '%s' not found. Is it loaded?" backend-sym))

    ;; 4. Render
    (setf (drake-plot-image plot) (funcall (drake-backend-render-fn backend) plot))

    ;; 5. Display
    (drake--display-in-buffer plot (or (plist-get args :buffer) "*drake-plot*"))

    plot))

;;; Internal Helpers

(defun drake--ensure-vector (seq)
  "Ensure SEQ is a vector. Convert if it is a list."
  (cond
   ((vectorp seq) seq)
   ((listp seq) (vconcat seq))
   (t (error "Cannot convert to vector: %S" seq))))

(defun drake--normalize-data (data x-key y-key)
  "Normalize DATA into a plist with :x and :y vectors.
Handles columnar plists and row-based lists."
  (cond
   ;; DuckDB-style columnar nested plist (:data (:col1 ...))
   ((plist-get data :data)
    (drake--normalize-data (plist-get data :data) x-key y-key))
   ;; Columnar plist
   ((and (listp data) (keywordp (car-safe data)))
    (list :x (drake--ensure-vector (plist-get data x-key))
          :y (drake--ensure-vector (plist-get data y-key))))
   ;; Row-based list of lists
   ((and (listp data) (listp (car-safe data)))
    (let ((x-vals (mapcar (lambda (row) (nth x-key row)) data))
          (y-vals (mapcar (lambda (row) (nth y-key row)) data)))
      (list :x (vconcat x-vals)
            :y (vconcat y-vals))))
   (t (error "Unsupported data format: %S" data))))

(defun drake--get-range (vec)
  "Return (min . max) for vector VEC."
  (let ((min most-positive-fixnum)
        (max most-negative-fixnum))
    (cl-loop for val across vec do
             (setq min (min min val)
                   max (max max val)))
    (cons min max)))

(defun drake--scale-vector (vec range)
  "Scale vector VEC elements to 0.0-1.0 range based on RANGE (min . max)."
  (let* ((min (car range))
         (max (cdr range))
         (diff (if (= max min) 1.0 (float (- max min))))
         (result (make-vector (length vec) 0.0)))
    (cl-loop for i from 0 below (length vec) do
             (aset result i (/ (- (aref vec i) min) diff)))
    result))

(defun drake--display-in-buffer (plot buffer-name)
  "Display PLOT in buffer BUFFER-NAME."
  (let ((buf (get-buffer-create buffer-name))
        (img (drake-plot-image plot)))
    (with-current-buffer buf
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert-image img)
        (setf (drake-plot-buffer plot) buf)
        (display-buffer buf)))))

(provide 'drake)
;;; drake.el ends here

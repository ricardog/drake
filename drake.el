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
:hue     - Column identifier for color grouping.
:palette - Palette name (symbol, e.g., 'viridis).
:title   - Plot title.
:buffer  - Target buffer name.
:width   - Plot width (pixels).
:height  - Plot height (pixels).
:backend - Backend to use (symbol)."
  (drake--create-plot 'scatter args))

(defun drake-plot-line (&rest args)
  "Create a line plot.
See `drake-plot-scatter' for ARGS."
  (drake--create-plot 'line args))

(defun drake-plot-bar (&rest args)
  "Create a bar plot.
See `drake-plot-scatter' for ARGS."
  (drake--create-plot 'bar args))

(defun drake--create-plot (type args)
  "Internal function to create a plot of TYPE with ARGS."
  (let* ((data (plist-get args :data))
         (x-key (plist-get args :x))
         (y-key (plist-get args :y))
         (hue-key (plist-get args :hue))
         ;; 1. Normalize data to columnar format
         (normalized (drake--normalize-data data (list :x x-key :y y-key :hue hue-key)))
         (x-vec (plist-get normalized :x))
         (y-vec (plist-get normalized :y))
         (hue-vec (plist-get normalized :hue))
         ;; 2. Determine Scale Types
         (x-type (drake--detect-type x-vec))
         (y-type (drake--detect-type y-vec))
         ;; 3. Calculate scales
         (x-scale (drake--make-scale x-vec x-type))
         (y-scale (drake--make-scale y-vec y-type))
         ;; 4. Scale data to 0.0-1.0 (Front-end responsibility)
         (x-scaled (drake--apply-scale x-vec x-scale))
         (y-scaled (drake--apply-scale y-vec y-scale))
         ;; 5. Handle Hue
         (hue-info (when hue-vec (drake--process-hue hue-vec (plist-get args :palette))))
         (backend-sym (or (plist-get args :backend) drake-default-backend))
         (backend (gethash backend-sym drake--backends))
         (plot (make-drake-plot
                :spec (append (list :type type) args)
                :data-internal (list :x x-scaled :y y-scaled :hue (plist-get hue-info :values))
                :scales (list :x x-scale :y y-scale :hue (plist-get hue-info :map)
                              :x-type x-type :y-type y-type))))

    (unless backend
      (error "Backend '%s' not found. Is it loaded?" backend-sym))

    ;; 6. Render
    (setf (drake-plot-image plot) (funcall (drake-backend-render-fn backend) plot))

    ;; 7. Display
    (drake--display-in-buffer plot (or (plist-get args :buffer) "*drake-plot*"))

    plot))

;;; Internal Helpers

(defun drake--detect-type (vec)
  "Detect if VEC is 'numeric or 'categorical."
  (if (and (> (length vec) 0)
           (cl-every (lambda (x) (or (numberp x) (null x))) vec))
      'numeric
    'categorical))

(defun drake--make-scale (vec type)
  "Create scale for VEC based on TYPE."
  (if (eq type 'numeric)
      (drake--get-range vec)
    (drake--get-unique-values vec)))

(defun drake--apply-scale (vec scale)
  "Scale VEC using SCALE."
  (if (and (consp scale) (numberp (car scale))) ;; numeric (min . max)
      (drake--scale-vector vec scale)
    ;; categorical (list of unique values)
    (let* ((n (length scale))
           (map (make-hash-table :test 'equal))
           (i 0))
      (dolist (val scale)
        ;; For categorical, we space them evenly
        (puthash val (if (> n 1) (/ (float i) (1- n)) 0.5) map)
        (setq i (1+ i)))
      (vconcat (mapcar (lambda (val) (gethash val map 0.0)) vec)))))

(defun drake--ensure-vector (seq)
  "Ensure SEQ is a vector. Convert if it is a list."
  (cond
   ((vectorp seq) seq)
   ((listp seq) (vconcat seq))
   (t (error "Cannot convert to vector: %S" seq))))

(defun drake--normalize-data (data column-map)
  "Normalize DATA into a plist of vectors based on COLUMN-MAP.
COLUMN-MAP is a plist mapping internal keys (like :x) to data keys.
Handles columnar plists, row-based lists, and lists of alists/plists."
  (let* ((actual-data (if (plist-get data :data) (plist-get data :data) data))
         (result nil))
    (cl-loop for (internal-key data-key) on column-map by #'cddr do
             (when data-key
               (let ((col (drake--extract-column actual-data data-key)))
                 (push internal-key result)
                 (push col result))))
    (nreverse result)))

(defun drake--extract-column (data key)
  "Extract column KEY from DATA."
  (cond
   ;; Columnar plist
   ((and (listp data) (keywordp (car-safe data)))
    (drake--ensure-vector (plist-get data key)))
   ;; List of Alists
   ((and (listp data) (consp (car-safe data)) (consp (caar data)))
    (vconcat (mapcar (lambda (row) (cdr (assoc key row))) data)))
   ;; List of Plists
   ((and (listp data) (listp (car-safe data)) (keywordp (caar data)))
    (vconcat (mapcar (lambda (row) (plist-get row key)) data)))
   ;; List of lists (Row-based)
   ((and (listp data) (listp (car-safe data)))
    (if (numberp key)
        (vconcat (mapcar (lambda (row) (nth key row)) data))
      (error "Positional column index required for row-based data: %S" key)))
   (t (error "Unsupported data format: %S" data))))

(defun drake--get-range (vec)
  "Return (min . max) for vector VEC."
  (if (= (length vec) 0)
      (cons 0 1)
    (let ((min most-positive-fixnum)
          (max most-negative-fixnum))
      (cl-loop for val across vec do
               (when (numberp val)
                 (setq min (min min val)
                       max (max max val))))
      (if (= min most-positive-fixnum)
          (cons 0 1)
        (cons min max)))))

(defun drake--scale-vector (vec range)
  "Scale vector VEC elements to 0.0-1.0 range based on RANGE (min . max)."
  (let* ((min (car range))
         (max (cdr range))
         (diff (if (= max min) 1.0 (float (- max min))))
         (result (make-vector (length vec) 0.0)))
    (cl-loop for i from 0 below (length vec) do
             (let ((val (aref vec i)))
               (if (numberp val)
                   (aset result i (/ (- val min) diff))
                 (aset result i 0.0))))
    result))

(defun drake--process-hue (hue-vec palette)
  "Process HUE-VEC and return a plist with mapped colors."
  (let* ((unique-vals (drake--get-unique-values hue-vec))
         (color-map (drake--color-manager unique-vals palette))
         (mapped-values (make-vector (length hue-vec) nil)))
    (cl-loop for i from 0 below (length hue-vec) do
             (aset mapped-values i (cdr (assoc (aref hue-vec i) color-map))))
    (list :values mapped-values :map color-map)))

(defun drake--get-unique-values (vec)
  "Return unique values from vector VEC."
  (let ((seen (make-hash-table :test 'equal))
        (result nil))
    (cl-loop for val across vec do
             (unless (gethash val seen)
               (puthash val t seen)
               (push val result)))
    (nreverse result)))

(defvar drake--palettes
  '((viridis . ("#440154" "#414487" "#2a788e" "#22a884" "#7ad151" "#fde725"))
    (default . ("#4c72b0" "#55a868" "#c44e52" "#8172b2" "#ccb974" "#64b5cd"))))

(defun drake--color-manager (unique-values palette-name)
  "Return an alist mapping values to colors based on PALETTE-NAME."
  (let* ((colors (or (cdr (assoc palette-name drake--palettes))
                    (cdr (assoc 'default drake--palettes))))
         (n (length colors))
         (i 0))
    (mapcar (lambda (val)
              (let ((color (nth (% i n) colors)))
                (setq i (1+ i))
                (cons val color)))
            unique-values)))

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

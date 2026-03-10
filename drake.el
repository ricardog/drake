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
  data-internal  ;; Normalized columnar vectors (plist of vectors: :x :y :hue :extra)
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

(defun drake-plot-hist (&rest args)
  "Create a histogram.
ARGS is a plist containing:
:data    - Columnar data (plist of vectors) or row-based data.
:x       - Column identifier to bin.
:bins    - Number of bins (default 10).
:hue     - Column identifier for color grouping.
:palette - Palette name.
:title   - Plot title.
:buffer  - Target buffer name.
:width   - Plot width.
:height  - Plot height."
  (drake--create-plot 'hist args))

(defun drake-plot-lm (&rest args)
  "Create a scatter plot with a linear regression line.
See `drake-plot-scatter' for ARGS."
  (drake--create-plot 'lm args))

(defun drake-plot-box (&rest args)
  "Create a box plot.
See `drake-plot-scatter' for ARGS."
  (drake--create-plot 'box args))

(defun drake-plot-violin (&rest args)
  "Create a violin plot.
See `drake-plot-scatter' for ARGS."
  (drake--create-plot 'violin args))

(defun drake-facet (&rest args)
  "Create a faceted plot (grid of plots).
ARGS is a plist containing:
:data    - Columnar data.
:row     - Column identifier to facet by row.
:col     - Column identifier to facet by column.
:plot-fn - Plotting function to use for each facet (e.g., #'drake-plot-scatter).
:args    - Additional arguments to pass to :plot-fn.
:title   - Overall title."
  (let* ((data (plist-get args :data))
         (row-key (plist-get args :row))
         (col-key (plist-get args :col))
         (plot-fn (plist-get args :plot-fn))
         (plot-args (plist-get args :args))
         (rows (if row-key (drake--get-unique-values (drake--extract-column data row-key)) '(nil)))
         (cols (if col-key (drake--get-unique-values (drake--extract-column data col-key)) '(nil)))
         (grid nil))
    (dolist (r rows)
      (let ((row-data nil))
        (dolist (c cols)
          (let* ((subset (drake--filter-data data (list (cons row-key r) (cons col-key c))))
                 (p (apply plot-fn :data subset plot-args)))
            (push p row-data)))
        (push (nreverse row-data) grid)))
    (setq grid (nreverse grid))
    ;; Create a composite plot or handle display differently
    ;; For now, we'll just return the grid and let the user display it
    ;; But a better way is to have a drake-facet-plot struct or similar.
    grid))

(defun drake--filter-data (data filters)
  "Filter DATA based on FILTERS (alist of key . value)."
  (let* ((actual-data (if (plist-get data :data) (plist-get data :data) data))
         (indices nil))
    ;; 1. Find indices that match all filters
    (let ((n (length (drake--extract-column actual-data (caar filters)))))
      (cl-loop for i from 0 below n do
               (when (cl-every (lambda (f)
                                 (let* ((k (car f))
                                        (v (cdr f))
                                        (col (drake--extract-column actual-data k)))
                                   (if k (equal (aref col i) v) t)))
                               filters)
                 (push i indices))))
    (setq indices (nreverse indices))
    ;; 2. Extract subset for all keys in data
    (cond
     ((and (listp actual-data) (keywordp (car-safe actual-data)))
      (let (res)
        (cl-loop for (k v) on actual-data by #'cddr do
                 (push k res)
                 (push (vconcat (mapcar (lambda (i) (aref v i)) indices)) res))
        (nreverse res)))
     (t (error "Faceting currently only supports columnar plist data format")))))

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
         ;; 2. Statistical Transformation (Stage 3)
         (transformed (drake--transform-data type x-vec y-vec hue-vec args))
         (x-final (plist-get transformed :x))
         (y-final (plist-get transformed :y))
         (hue-final (plist-get transformed :hue))
         (extra-data (plist-get transformed :extra))
         ;; 3. Determine Scale Types
         (x-type (drake--detect-type x-final))
         (y-type (drake--detect-type y-final))
         ;; 4. Calculate scales
         (x-scale (drake--make-scale x-final x-type))
         (y-scale (drake--make-scale y-final y-type))
         ;; 5. Scale data to 0.0-1.0
         (x-scaled (drake--apply-scale x-final x-scale))
         (y-scaled (drake--apply-scale y-final y-scale))
         ;; 6. Handle Hue
         (hue-info (when hue-final (drake--process-hue hue-final (plist-get args :palette))))
         (backend-sym (or (plist-get args :backend) drake-default-backend))
         (backend (gethash backend-sym drake--backends))
         (plot (make-drake-plot
                :spec (append (list :type type) args)
                :data-internal (list :x x-scaled :y y-scaled :hue (plist-get hue-info :values) :extra extra-data)
                :scales (list :x x-scale :y y-scale :hue (plist-get hue-info :map)
                              :x-type x-type :y-type y-type))))

    (unless backend
      (error "Backend '%s' not found. Is it loaded?" backend-sym))

    ;; 7. Render
    (setf (drake-plot-image plot) (funcall (drake-backend-render-fn backend) plot))

    ;; 8. Add tooltips (Stage 4)
    (setf (drake-plot-image plot) (drake--attach-tooltips (drake-plot-image plot) plot))

    ;; 9. Display
    (drake--display-in-buffer plot (or (plist-get args :buffer) "*drake-plot*"))

    plot))

(defun drake-plot-smooth (&rest args)
  "Create a plot with a smoothed trend line.
See `drake-plot-scatter' for ARGS."
  (drake--create-plot 'smooth args))

(defun drake--transform-data (type x-vec y-vec hue-vec args)
  "Perform statistical transformation based on TYPE."
  (cond
   ((eq type 'hist)
    (drake--transform-hist x-vec hue-vec (or (plist-get args :bins) 10)))
   ((eq type 'box)
    (drake--transform-stats x-vec y-vec hue-vec))
   ((eq type 'violin)
    (drake--transform-stats x-vec y-vec hue-vec))
   ((eq type 'lm)
    (drake--transform-lm x-vec y-vec hue-vec))
   ((eq type 'smooth)
    (drake--transform-smooth x-vec y-vec hue-vec args))
   (t
    (list :x x-vec :y y-vec :hue hue-vec))))

(defun drake--transform-smooth (x-vec y-vec hue-vec args)
  "Apply Gaussian kernel smoothing to X-VEC and Y-VEC."
  (let* ((range (drake--get-range x-vec))
         (x-min (car range))
         (x-max (cdr range))
         (steps 50)
         (bandwidth (* 0.1 (- x-max x-min)))
         (res-x nil) (res-y nil) (res-hue nil))
    (let ((groups (make-hash-table :test 'equal)))
      (cl-loop for i from 0 below (length x-vec) do
               (let ((h (if hue-vec (aref hue-vec i) 'overall)))
                 (push (cons (aref x-vec i) (aref y-vec i)) (gethash h groups))))
      (maphash
       (lambda (h pts)
         (cl-loop for i from 0 to steps do
                  (let* ((target-x (+ x-min (* (/ (float i) steps) (- x-max x-min))))
                         (weighted-sum 0.0)
                         (total-weight 0.0))
                    (dolist (p pts)
                      (let* ((dist (- target-x (car p)))
                             (weight (exp (/ (- (expt dist 2)) (* 2.0 (expt bandwidth 2))))))
                        (cl-incf weighted-sum (* (cdr p) weight))
                        (cl-incf total-weight weight)))
                    (when (> total-weight 0)
                      (push target-x res-x)
                      (push (/ weighted-sum total-weight) res-y)
                      (push (if (eq h 'overall) nil h) res-hue)))))
       groups))
    (list :x (vconcat (nreverse res-x))
          :y (vconcat (nreverse res-y))
          :hue (if hue-vec (vconcat (nreverse res-hue)) nil)
          :extra (list :original-x x-vec :original-y y-vec :original-hue hue-vec))))

(defun drake--transform-lm (x-vec y-vec hue-vec)
  "Calculate OLS regression for each group in HUE-VEC (or overall)."
  (let ((groups (make-hash-table :test 'equal))
        (extra nil))
    (if hue-vec
        (cl-loop for i from 0 below (length x-vec) do
                 (let ((h (aref hue-vec i)))
                   (push (cons (aref x-vec i) (aref y-vec i)) (gethash h groups))))
      (let (pts)
        (cl-loop for i from 0 below (length x-vec) do
                 (push (cons (aref x-vec i) (aref y-vec i)) pts))
        (puthash 'overall pts groups)))
    
    (maphash
     (lambda (h pts)
       (let ((res (drake--ols-regression pts)))
         (push (cons h res) extra)))
     groups)
    (list :x x-vec :y y-vec :hue hue-vec :extra (nreverse extra))))

(defun drake--ols-regression (points)
  "Perform Ordinary Least Squares regression on a list of (X . Y) points.
Returns a plist (:m slope :b intercept :r2 r-squared :se standard-error :sxx sxx :mean-x mean-x :n n)."
  (let* ((n (length points))
         (sum-x 0.0) (sum-y 0.0) (sum-xy 0.0) (sum-xx 0.0) (sum-yy 0.0))
    (dolist (p points)
      (let ((x (float (car p)))
            (y (float (cdr p))))
        (cl-incf sum-x x)
        (cl-incf sum-y y)
        (cl-incf sum-xy (* x y))
        (cl-incf sum-xx (* x x))
        (cl-incf sum-yy (* y y))))
    (let* ((denom (- (* n sum-xx) (* sum-x sum-x)))
           (m (if (= denom 0) 0.0 (/ (- (* n sum-xy) (* sum-x sum-y)) denom)))
           (b (/ (- sum-y (* m sum-x)) n))
           ;; R2 calculation
           (ss-tot (- sum-yy (/ (* sum-y sum-y) n)))
           (ss-res 0.0))
      (dolist (p points)
        (let* ((x (float (car p)))
               (y (float (cdr p)))
               (y-pred (+ (* m x) b))
               (err (- y y-pred)))
          (cl-incf ss-res (* err err))))
      (let* ((r2 (if (= ss-tot 0) 1.0 (- 1.0 (/ ss-res ss-tot))))
             (se (if (> n 2) (sqrt (/ ss-res (- n 2))) 0.0))
             (mean-x (/ sum-x n))
             (sxx (- sum-xx (/ (* sum-x sum-x) n))))
        (list :m m :b b :r2 r2 :se se :sxx sxx :mean-x mean-x :n n)))))

(defun drake--transform-hist (vec hue-vec bins)
  "Transform VEC into binned counts for histogram."
  (let* ((range (drake--get-range vec))
         (min (car range))
         (max (cdr range))
         (span (- max min))
         (bin-width (if (= span 0) 1.0 (/ (float span) bins)))
         (results nil))
    ;; For simplicity, we create centers of bins
    (if hue-vec
        (let ((groups (make-hash-table :test 'equal))
              (unique-hues (drake--get-unique-values hue-vec)))
          (cl-loop for i from 0 below (length vec) do
                   (let ((h (aref hue-vec i))
                         (v (aref vec i)))
                     (push v (gethash h groups))))
          (let (x-all y-all h-all)
            (dolist (h unique-hues)
              (let* ((vals (gethash h groups))
                     (counts (make-vector bins 0)))
                (dolist (v vals)
                  (let ((bin (min (1- bins) (floor (/ (- v min) bin-width)))))
                    (when (>= bin 0)
                      (aset counts bin (1+ (aref counts bin))))))
                (cl-loop for i from 0 below bins do
                         (push (+ min (* i bin-width) (* 0.5 bin-width)) x-all)
                         (push (aref counts i) y-all)
                         (push h h-all))))
            (list :x (vconcat (nreverse x-all))
                  :y (vconcat (nreverse y-all))
                  :hue (vconcat (nreverse h-all)))))
      ;; No hue
      (let ((counts (make-vector bins 0)))
        (cl-loop for v across vec do
                 (let ((bin (min (1- bins) (floor (/ (- v min) bin-width)))))
                   (when (>= bin 0)
                     (aset counts bin (1+ (aref counts bin))))))
        (let ((x-centers (make-vector bins 0.0))
              (y-counts (make-vector bins 0.0)))
          (cl-loop for i from 0 below bins do
                   (aset x-centers i (+ min (* i bin-width) (* 0.5 bin-width)))
                   (aset y-counts i (float (aref counts i))))
          (list :x x-centers :y y-counts))))))

(defun drake--transform-stats (x-vec y-vec hue-vec)
  "Calculate summary statistics (quartiles, etc.) for each category in X-VEC."
  (let* ((groups (make-hash-table :test 'equal))
         (categories (drake--get-unique-values x-vec))
         (x-res nil) (y-res nil) (hue-res nil) (extra-res nil))
    (cl-loop for i from 0 below (length x-vec) do
             (let ((cat (aref x-vec i))
                   (val (aref y-vec i))
                   (h (when hue-vec (aref hue-vec i))))
               (push val (gethash (cons cat h) groups))))
    
    (maphash
     (lambda (key vals)
       (let* ((sorted (sort (cl-remove-if-not #'numberp vals) #'<))
              (n (length sorted)))
         (when (> n 0)
           (let ((min (car sorted))
                 (max (car (last sorted)))
                 (q1 (drake--quantile sorted 0.25))
                 (median (drake--quantile sorted 0.5))
                 (q3 (drake--quantile sorted 0.75)))
             (push (car key) x-res)
             (push median y-res) ;; representative Y
             (push (cdr key) hue-res)
             (push (list :min min :q1 q1 :median median :q3 q3 :max max :vals sorted) extra-res)))))
     groups)
    (list :x (vconcat (nreverse x-res))
          :y (vconcat (nreverse y-res))
          :hue (if hue-vec (vconcat (nreverse hue-res)) nil)
          :extra (vconcat (nreverse extra-res)))))

(defun drake--quantile (sorted-vec q)
  "Get quantile Q from SORTED-VEC."
  (let* ((n (length sorted-vec))
         (index (* q (1- n)))
         (low (floor index))
         (high (ceiling index))
         (fraction (- index low)))
    (if (= low high)
        (nth low sorted-vec)
      (+ (* (1- fraction) (nth low sorted-vec))
         (* fraction (nth high sorted-vec))))))

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

(defun drake--attach-tooltips (img plot)
  "Attach a summary tooltip to IMG based on PLOT data."
  (let* ((spec (drake-plot-spec plot))
         (type (plist-get spec :type))
         (x-key (plist-get spec :x))
         (y-key (plist-get spec :y))
         (title (plist-get spec :title))
         (tooltip (concat (when title (format "%s\n" title))
                         (format "Type: %s\n" type)
                         (format "X: %s\n" x-key)
                         (when y-key (format "Y: %s\n" y-key)))))
    (if (imagep img)
        (progn
          (plist-put (cdr img) :help-echo tooltip)
          img)
      img)))

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

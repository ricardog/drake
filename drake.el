;;; drake.el --- High-level statistical visualization library -*- lexical-binding: t; -*-

;; Author: Ricardo G. <ricardo@example.com>
;; Keywords: data, visualization, plotting
;; Package-Requires: ((emacs "28.1") (cl-lib "0.5") (duckdb "0.1"))

;;; Commentary:
;; `drake` is a declarative plotting library for Emacs, inspired by
;; Seaborn.  It supports multiple backends, including a native SVG
;; backend (using svg.el), gnuplot, and a rust dynamic module library
;; (based on plotters).

;;; Code:

(require 'cl-lib)
(require 'json)
(require 'url)

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
  "Default pixel height of plots."
  :type 'integer
  :group 'drake)

(defcustom drake-kde-bandwidth-method 'scott
  "Automatic bandwidth selection method for Kernel Density Estimation.
Valid options are 'scott and 'silverman."
  :type '(choice (const :tag "Scott's Rule" scott)
                 (const :tag "Silverman's Rule" silverman))
  :group 'drake)

(defcustom drake-palette-url "https://raw.githubusercontent.com/axismaps/colorbrewer/master/export/colorbrewer.json"
  "URL to fetch additional palettes from (ColorBrewer format)."
  :type 'string
  :group 'drake)

;;; Color & Palettes

(defvar drake--bundled-palettes
  '((viridis . ("#440154" "#414487" "#2a788e" "#22a884" "#7ad151" "#fde725"))
    (magma . ("#000004" "#3b0f70" "#8c2981" "#de4968" "#fe9f6d" "#fcfdbf"))
    (inferno . ("#000004" "#420a68" "#932667" "#dd513a" "#fca50a" "#fcffa4"))
    (plasma . ("#0d0887" "#6a00a8" "#b12a90" "#e16462" "#fca636" "#f0f921"))
    (set1 . ("#e41a1c" "#377eb8" "#4daf4a" "#984ea3" "#ff7f00" "#ffff33" "#a65628" "#f781bf" "#999999"))
    (set2 . ("#66c2a5" "#fc8d62" "#8da0cb" "#e78ac3" "#a6d854" "#ffd92f" "#e5c494" "#b3b3b3"))
    (dark2 . ("#1b9e77" "#d95f02" "#7570b3" "#e7298a" "#66a61e" "#e6ab02" "#a6761d" "#666666"))
    (paired . ("#a6cee3" "#1f78b4" "#b2df8a" "#33a02c" "#fb9a99" "#e31a1c" "#fdbf6f" "#ff7f00" "#cab2d6" "#6a3d9a" "#ffff99" "#b15928"))
    (rdbu . ("#ca0020" "#f4a582" "#f7f7f7" "#92c5de" "#0571b0"))
    (spectral . ("#d53e4f" "#f46d43" "#fdae61" "#fee08b" "#ffffbf" "#e6f598" "#abdda4" "#66c2a5" "#3288bd"))
    (blues . ("#eff3ff" "#bdd7e7" "#6baed6" "#3182bd" "#08519c"))
    (default . ("#4c72b0" "#55a868" "#c44e52" "#8172b2" "#ccb974" "#64b5cd")))
  "Core bundled palettes.")

(defvar drake--palette-cache nil
  "Cached palettes from external sources.")

(defvar drake--user-palettes nil
  "User-registered palettes.")

(defun drake-register-palette (name colors)
  "Register a new palette NAME with COLORS (list of hex strings)."
  (push (cons name colors) drake--user-palettes))

(defun drake-fetch-palettes ()
  "Fetch and cache additional palettes from `drake-palette-url`."
  (interactive)
  (message "Fetching additional palettes from %s..." drake-palette-url)
  (let ((url-request-method "GET"))
    (with-current-buffer (url-retrieve-synchronously drake-palette-url)
      (goto-char (point-min))
      (re-search-forward "^$" nil t)
      (let* ((json-object-type 'alist)
             (raw-data (json-read))
             (processed nil))
        (dolist (entry raw-data)
          (let* ((name (symbol-name (car entry)))
                 (data (cdr entry))
                 ;; Get the largest available class count (k)
                 (max-k (apply #'max (mapcar (lambda (k-entry)
                                               (if (string-match "^[0-9]+$" (symbol-name (car k-entry)))
                                                   (string-to-number (symbol-name (car k-entry)))
                                                 0))
                                             data)))
                 (colors (cdr (assoc (intern (number-to-string max-k)) data))))
            (when (vectorp colors)
              (push (cons (intern (downcase name)) (append colors nil)) processed))))
        (setq drake--palette-cache processed)
        ;; Simple persistence in ~/.emacs.d/drake/
        (let ((cache-dir (expand-file-name "drake" user-emacs-directory)))
          (unless (file-exists-p cache-dir) (make-directory cache-dir t))
          (with-temp-file (expand-file-name "palettes-cache.el" cache-dir)
            (insert ";;; Generated drake palettes cache\n")
            (insert (format "(setq drake--palette-cache '%S)" processed))))
        (message "Successfully loaded %d additional palettes." (length processed))))))

(defun drake--load-cache-if-needed ()
  "Load palettes from disk cache if not already loaded."
  (unless drake--palette-cache
    (let ((cache-file (expand-file-name "drake/palettes-cache.el" user-emacs-directory)))
      (when (file-exists-p cache-file)
        (load cache-file t t)))))

(defun drake--get-palette (name)
  "Return color list for palette NAME."
  (cond
   ((and name (listp name)) name) ;; Direct list of colors
   ((symbolp name)
    (drake--load-cache-if-needed)
    (or (and name (cdr (assoc name drake--user-palettes)))
        (and name (cdr (assoc name drake--bundled-palettes)))
        (and name (cdr (assoc name drake--palette-cache)))
        (cdr (assoc 'default drake--bundled-palettes))))
   (t (cdr (assoc 'default drake--bundled-palettes)))))

(defun drake--color-manager (unique-values palette-name)
  "Return an alist mapping values to colors based on PALETTE-NAME."
  (let* ((colors (or (drake--get-palette palette-name) '("blue")))
         (n (length colors))
         (i 0))
    (mapcar (lambda (val)
              (let ((color (nth (% i n) colors)))
                (setq i (1+ i))
                (cons val color)))
            unique-values)))

;;; Structs

(cl-defstruct drake-plot
  spec           ;; The original plist of arguments passed to the function
  data-internal  ;; Normalized columnar vectors (plist of vectors: :x :y :hue :extra)
  scales         ;; Mapping functions/data from data-space to pixel-space
  image          ;; The actual Emacs image object (SVG or Bitmap)
  svg-xml        ;; Raw SVG XML data (Stage 3 facet support)
  buffer         ;; The buffer where the plot was rendered
  )

(cl-defstruct drake-backend
  name             ;; Symbol identifying the backend (e.g., 'svg)
  render-fn        ;; Function (plot) -> emacs-image
  render-facet-fn  ;; Function (facet-plot) -> emacs-image (Stage 5)
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
:legend  - Legend position ('top-right, 'top-left, 'bottom-right, 'bottom-left).
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

(cl-defstruct drake-facet-plot
  grid           ;; 2D list of drake-plot objects
  title          ;; Overall title
  rows           ;; Number of rows
  cols           ;; Number of columns
  image          ;; Composite image
  svg-xml        ;; Raw SVG XML data
  spec           ;; Original facet spec (Stage 5)
  )

(defun drake-facet (&rest args)
  "Create a faceted plot (grid of plots).
ARGS is a plist containing:
:data    - Columnar data.
:row     - Column identifier to facet by row.
:col     - Column identifier to facet by column.
:plot-fn - Plotting function to use for each facet (e.g., #'drake-plot-scatter).
:args    - Additional arguments to pass to :plot-fn.
:title   - Overall title.
:backend - Backend to use (symbol)."
  (let* ((data (drake--normalize-data-all (plist-get args :data)))
         (row-key (plist-get args :row))
         (col-key (plist-get args :col))
         (plot-fn (plist-get args :plot-fn))
         (plot-args (plist-get args :args))
         (backend-sym (or (plist-get args :backend) drake-default-backend))
         (backend (gethash backend-sym drake--backends))
         (rows (if row-key (drake--get-unique-values (plist-get data row-key)) '(nil)))
         (cols (if col-key (drake--get-unique-values (plist-get data col-key)) '(nil)))
         (grid nil))
    (dolist (r rows)
      (let ((row-data nil))
        (dolist (c cols)
          (let* ((filters (cl-remove-if (lambda (f) (null (car f)))
                                       (list (cons row-key r) (cons col-key c))))
                 (subset (drake--filter-data data filters))
                 (p (apply plot-fn :data subset :buffer nil :backend backend-sym plot-args)))
            (push p row-data)))
        (push (nreverse row-data) grid)))
    (setq grid (nreverse grid))
    (let* ((fplot (make-drake-facet-plot
                   :grid grid
                   :title (plist-get args :title)
                   :rows (length rows)
                   :cols (length cols)
                   :spec args)))
      (if (and backend (drake-backend-render-facet-fn backend))
          (setf (drake-facet-plot-image fplot) (funcall (drake-backend-render-facet-fn backend) fplot))
        (setf (drake-facet-plot-image fplot) (drake--render-facet fplot)))
      (drake--display-in-buffer fplot (or (plist-get args :buffer) "*drake-facet*"))
      fplot)))

(defun drake--render-facet (fplot)
  "Render a drake-facet-plot FPLOT into a single composite SVG image."
  (let* ((grid (drake-facet-plot-grid fplot))
         (n-rows (drake-facet-plot-rows fplot))
         (n-cols (drake-facet-plot-cols fplot))
         (first-plot (caar grid))
         (p-spec (drake-plot-spec first-plot))
         (p-width (or (plist-get p-spec :width) drake-default-width))
         (p-height (or (plist-get p-spec :height) drake-default-height))
         (padding 10)
         (title-height (if (drake-facet-plot-title fplot) 40 0))
         (total-width (+ (* n-cols p-width) (* (1+ n-cols) padding)))
         (total-height (+ title-height (* n-rows p-height) (* (1+ n-rows) padding)))
         (svg (svg-create total-width total-height)))
    
    (svg-rectangle svg 0 0 total-width total-height :fill "white")
    
    (when (drake-facet-plot-title fplot)
      (svg-text svg (drake-facet-plot-title fplot) 
                :x (/ total-width 2) :y 25 :text-anchor "middle" 
                :font-size "20px" :fill "black" :font-weight "bold"))
    
    (cl-loop for r from 0 below n-rows do
             (cl-loop for c from 0 below n-cols do
                      (let* ((p (nth c (nth r grid)))
                             (xml (drake-plot-svg-xml p))
                             (px (+ padding (* c (+ p-width padding))))
                             (py (+ title-height padding (* r (+ p-height padding)))))
                        (if xml
                            (svg-embed svg xml "image/svg+xml" t 
                                       :x px :y py :width p-width :height p-height)
                          (svg-rectangle svg px py p-width p-height :fill "none" :stroke "#ccc")
                          (svg-text svg (format "Plot (%d,%d)" r c) :x (+ px (/ p-width 2)) :y (+ py (/ p-height 2))
                                    :text-anchor "middle" :font-size "12px" :fill "#999")))))
    (let ((xml (with-temp-buffer
                 (svg-print svg)
                 (buffer-string))))
      (setf (drake-facet-plot-svg-xml fplot) xml)
      (svg-image svg))))

(defun drake--filter-data (data filters)
  "Filter DATA based on FILTERS (alist of key . value)."
  (let* ((normalized (drake--normalize-data-all data))
         (indices nil))
    (if (null filters)
        normalized
      (let* ((first-col-key (caar filters))
             (n (length (plist-get normalized first-col-key)))
             (filter-cols (mapcar (lambda (f) (cons (cdr f) (plist-get normalized (car f)))) filters)))
        ;; 1. Find indices that match all filters
        (cl-loop for i from 0 below n do
                 (when (cl-every (lambda (f-col)
                                   (equal (aref (cdr f-col) i) (car f-col)))
                                 filter-cols)
                   (push i indices)))
        (setq indices (nreverse indices))
        ;; 2. Subset all columns
        (let (res)
          (cl-loop for (k v) on normalized by #'cddr do
                   (push k res)
                   (push (vconcat (mapcar (lambda (i) (aref v i)) indices)) res))
          (nreverse res))))))

(defun drake--create-plot (type args)
  "Internal function to create a plot of TYPE with ARGS."
  (let* ((data (plist-get args :data))
         (x-key (plist-get args :x))
         (y-key (plist-get args :y))
         (hue-key (plist-get args :hue))
         ;; 1. Normalize data to columnar format
         (normalized (drake--normalize-data data (list :x x-key :y y-key :hue hue-key :tooltip (plist-get args :tooltip))))
         (x-vec (plist-get normalized :x))
         (y-vec (plist-get normalized :y))
         (hue-vec (plist-get normalized :hue))
         (tooltip-vec (plist-get normalized :tooltip))
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
         (x-scaled (drake--apply-scale x-final x-scale (plist-get args :logx)))
         (y-scaled (drake--apply-scale y-final y-scale (plist-get args :logy)))
         ;; 6. Handle Hue
         (hue-info (when hue-final (drake--process-hue hue-final (plist-get args :palette))))

         ;; 7. Prepare Tooltips
         (final-tooltips (or tooltip-vec
                            (vconcat (cl-loop for i from 0 below (length x-final) collect
                                              (format "%s: %s\n%s: %s%s" 
                                                      (or x-key "X") (aref x-final i)
                                                      (or y-key "Y") (aref y-final i)
                                                      (if hue-final (format "\n%s: %s" (or hue-key "Hue") (aref hue-final i)) ""))))))

         (backend-sym (or (plist-get args :backend) drake-default-backend))
         (backend (gethash backend-sym drake--backends))
         (plot (make-drake-plot
                :spec (append (list :type type) args)
                :data-internal (list :x x-scaled :y y-scaled :hue (plist-get hue-info :values) 
                                     :extra extra-data :tooltip final-tooltips)
                :scales (list :x x-scale :y y-scale :hue (plist-get hue-info :map)
                              :x-type x-type :y-type y-type
                              :x-log (plist-get args :logx) :y-log (plist-get args :logy)))))
    (unless backend
      (error "Backend '%s' not found. Is it loaded?" backend-sym))

    (message "DEBUG: x-type=%S y-type=%S scales=%S" x-type y-type (drake-plot-scales plot))

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

(defun drake--kde-gaussian-kernel (u)
  "Calculate the Gaussian kernel value for U."
  (/ (exp (* -0.5 u u))
     (sqrt (* 2.0 float-pi))))

(defun drake--kde-estimate-density (x data bandwidth)
  "Estimate the density at X for DATA using BANDWIDTH."
  (let ((n (length data))
        (sum 0.0))
    (dolist (xi data)
      (let ((u (/ (- x xi) (float bandwidth))))
        (cl-incf sum (drake--kde-gaussian-kernel u))))
    (/ sum (* n bandwidth))))

(defun drake--standard-deviation (data)
  "Calculate the sample standard deviation of DATA."
  (let* ((n (length data))
         (avg (/ (cl-reduce #'+ data) (float n)))
         (variance (/ (cl-reduce #'+ (mapcar (lambda (x) (expt (- x avg) 2)) data))
                      (float (max 1 (1- n))))))
    (sqrt (max 0.0001 variance))))

(defun drake--kde-silverman-bandwidth (data)
  "Calculate the optimal bandwidth for DATA using Silverman's rule of thumb."
  (let* ((n (length data))
         (sd (drake--standard-deviation data)))
    (* 1.06 sd (expt n -0.2))))

(defun drake--kde-scott-bandwidth (data)
  "Calculate the optimal bandwidth for DATA using Scott's rule."
  (let* ((n (length data))
         (sd (drake--standard-deviation data)))
    (* sd (expt n -0.2))))

(defun drake--transform-stats (x-vec y-vec hue-vec)
  "Calculate summary statistics (quartiles, etc.) and KDE for each category."
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
           (let* ((min (car sorted))
                  (max (car (last sorted)))
                  (q1 (drake--quantile sorted 0.25))
                  (median (drake--quantile sorted 0.5))
                  (q3 (drake--quantile sorted 0.75))
                  ;; KDE calculation
                  (h (if (eq drake-kde-bandwidth-method 'scott)
                         (drake--kde-scott-bandwidth sorted)
                       (drake--kde-silverman-bandwidth sorted)))
                  (kde-points nil)
                  (steps 50)
                  (span (- max min))
                  ;; Extend range slightly for KDE
                  (kde-min (- min (* 0.2 span)))
                  (kde-max (+ max (* 0.2 span)))
                  (kde-step (/ (- kde-max kde-min) (float steps))))
             (cl-loop for i from 0 to steps do
                      (let* ((target-x (+ kde-min (* i kde-step)))
                             (density (drake--kde-estimate-density target-x sorted h)))
                        (push (cons target-x density) kde-points)))
             (push (car key) x-res)
             (push median y-res)
             (push (cdr key) hue-res)
             (push (list :min min :q1 q1 :median median :q3 q3 :max max 
                         :vals sorted :kde (nreverse kde-points)) extra-res)))))
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
  "Detect if VEC is 'numeric, 'time or 'categorical."
  (cond
   ((and (> (length vec) 0)
         (cl-every (lambda (x) (or (numberp x) (null x))) vec))
    'numeric)
   ((and (> (length vec) 0)
         (cl-every (lambda (x) (or (null x) 
                                   (and (listp x) (>= (length x) 2) (cl-every #'integerp x))
                                   (and (stringp x) (string-match-p "^[0-9]\\{4\\}-[0-9]\\{2\\}-[0-9]\\{2\\}" x)))) 
               vec))
    'time)
   (t 'categorical)))

(defun drake--to-timestamp (val)
  "Convert VAL to a float-time value."
  (cond
   ((null val) 0.0)
   ((numberp val) (float val))
   ((and (listp val) (>= (length val) 2)) (float-time val))
   ((stringp val) (float-time (date-to-time val)))
   (t 0.0)))

(defun drake--make-scale (vec type)
  "Create scale for VEC based on TYPE."
  (cond
   ((eq type 'numeric) (drake--get-range vec))
   ((eq type 'time)
    (let ((timestamps (mapcar #'drake--to-timestamp vec)))
      (cons (apply #'min timestamps) (apply #'max timestamps))))
   (t (drake--get-unique-values vec))))

(defun drake--apply-scale (vec scale &optional log)
  "Scale VEC using SCALE. If LOG is non-nil, use logarithmic scaling."
  (cond
   ((and (consp scale) (numberp (car scale))) ;; numeric or time
    (let* ((min (car scale))
           (max (cdr scale))
           (vals (if (listp (aref vec 0)) ;; time list
                     (vconcat (mapcar #'drake--to-timestamp vec))
                   (if (stringp (aref vec 0)) ;; iso date
                       (vconcat (mapcar #'drake--to-timestamp vec))
                     vec))))
      (if log
          (let* ((lmin (log (max 1e-10 min)))
                 (lmax (log (max 1e-10 max)))
                 (ldiff (if (= lmax lmin) 1.0 (- lmax lmin))))
            (vconcat (mapcar (lambda (v) (/ (- (log (max 1e-10 v)) lmin) ldiff)) vals)))
        (drake--scale-vector vals scale))))
   (t ;; categorical
    (let* ((n (length scale))
           (map (make-hash-table :test 'equal))
           (i 0))
      (dolist (val scale)
        (puthash val (if (> n 1) (/ (float i) (1- n)) 0.5) map)
        (setq i (1+ i)))
      (vconcat (mapcar (lambda (val) (gethash val map 0.0)) vec))))))

(defun drake--ensure-vector (seq)
  "Ensure SEQ is a vector. Convert if it is a list."
  (cond
   ((vectorp seq) seq)
   ((listp seq) (vconcat seq))
   (t (error "Cannot convert to vector: %S" seq))))

(defun drake--identify-format (data)
  "Identify the format of DATA.
Returns one of: 'columnar-plist, 'alist-rows, 'plist-rows, 'list-rows, or nil."
  (cond
   ((null data) nil)
   ;; Columnar plist: (:key1 [v1 v2] :key2 [v3 v4])
   ((and (listp data) (keywordp (car-safe data)) (vectorp (car-safe (cdr-safe data))))
    'columnar-plist)
   ;; List of rows
   ((listp data)
    (let ((first-row (car data)))
      (cond
       ((null first-row) nil)
       ;; Alist: ((:x . 1) (:y . 2))
       ((and (consp first-row) (consp (car first-row))) 'alist-rows)
       ;; Plist: (:x 1 :y 2)
       ((and (listp first-row) (keywordp (car-safe first-row))) 'plist-rows)
       ;; List: (1 2)
       ((listp first-row) 'list-rows)
       (t nil))))
   (t nil)))

(defun drake--normalize-data (data column-map)
  "Normalize DATA into a plist of vectors based on COLUMN-MAP.
COLUMN-MAP is a plist mapping internal keys (like :x) to data keys.
Handles columnar plists, row-based lists, and lists of alists/plists."
  (let* ((actual-data (if (plist-get data :data) (plist-get data :data) data))
         (format (drake--identify-format actual-data))
         (result nil))
    (unless format
      (error "Unsupported or empty data format: %S" actual-data))

    (if (eq format 'columnar-plist)
        ;; For columnar, just pick requested columns
        (cl-loop for (internal-key data-key) on column-map by #'cddr do
                 (when data-key
                   (unless (plist-member actual-data data-key)
                     (error "Column %S not found in data" data-key))
                   (push internal-key result)
                   (push (drake--ensure-vector (plist-get actual-data data-key)) result)))
      
      ;; Validation for row-based data
      (let ((first-row (car actual-data)))
        (cl-loop for (internal-key data-key) on column-map by #'cddr do
                 (when data-key
                   (cond
                    ((eq format 'alist-rows)
                     (unless (assoc data-key first-row)
                       (error "Column %S not found in alist row" data-key)))
                    ((eq format 'plist-rows)
                     (unless (plist-member first-row data-key)
                       (error "Column %S not found in plist row" data-key)))
                    ((eq format 'list-rows)
                     (unless (and (numberp data-key) (< data-key (length first-row)))
                       (error "Column index %S out of range" data-key)))))))
      
      ;; For row-based, use mapcar for speed (C optimization)
      (cl-loop for (internal-key data-key) on column-map by #'cddr do
               (when data-key
                 (let ((col (cond
                             ((eq format 'alist-rows)
                              (vconcat (mapcar (lambda (row) (cdr (assoc data-key row))) actual-data)))
                             ((eq format 'plist-rows)
                              (vconcat (mapcar (lambda (row) (plist-get row data-key)) actual-data)))
                             ((eq format 'list-rows)
                              (vconcat (mapcar (lambda (row) (nth data-key row)) actual-data))))))
                   (push internal-key result)
                   (push col result)))))
    (nreverse result)))

(defun drake--normalize-data-all (data)
  "Convert DATA of any format into a single columnar plist of vectors."
  (let* ((actual-data (if (plist-get data :data) (plist-get data :data) data))
         (format (drake--identify-format actual-data)))
    (if (eq format 'columnar-plist)
        actual-data
      (let* ((first-row (car actual-data))
             (all-keys (cond
                        ((eq format 'alist-rows) (mapcar #'car first-row))
                        ((eq format 'plist-rows) (cl-loop for (k v) on first-row by #'cddr collect k))
                        ((eq format 'list-rows) (cl-loop for i from 0 below (length first-row) collect i))))
             (column-map (cl-loop for k in all-keys nconc (list k k))))
        (drake--normalize-data actual-data column-map)))))

(defun drake--extract-column (data key)
  "Extract column KEY from DATA. Raise error if KEY is missing."
  (let ((norm (drake--normalize-data data (list :out key))))
    (plist-get norm :out)))

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

(defvar-local drake-current-plot nil
  "The plot currently displayed in this buffer.")

(defun drake-save-plot (plot filename)
  "Save the SVG representation of PLOT to FILENAME."
  (let ((xml (cond
              ((drake-plot-p plot) (drake-plot-svg-xml plot))
              ((drake-facet-plot-p plot) (drake-facet-plot-svg-xml plot)))))
    (if xml
        (with-temp-file filename
          (insert xml))
      (error "Plot does not contain SVG XML data"))))

(defun drake-save (filename)
  "Interactively save the current plot in the buffer to FILENAME."
  (interactive "FSave plot to: ")
  (if drake-current-plot
      (drake-save-plot drake-current-plot filename)
    (error "No plot found in this buffer")))

(defun drake--display-in-buffer (plot buffer-name)
  "Display PLOT (drake-plot or drake-facet-plot) in buffer BUFFER-NAME."
  (let ((buf (get-buffer-create buffer-name))
        (img (cond
              ((drake-plot-p plot) (drake-plot-image plot))
              ((drake-facet-plot-p plot) (drake-facet-plot-image plot)))))
    (with-current-buffer buf
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert-image img)
        (setq drake-current-plot plot)
        (cond
         ((drake-plot-p plot) (setf (drake-plot-buffer plot) buf))
         ((drake-facet-plot-p plot) nil))
        (display-buffer buf)))))

(provide 'drake)
;;; drake.el ends here

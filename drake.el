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
(require 'drake-theme)

;; Optional palette browser (loaded on demand)
(autoload 'drake-palette-browser "drake-palette-browser" "Open palette browser" t)
(autoload 'drake-palette-preview "drake-palette-browser" "Preview a palette" t)
(autoload 'drake-palette-browser-quick-select "drake-palette-browser" "Quick palette selection" t)
;;;###autoload
(autoload 'drake-fetch-palettes "drake-palette-browser" "Fetch and cache additional palettes from ColorBrewer" t)

;; Optional org-babel support (loaded on demand)
(autoload 'org-babel-execute:drake "ob-drake" "Execute Drake code in org-babel" nil)
(autoload 'drake-org-update-plot-at-point "ob-drake" "Update Drake plot at point" t)
(autoload 'drake-org-clear-plot-registry "ob-drake" "Clear plot registry" t)

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

(defun drake--load-cache-if-needed ()
  "Load palettes from disk cache if not already loaded."
  (unless drake--palette-cache
    (let ((cache-file (expand-file-name "drake/palettes-cache.el" user-emacs-directory)))
      (when (file-exists-p cache-file)
        (load cache-file t t)))))

(defun drake--normalize-color (color)
  "Convert COLOR from rgb(r,g,b) format to hex #rrggbb format.
If COLOR is already in hex format, return it unchanged."
  (if (and (stringp color)
           (string-match "^rgb(\\([0-9]+\\),\\([0-9]+\\),\\([0-9]+\\))" color))
      (let ((r (string-to-number (match-string 1 color)))
            (g (string-to-number (match-string 2 color)))
            (b (string-to-number (match-string 3 color))))
        (format "#%02x%02x%02x" r g b))
    ;; Already hex or other format, return as is
    color))

(defun drake--normalize-colors (colors)
  "Normalize COLORS list, converting RGB format to hex."
  (mapcar #'drake--normalize-color colors))

(defun drake--get-palette (name)
  "Return color list for palette NAME.
If NAME is nil, uses the palette specified by the current theme.
All colors are normalized to hex format."
  (let ((colors
         (cond
          ((and name (listp name)) name) ;; Direct list of colors
          ((symbolp name)
           (drake--load-cache-if-needed)
           (or (and name (cdr (assoc name drake--user-palettes)))
               (and name (cdr (assoc name drake--bundled-palettes)))
               (and name (cdr (assoc name drake--palette-cache)))
               ;; Fall back to theme palette
               (let ((theme-palette (drake-theme-get :palette)))
                 (if theme-palette
                     (drake--get-palette theme-palette)
                   (cdr (assoc 'default drake--bundled-palettes))))))
          (t
           ;; No name provided, use theme palette or default
           (let ((theme-palette (drake-theme-get :palette)))
             (if theme-palette
                 (drake--get-palette theme-palette)
               (cdr (assoc 'default drake--bundled-palettes))))))))
    ;; Normalize all colors to hex format
    (if (listp colors)
        (drake--normalize-colors colors)
      colors)))

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

(defun drake-plot-count (&rest args)
  "Create a count plot (bar chart of categorical frequencies).

Automatically counts occurrences of categorical values and displays
them as a bar chart. This is a convenience wrapper around `drake-plot-bar'
with implicit aggregation.

ARGS is a plist:
:data    - Data source (required)
:x       - Categorical column for X-axis (vertical bars) - mutually exclusive with :y
:y       - Categorical column for Y-axis (horizontal bars) - mutually exclusive with :x
:hue     - Optional color grouping column
:order   - Category ordering: 'appearance (default), 'alpha, 'value-desc, 'value-asc,
           or explicit list
:hue-order - Order of hue categories (list)
:stat    - Statistical transformation: 'count (default), 'proportion, or 'percent
:palette - Color palette
:title   - Plot title
:xlabel  - X-axis label
:ylabel  - Y-axis label
:width   - Plot width
:height  - Plot height
:backend - Rendering backend
:buffer  - Target buffer name

Examples:
  ;; Simple count plot
  (drake-plot-count :data tips :x :day)

  ;; With hue grouping
  (drake-plot-count :data tips :x :day :hue :time)

  ;; Ordered by frequency (most common first)
  (drake-plot-count :data tips :x :day :order 'value-desc)

  ;; Show as percentages
  (drake-plot-count :data tips :x :day :stat 'percent)"
  ;; Validate parameters
  (unless (or (plist-get args :x) (plist-get args :y))
    (error "Either :x or :y must be specified"))
  (when (and (plist-get args :x) (plist-get args :y))
    (error "Cannot specify both :x and :y"))

  (let* ((data (plist-get args :data))
         (x-key (plist-get args :x))
         (y-key (plist-get args :y))
         (hue-key (plist-get args :hue))
         (stat (or (plist-get args :stat) 'count))
         (order-method (or (plist-get args :order) 'appearance))

         ;; Determine orientation
         (cat-key (or x-key y-key))
         (orientation (if x-key 'vertical 'horizontal))

         ;; Extract columns
         (cat-vec (drake--extract-column data cat-key))
         (hue-vec (when hue-key (drake--extract-column data hue-key)))

         ;; Count occurrences
         (counts (drake--count-by-group cat-vec hue-vec cat-key hue-key))

         ;; Apply ordering
         (counts-ordered (drake--order-counts counts cat-key order-method))

         ;; Apply statistical transformation
         (counts-transformed (drake--transform-counts counts-ordered stat)))

    ;; Build bar plot arguments
    (let ((bar-args (list :data counts-transformed
                         :x (if (eq orientation 'vertical) cat-key :count)
                         :y (if (eq orientation 'vertical) :count cat-key))))
      ;; Add optional parameters
      (when hue-key
        (setq bar-args (plist-put bar-args :hue hue-key)))
      (when (plist-get args :hue-order)
        (setq bar-args (plist-put bar-args :hue-order (plist-get args :hue-order))))
      (when (plist-get args :palette)
        (setq bar-args (plist-put bar-args :palette (plist-get args :palette))))
      (when (plist-get args :title)
        (setq bar-args (plist-put bar-args :title (plist-get args :title))))
      (when (plist-get args :xlabel)
        (setq bar-args (plist-put bar-args :xlabel (plist-get args :xlabel))))
      (when (plist-get args :ylabel)
        (setq bar-args (plist-put bar-args :ylabel (plist-get args :ylabel))))
      (when (plist-get args :width)
        (setq bar-args (plist-put bar-args :width (plist-get args :width))))
      (when (plist-get args :height)
        (setq bar-args (plist-put bar-args :height (plist-get args :height))))
      (when (plist-get args :backend)
        (setq bar-args (plist-put bar-args :backend (plist-get args :backend))))
      (when (plist-get args :buffer)
        (setq bar-args (plist-put bar-args :buffer (plist-get args :buffer))))

      ;; Plot as bar chart
      (apply #'drake-plot-bar bar-args))))

(defun drake--count-by-group (cat-vec hue-vec cat-key hue-key)
  "Count occurrences of categories in CAT-VEC, optionally grouped by HUE-VEC.
Returns columnar plist with CAT-KEY, optional HUE-KEY, and :count columns."
  (let ((counts (make-hash-table :test 'equal))
        (order nil))
    ;; Count each (category, hue) combination
    (cl-loop for i from 0 below (length cat-vec) do
             (let* ((cat (aref cat-vec i))
                    (hue (when hue-vec (aref hue-vec i)))
                    (key (if hue (cons cat hue) cat)))
               (unless (gethash key counts)
                 (push key order))  ; Track order of first appearance
               (puthash key (1+ (gethash key counts 0)) counts)))

    (setq order (nreverse order))

    ;; Convert hash to columnar plist
    (if hue-vec
        ;; With hue: need cat, hue, count columns
        (let ((cat-list nil)
              (hue-list nil)
              (count-list nil))
          (dolist (key order)
            (push (car key) cat-list)
            (push (cdr key) hue-list)
            (push (gethash key counts) count-list))
          (list cat-key (vconcat (nreverse cat-list))
                hue-key (vconcat (nreverse hue-list))
                :count (vconcat (nreverse count-list))))
      ;; No hue: just cat and count columns
      (let ((cat-list nil)
            (count-list nil))
        (dolist (key order)
          (push key cat-list)
          (push (gethash key counts) count-list))
        (list cat-key (vconcat (nreverse cat-list))
              :count (vconcat (nreverse count-list)))))))

(defun drake--order-counts (counts cat-key order-method)
  "Order COUNTS data according to ORDER-METHOD.
Methods: 'appearance (default), 'alpha, 'value-desc, 'value-asc, or explicit list."
  (cond
   ((eq order-method 'appearance)
    counts)  ; Already in order of first appearance

   ((eq order-method 'alpha)
    (drake--sort-counts-by-category counts cat-key #'string<))

   ((eq order-method 'value-desc)
    (drake--sort-counts-by-count counts #'>))

   ((eq order-method 'value-asc)
    (drake--sort-counts-by-count counts #'<))

   ((listp order-method)
    (drake--reorder-counts counts cat-key order-method))

   (t counts)))

(defun drake--sort-counts-by-category (counts cat-key predicate)
  "Sort COUNTS by category using PREDICATE."
  (let* ((cat-vec (plist-get counts cat-key))
         (count-vec (plist-get counts :count))
         (hue-key (cl-loop for (k v) on counts by #'cddr
                          when (and (not (eq k cat-key)) (not (eq k :count)))
                          return k))
         (hue-vec (when hue-key (plist-get counts hue-key)))
         (indices (cl-loop for i from 0 below (length cat-vec) collect i))
         (sorted-indices (sort indices (lambda (a b)
                                        (funcall predicate
                                                (format "%s" (aref cat-vec a))
                                                (format "%s" (aref cat-vec b)))))))
    (if hue-key
        (list cat-key (vconcat (mapcar (lambda (i) (aref cat-vec i)) sorted-indices))
              hue-key (vconcat (mapcar (lambda (i) (aref hue-vec i)) sorted-indices))
              :count (vconcat (mapcar (lambda (i) (aref count-vec i)) sorted-indices)))
      (list cat-key (vconcat (mapcar (lambda (i) (aref cat-vec i)) sorted-indices))
            :count (vconcat (mapcar (lambda (i) (aref count-vec i)) sorted-indices))))))

(defun drake--sort-counts-by-count (counts predicate)
  "Sort COUNTS by count value using PREDICATE."
  (let* ((cat-key (cl-loop for (k v) on counts by #'cddr
                          when (not (eq k :count))
                          return k))
         (cat-vec (plist-get counts cat-key))
         (count-vec (plist-get counts :count))
         (hue-key (cl-loop for (k v) on counts by #'cddr
                          when (and (not (eq k cat-key)) (not (eq k :count)))
                          return k))
         (hue-vec (when hue-key (plist-get counts hue-key)))
         (indices (cl-loop for i from 0 below (length count-vec) collect i))
         (sorted-indices (sort indices (lambda (a b)
                                        (funcall predicate
                                                (aref count-vec a)
                                                (aref count-vec b))))))
    (if hue-key
        (list cat-key (vconcat (mapcar (lambda (i) (aref cat-vec i)) sorted-indices))
              hue-key (vconcat (mapcar (lambda (i) (aref hue-vec i)) sorted-indices))
              :count (vconcat (mapcar (lambda (i) (aref count-vec i)) sorted-indices)))
      (list cat-key (vconcat (mapcar (lambda (i) (aref cat-vec i)) sorted-indices))
            :count (vconcat (mapcar (lambda (i) (aref count-vec i)) sorted-indices))))))

(defun drake--reorder-counts (counts cat-key explicit-order)
  "Reorder COUNTS according to EXPLICIT-ORDER list."
  (let* ((cat-vec (plist-get counts cat-key))
         (count-vec (plist-get counts :count))
         (hue-key (cl-loop for (k v) on counts by #'cddr
                          when (and (not (eq k cat-key)) (not (eq k :count)))
                          return k))
         (hue-vec (when hue-key (plist-get counts hue-key)))
         (new-cat nil)
         (new-hue nil)
         (new-count nil))
    ;; Build new vectors in the order specified
    (dolist (cat explicit-order)
      (cl-loop for i from 0 below (length cat-vec)
               when (equal (aref cat-vec i) cat)
               do (push (aref cat-vec i) new-cat)
                  (when hue-vec (push (aref hue-vec i) new-hue))
                  (push (aref count-vec i) new-count)))
    (if hue-key
        (list cat-key (vconcat (nreverse new-cat))
              hue-key (vconcat (nreverse new-hue))
              :count (vconcat (nreverse new-count)))
      (list cat-key (vconcat (nreverse new-cat))
            :count (vconcat (nreverse new-count))))))

(defun drake--transform-counts (counts stat)
  "Transform counts according to STAT ('count, 'proportion, or 'percent)."
  (cond
   ((eq stat 'count)
    counts)  ; Already counts

   ((eq stat 'proportion)
    (let* ((count-vec (plist-get counts :count))
           (total (apply #'+ (append count-vec nil)))
           (prop-vec (vconcat (mapcar (lambda (c) (/ (float c) total))
                                     (append count-vec nil)))))
      (plist-put (copy-sequence counts) :count prop-vec)))

   ((eq stat 'percent)
    (let* ((counts-prop (drake--transform-counts counts 'proportion))
           (prop-vec (plist-get counts-prop :count))
           (pct-vec (vconcat (mapcar (lambda (p) (* p 100.0)) (append prop-vec nil)))))
      (plist-put counts-prop :count pct-vec)))

   (t counts)))

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

(defun drake-plot-pair (&rest args)
  "Create a pair plot (scatter matrix) showing pairwise relationships.

Displays a grid of plots where each cell shows the relationship between
two variables. Diagonal cells show the distribution of individual variables
(histograms or KDE), while off-diagonal cells show scatter plots or
regression lines.

ARGS is a plist:
:data      - Data source (required)
:vars      - List of variable keywords '(:var1 :var2 ...) (required unless x-vars/y-vars)
:x-vars    - Alternative: list of variables for columns (overrides :vars)
:y-vars    - Alternative: list of variables for rows (overrides :vars)
:hue       - Optional color grouping column
:palette   - Color palette
:kind      - 'scatter (default) or 'reg (regression lines)
:diag-kind - 'hist (default), 'kde, or 'none
:diag-bins - Number of bins for diagonal histograms (default 20)
:corner    - If t, only show lower triangle (default nil)
:alpha     - Point transparency (default 0.7)
:title     - Overall title
:width     - Width of each subplot
:height    - Height of each subplot
:backend   - Rendering backend
:buffer    - Target buffer name

Examples:
  ;; Basic pair plot
  (drake-plot-pair :data iris
                  :vars '(:sepal_length :sepal_width :petal_length))

  ;; With species coloring
  (drake-plot-pair :data iris
                  :vars '(:sepal_length :sepal_width :petal_length)
                  :hue :species)

  ;; Corner mode (lower triangle only)
  (drake-plot-pair :data iris
                  :vars '(:sepal_length :sepal_width :petal_length)
                  :corner t)

  ;; With regression lines
  (drake-plot-pair :data iris
                  :vars '(:sepal_length :petal_length)
                  :kind 'reg)"
  (let* ((data (drake--normalize-data-all (plist-get args :data)))
         (vars (plist-get args :vars))
         (x-vars (or (plist-get args :x-vars) vars))
         (y-vars (or (plist-get args :y-vars) vars)))

    ;; Validate parameters
    (unless (and x-vars y-vars)
      (error "Must specify either :vars or both :x-vars and :y-vars"))
    (when (null x-vars)
      (error "No variables specified"))

    ;; Validate variables exist in data
    (cl-loop for var in x-vars
             unless (plist-member data var)
             do (error "Variable %s not found in data" var))
    (cl-loop for var in y-vars
             unless (plist-member data var)
             do (error "Variable %s not found in data" var))

    (let* ((hue-key (plist-get args :hue))
           (kind (or (plist-get args :kind) 'scatter))
           (diag-kind (or (plist-get args :diag-kind) 'hist))
           (corner (plist-get args :corner))
           (backend-sym (or (plist-get args :backend) drake-default-backend))

           ;; Determine grid dimensions
           (n-rows (length y-vars))
           (n-cols (length x-vars))

           ;; Create grid of plots
           (grid (drake--create-pair-grid data x-vars y-vars hue-key kind diag-kind
                                         corner backend-sym args)))

      ;; Package as facet plot
      (let ((fplot (make-drake-facet-plot
                    :grid grid
                    :title (plist-get args :title)
                    :rows n-rows
                    :cols n-cols
                    :spec args)))

        ;; Render
        (let ((backend (gethash backend-sym drake--backends)))
          (if (and backend (drake-backend-render-facet-fn backend))
              (setf (drake-facet-plot-image fplot)
                    (funcall (drake-backend-render-facet-fn backend) fplot))
            (setf (drake-facet-plot-image fplot) (drake--render-facet fplot))))

        ;; Display
        (drake--display-in-buffer fplot (or (plist-get args :buffer) "*drake-pair*"))
        fplot))))

(defun drake--create-pair-grid (data x-vars y-vars hue-key kind diag-kind corner backend args)
  "Create grid of plots for pair plot."
  (let ((grid nil))
    (cl-loop for row-idx from 0 below (length y-vars) do
      (let ((y-var (nth row-idx y-vars))
            (row-plots nil))
        (cl-loop for col-idx from 0 below (length x-vars) do
          (let ((x-var (nth col-idx x-vars)))
            (cond
             ;; Skip upper triangle if corner mode
             ((and corner (> col-idx row-idx))
              (push nil row-plots))

             ;; Diagonal: histogram or KDE
             ((equal x-var y-var)
              (push (drake--create-diagonal-plot data x-var hue-key diag-kind backend args)
                    row-plots))

             ;; Off-diagonal: scatter or regression
             (t
              (push (drake--create-offdiag-plot data x-var y-var hue-key kind backend args)
                    row-plots)))))
        (push (nreverse row-plots) grid)))
    (nreverse grid)))

(defun drake--create-diagonal-plot (data var hue-key diag-kind backend args)
  "Create diagonal plot (histogram or KDE)."
  (cond
   ((eq diag-kind 'hist)
    (drake-plot-hist :data data :x var :hue hue-key
                    :backend backend :buffer nil
                    :bins (or (plist-get args :diag-bins) 20)
                    :palette (plist-get args :palette)
                    :width (plist-get args :width)
                    :height (plist-get args :height)))

   ((eq diag-kind 'kde)
    ;; KDE plot not implemented yet, fall back to histogram
    (drake-plot-hist :data data :x var :hue hue-key
                    :backend backend :buffer nil
                    :bins (or (plist-get args :diag-bins) 20)
                    :palette (plist-get args :palette)
                    :width (plist-get args :width)
                    :height (plist-get args :height)))

   ((eq diag-kind 'none)
    nil)  ; Empty subplot

   (t
    (drake-plot-hist :data data :x var :hue hue-key
                    :backend backend :buffer nil
                    :bins (or (plist-get args :diag-bins) 20)
                    :palette (plist-get args :palette)
                    :width (plist-get args :width)
                    :height (plist-get args :height)))))

(defun drake--create-offdiag-plot (data x-var y-var hue-key kind backend args)
  "Create off-diagonal plot (scatter or regression)."
  (cond
   ((eq kind 'scatter)
    (drake-plot-scatter :data data :x x-var :y y-var :hue hue-key
                       :backend backend :buffer nil
                       :palette (plist-get args :palette)
                       :width (plist-get args :width)
                       :height (plist-get args :height)))

   ((eq kind 'reg)
    (drake-plot-lm :data data :x x-var :y y-var :hue hue-key
                  :backend backend :buffer nil
                  :palette (plist-get args :palette)
                  :width (plist-get args :width)
                  :height (plist-get args :height)))

   (t
    (drake-plot-scatter :data data :x x-var :y y-var :hue hue-key
                       :backend backend :buffer nil
                       :palette (plist-get args :palette)
                       :width (plist-get args :width)
                       :height (plist-get args :height)))))

(defun drake--render-facet (fplot)
  "Render a drake-facet-plot FPLOT into a single composite SVG image."
  (let* ((grid (drake-facet-plot-grid fplot))
         (n-rows (drake-facet-plot-rows fplot))
         (n-cols (drake-facet-plot-cols fplot))
         ;; Find first non-nil plot to get dimensions
         (first-plot (cl-loop for row in grid
                             thereis (cl-loop for p in row
                                             when p return p)))
         (p-spec (when first-plot (drake-plot-spec first-plot)))
         (p-width (or (and p-spec (plist-get p-spec :width)) drake-default-width))
         (p-height (or (and p-spec (plist-get p-spec :height)) drake-default-height))
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
                             (xml (when p (drake-plot-svg-xml p)))
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
      ;; In batch mode or if SVG support is unavailable, return a placeholder
      (condition-case nil
          (svg-image svg)
        (error (list 'image :type 'svg :data xml))))))

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
         ;; For box/violin plots, y-scale should cover full data range, not just medians
         (x-scale (if (and (eq x-type 'categorical) (plist-get args :order))
                      (plist-get args :order)
                    (drake--make-scale x-final x-type)))
         (y-scale (if (or (eq type 'box) (eq type 'violin))
                      (drake--make-scale-from-stats extra-data)
                    (drake--make-scale y-final y-type)))
         ;; 5. Scale data to 0.0-1.0
         (x-scaled (drake--apply-scale x-final x-scale (plist-get args :logx)))
         (y-scaled (drake--apply-scale y-final y-scale (plist-get args :logy)))
         ;; 6. Handle Hue
         (hue-info (when hue-final (drake--process-hue hue-final (plist-get args :palette) (plist-get args :hue-order))))

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
    (drake--transform-stats x-vec y-vec hue-vec (plist-get args :order) (plist-get args :hue-order)))
   ((eq type 'violin)
    (drake--transform-stats x-vec y-vec hue-vec (plist-get args :order) (plist-get args :hue-order)))
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
Returns a plist (:m slope :b intercept :r2 r-squared :se standard-error :sxx sxx :mean-x mean-x :n n).
Uses Rust implementation if available."
  (if (and (boundp 'drake-rust-module-loaded) drake-rust-module-loaded
           (fboundp 'drake-rust-module/ols-regression))
      ;; Use Rust implementation
      (condition-case err
          (let* ((result (drake-rust-module/ols-regression points))
                 (m (plist-get result :slope))
                 (b (plist-get result :intercept))
                 (r2 (plist-get result :r-squared))
                 (n (length points))
                 ;; Calculate additional stats needed by Elisp code
                 (sum-x 0.0)
                 (sum-xx 0.0)
                 (ss-res 0.0))
            (dolist (p points)
              (let* ((x (float (car p)))
                     (y (float (cdr p)))
                     (y-pred (+ (* m x) b)))
                (cl-incf sum-x x)
                (cl-incf sum-xx (* x x))
                (cl-incf ss-res (* (- y y-pred) (- y y-pred)))))
            (let* ((mean-x (/ sum-x n))
                   (sxx (- sum-xx (/ (* sum-x sum-x) n)))
                   (se (if (> n 2) (sqrt (/ ss-res (- n 2))) 0.0)))
              (list :m m :b b :r2 r2 :se se :sxx sxx :mean-x mean-x :n n)))
        (error
         (message "Rust OLS failed, falling back to Elisp: %s" err)
         (drake--ols-regression-elisp points)))
    ;; Use Elisp implementation
    (drake--ols-regression-elisp points)))

(defun drake--ols-regression-elisp (points)
  "Perform OLS regression in pure Elisp."
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
  ;; Note: This Elisp version is kept for reference but not used when Rust is available
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

(defun drake--compute-kde (data method)
  "Compute KDE for DATA using METHOD (scott or silverman).
Uses Rust implementation if available, falls back to Elisp."
  (if (and (boundp 'drake-rust-module-loaded) drake-rust-module-loaded
           (fboundp 'drake-rust-module/kde-compute))
      ;; Use Rust implementation
      (condition-case err
          (drake-rust-module/kde-compute data method 50)
        (error
         (message "Rust KDE failed, falling back to Elisp: %s" err)
         (drake--compute-kde-elisp data method)))
    ;; Use Elisp implementation
    (drake--compute-kde-elisp data method)))

(defun drake--compute-kde-elisp (data method)
  "Compute KDE for DATA using METHOD in pure Elisp."
  (let* ((sorted (sort (cl-remove-if-not #'numberp (append data nil)) #'<))
         (n (length sorted)))
    (when (> n 0)
      (let* ((h (if (eq method 'scott)
                    (drake--kde-scott-bandwidth sorted)
                  (drake--kde-silverman-bandwidth sorted)))
             (min-val (car sorted))
             (max-val (car (last sorted)))
             (span (- max-val min-val))
             (kde-min (- min-val (* 0.2 span)))
             (kde-max (+ max-val (* 0.2 span)))
             (steps 50)
             (kde-step (/ (- kde-max kde-min) (float steps)))
             (kde-points nil))
        (cl-loop for i from 0 to steps do
                 (let* ((target-x (+ kde-min (* i kde-step)))
                        (density (drake--kde-estimate-density target-x sorted h)))
                   (push (cons target-x density) kde-points)))
        (nreverse kde-points)))))

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

(defun drake--compute-quartiles-safe (data)
  "Compute quartiles for DATA, using Rust if available."
  (if (and (boundp 'drake-rust-module-loaded) drake-rust-module-loaded
           (fboundp 'drake-rust-module/compute-quartiles))
      ;; Use Rust implementation
      (condition-case err
          (let ((result (drake-rust-module/compute-quartiles (vconcat data))))
            (list :min (plist-get result :min)
                  :q1 (plist-get result :q1)
                  :median (plist-get result :median)
                  :q3 (plist-get result :q3)
                  :max (plist-get result :max)))
        (error
         (message "Rust quartiles failed, falling back to Elisp: %s" err)
         (drake--compute-quartiles-elisp data)))
    ;; Use Elisp implementation
    (drake--compute-quartiles-elisp data)))

(defun drake--compute-quartiles-elisp (data)
  "Compute quartiles for DATA in pure Elisp."
  (let* ((sorted (sort (cl-copy-list data) #'<))
         (n (length sorted)))
    (when (> n 0)
      (list :min (car sorted)
            :q1 (drake--quantile sorted 0.25)
            :median (drake--quantile sorted 0.5)
            :q3 (drake--quantile sorted 0.75)
            :max (car (last sorted))))))

(defun drake--transform-stats (x-vec y-vec hue-vec &optional order hue-order)
  "Calculate summary statistics (quartiles, etc.) and KDE for each category.
Optional ORDER specifies the order of categories on the x-axis.
Optional HUE-ORDER specifies the order of hue values."
  (let* ((groups (make-hash-table :test 'equal))
         (categories (or order (drake--get-unique-values x-vec)))
         (x-res nil) (y-res nil) (hue-res nil) (extra-res nil))
    ;; Collect data into groups
    (cl-loop for i from 0 below (length x-vec) do
             (let ((cat (aref x-vec i))
                   (val (aref y-vec i))
                   (h (when hue-vec (aref hue-vec i))))
               (push val (gethash (cons cat h) groups))))

    ;; Process categories in the specified order
    (dolist (cat categories)
      ;; For each category, process all hue values in specified order
      (let ((hue-values (if hue-vec
                            (or hue-order (drake--get-unique-values hue-vec))
                          '(nil))))
        (dolist (h hue-values)
          (let ((key (cons cat h)))
            (when-let ((vals (gethash key groups)))
              (let* ((sorted (sort (cl-remove-if-not #'numberp vals) #'<))
                     (n (length sorted)))
                (when (> n 0)
                  ;; Use Rust-aware functions
                  (let* ((quartiles (drake--compute-quartiles-safe sorted))
                         (min (plist-get quartiles :min))
                         (max (plist-get quartiles :max))
                         (q1 (plist-get quartiles :q1))
                         (median (plist-get quartiles :median))
                         (q3 (plist-get quartiles :q3))
                         ;; KDE calculation (Rust-aware)
                         (kde-points (drake--compute-kde (vconcat sorted) drake-kde-bandwidth-method)))
                    (push cat x-res)
                    (push median y-res)
                    (push h hue-res)
                    (push (list :min min :q1 q1 :median median :q3 q3 :max max
                                :vals sorted :kde kde-points) extra-res)))))))))

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
      (+ (* (- 1 fraction) (nth low sorted-vec))
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

(defun drake--make-scale-from-stats (extra-vec)
  "Create y-scale from box/violin plot statistics in EXTRA-VEC.
Each element should be a plist with :min and :max keys, and optionally :kde."
  (let ((all-mins nil)
        (all-maxs nil))
    (cl-loop for i from 0 below (length extra-vec) do
             (let ((stats (aref extra-vec i)))
               ;; Collect data min/max
               (when (plist-get stats :min)
                 (push (plist-get stats :min) all-mins))
               (when (plist-get stats :max)
                 (push (plist-get stats :max) all-maxs))
               ;; Also collect KDE range if present (for violin plots)
               (when-let ((kde (plist-get stats :kde)))
                 (dolist (point kde)
                   (let ((y-val (car point)))
                     (push y-val all-mins)
                     (push y-val all-maxs))))))
    (if (and all-mins all-maxs)
        (cons (apply #'min all-mins) (apply #'max all-maxs))
      (cons 0 1)))) ;; Fallback

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
           (padding 0.1)  ;; 10% padding on each side
           (i 0))
      (dolist (val scale)
        (puthash val
                 (if (> n 1)
                     (+ padding (* (/ (float i) (1- n)) (- 1.0 (* 2 padding))))
                   0.5)
                 map)
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

(defun drake--process-hue (hue-vec palette &optional hue-order)
  "Process HUE-VEC and return a plist with mapped colors.
Optional HUE-ORDER specifies the order of hue values for color assignment."
  (let* ((unique-vals (or hue-order (drake--get-unique-values hue-vec)))
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
    ;; Only attach tooltip if imagep is available (not in batch mode)
    (if (and (fboundp 'imagep) (imagep img))
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

;; Load default backend after providing drake to avoid circular dependency
;; Respects user's drake-default-backend setting (e.g., via use-package :custom)
(pcase drake-default-backend
  ('svg (require 'drake-svg))
  ('gnuplot (require 'drake-gnuplot))
  ('rust (require 'drake-rust))
  (_ (require 'drake-svg))) ;; Fallback to svg if unknown backend

;;; drake.el ends here

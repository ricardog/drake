;;; drake-svg.el --- SVG backend for drake -*- lexical-binding: t; -*-

(require 'drake)
(require 'svg)
(require 'cl-lib)
(require 'dom)

(defun drake-svg-render (plot)
  "Render PLOT to an SVG image."
  (let* ((spec (drake-plot-spec plot))
         (type (plist-get spec :type))
         (width (or (plist-get spec :width) drake-default-width))
         (height (or (plist-get spec :height) drake-default-height))
         (margin 60)
         (inner-width (- width (* 2 margin)))
         (inner-height (- height (* 2 margin)))
         (data (drake-plot-data-internal plot))
         (x-scaled (plist-get data :x))
         (y-scaled (plist-get data :y))
         (hue-colors (plist-get data :hue))
         (tooltips (plist-get data :tooltip))
         (svg (svg-create width height)))

    ;; Background
    (svg-rectangle svg 0 0 width height :fill "white")

    ;; Grid lines and ticks
    (drake-svg--draw-axes svg margin margin inner-width inner-height plot)

    ;; Draw data based on type
    (cond
     ((eq type 'scatter)
      (drake-svg--draw-scatter svg margin margin inner-width inner-height x-scaled y-scaled hue-colors tooltips))
     ((eq type 'lm)
      (drake-svg--draw-scatter svg margin margin inner-width inner-height x-scaled y-scaled hue-colors tooltips)
      (drake-svg--draw-lm svg margin margin inner-width inner-height plot))
     ((eq type 'line)
      (drake-svg--draw-line svg margin margin inner-width inner-height x-scaled y-scaled hue-colors tooltips))
     ((eq type 'bar)
      (drake-svg--draw-bar svg margin margin inner-width inner-height x-scaled y-scaled hue-colors tooltips))
     ((eq type 'hist)
      (drake-svg--draw-hist svg margin margin inner-width inner-height x-scaled y-scaled hue-colors tooltips plot))
     ((eq type 'smooth)
      (drake-svg--draw-smooth svg margin margin inner-width inner-height plot tooltips))
     ((eq type 'box)
      (drake-svg--draw-box svg margin margin inner-width inner-height x-scaled y-scaled hue-colors tooltips plot))
     ((eq type 'violin)
      (drake-svg--draw-violin svg margin margin inner-width inner-height x-scaled y-scaled hue-colors tooltips plot)))

    ;; Legend
    (when-let ((hue-map (plist-get (drake-plot-scales plot) :hue)))
      (drake-svg--draw-legend svg width height margin hue-map plot))

    ;; Title
    (when-let ((title (plist-get spec :title)))
      (svg-text svg title :x (/ width 2) :y (/ margin 2) :text-anchor "middle" :font-size "16px" :fill "black" :font-weight "bold"))

    (let ((xml (with-temp-buffer
                 (svg-print svg)
                 (buffer-string))))
      ;; Post-process XML to convert drake-tooltip attributes to <title> children
      (setq xml (drake-svg--post-process-tooltips xml))
      (setf (drake-plot-svg-xml plot) xml)
      (condition-case nil
          (create-image xml 'svg t :width width :height height)
        (error (list 'image :type 'svg :data xml))))))

(defun drake-svg--draw-axes (svg x y width height plot)
  "Draw axes, ticks, and grid lines."
  (let* ((scales (drake-plot-scales plot))
         (spec (drake-plot-spec plot))
         (x-range (plist-get scales :x))
         (y-range (plist-get scales :y))
         (x-type (plist-get scales :x-type))
         (y-type (plist-get scales :y-type))
         (num-ticks 5))
    
    ;; Y Axis Ticks and Grid
    (if (eq y-type 'numeric)
        (cl-loop for i from 0 to num-ticks do
                 (let* ((ratio (/ (float i) num-ticks))
                        (py (+ y (- height (* ratio height))))
                        (val (+ (car y-range) (* ratio (- (cdr y-range) (car y-range))))))
                   (svg-line svg x py (+ x width) py :stroke "#eee" :stroke-width 1)
                   (svg-line svg (- x 5) py x py :stroke "black")
                   (svg-text svg (format "%.1f" val) :x (- x 10) :y (+ py 4) :text-anchor "end" :font-size "10px")))
      ;; Categorical Y
      (let* ((n (length y-range))
             (i 0))
        (dolist (val y-range)
          (let* ((ratio (if (> n 1) (/ (float i) (1- n)) 0.5))
                 (py (+ y (- height (* ratio height)))))
            (svg-line svg x py (+ x width) py :stroke "#eee" :stroke-width 1)
            (svg-text svg (format "%s" val) :x (- x 10) :y (+ py 4) :text-anchor "end" :font-size "10px")
            (setq i (1+ i))))))

    ;; X Axis Ticks and Grid
    (if (eq x-type 'numeric)
        (cl-loop for i from 0 to num-ticks do
                 (let* ((ratio (/ (float i) num-ticks))
                        (px (+ x (* ratio width)))
                        (val (+ (car x-range) (* ratio (- (cdr x-range) (car x-range))))))
                   (svg-line svg px y px (+ y height) :stroke "#eee" :stroke-width 1)
                   (svg-line svg px (+ y height) px (+ y height 5) :stroke "black")
                   (svg-text svg (format "%.1f" val) :x px :y (+ y height 20) :text-anchor "middle" :font-size "10px")))
      ;; Categorical X
      (let* ((n (length x-range))
             (i 0))
        (dolist (val x-range)
          (let* ((ratio (if (> n 1) (/ (float i) (1- n)) 0.5))
                 (px (+ x (* ratio width))))
            (svg-line svg px y px (+ y height) :stroke "#eee" :stroke-width 1)
            (svg-text svg (format "%s" val) :x px :y (+ y height 20) :text-anchor "middle" :font-size "10px")
            (setq i (1+ i))))))

    ;; Axis lines
    (svg-line svg x y x (+ y height) :stroke "black" :stroke-width 1)
    (svg-line svg x (+ y height) (+ x width) (+ y height) :stroke "black" :stroke-width 1)

    ;; Axis Labels
    (when-let ((xlabel (or (plist-get spec :xlabel) (plist-get spec :x))))
      (svg-text svg (format "%s" xlabel) :x (+ x (/ width 2)) :y (+ y height 40) :text-anchor "middle" :font-size "12px" :fill "black"))
    (when-let ((ylabel (or (plist-get spec :ylabel) (plist-get spec :y))))
      (svg-text svg (format "%s" ylabel) :x (- x 50) :y (+ y (/ height 2)) :text-anchor "middle" :font-size "12px" :fill "black" :transform (format "rotate(-90 %d %d)" (- x 50) (+ y (/ height 2)))))))

(defun drake-svg--draw-scatter (svg x y width height x-scaled y-scaled hue-colors tooltips)
  (cl-loop for i from 0 below (length x-scaled) do
           (let* ((px (+ x (* (aref x-scaled i) width)))
                  (py (+ y (- height (* (aref y-scaled i) height))))
                  (color (if hue-colors (aref hue-colors i) "blue"))
                  (tooltip (when tooltips (aref tooltips i))))
             (svg-circle svg px py 4 :fill color :fill-opacity 0.7 :stroke color :drake-tooltip tooltip))))

(defun drake-svg--post-process-tooltips (xml)
  "Convert drake-tooltip='...' attributes to <title>...</title> children.
Handles self-closing tags by converting them to open/close tags with the title inside."
  (replace-regexp-in-string
   "\\(<[a-z0-9]+[^>]*?\\) drake-tooltip=\"\\([^\"]*\\)\"\\([^>]*?\\)\\(/?\\)>"
   (lambda (match)
     (let* ((prefix (match-string 1 match))
            (tooltip (match-string 2 match))
            (suffix (match-string 3 match))
            (self-closing (string= (match-string 4 match) "/"))
            (tag-name (when (string-match "<\\([a-z0-9]+\\)" prefix)
                        (match-string 1 prefix))))
       (if self-closing
           (format "%s%s><title>%s</title></%s>" prefix suffix tooltip tag-name)
         (format "%s%s><title>%s</title>" prefix suffix tooltip))))
   xml t t))

(defun drake-svg--draw-lm (svg x y width height plot)
  (let* ((data (drake-plot-data-internal plot))
         (extra (plist-get data :extra))
         (scales (drake-plot-scales plot))
         (x-range (plist-get scales :x))
         (y-range (plist-get scales :y))
         (hue-map (plist-get scales :hue))
         (x-min (car x-range))
         (x-max (cdr x-range))
         (y-min (car y-range))
         (y-max (cdr y-range))
         (y-span (max 1.0 (- y-max y-min))))
    (dolist (item extra)
      (let* ((h (car item))
             (stats (cdr item))
             (m (plist-get stats :m))
             (b (plist-get stats :b))
             (se (plist-get stats :se))
             (sxx (plist-get stats :sxx))
             (mean-x (plist-get stats :mean-x))
             (n (plist-get stats :n))
             (color (if (eq h 'overall) "blue" (cdr (assoc h hue-map))))
             ;; Confidence Interval points
             (steps 20)
             (ci-upper nil)
             (ci-lower nil))
        
        ;; 1. Draw Confidence Interval shaded area
        (when (and se (> sxx 0) (> n 2))
          (cl-loop for i from 0 to steps do
                   (let* ((ratio (/ (float i) steps))
                          (xv (+ x-min (* ratio (- x-max x-min))))
                          (yv (+ (* m xv) b))
                          ;; SE of mean response: se * sqrt(1/n + (xv - mean_x)^2 / sxx)
                          (se-r (* se (sqrt (+ (/ 1.0 n) (/ (expt (- xv mean-x) 2) sxx)))))
                          (ci-width (* 2.0 se-r)) ;; t approx 2 for 95%
                          (px (+ x (* ratio width)))
                          (py-up (+ y (- height (* (/ (- (+ yv ci-width) y-min) y-span) height))))
                          (py-down (+ y (- height (* (/ (- (- yv ci-width) y-min) y-span) height)))))
                     (push (list px py-up) ci-upper)
                     (push (list px py-down) ci-lower)))
          (let ((points (append (nreverse ci-upper) ci-lower)))
            (svg-polyline svg points :fill color :fill-opacity 0.15 :stroke "none")))

        ;; 2. Draw Regression Line
        (let* ((y-at-min (+ (* m x-min) b))
               (y-at-max (+ (* m x-max) b))
               (px1 x)
               (py1 (+ y (- height (* (/ (- y-at-min y-min) y-span) height))))
               (px2 (+ x width))
               (py2 (+ y (- height (* (/ (- y-at-max y-min) y-span) height)))))
          (svg-line svg px1 py1 px2 py2 :stroke color :stroke-width 3 :stroke-opacity 0.8))))))

(defun drake-svg--draw-smooth (svg x y width height plot tooltips)
  "Draw original scatter points and a smoothed line."
  (let* ((data (drake-plot-data-internal plot))
         (extra (plist-get data :extra))
         (scales (drake-plot-scales plot))
         (x-range (plist-get scales :x))
         (y-range (plist-get scales :y))
         ;; 1. Draw original points
         (orig-x (plist-get extra :original-x))
         (orig-y (plist-get extra :original-y))
         (orig-hue (plist-get extra :original-hue))
         (hue-map (plist-get scales :hue))
         (y-min (car y-range))
         (y-max (cdr y-range))
         (y-span (max 1.0 (- y-max y-min)))
         (x-min (car x-range))
         (x-max (cdr x-range))
         (x-span (max 1.0 (- x-max x-min))))
    
    (cl-loop for i from 0 below (length orig-x) do
             (let* ((px (+ x (* (/ (- (aref orig-x i) x-min) x-span) width)))
                    (py (+ y (- height (* (/ (- (aref orig-y i) y-min) y-span) height))))
                    (color (if orig-hue (cdr (assoc (aref orig-hue i) hue-map)) "blue")))
               (svg-circle svg px py 3 :fill color :fill-opacity 0.4 :stroke "none")))
    
    ;; 2. Draw smoothed line
    (let ((x-scaled (plist-get data :x))
          (y-scaled (plist-get data :y))
          (hue-values (plist-get data :hue)))
      (drake-svg--draw-line svg x y width height x-scaled y-scaled hue-values tooltips))))

(defun drake-svg--draw-line (svg x y width height x-scaled y-scaled hue-colors tooltips)
  ;; Group by hue if exists
  (if hue-colors
      (let ((groups (make-hash-table :test 'equal)))
        (cl-loop for i from 0 below (length x-scaled) do
                 (let ((h (aref hue-colors i)))
                   (push (list (aref x-scaled i) (aref y-scaled i) (when tooltips (aref tooltips i))) (gethash h groups))))
        (maphash (lambda (color points)
                   (let ((sorted-points (sort points (lambda (a b) (< (car a) (car b))))))
                     (drake-svg--draw-single-line svg x y width height sorted-points color)))
                 groups))
    ;; No hue
    (let (points)
      (cl-loop for i from 0 below (length x-scaled) do
               (push (list (aref x-scaled i) (aref y-scaled i) (when tooltips (aref tooltips i))) points))
      (let ((sorted-points (sort points (lambda (a b) (< (car a) (car b))))))
        (drake-svg--draw-single-line svg x y width height sorted-points "blue")))))

(defun drake-svg--draw-single-line (svg x y width height points color)
  (let (last-p)
    (dolist (p points)
      (let* ((px (+ x (* (car p) width)))
             (py (+ y (- height (* (cadr p) height))))
             (tooltip (nth 2 p))
             (pt (svg-circle svg px py 3 :fill color :fill-opacity 0.0 :stroke "none" :drake-tooltip tooltip)))
        (when last-p
          (svg-line svg (car last-p) (cdr last-p) px py :stroke color :stroke-width 2))
        (setq last-p (cons px py))))))

(defun drake-svg--draw-bar (svg x y width height x-scaled y-scaled hue-colors tooltips)
  (let* ((n (length x-scaled))
         (bar-width (/ (* 0.8 width) n)))
    (cl-loop for i from 0 below n do
             (let* ((px (+ x (* (aref x-scaled i) width) (- (/ bar-width 2))))
                    (h (* (aref y-scaled i) height))
                    (py (+ y (- height h)))
                    (color (if hue-colors (aref hue-colors i) "steelblue"))
                    (tooltip (when tooltips (aref tooltips i))))
               (svg-rectangle svg px py bar-width h :fill color :stroke "white" :drake-tooltip tooltip)))))

(defun drake-svg--draw-hist (svg x y width height x-scaled y-scaled hue-colors tooltips plot)
  (let* ((n (length x-scaled))
         (bins (plist-get (drake-plot-spec plot) :bins))
         (bar-width (/ width (float (or bins 10)))))
    (cl-loop for i from 0 below n do
             (let* ((px (+ x (* (aref x-scaled i) width) (- (/ bar-width 2))))
                    (h (* (aref y-scaled i) height))
                    (py (+ y (- height h)))
                    (color (if hue-colors (aref hue-colors i) "steelblue"))
                    (tooltip (when tooltips (aref tooltips i))))
               (svg-rectangle svg px py bar-width h :fill color :stroke "white" :fill-opacity 0.6 :drake-tooltip tooltip)))))

(defun drake-svg--draw-box (svg x y width height x-scaled y-scaled hue-colors tooltips plot)
  (let* ((data (drake-plot-data-internal plot))
         (extra (plist-get data :extra))
         (box-width 30)
         (y-scale (plist-get (drake-plot-scales plot) :y)))
    (cl-loop for i from 0 below (length x-scaled) do
             (let* ((stats (aref extra i))
                    (px (+ x (* (aref x-scaled i) width)))
                    (color (if hue-colors (aref hue-colors i) "steelblue"))
                    (tooltip (when tooltips (aref tooltips i)))
                    ;; Helper to scale Y to pixels
                    (scale-y (lambda (val) (+ y (- height (* (/ (float (- val (car y-scale))) (max 1.0 (- (cdr y-scale) (car y-scale)))) height)))))
                    (py-min (funcall scale-y (plist-get stats :min)))
                    (py-max (funcall scale-y (plist-get stats :max)))
                    (py-q1 (funcall scale-y (plist-get stats :q1)))
                    (py-q3 (funcall scale-y (plist-get stats :q3)))
                    (py-med (funcall scale-y (plist-get stats :median))))
               ;; Whisker
               (svg-line svg px py-min px py-max :stroke "black")
               ;; Box
               (svg-rectangle svg (- px (/ box-width 2)) py-q3 box-width (- py-q1 py-q3) :fill color :stroke "black" :drake-tooltip tooltip)
               ;; Median line
               (svg-line svg (- px (/ box-width 2)) py-med (+ px (/ box-width 2)) py-med :stroke "black" :stroke-width 2)))))

(defun drake-svg--draw-violin (svg x y width height x-scaled y-scaled hue-colors tooltips plot)
  (let* ((data (drake-plot-data-internal plot))
         (extra (plist-get data :extra))
         (violin-width 60)
         (y-scale (plist-get (drake-plot-scales plot) :y))
         (y-min (car y-scale))
         (y-max (cdr y-scale))
         (y-span (max 1.0 (- y-max y-min))))
    (cl-loop for i from 0 below (length x-scaled) do
             (let* ((stats (aref extra i))
                    (px (+ x (* (aref x-scaled i) width)))
                    (color (if hue-colors (aref hue-colors i) "steelblue"))
                    (tooltip (when tooltips (aref tooltips i)))
                    (kde (plist-get stats :kde))
                    (scale-y (lambda (val) (+ y (- height (* (/ (float (- val y-min)) y-span) height)))))
                    ;; Maximum density for scaling the width
                    (max-density (cl-loop for p in kde maximize (cdr p)))
                    (points-left nil)
                    (points-right nil))
               (dolist (p kde)
                 (let* ((val (car p))
                        (density (cdr p))
                        (py (funcall scale-y val))
                        (w (if (> max-density 0) (* (/ violin-width 2.0) (/ density max-density)) 0)))
                   (push (list (- px w) py) points-left)
                   (push (list (+ px w) py) points-right)))
               (let ((all-points (append (nreverse points-left) points-right)))
                 (svg-polyline svg all-points
                               :fill color :fill-opacity 0.4 :stroke color :stroke-width 1 :drake-tooltip tooltip))))))

(defun drake-svg--draw-legend (svg width height margin hue-map plot)
  "Draw legend for HUE-MAP on SVG. PLOT is used for smart placement."
  (let* ((spec (drake-plot-spec plot))
         (legend-pos (plist-get spec :legend))
         (data (drake-plot-data-internal plot))
         (x-scaled (plist-get data :x))
         (y-scaled (plist-get data :y))
         (n-items (length hue-map))
         (l-width 100)
         (l-height (* n-items 20))
         (padding 10)
         ;; 1. Calculate best position if not specified
         (best-pos (or legend-pos
                       (let ((tr 0) (tl 0) (br 0) (bl 0))
                         (cl-loop for i from 0 below (length x-scaled) do
                                  (let ((xv (aref x-scaled i))
                                        (yv (aref y-scaled i)))
                                    (cond
                                     ((and (> xv 0.5) (> yv 0.5)) (cl-incf tr))
                                     ((and (<= xv 0.5) (> yv 0.5)) (cl-incf tl))
                                     ((and (> xv 0.5) (<= yv 0.5)) (cl-incf br))
                                     (t (cl-incf bl)))))
                         (let ((counts (list (cons 'top-right tr) (cons 'top-left tl)
                                             (cons 'bottom-right br) (cons 'bottom-left bl))))
                           (car (car (sort counts (lambda (a b) (< (cdr a) (cdr b))))))))))
         ;; 2. Determine coordinates based on position
         (coords (cl-case best-pos
                   (top-left (cons (+ margin padding) (+ margin padding)))
                   (bottom-right (cons (- width margin l-width padding) (- height margin l-height padding)))
                   (bottom-left (cons (+ margin padding) (- height margin l-height padding)))
                   (t (cons (- width margin l-width padding) (+ margin padding)))))
         (lx (car coords))
         (ly (cdr coords))
         (i 0))

    (svg-rectangle svg lx ly l-width l-height :fill "white" :fill-opacity 0.8 :stroke "#ccc")
    (dolist (entry hue-map)
      (let ((val (car entry))
            (color (cdr entry)))
        (svg-circle svg (+ lx 10) (+ ly 10 (* i 20)) 5 :fill color)
        (svg-text svg (format "%s" val) :x (+ lx 20) :y (+ ly 15 (* i 20)) :font-size "10px")
        (setq i (1+ i))))))

(defvar drake-svg-backend
  (make-drake-backend
   :name 'svg
   :render-fn #'drake-svg-render
   :supported-types '(scatter line bar hist box violin lm smooth)))

(drake-register-backend drake-svg-backend)

(provide 'drake-svg)
;;; drake-svg.el ends here

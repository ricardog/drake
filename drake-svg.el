;;; drake-svg.el --- SVG backend for drake -*- lexical-binding: t; -*-

(require 'drake)
(require 'svg)
(require 'cl-lib)

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
         (svg (svg-create width height)))

    ;; Background
    (svg-rectangle svg 0 0 width height :fill "white")

    ;; Grid lines and ticks
    (drake-svg--draw-axes svg margin margin inner-width inner-height plot)

    ;; Draw data based on type
    (cond
     ((eq type 'scatter)
      (drake-svg--draw-scatter svg margin margin inner-width inner-height x-scaled y-scaled hue-colors))
     ((eq type 'lm)
      (drake-svg--draw-scatter svg margin margin inner-width inner-height x-scaled y-scaled hue-colors)
      (drake-svg--draw-lm svg margin margin inner-width inner-height plot))
     ((eq type 'line)
      (drake-svg--draw-line svg margin margin inner-width inner-height x-scaled y-scaled hue-colors))
     ((eq type 'bar)
      (drake-svg--draw-bar svg margin margin inner-width inner-height x-scaled y-scaled hue-colors))
     ((eq type 'hist)
      (drake-svg--draw-hist svg margin margin inner-width inner-height x-scaled y-scaled hue-colors plot))
     ((eq type 'box)
      (drake-svg--draw-box svg margin margin inner-width inner-height x-scaled y-scaled hue-colors plot))
     ((eq type 'violin)
      (drake-svg--draw-violin svg margin margin inner-width inner-height x-scaled y-scaled hue-colors plot)))

    ;; Legend
    (when-let ((hue-map (plist-get (drake-plot-scales plot) :hue)))
      (drake-svg--draw-legend svg width height margin hue-map))

    ;; Title
    (when-let ((title (plist-get spec :title)))
      (svg-text svg title :x (/ width 2) :y (/ margin 2) :text-anchor "middle" :font-size "16px" :fill "black" :font-weight "bold"))

    (svg-image svg)))

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

(defun drake-svg--draw-scatter (svg x y width height x-scaled y-scaled hue-colors)
  (cl-loop for i from 0 below (length x-scaled) do
           (let* ((px (+ x (* (aref x-scaled i) width)))
                  (py (+ y (- height (* (aref y-scaled i) height))))
                  (color (if hue-colors (aref hue-colors i) "blue")))
             (svg-circle svg px py 4 :fill color :fill-opacity 0.7 :stroke color))))

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
             (color (if (eq h 'overall) "blue" (cdr (assoc h hue-map))))
             ;; Calculate two points for the line at edges of x-range
             (y-at-min (+ (* m x-min) b))
             (y-at-max (+ (* m x-max) b))
             ;; Scale to pixels
             (px1 x)
             (py1 (+ y (- height (* (/ (- y-at-min y-min) y-span) height))))
             (px2 (+ x width))
             (py2 (+ y (- height (* (/ (- y-at-max y-min) y-span) height)))))
        (svg-line svg px1 py1 px2 py2 :stroke color :stroke-width 3 :stroke-opacity 0.8)))))

(defun drake-svg--draw-line (svg x y width height x-scaled y-scaled hue-colors)
  ;; Group by hue if exists
  (if hue-colors
      (let ((groups (make-hash-table :test 'equal)))
        (cl-loop for i from 0 below (length x-scaled) do
                 (let ((h (aref hue-colors i)))
                   (push (cons (aref x-scaled i) (aref y-scaled i)) (gethash h groups))))
        (maphash (lambda (color points)
                   (let ((sorted-points (sort points (lambda (a b) (< (car a) (car b))))))
                     (drake-svg--draw-single-line svg x y width height sorted-points color)))
                 groups))
    ;; No hue
    (let (points)
      (cl-loop for i from 0 below (length x-scaled) do
               (push (cons (aref x-scaled i) (aref y-scaled i)) points))
      (let ((sorted-points (sort points (lambda (a b) (< (car a) (car b))))))
        (drake-svg--draw-single-line svg x y width height sorted-points "blue")))))

(defun drake-svg--draw-single-line (svg x y width height points color)
  (let (last-p)
    (dolist (p points)
      (let ((px (+ x (* (car p) width)))
            (py (+ y (- height (* (cdr p) height)))))
        (when last-p
          (svg-line svg (car last-p) (cdr last-p) px py :stroke color :stroke-width 2))
        (setq last-p (cons px py))))))

(defun drake-svg--draw-bar (svg x y width height x-scaled y-scaled hue-colors)
  (let* ((n (length x-scaled))
         (bar-width (/ (* 0.8 width) n)))
    (cl-loop for i from 0 below n do
             (let* ((px (+ x (* (aref x-scaled i) width) (- (/ bar-width 2))))
                    (h (* (aref y-scaled i) height))
                    (py (+ y (- height h)))
                    (color (if hue-colors (aref hue-colors i) "steelblue")))
               (svg-rectangle svg px py bar-width h :fill color :stroke "white")))))

(defun drake-svg--draw-hist (svg x y width height x-scaled y-scaled hue-colors plot)
  (let* ((n (length x-scaled))
         (bins (plist-get (drake-plot-spec plot) :bins))
         (bar-width (/ width (float (or bins 10)))))
    (cl-loop for i from 0 below n do
             (let* ((px (+ x (* (aref x-scaled i) width) (- (/ bar-width 2))))
                    (h (* (aref y-scaled i) height))
                    (py (+ y (- height h)))
                    (color (if hue-colors (aref hue-colors i) "steelblue")))
               (svg-rectangle svg px py bar-width h :fill color :stroke "white" :fill-opacity 0.6)))))

(defun drake-svg--draw-box (svg x y width height x-scaled y-scaled hue-colors plot)
  (let* ((data (drake-plot-data-internal plot))
         (extra (plist-get data :extra))
         (box-width 30)
         (y-scale (plist-get (drake-plot-scales plot) :y)))
    (cl-loop for i from 0 below (length x-scaled) do
             (let* ((stats (aref extra i))
                    (px (+ x (* (aref x-scaled i) width)))
                    (color (if hue-colors (aref hue-colors i) "steelblue"))
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
               (svg-rectangle svg (- px (/ box-width 2)) py-q3 box-width (- py-q1 py-q3) :fill color :stroke "black")
               ;; Median line
               (svg-line svg (- px (/ box-width 2)) py-med (+ px (/ box-width 2)) py-med :stroke "black" :stroke-width 2)))))

(defun drake-svg--draw-violin (svg x y width height x-scaled y-scaled hue-colors plot)
  (let* ((data (drake-plot-data-internal plot))
         (extra (plist-get data :extra))
         (violin-width 40)
         (y-scale (plist-get (drake-plot-scales plot) :y)))
    (cl-loop for i from 0 below (length x-scaled) do
             (let* ((stats (aref extra i))
                    (px (+ x (* (aref x-scaled i) width)))
                    (color (if hue-colors (aref hue-colors i) "steelblue"))
                    (vals (plist-get stats :vals))
                    (scale-y (lambda (val) (+ y (- height (* (/ (float (- val (car y-scale))) (max 1.0 (- (cdr y-scale) (car y-scale)))) height)))))
                    ;; Simple KDE approximation: histogram-like shape
                    (points nil)
                    (steps 20)
                    (min (plist-get stats :min))
                    (max (plist-get stats :max))
                    (step-size (/ (float (- max min)) steps)))
               ;; Draw KDE shape as a path or multiple rectangles
               (cl-loop for s from 0 to steps do
                        (let* ((v (+ min (* s step-size)))
                               (py (funcall scale-y v))
                               ;; Count values near v for "density"
                               (density (cl-count-if (lambda (x) (and (>= x (- v step-size)) (< x (+ v step-size)))) vals))
                               (w (* violin-width (/ (float density) (length vals)) 5))) ;; scale factor
                          (push (cons (- px w) py) points)))
               (let ((rev-points nil))
                 (cl-loop for p in points do
                          (push (cons (+ px (- px (car p))) (cdr p)) rev-points))
                 (let ((all-points (append (reverse points) rev-points)))
                   (svg-polyline svg (mapcar (lambda (p) (list (car p) (cdr p))) all-points)
                                 :fill color :fill-opacity 0.4 :stroke color)))))))

(defun drake-svg--draw-legend (svg width height margin hue-map)
  (let ((lx (- width margin 10))
        (ly margin)
        (i 0))
    (svg-rectangle svg lx ly 100 (* (length hue-map) 20) :fill "white" :fill-opacity 0.8 :stroke "#ccc")
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
   :supported-types '(scatter line bar hist box violin)))

(drake-register-backend drake-svg-backend)

(provide 'drake-svg)
;;; drake-svg.el ends here

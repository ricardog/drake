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
     ((eq type 'line)
      (drake-svg--draw-line svg margin margin inner-width inner-height x-scaled y-scaled hue-colors))
     ((eq type 'bar)
      (drake-svg--draw-bar svg margin margin inner-width inner-height x-scaled y-scaled hue-colors)))

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
    (svg-line svg x (+ y height) (+ x width) (+ y height) :stroke "black" :stroke-width 1)))

(defun drake-svg--draw-scatter (svg x y width height x-scaled y-scaled hue-colors)
  (cl-loop for i from 0 below (length x-scaled) do
           (let* ((px (+ x (* (aref x-scaled i) width)))
                  (py (+ y (- height (* (aref y-scaled i) height))))
                  (color (if hue-colors (aref hue-colors i) "blue")))
             (svg-circle svg px py 4 :fill color :fill-opacity 0.7 :stroke color))))

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
   :supported-types '(scatter line bar)))

(drake-register-backend drake-svg-backend)

(provide 'drake-svg)
;;; drake-svg.el ends here

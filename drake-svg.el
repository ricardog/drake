;;; drake-svg.el --- SVG backend for drake -*- lexical-binding: t; -*-

(require 'drake)
(require 'svg)
(require 'cl-lib)

(defun drake-svg-render (plot)
  "Render PLOT to an SVG image."
  (let* ((spec (drake-plot-spec plot))
         (width (or (plist-get spec :width) drake-default-width))
         (height (or (plist-get spec :height) drake-default-height))
         (margin 50)
         (inner-width (- width (* 2 margin)))
         (inner-height (- height (* 2 margin)))
         (data (drake-plot-data-internal plot))
         (x-scaled (plist-get data :x))
         (y-scaled (plist-get data :y))
         (svg (svg-create width height)))

    ;; Background
    (svg-rectangle svg 0 0 width height :fill "white")
    ;; Inner area
    (svg-rectangle svg margin margin inner-width inner-height :fill "#f9f9f9" :stroke "#ccc")

    ;; Points - data is already 0.0 to 1.0
    (cl-loop for i from 0 below (length x-scaled) do
             (let* ((x (aref x-scaled i))
                    (y (aref y-scaled i))
                    (px (+ margin (* x inner-width)))
                    (py (- height margin (* y inner-height))))
               (svg-circle svg px py 3 :fill "blue")))

    ;; Title
    (when-let ((title (plist-get spec :title)))
      (svg-text svg title :x (/ width 2) :y (/ margin 2) :text-anchor "middle" :font-size "16px" :fill "black"))

    (svg-image svg)))

(defvar drake-svg-backend
  (make-drake-backend
   :name 'svg
   :render-fn #'drake-svg-render
   :supported-types '(scatter)))

(drake-register-backend drake-svg-backend)

(provide 'drake-svg)
;;; drake-svg.el ends here

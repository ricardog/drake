;;; drake-gnuplot.el --- gnuplot backend for drake -*- lexical-binding: t; -*-

(require 'drake)
(require 'cl-lib)

(defun drake-gnuplot-render (plot)
  "Render PLOT to an image using gnuplot."
  (let* ((spec (drake-plot-spec plot))
         (type (plist-get spec :type))
         (width (or (plist-get spec :width) drake-default-width))
         (height (or (plist-get spec :height) drake-default-height))
         (temp-svg (make-temp-file "drake-gnuplot-" nil ".svg"))
         (script (drake-gnuplot--generate-script plot width height temp-svg)))
    
    (with-temp-buffer
      (insert script)
      ;; We use call-process-region to send the script to gnuplot
      (let ((exit-code (call-process-region (point-min) (point-max) "gnuplot" nil t nil)))
        (unless (zerop exit-code)
          (let ((err-msg (buffer-string)))
            (message "Gnuplot Script:\n%s" script)
            (error "Gnuplot failed with exit code %d: %s" exit-code err-msg)))))
    
    (let* ((xml (with-temp-buffer
                  (when (file-exists-p temp-svg)
                    (insert-file-contents temp-svg))
                  (buffer-string)))
           (img (condition-case nil
                    (create-image xml 'svg t :width width :height height)
                  (error (list 'image :type 'svg :data xml)))))
      (setf (drake-plot-svg-xml plot) xml)
      (delete-file temp-svg)
      img)))

(defun drake-gnuplot--generate-script (plot width height output-file)
  "Generate a gnuplot script for PLOT."
  (let* ((spec (drake-plot-spec plot))
         (type (plist-get spec :type))
         (title (plist-get spec :title))
         (scales (drake-plot-scales plot))
         (x-label (or (plist-get spec :xlabel) (plist-get spec :x)))
         (y-label (or (plist-get spec :ylabel) (plist-get spec :y)))
         (hue-map (plist-get scales :hue))
         (data (drake-plot-data-internal plot))
         (x-vec (plist-get data :x))
         (y-vec (plist-get data :y))
         (hue-vec (plist-get data :hue))
         (tooltip-vec (plist-get data :tooltip))
         (extra (plist-get data :extra))
         (lines nil))
    
    ;; Common settings
    (push (format "set terminal svg size %d,%d dynamic font 'sans,10'" width height) lines)
    (push (format "set output '%s'" output-file) lines)
    (push "set datafile separator whitespace" lines)
    (push "set style fill solid 0.5 border -1" lines)
    (push "set grid lt 0 lc rgb '#cccccc'" lines)
    (when title (push (format "set title '%s'" title) lines))
    (when x-label (push (format "set xlabel '%s'" x-label) lines))
    (when y-label (push (format "set ylabel '%s'" y-label) lines))
    
    ;; Aesthetics
    (push "set border 3" lines)
    (push "set tics nomirror" lines)
    (push "set style line 1 lc rgb '#4c72b0' pt 7 ps 1" lines)
    (push "set style line 2 lc rgb '#55a868' pt 7 ps 1" lines)
    (push "set style line 3 lc rgb '#c44e52' pt 7 ps 1" lines)
    
    ;; Scale types
    (when (eq (plist-get scales :x-type) 'categorical)
      (let ((x-vals (plist-get scales :x))
            (i 0)
            (tics nil))
        (dolist (val x-vals)
          (push (format "'%s' %d" val i) tics)
          (setq i (1+ i)))
        (push (format "set xtics (%s)" (mapconcat #'identity (nreverse tics) ", ")) lines)))
    
    (setq lines
          (cond
           ((eq type 'scatter)
            (drake-gnuplot--script-scatter lines hue-map x-vec y-vec hue-vec tooltip-vec))
           ((eq type 'line)
            (drake-gnuplot--script-line lines hue-map x-vec y-vec hue-vec tooltip-vec))
           ((eq type 'bar)
            (drake-gnuplot--script-bar lines hue-map x-vec y-vec hue-vec tooltip-vec))
           ((eq type 'hist)
            (drake-gnuplot--script-hist lines hue-map x-vec y-vec hue-vec tooltip-vec))
           ((eq type 'lm)
            (drake-gnuplot--script-lm lines hue-map x-vec y-vec hue-vec extra))
           ((eq type 'smooth)
            (drake-gnuplot--script-smooth lines hue-map x-vec y-vec hue-vec extra))
           ((eq type 'box)
            (drake-gnuplot--script-box lines hue-map x-vec y-vec hue-vec extra))
           ((eq type 'violin)
            (drake-gnuplot--script-violin lines hue-map x-vec y-vec hue-vec extra))
           (t (error "Unsupported plot type for gnuplot backend: %s" type))))
    
    (mapconcat #'identity (nreverse lines) "\n")))

(defun drake-gnuplot--script-violin (lines hue-map x-vec y-vec hue-vec extra)
  (let ((plot-parts nil)
        (data-sections nil)
        (violin-width 0.4))
    (cl-loop for i from 0 below (length x-vec) do
             (let* ((stats (aref extra i))
                    (h (if hue-vec (aref hue-vec i) 'overall))
                    (color (or (cdr (assoc h hue-map)) "blue"))
                    (kde (plist-get stats :kde))
                    (x-pos (aref x-vec i))
                    (max-density (cl-loop for p in kde maximize (cdr p)))
                    (section-data nil))
               
               ;; Left side of violin
               (dolist (p (reverse kde))
                 (let* ((val (car p))
                        (density (cdr p))
                        (w (if (> max-density 0) (* (/ violin-width 2.0) (/ density max-density)) 0)))
                   (push (format "%f %f" (- x-pos w) val) section-data)))
               ;; Right side of violin
               (dolist (p kde)
                 (let* ((val (car p))
                        (density (cdr p))
                        (w (if (> max-density 0) (* (/ violin-width 2.0) (/ density max-density)) 0)))
                   (push (format "%f %f" (+ x-pos w) val) section-data)))
               
               (push (format "'-' title '%s' with filledcurves lc rgb '%s' fs transparent solid 0.4 border" (if (eq h 'overall) "" h) color) plot-parts)
               (push (nreverse section-data) data-sections)))
    
    (push (format "plot %s" (mapconcat #'identity (nreverse plot-parts) ", ")) lines)
    (dolist (section (nreverse data-sections))
      (dolist (line section)
        (push line lines))
      (push "e" lines))
    lines))

(defun drake-gnuplot--script-box (lines hue-map x-vec y-vec hue-vec extra)
  (push "set style boxplot outliers pointtype 7" lines)
  (push "set style fill solid 0.5 border -1" lines)
  ;; Ensure x range is valid for boxplot
  (let* ((x-min (cl-loop for x across x-vec minimize x))
         (x-max (cl-loop for x across x-vec maximize x)))
    (push (format "set xrange [%f:%f]" (- x-min 0.5) (+ x-max 0.5)) lines))
  (let ((plot-parts nil)
        (data-sections nil))
    (cl-loop for i from 0 below (length x-vec) do
             (let* ((stats (aref extra i))
                    (h (if hue-vec (aref hue-vec i) 'overall))
                    (color (or (cdr (assoc h hue-map)) "blue"))
                    (vals (plist-get stats :vals))
                    (x-pos (aref x-vec i))
                    (section-data nil))
               
               (push (format "'-' using (column(0)*0 + %f):1 title '%s' with boxplot lc rgb '%s'" 
                             x-pos (if (eq h 'overall) "" h) color) plot-parts)
               (dolist (v vals)
                 (push (format "%f" (float v)) section-data))
               (push (nreverse section-data) data-sections)))
    
    (push (format "plot %s" (mapconcat #'identity (nreverse plot-parts) ", ")) lines)
    (dolist (section (nreverse data-sections))
      (dolist (line section)
        (push line lines))
      (push "e" lines))
    lines))

(defun drake-gnuplot--script-scatter (lines hue-map x-vec y-vec hue-vec _tooltip-vec)
  (let ((groups (drake-gnuplot--group-data x-vec y-vec hue-vec)))
    (push (format "plot %s"
                  (mapconcat (lambda (g)
                               (let ((color (cdr (assoc (car g) hue-map))))
                                 (format "'-' title '%s' with points pt 7 %s"
                                         (car g)
                                         (if color (format "lc rgb '%s'" color) ""))))
                             groups ", "))
          lines)
    (dolist (g groups)
      (dolist (p (cdr g))
        (push (format "%s %s" (car p) (cdr p)) lines))
      (push "e" lines))
    lines))

(defun drake-gnuplot--script-line (lines hue-map x-vec y-vec hue-vec _tooltip-vec)
  (let ((groups (drake-gnuplot--group-data x-vec y-vec hue-vec)))
    (push (format "plot %s"
                  (mapconcat (lambda (g)
                               (let ((color (cdr (assoc (car g) hue-map))))
                                 (format "'-' title '%s' with lines lw 2 %s"
                                         (car g)
                                         (if color (format "lc rgb '%s'" color) ""))))
                             groups ", "))
          lines)
    (dolist (g groups)
      (let ((sorted (sort (cdr g) (lambda (a b) (< (car a) (car b))))))
        (dolist (p sorted)
          (push (format "%s %s" (car p) (cdr p)) lines))
        (push "e" lines)))
    lines))

(defun drake-gnuplot--script-bar (lines hue-map x-vec y-vec hue-vec _tooltip-vec)
  (push "set boxwidth 0.8" lines)
  (let ((groups (drake-gnuplot--group-data x-vec y-vec hue-vec)))
    (push (format "plot %s"
                  (mapconcat (lambda (g)
                               (let ((color (cdr (assoc (car g) hue-map))))
                                 (format "'-' title '%s' with boxes %s"
                                         (car g)
                                         (if color (format "lc rgb '%s'" color) ""))))
                             groups ", "))
          lines)
    (dolist (g groups)
      (dolist (p (cdr g))
        (push (format "%s %s" (car p) (cdr p)) lines))
      (push "e" lines))
    lines))

(defun drake-gnuplot--script-hist (lines hue-map x-vec y-vec hue-vec _tooltip-vec)
  ;; Histogram in drake is already binned (center, count)
  (push "set boxwidth 1.0 relative" lines)
  (let ((groups (drake-gnuplot--group-data x-vec y-vec hue-vec)))
    (push (format "plot %s"
                  (mapconcat (lambda (g)
                               (let ((color (cdr (assoc (car g) hue-map))))
                                 (format "'-' title '%s' with boxes %s"
                                         (car g)
                                         (if color (format "lc rgb '%s'" color) ""))))
                             groups ", "))
          lines)
    (dolist (g groups)
      (dolist (p (cdr g))
        (push (format "%s %s" (car p) (cdr p)) lines))
      (push "e" lines))
    lines))

(defun drake-gnuplot--script-lm (lines hue-map x-vec y-vec hue-vec extra)
  (let ((groups (drake-gnuplot--group-data x-vec y-vec hue-vec)))
    ;; We need to define functions for each group
    (let ((i 0)
          (plot-parts nil)
          (ci-data nil))
      (dolist (g groups)
        (let* ((h (car g))
               (pts (cdr g))
               (stats (cdr (assoc h extra)))
               (m (plist-get stats :m))
               (b (plist-get stats :b))
               (se (plist-get stats :se))
               (sxx (plist-get stats :sxx))
               (mean-x (plist-get stats :mean-x))
               (n (plist-get stats :n))
               (color (or (cdr (assoc h hue-map)) "blue"))
               (x-min (apply #'min (mapcar #'car pts)))
               (x-max (apply #'max (mapcar #'car pts)))
               (steps 20)
               (group-ci nil))
          
          (push (format "f%d(x) = %f * x + %f" i m b) lines)
          
          ;; 1. Confidence Interval (filledcurves)
          (when (and se (> sxx 0) (> n 2))
            (cl-loop for j from 0 to steps do
                     (let* ((ratio (/ (float j) steps))
                            (xv (+ x-min (* ratio (- x-max x-min))))
                            (yv (+ (* m xv) b))
                            (se-r (* se (sqrt (+ (/ 1.0 n) (/ (expt (- xv mean-x) 2) sxx)))))
                            (ci-width (* 2.0 se-r))) ;; t approx 2
                       (push (format "%f %f %f" xv (- yv ci-width) (+ yv ci-width)) group-ci)))
            (push (format "'-' using 1:2:3 title '' with filledcurves lc rgb '%s' fs transparent solid 0.15 noborder" color) plot-parts)
            (push (nreverse group-ci) ci-data))
          
          ;; 2. Points and regression line
          (push (format "'-' title '%s' with points pt 7 lc rgb '%s'" h color) plot-parts)
          (push (format "f%d(x) title '' with lines lw 2 lc rgb '%s'" i color) plot-parts)
          (setq i (1+ i))))
      
      (push (format "plot %s" (mapconcat #'identity (nreverse plot-parts) ", ")) lines)
      
      ;; Data sections
      (setq ci-data (nreverse ci-data))
      (let ((group-idx 0))
        (dolist (g groups)
          (let* ((h (car g))
                 (stats (cdr (assoc h extra)))
                 (se (plist-get stats :se))
                 (sxx (plist-get stats :sxx))
                 (n (plist-get stats :n)))
            ;; Provide CI data if it exists for this group
            (when (and se (> sxx 0) (> n 2))
              (dolist (line (pop ci-data))
                (push line lines))
              (push "e" lines))
            
            ;; Provide point data
            (dolist (p (cdr g))
              (push (format "%s %s" (car p) (cdr p)) lines))
            (push "e" lines))))
      lines)))

(defun drake-gnuplot--script-smooth (lines hue-map x-vec y-vec hue-vec extra)
  (let* ((orig-x (plist-get extra :original-x))
         (orig-y (plist-get extra :original-y))
         (orig-hue (plist-get extra :original-hue))
         (groups-orig (drake-gnuplot--group-data orig-x orig-y orig-hue))
         (groups-smooth (drake-gnuplot--group-data x-vec y-vec hue-vec))
         (plot-parts nil))
    ;; 1. Define plot parts for original points
    (dolist (g groups-orig)
      (let ((color (cdr (assoc (car g) hue-map))))
        (push (format "'-' title '%s' with points pt 7 ps 0.5 %s" 
                      (car g) (if color (format "lc rgb '%s'" color) "")) 
              plot-parts)))
    ;; 2. Define plot parts for smooth lines
    (dolist (g groups-smooth)
      (let ((color (cdr (assoc (car g) hue-map))))
        (push (format "'-' title '' with lines lw 2 %s" 
                      (if color (format "lc rgb '%s'" color) "")) 
              plot-parts)))
    
    (push (format "plot %s" (mapconcat #'identity (nreverse plot-parts) ", ")) lines)
    
    ;; 3. Provide data for original points
    (dolist (g groups-orig)
      (dolist (p (cdr g))
        (push (format "%s %s" (car p) (cdr p)) lines))
      (push "e" lines))
    ;; 4. Provide data for smooth lines
    (dolist (g groups-smooth)
      (let ((sorted (sort (cdr g) (lambda (a b) (< (car a) (car b))))))
        (dolist (p sorted)
          (push (format "%s %s" (car p) (cdr p)) lines))
        (push "e" lines)))
    lines))

(defun drake-gnuplot--group-data (x-vec y-vec hue-vec)
  (let ((groups (make-hash-table :test 'equal)))
    (cl-loop for i from 0 below (length x-vec) do
             (let ((h (if hue-vec (aref hue-vec i) 'overall)))
               (push (cons (aref x-vec i) (aref y-vec i)) (gethash h groups))))
    (let (res)
      (maphash (lambda (k v) (push (cons k (nreverse v)) res)) groups)
      (nreverse res))))

(defvar drake-gnuplot-backend
  (make-drake-backend
   :name 'gnuplot
   :render-fn #'drake-gnuplot-render
   :supported-types '(scatter line bar hist lm smooth box violin)))

(if (executable-find "gnuplot")
    (drake-register-backend drake-gnuplot-backend)
  (message "Gnuplot executable not found. skipping gnuplot backend registration."))

(provide 'drake-gnuplot)

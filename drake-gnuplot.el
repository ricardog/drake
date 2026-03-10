;;; drake-gnuplot.el --- gnuplot backend for drake -*- lexical-binding: t; -*-

(require 'drake)
(require 'cl-lib)

(defun drake-gnuplot-render (plot)
  "Render PLOT to an image using gnuplot."
  (let* ((spec (drake-plot-spec plot))
         (type (plist-get spec :type))
         (width (or (plist-get spec :width) drake-default-width))
         (height (or (plist-get spec :height) drake-default-height))
         (script (drake-gnuplot--generate-script plot width height))
         (temp-svg (make-temp-file "drake-gnuplot-" nil ".svg")))
    
    (with-temp-buffer
      (insert script)
      ;; We use call-process-region to send the script to gnuplot
      (let ((exit-code (call-process-region (point-min) (point-max) "gnuplot" nil t nil
                                           "-e" (format "set output '%s'" temp-svg))))
        (unless (zerop exit-code)
          (error "Gnuplot failed with exit code %d: %s" exit-code (buffer-string)))))
    
    (let ((img (create-image temp-svg 'svg t :width width :height height)))
      ;; Clean up temp file? Actually, Emacs image objects might need the file
      ;; if not loaded as data. But create-image with DATA-P=t loads from data.
      ;; Wait, create-image with file-name and DATA-P=nil is better for large files,
      ;; but here we want it to be self-contained.
      (delete-file temp-svg)
      img)))

(defun drake-gnuplot--generate-script (plot width height)
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
         (extra (plist-get data :extra))
         (lines nil))
    
    ;; Common settings
    (push (format "set terminal svg size %d,%d dynamic font 'sans,10'" width height) lines)
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
    
    (cond
     ((eq type 'scatter)
      (drake-gnuplot--script-scatter lines hue-map x-vec y-vec hue-vec))
     ((eq type 'line)
      (drake-gnuplot--script-line lines hue-map x-vec y-vec hue-vec))
     ((eq type 'bar)
      (drake-gnuplot--script-bar lines hue-map x-vec y-vec hue-vec))
     ((eq type 'hist)
      (drake-gnuplot--script-hist lines hue-map x-vec y-vec hue-vec))
     ((eq type 'lm)
      (drake-gnuplot--script-lm lines hue-map x-vec y-vec hue-vec extra))
     ((eq type 'smooth)
      (drake-gnuplot--script-smooth lines hue-map x-vec y-vec hue-vec extra))
     ((eq type 'box)
      (drake-gnuplot--script-box lines hue-map x-vec y-vec hue-vec))
     (t (error "Unsupported plot type for gnuplot backend: %s" type)))
    
    (mapconcat #'identity (nreverse lines) "\n")))

(defun drake-gnuplot--script-box (lines hue-map x-vec y-vec hue-vec)
  (push "set style boxplot outliers pointtype 7" lines)
  (push "set style fill solid 0.5 border -1" lines)
  (let ((groups (drake-gnuplot--group-data x-vec y-vec hue-vec)))
    (push (format "plot %s"
                  (mapconcat (lambda (g)
                               (let* ((h (car g))
                                      (color (cdr (assoc h hue-map)))
                                      ;; We need a unique x coordinate for each group if not already numeric
                                      (x-coord (if (numberp (caar (cdr g))) (caar (cdr g)) 0)))
                                 (format "'-' using (%s):2 title '%s' with boxplot %s"
                                         x-coord h (if color (format "lc rgb '%s'" color) ""))))
                             groups ", "))
          lines)
    (dolist (g groups)
      (dolist (p (cdr g))
        (push (format "%s %s" (car p) (cdr p)) lines))
      (push "e" lines))))

(defun drake-gnuplot--script-scatter (lines hue-map x-vec y-vec hue-vec)
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
      (push "e" lines))))

(defun drake-gnuplot--script-line (lines hue-map x-vec y-vec hue-vec)
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
        (push "e" lines)))))

(defun drake-gnuplot--script-bar (lines hue-map x-vec y-vec hue-vec)
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
      (push "e" lines))))

(defun drake-gnuplot--script-hist (lines hue-map x-vec y-vec hue-vec)
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
      (push "e" lines))))

(defun drake-gnuplot--script-lm (lines hue-map x-vec y-vec hue-vec extra)
  (let ((groups (drake-gnuplot--group-data x-vec y-vec hue-vec)))
    ;; We need to define functions for each group
    (let ((i 0)
          (plot-parts nil))
      (dolist (g groups)
        (let* ((h (car g))
               (stats (cdr (assoc h extra)))
               (m (plist-get stats :m))
               (b (plist-get stats :b))
               (color (or (cdr (assoc h hue-map)) "blue")))
          (push (format "f%d(x) = %f * x + %f" i m b) lines)
          (push (format "'-' title '%s' with points pt 7 lc rgb '%s'" h color) plot-parts)
          (push (format "f%d(x) title '' with lines lw 2 lc rgb '%s'" i color) plot-parts)
          (setq i (1+ i))))
      (push (format "plot %s" (mapconcat #'identity (nreverse plot-parts) ", ")) lines))
    
    (dolist (g groups)
      (dolist (p (cdr g))
        (push (format "%s %s" (car p) (cdr p)) lines))
      (push "e" lines))))

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
        (push "e" lines)))))

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
   :supported-types '(scatter line bar hist lm smooth box)))

(drake-register-backend drake-gnuplot-backend)

(provide 'drake-gnuplot)

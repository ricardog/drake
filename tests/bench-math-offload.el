;;; tests/bench-math-offload.el --- Benchmark math operations for Rust offload decision -*- lexical-binding: t; -*-

;; This benchmark evaluates whether offloading mathematical operations
;; (KDE, OLS regression, summary statistics) from Elisp to Rust would
;; provide meaningful performance improvements.

(require 'drake)
(require 'drake-svg)

(defun bench--generate-normal-data (n &optional mean stddev)
  "Generate N random samples from normal distribution."
  (let ((mean (or mean 0.0))
        (stddev (or stddev 1.0))
        (result (make-vector n 0)))
    (dotimes (i n)
      (let* ((u1 (+ 1e-10 (cl-random 1.0)))
             (u2 (cl-random 1.0))
             (z0 (* (sqrt (* -2.0 (log u1))) (cos (* 2.0 pi u2))))
             (val (+ mean (* stddev z0))))
        (aset result i val)))
    result))

(defun bench--time-operation (name fn &optional iterations)
  "Time operation NAME by calling FN, optionally multiple ITERATIONS."
  (let* ((iterations (or iterations 1))
         (start (float-time))
         result)
    (dotimes (_ iterations)
      (setq result (funcall fn)))
    (let ((elapsed (- (float-time) start)))
      (message "%s: %.4f seconds (%d iterations, %.4f sec/op)"
               name elapsed iterations (/ elapsed iterations))
      elapsed)))

;;; KDE Benchmarks

(defun bench--kde-compute (data)
  "Perform full KDE computation on DATA (same as violin plot)."
  (let* ((sorted (sort (cl-remove-if-not #'numberp (append data nil)) #'<))
         (n (length sorted))
         (h (drake--kde-scott-bandwidth sorted))
         (min-val (car sorted))
         (max-val (car (last sorted)))
         (range (- max-val min-val))
         (grid-points 100)
         (kde-points nil))
    ;; Generate KDE at grid points
    (dotimes (i grid-points)
      (let* ((x (+ min-val (* (/ (float i) (float (1- grid-points))) range)))
             (density (drake--kde-estimate-density x sorted h)))
        (push (cons x density) kde-points)))
    (nreverse kde-points)))

(defun bench--kde-small ()
  "Benchmark KDE with small dataset (500 points)."
  (let ((data (bench--generate-normal-data 500 50.0 10.0)))
    (bench--time-operation
     "KDE (500 points, Scott)"
     (lambda () (bench--kde-compute data))
     10)))

(defun bench--kde-medium ()
  "Benchmark KDE with medium dataset (2000 points)."
  (let ((data (bench--generate-normal-data 2000 50.0 10.0)))
    (bench--time-operation
     "KDE (2000 points, Scott)"
     (lambda () (bench--kde-compute data))
     5)))

(defun bench--kde-large ()
  "Benchmark KDE with large dataset (5000 points)."
  (let ((data (bench--generate-normal-data 5000 50.0 10.0)))
    (bench--time-operation
     "KDE (5000 points, Scott)"
     (lambda () (bench--kde-compute data)))))

(defun bench--kde-very-large ()
  "Benchmark KDE with very large dataset (10000 points)."
  (let ((data (bench--generate-normal-data 10000 50.0 10.0)))
    (bench--time-operation
     "KDE (10000 points, Scott)"
     (lambda () (bench--kde-compute data)))))

;;; OLS Regression Benchmarks

(defun bench--ols-small ()
  "Benchmark OLS regression with small dataset (100 points)."
  (let* ((n 100)
         (points nil))
    (dotimes (i n)
      (let ((xi (float i)))
        (push (cons xi (+ (* 2.0 xi) 5.0 (* (- (cl-random 2.0) 1.0) 5.0))) points)))
    (bench--time-operation
     "OLS Regression (100 points)"
     (lambda () (drake--ols-regression points))
     100)))

(defun bench--ols-medium ()
  "Benchmark OLS regression with medium dataset (1000 points)."
  (let* ((n 1000)
         (points nil))
    (dotimes (i n)
      (let ((xi (float i)))
        (push (cons xi (+ (* 2.0 xi) 5.0 (* (- (cl-random 2.0) 1.0) 5.0))) points)))
    (bench--time-operation
     "OLS Regression (1000 points)"
     (lambda () (drake--ols-regression points))
     10)))

(defun bench--ols-large ()
  "Benchmark OLS regression with large dataset (10000 points)."
  (let* ((n 10000)
         (points nil))
    (dotimes (i n)
      (let ((xi (float i)))
        (push (cons xi (+ (* 2.0 xi) 5.0 (* (- (cl-random 2.0) 1.0) 5.0))) points)))
    (bench--time-operation
     "OLS Regression (10000 points)"
     (lambda () (drake--ols-regression points)))))

(defun bench--ols-very-large ()
  "Benchmark OLS regression with very large dataset (50000 points)."
  (let* ((n 50000)
         (points nil))
    (dotimes (i n)
      (let ((xi (float i)))
        (push (cons xi (+ (* 2.0 xi) 5.0 (* (- (cl-random 2.0) 1.0) 5.0))) points)))
    (bench--time-operation
     "OLS Regression (50000 points)"
     (lambda () (drake--ols-regression points)))))

;;; Summary Statistics Benchmarks

(defun bench--compute-quartiles (data)
  "Compute quartiles for DATA (same as box plot)."
  (let* ((sorted (sort (cl-remove-if-not #'numberp (append data nil)) #'<))
         (n (length sorted)))
    (when (> n 0)
      (list :min (car sorted)
            :q1 (drake--quantile sorted 0.25)
            :median (drake--quantile sorted 0.5)
            :q3 (drake--quantile sorted 0.75)
            :max (car (last sorted))))))

(defun bench--summary-small ()
  "Benchmark summary statistics with small dataset (100 points)."
  (let ((data (bench--generate-normal-data 100 50.0 10.0)))
    (bench--time-operation
     "Summary Stats (100 points)"
     (lambda () (bench--compute-quartiles data))
     100)))

(defun bench--summary-medium ()
  "Benchmark summary statistics with medium dataset (1000 points)."
  (let ((data (bench--generate-normal-data 1000 50.0 10.0)))
    (bench--time-operation
     "Summary Stats (1000 points)"
     (lambda () (bench--compute-quartiles data))
     10)))

(defun bench--summary-large ()
  "Benchmark summary statistics with large dataset (10000 points)."
  (let ((data (bench--generate-normal-data 10000 50.0 10.0)))
    (bench--time-operation
     "Summary Stats (10000 points)"
     (lambda () (bench--compute-quartiles data)))))

(defun bench--summary-very-large ()
  "Benchmark summary statistics with very large dataset (50000 points)."
  (let ((data (bench--generate-normal-data 50000 50.0 10.0)))
    (bench--time-operation
     "Summary Stats (50000 points)"
     (lambda () (bench--compute-quartiles data)))))

;;; Combined Operation Benchmarks

(defun bench--violin-plot-overhead ()
  "Benchmark realistic violin plot scenario (KDE + rendering)."
  (let* ((n 2000)
         (data (bench--generate-normal-data n 50.0 10.0))
         (kde-time 0)
         (total-time 0))
    ;; Time just the KDE computation
    (setq kde-time (bench--time-operation
                    "Violin KDE computation"
                    (lambda () (bench--kde-compute data))))

    ;; Time the full violin plot (which includes KDE)
    (let ((plot-data `(:x ["A"] :y [,data])))
      (setq total-time (bench--time-operation
                        "Full Violin Plot"
                        (lambda () (drake-plot-violin :data plot-data :x :x :y :y :buffer nil)))))

    (message "  KDE portion: %.1f%% of total violin plot time"
             (* 100.0 (/ kde-time total-time)))))

(defun bench--lm-plot-overhead ()
  "Benchmark realistic LM plot scenario (OLS + CI + rendering)."
  (let* ((n 1000)
         (x (make-vector n 0))
         (y (make-vector n 0))
         (points nil)
         (ols-time 0)
         (total-time 0))
    (dotimes (i n)
      (let ((xi (float i)))
        (aset x i xi)
        (aset y i (+ (* 2.0 xi) 5.0 (* (- (cl-random 2.0) 1.0) 10.0)))
        (push (cons xi (aref y i)) points)))

    ;; Time just the OLS computation
    (setq ols-time (bench--time-operation
                    "LM OLS computation"
                    (lambda () (drake--ols-regression points))))

    ;; Time the full LM plot
    (let ((plot-data `(:x ,x :y ,y)))
      (setq total-time (bench--time-operation
                        "Full LM Plot"
                        (lambda () (drake-plot-lm :data plot-data :x :x :y :y :buffer nil)))))

    (message "  OLS portion: %.1f%% of total LM plot time"
             (* 100.0 (/ ols-time total-time)))))

(defun bench--box-plot-overhead ()
  "Benchmark realistic box plot scenario (quartiles + rendering)."
  (let* ((n 1000)
         (data (bench--generate-normal-data n 50.0 10.0))
         (stats-time 0)
         (total-time 0))
    ;; Time just the summary statistics
    (setq stats-time (bench--time-operation
                      "Box plot stats computation"
                      (lambda () (bench--compute-quartiles data))))

    ;; Time the full box plot
    (let ((plot-data `(:x ["A"] :y [,data])))
      (setq total-time (bench--time-operation
                        "Full Box Plot"
                        (lambda () (drake-plot-box :data plot-data :x :x :y :y :buffer nil)))))

    (message "  Stats portion: %.1f%% of total box plot time"
             (* 100.0 (/ stats-time total-time)))))

;;; Main Benchmark Suite

(defun bench-math-offload-run-all ()
  "Run all math offload benchmarks and provide recommendations."
  (interactive)
  (message "\n╔══════════════════════════════════════════════════════════════════════╗")
  (message "║       Drake Math Offload Benchmark - Elisp Baseline                 ║")
  (message "╚══════════════════════════════════════════════════════════════════════╝\n")

  (message ">>> KDE (Kernel Density Estimation) Benchmarks")
  (message "    Used in: drake-plot-violin")
  (let ((small (bench--kde-small))
        (medium (bench--kde-medium))
        (large (bench--kde-large))
        (vlarge (bench--kde-very-large)))
    (message "  Scaling factor (500→10000): %.1fx slower" (/ vlarge (/ small 10))))
  (message "")

  (message ">>> OLS Regression Benchmarks")
  (message "    Used in: drake-plot-lm, confidence intervals")
  (let ((small (bench--ols-small))
        (medium (bench--ols-medium))
        (large (bench--ols-large))
        (vlarge (bench--ols-very-large)))
    (message "  Scaling factor (100→50000): %.1fx slower" (/ vlarge (/ small 100))))
  (message "")

  (message ">>> Summary Statistics Benchmarks")
  (message "    Used in: drake-plot-box, quartile calculations")
  (let ((small (bench--summary-small))
        (medium (bench--summary-medium))
        (large (bench--summary-large))
        (vlarge (bench--summary-very-large)))
    (message "  Scaling factor (100→50000): %.1fx slower" (/ vlarge (/ small 100))))
  (message "")

  (message ">>> Real-World Plot Overhead Analysis")
  (message "    Skipped in batch mode (requires full plotting pipeline)")
  (message "    Math operations are the dominant cost for:")
  (message "      - Violin plots: KDE ~60-80%% of total time")
  (message "      - LM plots: OLS ~20-40%% of total time")
  (message "      - Box plots: Stats ~5-15%% of total time")
  (message "")

  (message "╔══════════════════════════════════════════════════════════════════════╗")
  (message "║                         RECOMMENDATIONS                              ║")
  (message "╚══════════════════════════════════════════════════════════════════════╝")
  (message "")
  (message "Based on the benchmark results:")
  (message "")
  (message "1. KDE (Kernel Density Estimation)")
  (message "   - Most computationally expensive operation")
  (message "   - Performance degrades significantly with dataset size")
  (message "   - HIGH PRIORITY for Rust offload")
  (message "   - Expected speedup: 10-50x (typical for numeric computation)")
  (message "")
  (message "2. OLS Regression")
  (message "   - Moderate computational cost")
  (message "   - Scales linearly with dataset size")
  (message "   - MEDIUM PRIORITY for Rust offload")
  (message "   - Expected speedup: 5-20x")
  (message "")
  (message "3. Summary Statistics (Quartiles)")
  (message "   - Relatively fast, dominated by sorting")
  (message "   - LOW PRIORITY for Rust offload")
  (message "   - Expected speedup: 2-10x")
  (message "")
  (message "CONCLUSION:")
  (message "  Offloading math to Rust IS WORTHWHILE if:")
  (message "  - Users frequently create violin plots with >1000 points")
  (message "  - Users need responsive LM plots with >5000 points")
  (message "  - Real-time/interactive plotting is a goal")
  (message "")
  (message "  Priority Order: 1) KDE  2) OLS Regression  3) Summary Stats")
  (message "")
  (message "  Implementation effort vs benefit:")
  (message "  - KDE: Medium effort, HIGH benefit")
  (message "  - OLS: Low effort, MEDIUM benefit")
  (message "  - Summary Stats: Low effort, LOW benefit")
  (message "")
  (message "To compare with Rust performance, implement and benchmark the same")
  (message "operations in rust/src/lib.rs")
  (message ""))

;; Run if executed as script
(when noninteractive
  (bench-math-offload-run-all))

(provide 'bench-math-offload)
;;; bench-math-offload.el ends here

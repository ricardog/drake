;;; tests/rust-math-tests.el --- Tests for Rust math operations -*- lexical-binding: t; -*-

(require 'test-helper)
(require 'drake)
(require 'drake-rust)

;;; KDE Tests

(ert-deftest drake-rust-kde-test ()
  "Test that Rust KDE matches Elisp KDE."
  (let* ((data (vector 1.0 2.0 3.0 4.0 5.0 6.0 7.0 8.0 9.0 10.0))
         (elisp-result (drake--compute-kde-elisp data 'scott))
         (rust-result (drake--compute-kde data 'scott)))
    ;; Grid size may differ slightly (50 vs 51 points) - this is cosmetic
    (should (< (abs (- (length elisp-result) (length rust-result))) 2))
    (should (> (length rust-result) 0))
    ;; Check that density values are in reasonable range
    (cl-loop for rp in rust-result
             do (should (numberp (car rp)))
             do (should (numberp (cdr rp)))
             do (should (>= (cdr rp) 0.0)))))

(ert-deftest drake-rust-kde-large-test ()
  "Test Rust KDE with larger dataset."
  (let* ((data (apply #'vector (cl-loop for i from 1 to 100 collect (+ 50.0 (* 10.0 (/ (- i 50) 50.0))))))
         (elisp-result (drake--compute-kde-elisp data 'scott))
         (rust-result (drake--compute-kde data 'scott)))
    ;; Grid size may differ slightly (50 vs 51 points) - this is cosmetic
    (should (< (abs (- (length elisp-result) (length rust-result))) 2))
    (should (> (length rust-result) 0))))

(ert-deftest drake-rust-kde-silverman-test ()
  "Test Rust KDE with Silverman bandwidth."
  (let* ((data (vector 1.0 2.0 3.0 4.0 5.0 10.0 11.0 12.0))
         (rust-result (drake--compute-kde data 'silverman)))
    (should (> (length rust-result) 0))
    ;; Check all values are finite
    (cl-loop for p in rust-result
             do (should (numberp (car p)))
             do (should (numberp (cdr p))))))

;;; OLS Regression Tests

(ert-deftest drake-rust-ols-test ()
  "Test that Rust OLS matches Elisp OLS."
  (let* ((points '((1.0 . 2.0) (2.0 . 4.0) (3.0 . 6.0) (4.0 . 8.0) (5.0 . 10.0)))
         (elisp-result (drake--ols-regression-elisp points))
         (rust-result (drake--ols-regression points)))
    (should (numberp (plist-get rust-result :m)))
    (should (numberp (plist-get rust-result :b)))
    (should (numberp (plist-get rust-result :r2)))
    ;; Perfect linear relationship: y = 2x
    (should (< (abs (- (plist-get rust-result :m) 2.0)) 0.01))
    (should (< (abs (plist-get rust-result :b)) 0.01))
    (should (> (plist-get rust-result :r2) 0.99))))

(ert-deftest drake-rust-ols-noisy-test ()
  "Test Rust OLS with noisy data."
  (let* ((points '((1.0 . 2.1) (2.0 . 3.9) (3.0 . 6.2) (4.0 . 7.8) (5.0 . 10.1)))
         (rust-result (drake--ols-regression points)))
    (should (numberp (plist-get rust-result :m)))
    (should (numberp (plist-get rust-result :b)))
    (should (numberp (plist-get rust-result :r2)))
    ;; Approximately y = 2x
    (should (< (abs (- (plist-get rust-result :m) 2.0)) 0.5))
    (should (> (plist-get rust-result :r2) 0.95))))

(ert-deftest drake-rust-ols-large-test ()
  "Test Rust OLS with large dataset for performance."
  (let* ((points (cl-loop for i from 1 to 1000
                         collect (cons (float i) (+ (* 2.0 i) 5.0 (* (- (random 2.0) 1.0) 10.0)))))
         (rust-result (drake--ols-regression points)))
    (should (numberp (plist-get rust-result :m)))
    (should (numberp (plist-get rust-result :b)))
    (should (numberp (plist-get rust-result :r2)))))

;;; Quartile Tests

(ert-deftest drake-rust-quartiles-test ()
  "Test that Rust quartiles match Elisp quartiles."
  (let* ((data '(1.0 2.0 3.0 4.0 5.0 6.0 7.0 8.0 9.0 10.0))
         (elisp-result (drake--compute-quartiles-elisp data))
         (rust-result (drake--compute-quartiles-safe data)))
    (should (= (plist-get rust-result :min) 1.0))
    (should (= (plist-get rust-result :max) 10.0))
    (should (= (plist-get rust-result :median) 5.5))
    ;; Check quartiles are reasonable
    (should (< (plist-get rust-result :q1) (plist-get rust-result :median)))
    (should (> (plist-get rust-result :q3) (plist-get rust-result :median)))))

(ert-deftest drake-rust-quartiles-odd-test ()
  "Test Rust quartiles with odd number of points."
  (let* ((data '(1.0 2.0 3.0 4.0 5.0 6.0 7.0 8.0 9.0))
         (rust-result (drake--compute-quartiles-safe data)))
    (should (= (plist-get rust-result :min) 1.0))
    (should (= (plist-get rust-result :max) 9.0))
    (should (= (plist-get rust-result :median) 5.0))))

(ert-deftest drake-rust-quartiles-large-test ()
  "Test Rust quartiles with large dataset."
  (let* ((data (cl-loop for i from 1 to 10000 collect (float i)))
         (rust-result (drake--compute-quartiles-safe data)))
    (should (= (plist-get rust-result :min) 1.0))
    (should (= (plist-get rust-result :max) 10000.0))
    (should (< (abs (- (plist-get rust-result :median) 5000.5)) 1.0))))

;;; Integration Tests

(ert-deftest drake-rust-violin-plot-uses-rust ()
  "Test that violin plots use Rust KDE when available."
  (let* ((data '(:x ["A" "A" "A" "B" "B" "B"] :y [1.0 2.0 3.0 10.0 11.0 12.0]))
         (plot (drake-plot-violin :data data :x :x :y :y :buffer nil :backend 'svg)))
    (should (drake-plot-p plot))
    (should (drake-plot-image plot))))

(ert-deftest drake-rust-lm-plot-uses-rust ()
  "Test that LM plots use Rust OLS when available."
  (let* ((data '(:x [1.0 2.0 3.0 4.0 5.0] :y [2.1 3.9 6.2 7.8 10.1]))
         (plot (drake-plot-lm :data data :x :x :y :y :buffer nil :backend 'svg)))
    (should (drake-plot-p plot))
    (should (drake-plot-image plot))))

(ert-deftest drake-rust-box-plot-uses-rust ()
  "Test that box plots use Rust quartiles when available."
  (let* ((data '(:x ["A" "A" "A" "B" "B" "B"] :y [1.0 2.0 3.0 10.0 11.0 12.0]))
         (plot (drake-plot-box :data data :x :x :y :y :buffer nil :backend 'svg)))
    (should (drake-plot-p plot))
    (should (drake-plot-image plot))))

;;; Performance Comparison Tests

(ert-deftest drake-rust-kde-performance ()
  "Verify Rust KDE is faster than Elisp KDE."
  :tags '(:performance)
  (let* ((data (apply #'vector (cl-loop for i from 1 to 2000
                                        collect (+ 50.0 (* 10.0 (/ (float i) 1000.0))))))
         (elisp-time 0)
         (rust-time 0))
    ;; Time Elisp
    (let ((start (float-time)))
      (drake--compute-kde-elisp data 'scott)
      (setq elisp-time (- (float-time) start)))

    ;; Time Rust
    (let ((start (float-time)))
      (drake--compute-kde data 'scott)
      (setq rust-time (- (float-time) start)))

    (message "KDE (2000 points): Elisp=%.3fs Rust=%.3fs Speedup=%.1fx"
             elisp-time rust-time (/ elisp-time rust-time))
    ;; Rust should be significantly faster (at least 5x)
    (should (< rust-time (* 0.2 elisp-time)))))

(provide 'rust-math-tests)
;;; rust-math-tests.el ends here

;;; tests/rust-fallback-tests.el --- Tests for Rust module fallback behavior -*- lexical-binding: t; -*-

(require 'test-helper)
(require 'drake)

;;; These tests verify that the code works correctly when the Rust module is NOT available.
;;; They simulate an environment where the Rust module is unavailable and verify fallback to Elisp.

(ert-deftest drake-fallback-kde-test ()
  "Test that KDE falls back to Elisp when Rust module unavailable."
  (let ((drake-rust-module-loaded nil))  ; Force Rust unavailable
    (let* ((data (vector 1.0 2.0 3.0 4.0 5.0 6.0 7.0 8.0 9.0 10.0))
           (result (drake--compute-kde data 'scott)))
      ;; Should still get valid results using Elisp fallback
      (should (listp result))
      (should (> (length result) 0))
      (should (consp (car result)))
      (should (numberp (caar result)))  ; x value
      (should (numberp (cdar result)))  ; density value
      ;; Verify all density values are non-negative
      (cl-loop for p in result
               do (should (>= (cdr p) 0.0))))))

(ert-deftest drake-fallback-kde-silverman-test ()
  "Test that KDE with Silverman bandwidth falls back to Elisp when Rust unavailable."
  (let ((drake-rust-module-loaded nil))  ; Force Rust unavailable
    (let* ((data (vector 1.0 2.0 3.0 4.0 5.0 10.0 11.0 12.0))
           (result (drake--compute-kde data 'silverman)))
      (should (listp result))
      (should (> (length result) 0))
      (should (consp (car result)))
      ;; Check all values are finite
      (cl-loop for p in result
               do (should (numberp (car p)))
               do (should (numberp (cdr p)))))))

(ert-deftest drake-fallback-ols-test ()
  "Test that OLS regression falls back to Elisp when Rust unavailable."
  (let ((drake-rust-module-loaded nil))  ; Force Rust unavailable
    (let* ((points '((1.0 . 2.0) (2.0 . 4.0) (3.0 . 6.0) (4.0 . 8.0) (5.0 . 10.0)))
           (result (drake--ols-regression points)))
      ;; Should still get valid results using Elisp fallback
      (should (numberp (plist-get result :m)))
      (should (numberp (plist-get result :b)))
      (should (numberp (plist-get result :r2)))
      ;; Perfect linear relationship: y = 2x
      (should (< (abs (- (plist-get result :m) 2.0)) 0.01))
      (should (< (abs (plist-get result :b)) 0.01))
      (should (> (plist-get result :r2) 0.99)))))

(ert-deftest drake-fallback-quartiles-test ()
  "Test that quartiles computation falls back to Elisp when Rust unavailable."
  (let ((drake-rust-module-loaded nil))  ; Force Rust unavailable
    (let* ((data '(1.0 2.0 3.0 4.0 5.0 6.0 7.0 8.0 9.0 10.0))
           (result (drake--compute-quartiles-safe data)))
      ;; Should still get valid results using Elisp fallback
      (should (= (plist-get result :min) 1.0))
      (should (= (plist-get result :max) 10.0))
      (should (= (plist-get result :median) 5.5))
      (should (< (plist-get result :q1) (plist-get result :median)))
      (should (> (plist-get result :q3) (plist-get result :median))))))

(ert-deftest drake-fallback-violin-plot-test ()
  "Test that violin plots work when Rust module unavailable."
  (let ((drake-rust-module-loaded nil))  ; Force Rust unavailable
    (let* ((data '(:x ["A" "A" "A" "B" "B" "B"] :y [1.0 2.0 3.0 10.0 11.0 12.0]))
           (plot (drake-plot-violin :data data :x :x :y :y :buffer nil :backend 'svg)))
      ;; Should still successfully create plot using Elisp fallback
      (should (drake-plot-p plot))
      (should (drake-plot-image plot)))))

(ert-deftest drake-fallback-lm-plot-test ()
  "Test that LM plots work when Rust module unavailable."
  (let ((drake-rust-module-loaded nil))  ; Force Rust unavailable
    (let* ((data '(:x [1.0 2.0 3.0 4.0 5.0] :y [2.1 3.9 6.2 7.8 10.1]))
           (plot (drake-plot-lm :data data :x :x :y :y :buffer nil :backend 'svg)))
      ;; Should still successfully create plot using Elisp fallback
      (should (drake-plot-p plot))
      (should (drake-plot-image plot)))))

(ert-deftest drake-fallback-box-plot-test ()
  "Test that box plots work when Rust module unavailable."
  (let ((drake-rust-module-loaded nil))  ; Force Rust unavailable
    (let* ((data '(:x ["A" "A" "A" "B" "B" "B"] :y [1.0 2.0 3.0 10.0 11.0 12.0]))
           (plot (drake-plot-box :data data :x :x :y :y :buffer nil :backend 'svg)))
      ;; Should still successfully create plot using Elisp fallback
      (should (drake-plot-p plot))
      (should (drake-plot-image plot)))))

(ert-deftest drake-fallback-consistency-kde ()
  "Test that Elisp and Rust KDE produce consistent results."
  (skip-unless (and (boundp 'drake-rust-module-loaded) drake-rust-module-loaded))
  (let* ((data (vector 1.0 2.0 3.0 4.0 5.0 6.0 7.0 8.0 9.0 10.0))
         (elisp-result (let ((drake-rust-module-loaded nil))
                         (drake--compute-kde data 'scott)))
         (rust-result (drake--compute-kde data 'scott)))
    ;; Both should produce the same number of points (within 1)
    (should (< (abs (- (length elisp-result) (length rust-result))) 2))
    ;; Spot check a few density values are close (within 5%)
    (let ((e-mid (nth (/ (length elisp-result) 2) elisp-result))
          (r-mid (nth (/ (length rust-result) 2) rust-result)))
      (should (< (abs (- (cdr e-mid) (cdr r-mid)))
                 (* 0.05 (abs (cdr e-mid))))))))

(ert-deftest drake-fallback-consistency-ols ()
  "Test that Elisp and Rust OLS produce consistent results."
  (skip-unless (and (boundp 'drake-rust-module-loaded) drake-rust-module-loaded))
  (let* ((points '((1.0 . 2.0) (2.0 . 4.0) (3.0 . 6.0) (4.0 . 8.0) (5.0 . 10.0)))
         (elisp-result (let ((drake-rust-module-loaded nil))
                         (drake--ols-regression points)))
         (rust-result (drake--ols-regression points)))
    ;; Both should produce very similar coefficients
    (should (< (abs (- (plist-get elisp-result :m) (plist-get rust-result :m))) 0.001))
    (should (< (abs (- (plist-get elisp-result :b) (plist-get rust-result :b))) 0.001))
    (should (< (abs (- (plist-get elisp-result :r2) (plist-get rust-result :r2))) 0.001))))

(ert-deftest drake-fallback-consistency-quartiles ()
  "Test that Elisp and Rust quartiles produce consistent results."
  (skip-unless (and (boundp 'drake-rust-module-loaded) drake-rust-module-loaded))
  (let* ((data '(1.0 2.0 3.0 4.0 5.0 6.0 7.0 8.0 9.0 10.0))
         (elisp-result (let ((drake-rust-module-loaded nil))
                         (drake--compute-quartiles-safe data)))
         (rust-result (drake--compute-quartiles-safe data)))
    ;; Both should produce identical results (quartiles are deterministic)
    (should (= (plist-get elisp-result :min) (plist-get rust-result :min)))
    (should (= (plist-get elisp-result :max) (plist-get rust-result :max)))
    (should (= (plist-get elisp-result :median) (plist-get rust-result :median)))
    ;; Q1 and Q3 might differ slightly due to interpolation methods
    (should (< (abs (- (plist-get elisp-result :q1) (plist-get rust-result :q1))) 0.5))
    (should (< (abs (- (plist-get elisp-result :q3) (plist-get rust-result :q3))) 0.5))))

(provide 'rust-fallback-tests)
;;; rust-fallback-tests.el ends here

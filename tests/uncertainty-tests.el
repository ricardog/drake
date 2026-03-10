;;; uncertainty-tests.el --- Tests for CI and Smoothing -*- lexical-binding: t; -*-

(require 'test-helper)
(require 'drake)

(ert-deftest drake--ols-regression-ci-stats-test ()
  (let* ((pts '((1 . 2) (2 . 4) (3 . 6) (4 . 8)))
         (res (drake--ols-regression pts)))
    (should (equal (plist-get res :m) 2.0))
    (should (equal (plist-get res :b) 0.0))
    (should (equal (plist-get res :r2) 1.0))
    (should (equal (plist-get res :se) 0.0))
    (should (equal (plist-get res :n) 4))
    (should (equal (plist-get res :mean-x) 2.5))))

(ert-deftest drake-plot-smooth-smoke-test ()
  (let* ((data '(:x [1 2 3 4 5] :y [2 4 3 5 4]))
         (plot (drake-plot-smooth :data data :x :x :y :y :title "Smooth Plot Test")))
    (should (drake-plot-p plot))
    (should (eq (plist-get (drake-plot-spec plot) :type) 'smooth))
    (let ((data-int (drake-plot-data-internal plot)))
      (should (vectorp (plist-get data-int :x)))
      (should (vectorp (plist-get data-int :y)))
      ;; Check extra contains original data
      (let ((extra (plist-get data-int :extra)))
        (should (equal (plist-get extra :original-x) [1 2 3 4 5]))))))

(ert-deftest drake-plot-smooth-gnuplot-test ()
  (let* ((data '(:x [1 2 3 4 5] :y [2 4 3 5 4]))
         (plot (drake-plot-smooth :data data :x :x :y :y :backend 'gnuplot)))
    (should (drake-plot-p plot))
    (should (imagep (drake-plot-image plot)))))

(provide 'uncertainty-tests)

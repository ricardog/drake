;;; drake-tests.el --- Tests for drake core -*- lexical-binding: t; -*-

(require 'test-helper)

(ert-deftest drake--ensure-vector-test ()
  (should (equal (drake--ensure-vector [1 2 3]) [1 2 3]))
  (should (equal (drake--ensure-vector '(1 2 3)) [1 2 3]))
  (should-error (drake--ensure-vector "not a sequence")))

(ert-deftest drake--normalize-data-row-based-test ()
  ;; Test converting list of lists (rows) to columnar vectors
  (let* ((data '((1 10) (2 20) (3 30)))
         (normalized (drake--normalize-data data 0 1)))
    (should (equal (plist-get normalized :x) [1 2 3]))
    (should (equal (plist-get normalized :y) [10 20 30]))))

(ert-deftest drake--scale-vector-test ()
  ;; Test scaling a vector to 0.0-1.0 range
  (let ((vec [10 20 30]))
    (should (equal (drake--scale-vector vec '(10 . 30)) [0.0 0.5 1.0]))))

(ert-deftest drake-plot-scatter-scaling-test ()
  ;; Test that drake-plot-scatter stores scaled data in data-internal
  (let* ((data '(:x [10 20 30] :y [100 200 300]))
         (plot (drake-plot-scatter :data data :x :x :y :y)))
    ;; According to new spec, data-internal should be scaled 0.0 to 1.0
    (should (equal (plist-get (drake-plot-data-internal plot) :x) [0.0 0.5 1.0]))
    (should (equal (plist-get (drake-plot-data-internal plot) :y) [0.0 0.5 1.0]))))

(provide 'drake-tests)

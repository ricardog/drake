;;; stage4-tests.el --- Tests for Stage 4 features -*- lexical-binding: t; -*-

(require 'test-helper)
(require 'drake)

(ert-deftest drake--ols-regression-test ()
  (let* ((pts '((1 . 2) (2 . 4) (3 . 6)))
         (res (drake--ols-regression pts)))
    (should (equal (plist-get res :m) 2.0))
    (should (equal (plist-get res :b) 0.0))
    (should (equal (plist-get res :r2) 1.0))))

(ert-deftest drake-plot-lm-smoke-test ()
  (let* ((data '(:x [1 2 3 4 5] :y [2.1 3.9 6.1 8.2 10.1]))
         (plot (drake-plot-lm :data data :x :x :y :y :title "LM Plot Test")))
    (should (drake-plot-p plot))
    (should (eq (plist-get (drake-plot-spec plot) :type) 'lm))
    (let* ((extra (plist-get (drake-plot-data-internal plot) :extra))
           (stats (cdr (assoc 'overall extra))))
      (should (> (plist-get stats :m) 1.9))
      (should (< (plist-get stats :m) 2.1)))))

(ert-deftest drake-plot-lm-hue-test ()
  (let* ((data '(:x [1 2 1 2] :y [10 20 100 200] :h ["A" "A" "B" "B"]))
         (plot (drake-plot-lm :data data :x :x :y :y :hue :h)))
    (should (drake-plot-p plot))
    (let* ((extra (plist-get (drake-plot-data-internal plot) :extra)))
      (should (equal (length extra) 2))
      (should (assoc "A" extra))
      (should (assoc "B" extra))
      (should (equal (plist-get (cdr (assoc "A" extra)) :m) 10.0))
      (should (equal (plist-get (cdr (assoc "B" extra)) :m) 100.0)))))

(provide 'stage4-tests)

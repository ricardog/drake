;;; drake-gnuplot-tests.el --- Tests for gnuplot backend -*- lexical-binding: t; -*-

(require 'test-helper)
(require 'drake-gnuplot)

(ert-deftest drake-gnuplot-render-scatter-test ()
  (let* ((data '(:x [1 2 3] :y [10 20 30]))
         (plot (drake-plot-scatter :data data :x :x :y :y :backend 'gnuplot)))
    (should (drake-plot-image plot))
    (should (eq (image-type (drake-plot-image plot)) 'svg))))

(ert-deftest drake-gnuplot-render-lm-test ()
  (let* ((data '(:x [1 2 3] :y [10 20 30]))
         (plot (drake-plot-lm :data data :x :x :y :y :backend 'gnuplot)))
    (should (drake-plot-image plot))
    (should (eq (image-type (drake-plot-image plot)) 'svg))))

(ert-deftest drake-gnuplot-render-hue-test ()
  (let* ((data '(:x [1 2 3 4] :y [10 20 100 200] :h ["A" "A" "B" "B"]))
         (plot (drake-plot-scatter :data data :x :x :y :y :hue :h :backend 'gnuplot)))
    (should (drake-plot-image plot))
    (should (eq (image-type (drake-plot-image plot)) 'svg))))

(ert-deftest drake-gnuplot-render-box-test ()
  (let* ((data '((:cat "A" :val 10) (:cat "A" :val 12) (:cat "A" :val 15)
                 (:cat "B" :val 20) (:cat "B" :val 22) (:cat "B" :val 25)))
         (plot (drake-plot-box :data data :x :cat :y :val :backend 'gnuplot)))
    (should (drake-plot-image plot))
    (should (eq (image-type (drake-plot-image plot)) 'svg))))

(provide 'drake-gnuplot-tests)

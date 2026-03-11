;;; drake-gnuplot-tests.el --- Tests for gnuplot backend -*- lexical-binding: t; -*-

(require 'test-helper)
(require 'drake-gnuplot)

(ert-deftest drake-gnuplot-registration-test ()
  "Verify that gnuplot backend is registered only if executable is found."
  (if (executable-find "gnuplot")
      (should (gethash 'gnuplot drake--backends))
    (should-not (gethash 'gnuplot drake--backends))))

(ert-deftest drake-gnuplot-render-scatter-test ()
  (drake-skip-unless-gnuplot)
  (let* ((data '(:x [1 2 3] :y [10 20 30]))
         (plot (drake-plot-scatter :data data :x :x :y :y :backend 'gnuplot)))
    (should (drake-plot-image plot))
    (should (eq (image-type (drake-plot-image plot)) 'svg))))

(ert-deftest drake-gnuplot-render-lm-test ()
  (drake-skip-unless-gnuplot)
  (let* ((data '(:x [1 2 3] :y [10 20 30]))
         (plot (drake-plot-lm :data data :x :x :y :y :backend 'gnuplot)))
    (should (drake-plot-image plot))
    (should (eq (image-type (drake-plot-image plot)) 'svg))))

(ert-deftest drake-gnuplot-render-hue-test ()
  (drake-skip-unless-gnuplot)
  (let* ((data '(:x [1 2 3 4] :y [10 20 100 200] :h ["A" "A" "B" "B"]))
         (plot (drake-plot-scatter :data data :x :x :y :y :hue :h :backend 'gnuplot)))
    (should (drake-plot-image plot))
    (should (eq (image-type (drake-plot-image plot)) 'svg))))

(ert-deftest drake-gnuplot-render-box-test ()
  (drake-skip-unless-gnuplot)
  (let* ((data '((:cat "A" :val 10) (:cat "A" :val 12) (:cat "A" :val 15)
                 (:cat "B" :val 20) (:cat "B" :val 22) (:cat "B" :val 25)))
         (plot (drake-plot-box :data data :x :cat :y :val :backend 'gnuplot)))
    (should (drake-plot-image plot))
    (should (eq (image-type (drake-plot-image plot)) 'svg))))

(provide 'drake-gnuplot-tests)

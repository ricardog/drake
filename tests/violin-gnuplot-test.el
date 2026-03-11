;;; tests/violin-gnuplot-test.el --- Tests for Gnuplot violin -*- lexical-binding: t; -*-
(require 'test-helper)
(require 'drake)
(require 'drake-gnuplot)

(ert-deftest drake-plot-violin-gnuplot-test ()
  (drake-skip-unless-gnuplot)
  (let* ((data '((:cat "A" :val 10) (:cat "A" :val 12) (:cat "A" :val 15)
                 (:cat "B" :val 20) (:cat "B" :val 22) (:cat "B" :val 25)))
         (plot (drake-plot-violin :data data :x :cat :y :val :backend 'gnuplot :title "Gnuplot Violin Test")))
    (should (drake-plot-p plot))
    (should (drake-plot-svg-xml plot))
    (should (string-match "<svg" (drake-plot-svg-xml plot)))))

(provide 'violin-gnuplot-test)

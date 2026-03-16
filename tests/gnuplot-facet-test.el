;;; tests/gnuplot-facet-test.el --- Tests for gnuplot native faceting -*- lexical-binding: t; -*-

(require 'test-helper)
(require 'drake)
(require 'drake-gnuplot)

(ert-deftest drake-gnuplot-facet-test ()
  (skip-unless (executable-find "gnuplot"))
  (let* ((data '(:x [1 2 3 4] :y [10 20 10 20] :category ["A" "A" "B" "B"]))
         (fplot (drake-facet :data data :col :category 
                            :plot-fn #'drake-plot-scatter 
                            :args '(:x :x :y :y)
                            :backend 'gnuplot)))
    (should (drake-facet-plot-p fplot))
    (should (= (drake-facet-plot-cols fplot) 2))
    (should (drake-facet-plot-image fplot))
    ;; Verify it used gnuplot (svg-xml should be present)
    (should (drake-facet-plot-svg-xml fplot))))

(provide 'gnuplot-facet-test)

;;; tests/facet-tests.el --- Tests for drake-facet -*- lexical-binding: t; -*-

(require 'test-helper)
(require 'drake)
(require 'drake-svg)

(ert-deftest drake-facet-smoke-test ()
  (let* ((data '(:x [1 2 3 4] :y [10 20 10 20] :category ["A" "A" "B" "B"]))
         (fplot (drake-facet :data data :col :category :plot-fn #'drake-plot-scatter :args '(:x :x :y :y))))
    (should (drake-facet-plot-p fplot))
    (should (= (drake-facet-plot-cols fplot) 2))
    (should (= (drake-facet-plot-rows fplot) 1))
    (should (drake-facet-plot-image fplot))))

(ert-deftest drake-facet-row-col-test ()
  (let* ((data '(:x [1 2 3 4] :y [10 20 30 40] 
                 :r ["R1" "R1" "R2" "R2"] 
                 :c ["C1" "C2" "C1" "C2"]))
         (fplot (drake-facet :data data :row :r :col :c 
                            :plot-fn #'drake-plot-scatter 
                            :args '(:x :x :y :y)
                            :title "Row/Col Facet Test")))
    (should (drake-facet-plot-p fplot))
    (should (= (drake-facet-plot-rows fplot) 2))
    (should (= (drake-facet-plot-cols fplot) 2))
    (should (drake-facet-plot-image fplot))))

(provide 'facet-tests)

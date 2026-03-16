;;; tests/rust-facet-test.el --- Tests for rust native faceting -*- lexical-binding: t; -*-

(require 'test-helper)
(require 'drake)
(require 'drake-rust)

(ert-deftest drake-rust-facet-test ()
  (let* ((data '(:x [1 2 3 4] :y [10 20 10 20] :category ["A" "A" "B" "B"]))
         (fplot (drake-facet :data data :col :category 
                            :plot-fn #'drake-plot-scatter 
                            :args '(:x :x :y :y)
                            :backend 'rust)))
    (should (drake-facet-plot-p fplot))
    (should (= (drake-facet-plot-cols fplot) 2))
    (should (drake-facet-plot-image fplot))
    (should (drake-facet-plot-svg-xml fplot))))

(provide 'rust-facet-test)

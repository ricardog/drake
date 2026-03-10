;;; drake-svg-tests.el --- Tests for drake SVG backend -*- lexical-binding: t; -*-

(require 'test-helper)

(ert-deftest drake-svg-render-test ()
  (let* ((data '(:x [1 2 3] :y [10 20 30]))
         (plot (drake-plot-scatter :data data :x :x :y :y :backend 'svg)))
    (should (drake-plot-image plot))
    (should (imagep (drake-plot-image plot)))
    (should (eq (image-type (drake-plot-image plot)) 'svg))))

(provide 'drake-svg-tests)

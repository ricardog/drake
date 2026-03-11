;;; drake-svg-tests.el --- Tests for drake SVG backend -*- lexical-binding: t; -*-

(require 'test-helper)

(ert-deftest drake-svg-render-test ()
  (let* ((data '(:x [1 2 3] :y [10 20 30]))
         (plot (drake-plot-scatter :data data :x :x :y :y :backend 'svg)))
    (should (drake-plot-image plot))
    (should (imagep (drake-plot-image plot)))
    (should (eq (drake-test-get-image-type (drake-plot-image plot)) 'svg))))

(ert-deftest drake-svg-tooltip-test ()
  (let* ((data '(:x [1] :y [10] :note ["Special Point"]))
         (plot (drake-plot-scatter :data data :x :x :y :y :tooltip :note :backend 'svg))
         (xml (drake-plot-svg-xml plot)))
    (should (string-match-p "<title>Special Point</title>" xml))))

(provide 'drake-svg-tests)

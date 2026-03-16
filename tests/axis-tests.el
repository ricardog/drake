;;; tests/axis-tests.el --- Tests for advanced axis support -*- lexical-binding: t; -*-

(require 'test-helper)
(require 'drake)
(require 'drake-svg)
(require 'drake-gnuplot)
(require 'drake-rust)

(ert-deftest drake-log-axis-test ()
  (let* ((data '(:x [1 10 100 1000] :y [1 2 3 4]))
         (plot (drake-plot-scatter :data data :x :x :y :y :logx t :backend 'svg)))
    (should (drake-plot-p plot))
    (should (drake-plot-image plot))))

(ert-deftest drake-date-axis-test ()
  (let* ((data '(:x ["2026-01-01 00:00:00" "2026-02-01 00:00:00" "2026-03-01 00:00:00"] :y [10 20 30]))
         (plot (drake-plot-line :data data :x :x :y :y :backend 'svg)))
    (should (drake-plot-p plot))
    (should (eq (plist-get (drake-plot-scales plot) :x-type) 'time))
    (should (drake-plot-image plot))))

(ert-deftest drake-gnuplot-log-test ()
  (skip-unless (executable-find "gnuplot"))
  (let* ((data '(:x [1 10 100 1000] :y [1 2 3 4]))
         (plot (drake-plot-scatter :data data :x :x :y :y :logx t :backend 'gnuplot)))
    (should (drake-plot-p plot))
    (should (drake-plot-image plot))))

(ert-deftest drake-rust-date-test ()
  (let* ((data '(:x ["2026-01-01 00:00:00" "2026-02-01 00:00:00" "2026-03-01 00:00:00"] :y [10 20 30]))
         (plot (drake-plot-line :data data :x :x :y :y :backend 'rust)))
    (should (drake-plot-p plot))
    (should (drake-plot-image plot))))

(provide 'axis-tests)

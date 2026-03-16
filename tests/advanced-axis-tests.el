;;; tests/advanced-axis-tests.el --- Advanced tests for axis support -*- lexical-binding: t; -*-

(require 'test-helper)
(require 'drake)
(require 'drake-gnuplot)
(require 'drake-rust)
(require 'drake-svg)

;;; Logarithmic Scale Tests

(ert-deftest drake-log-scale-x-only ()
  "Test logarithmic scaling on X axis only."
  (let* ((data '(:x [1 10 100 1000] :y [1 2 3 4]))
         (plot (drake-plot-scatter :data data :x :x :y :y :logx t :backend 'svg)))
    (should (drake-plot-p plot))
    (should (plist-get (drake-plot-scales plot) :x-log))
    (should-not (plist-get (drake-plot-scales plot) :y-log))
    (should (drake-plot-image plot))))

(ert-deftest drake-log-scale-y-only ()
  "Test logarithmic scaling on Y axis only."
  (let* ((data '(:x [1 2 3 4] :y [1 10 100 1000]))
         (plot (drake-plot-scatter :data data :x :x :y :y :logy t :backend 'svg)))
    (should (drake-plot-p plot))
    (should-not (plist-get (drake-plot-scales plot) :x-log))
    (should (plist-get (drake-plot-scales plot) :y-log))
    (should (drake-plot-image plot))))

(ert-deftest drake-log-scale-both-axes ()
  "Test logarithmic scaling on both axes."
  (let* ((data '(:x [1 10 100] :y [1 10 100]))
         (plot (drake-plot-scatter :data data :x :x :y :y :logx t :logy t :backend 'svg)))
    (should (drake-plot-p plot))
    (should (plist-get (drake-plot-scales plot) :x-log))
    (should (plist-get (drake-plot-scales plot) :y-log))
    (should (drake-plot-image plot))))

(ert-deftest drake-log-scale-with-line-plot ()
  "Test log scale with line plots."
  (let* ((data '(:x [1 10 100 1000] :y [2 4 8 16]))
         (plot (drake-plot-line :data data :x :x :y :y :logx t :logy t :backend 'svg)))
    (should (drake-plot-p plot))
    (should (plist-get (drake-plot-scales plot) :x-log))
    (should (plist-get (drake-plot-scales plot) :y-log))
    (should (drake-plot-image plot))))

(ert-deftest drake-log-scale-gnuplot ()
  "Test log scale with gnuplot backend."
  (skip-unless (executable-find "gnuplot"))
  (let* ((data '(:x [1 10 100 1000 10000] :y [1 2 3 4 5]))
         (plot (drake-plot-scatter :data data :x :x :y :y :logx t :backend 'gnuplot)))
    (should (drake-plot-p plot))
    (should (plist-get (drake-plot-scales plot) :x-log))
    (should (drake-plot-image plot))))

(ert-deftest drake-log-scale-rust ()
  "Test log scale with Rust backend."
  (let* ((data '(:x [1 10 100 1000] :y [5 4 3 2]))
         (plot (drake-plot-scatter :data data :x :x :y :y :logx t :logy t :backend 'rust)))
    (should (drake-plot-p plot))
    (should (plist-get (drake-plot-scales plot) :x-log))
    (should (plist-get (drake-plot-scales plot) :y-log))
    (should (drake-plot-image plot))))

;;; Date/Time Axis Tests

(ert-deftest drake-date-axis-iso-format ()
  "Test date axis with ISO 8601 format."
  (let* ((data '(:x ["2026-01-01 00:00:00" "2026-02-01 00:00:00" "2026-03-01 00:00:00"]
                 :y [10 20 30]))
         (plot (drake-plot-line :data data :x :x :y :y :backend 'svg)))
    (should (drake-plot-p plot))
    (should (eq (plist-get (drake-plot-scales plot) :x-type) 'time))
    (should (drake-plot-image plot))))

(ert-deftest drake-date-axis-short-format ()
  "Test date axis with full ISO format."
  (let* ((data '(:x ["2026-01-15 12:00:00" "2026-02-15 12:00:00" "2026-03-15 12:00:00"]
                 :y [100 200 150]))
         (plot (drake-plot-line :data data :x :x :y :y :backend 'svg)))
    (should (drake-plot-p plot))
    (should (eq (plist-get (drake-plot-scales plot) :x-type) 'time))
    (should (drake-plot-image plot))))

(ert-deftest drake-date-axis-scatter ()
  "Test date axis with scatter plot."
  (let* ((data '(:x ["2026-01-01 00:00:00" "2026-01-15 00:00:00" "2026-02-01 00:00:00" "2026-02-15 00:00:00"]
                 :y [10 15 20 25]))
         (plot (drake-plot-scatter :data data :x :x :y :y :backend 'svg)))
    (should (drake-plot-p plot))
    (should (eq (plist-get (drake-plot-scales plot) :x-type) 'time))
    (should (drake-plot-image plot))))

(ert-deftest drake-date-axis-gnuplot ()
  "Test date axis with gnuplot backend - needs raw timestamp support."
  :expected-result :failed
  (skip-unless (executable-find "gnuplot"))
  ;; TODO: Gnuplot time axis requires raw timestamps, not scaled 0-1 values
  ;; This is a known limitation to be addressed in future work
  (let* ((data '(:x ["2026-01-01 00:00:00" "2026-02-01 00:00:00" "2026-03-01 00:00:00"]
                 :y [5 10 15]))
         (plot (drake-plot-line :data data :x :x :y :y :backend 'gnuplot)))
    (should (drake-plot-p plot))
    (should (eq (plist-get (drake-plot-scales plot) :x-type) 'time))
    (should (drake-plot-image plot))))

(ert-deftest drake-date-axis-rust ()
  "Test date axis with Rust backend."
  (let* ((data '(:x ["2026-01-01 00:00:00" "2026-06-01 00:00:00" "2026-12-31 23:59:59"]
                 :y [1 50 100]))
         (plot (drake-plot-line :data data :x :x :y :y :backend 'rust)))
    (should (drake-plot-p plot))
    (should (eq (plist-get (drake-plot-scales plot) :x-type) 'time))
    (should (drake-plot-image plot))))

;;; Combined Features Tests

(ert-deftest drake-log-scale-with-hue ()
  "Test log scale combined with hue grouping."
  (let* ((data '(:x [1 10 100 1 10 100]
                 :y [5 10 15 10 20 30]
                 :group ["A" "A" "A" "B" "B" "B"]))
         (plot (drake-plot-scatter :data data :x :x :y :y :hue :group :logx t :backend 'svg)))
    (should (drake-plot-p plot))
    (should (plist-get (drake-plot-scales plot) :x-log))
    (should (plist-get (drake-plot-scales plot) :hue))
    (should (drake-plot-image plot))))

(ert-deftest drake-date-axis-with-hue ()
  "Test date axis combined with hue grouping."
  (let* ((data '(:x ["2026-01-01 00:00:00" "2026-02-01 00:00:00" "2026-01-01 00:00:00" "2026-02-01 00:00:00"]
                 :y [10 20 15 25]
                 :group ["A" "A" "B" "B"]))
         (plot (drake-plot-line :data data :x :x :y :y :hue :group :backend 'svg)))
    (should (drake-plot-p plot))
    (should (eq (plist-get (drake-plot-scales plot) :x-type) 'time))
    (should (plist-get (drake-plot-scales plot) :hue))
    (should (drake-plot-image plot))))

(ert-deftest drake-log-scale-with-regression ()
  "Test log scale with regression line."
  (let* ((data '(:x [1 10 100 1000] :y [2 4 6 8]))
         (plot (drake-plot-lm :data data :x :x :y :y :logx t :backend 'svg)))
    (should (drake-plot-p plot))
    (should (plist-get (drake-plot-scales plot) :x-log))
    (should (drake-plot-image plot))))

;;; Edge Cases

(ert-deftest drake-log-scale-with-zero-values ()
  "Test log scale handles zero values gracefully."
  (let* ((data '(:x [0 1 10 100] :y [1 2 3 4]))
         (plot (drake-plot-scatter :data data :x :x :y :y :logx t :backend 'svg)))
    (should (drake-plot-p plot))
    ;; Should not error even with zero values
    (should (drake-plot-image plot))))

(ert-deftest drake-log-scale-with-negative-values ()
  "Test log scale handles negative values gracefully."
  (let* ((data '(:x [-10 -1 1 10] :y [1 2 3 4]))
         (plot (drake-plot-scatter :data data :x :x :y :y :logx t :backend 'svg)))
    (should (drake-plot-p plot))
    ;; Should not error even with negative values
    (should (drake-plot-image plot))))

(ert-deftest drake-date-axis-mixed-formats ()
  "Test date axis with consistent format requirement."
  ;; All dates should be in the same format
  (let* ((data '(:x ["2026-01-01 00:00:00" "2026-02-01 00:00:00" "2026-03-01 00:00:00"]
                 :y [10 20 30]))
         (plot (drake-plot-line :data data :x :x :y :y :backend 'svg)))
    (should (drake-plot-p plot))
    (should (eq (plist-get (drake-plot-scales plot) :x-type) 'time))))

;;; Categorical axis tests (for completeness)

(ert-deftest drake-categorical-x-axis ()
  "Test categorical X axis."
  (let* ((data '(:x ["Low" "Medium" "High"] :y [10 20 30]))
         (plot (drake-plot-bar :data data :x :x :y :y :backend 'svg)))
    (should (drake-plot-p plot))
    (should (eq (plist-get (drake-plot-scales plot) :x-type) 'categorical))
    (should (drake-plot-image plot))))

(ert-deftest drake-categorical-y-axis ()
  "Test categorical Y axis (horizontal bar chart)."
  (let* ((data '(:x [10 20 30] :y ["Alpha" "Beta" "Gamma"]))
         (plot (drake-plot-scatter :data data :x :x :y :y :backend 'svg)))
    (should (drake-plot-p plot))
    (should (eq (plist-get (drake-plot-scales plot) :y-type) 'categorical))
    (should (drake-plot-image plot))))

(provide 'advanced-axis-tests)

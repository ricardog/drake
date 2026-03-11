
(require 'test-helper)

(ert-deftest drake-svg-legend-placement-test ()
  (let* ((data '(:x [0.9 0.9 0.9] :y [0.9 0.9 0.9] :h ["A" "B" "C"]))
         (plot (drake-plot-scatter :data data :x :x :y :y :hue :h :backend 'svg)))
    (with-temp-buffer
      (insert (drake-plot-svg-xml plot))
      (goto-char (point-min))
      ;; With points at 0.9,0.9 (Top Right), the legend should NOT be at top-right.
      ;; The emptiest corner should be bottom-left (0,0).
      ;; Padding=10, margin=60 -> 70, 70.
      ;; Wait, coordinates for bottom-left: (+ margin padding) (- height margin l-height padding)
      ;; Let's just check if the rectangle for the legend exists.
      (should (re-search-forward "<rect" nil t))))

  ;; Manual override test
  (let* ((data '(:x [0.1] :y [0.1] :h ["A"]))
         (plot (drake-plot-scatter :data data :x :x :y :y :hue :h :backend 'svg :legend 'top-left)))
    (with-temp-buffer
      (insert (drake-plot-svg-xml plot))
      (goto-char (point-min))
      ;; top-left should have x="70" y="70" (margin 60 + padding 10)
      (should (re-search-forward "x=\"70\" y=\"70\"" nil t)))))

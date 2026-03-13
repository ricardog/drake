(require 'ert)
(require 'drake)
(require 'drake-rust)

;; Mock imagep if not defined (e.g. in batch mode)
(unless (fboundp 'imagep)
  (defun imagep (_) t))

(ert-deftest drake-rust-scatter-test ()
  "Test rendering a scatter plot with the Rust backend."
  (let* ((data '(:x [1.0 2.0 3.0] :y [10.0 20.0 30.0]))
         (plot (drake-plot-scatter :data data :x :x :y :y :title "Rust Test" :backend 'rust)))
    (should (drake-plot-p plot))
    (should (plist-get (drake-plot-spec plot) :title))
    (should (string-prefix-p "<svg" (drake-plot-svg-xml plot)))
    (should (string-match-all "circle" (drake-plot-svg-xml plot) 3))))

(ert-deftest drake-rust-hue-test ()
  "Test rendering a scatter plot with Hue in the Rust backend."
  (let* ((data '(:x [1.0 2.0 3.0] :y [10.0 20.0 30.0] :h ["A" "B" "A"]))
         (plot (drake-plot-scatter :data data :x :x :y :y :hue :h :palette 'set1 :backend 'rust)))
    (should (drake-plot-p plot))
    (should (string-match-all "circle" (drake-plot-svg-xml plot) 3))
    ;; Check for different colors in the SVG
    (let ((xml (drake-plot-svg-xml plot)))
      (should (string-match "fill=\"#E41A1C\"" xml)) ;; Set1 color 1
      (should (string-match "fill=\"#377EB8\"" xml))))) ;; Set1 color 2

(ert-deftest drake-rust-line-test ()
  "Test rendering a line plot with the Rust backend."
  (let* ((data '(:x [1.0 2.0 3.0] :y [10.0 20.0 30.0]))
         (plot (drake-plot-line :data data :x :x :y :y :backend 'rust)))
    (should (drake-plot-p plot))
    (should (string-match "polyline" (drake-plot-svg-xml plot)))))

(ert-deftest drake-rust-bar-test ()
  "Test rendering a bar plot with the Rust backend."
  (let* ((data '(:x ["A" "B" "C"] :y [10.0 20.0 30.0]))
         (plot (drake-plot-bar :data data :x :x :y :y :backend 'rust)))
    (should (drake-plot-p plot))
    (should (string-match-all "rect" (drake-plot-svg-xml plot) 4)))) ;; 1 background + 3 bars

(ert-deftest drake-rust-box-test ()
  "Test rendering a box plot with the Rust backend."
  (let* ((data '(:x ["A" "A" "A" "B" "B" "B"] :y [1 2 3 10 20 30]))
         (plot (drake-plot-box :data data :x :x :y :y :backend 'rust)))
    (should (drake-plot-p plot))
    (should (string-match "polyline" (drake-plot-svg-xml plot)))))

(ert-deftest drake-rust-violin-test ()
  "Test rendering a violin plot with the Rust backend."
  (let* ((data '(:x ["A" "A" "A" "B" "B" "B"] :y [1 2 3 10 20 30]))
         (plot (drake-plot-violin :data data :x :x :y :y :backend 'rust)))
    (should (drake-plot-p plot))
    (should (string-match "polygon" (drake-plot-svg-xml plot)))))

(ert-deftest drake-rust-lm-test ()
  "Test rendering a regression plot with the Rust backend."
  (let* ((data '(:x [1 2 3 4 5] :y [2 4 5 4 5]))
         (plot (drake-plot-lm :data data :x :x :y :y :backend 'rust)))
    (should (drake-plot-p plot))
    (should (string-match "polyline" (drake-plot-svg-xml plot)))
    (should (string-match "polygon" (drake-plot-svg-xml plot))))) ;; CI area

(ert-deftest drake-rust-smooth-test ()
  "Test rendering a smooth plot with the Rust backend."
  (let* ((data '(:x [1 2 3 4 5] :y [2 4 5 4 5]))
         (plot (drake-plot-smooth :data data :x :x :y :y :backend 'rust)))
    (should (drake-plot-p plot))
    (should (string-match "polyline" (drake-plot-svg-xml plot)))))

(ert-deftest drake-rust-unsupported-type-test ()
  "Test that an unsupported plot type signals a Lisp error."
  (let* ((data '(:x [1.0] :y [10.0]))
         (plot (drake-plot-scatter :data data :x :x :y :y :backend 'rust)))
    ;; Force an unsupported type in the spec
    (setf (plist-get (drake-plot-spec plot) :type) 'unsupported)
    (should-error (drake-rust-render plot) :type 'error)))

(defun string-match-all (regexp string count)
  "Verify that REGEXP matches STRING at least COUNT times."
  (let ((start 0)
        (matches 0))
    (while (string-match regexp string start)
      (setq matches (1+ matches))
      (setq start (match-end 0)))
    (>= matches count)))

(provide 'drake-rust-tests)

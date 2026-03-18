;;; pair-plot-tests.el --- Tests for drake pair plot -*- lexical-binding: t; -*-

(require 'test-helper)

;;; Basic Functionality

(ert-deftest drake-pair-basic-test ()
  "Test basic pair plot functionality."
  (let* ((data '(:x [1 2 3] :y [4 5 6] :z [7 8 9]))
         (plot (drake-plot-pair :data data
                               :vars '(:x :y :z)
                               :buffer nil)))
    (should (drake-facet-plot-p plot))
    (should (= (drake-facet-plot-rows plot) 3))
    (should (= (drake-facet-plot-cols plot) 3))
    ;; Should have 3x3 grid
    (let ((grid (drake-facet-plot-grid plot)))
      (should (= (length grid) 3))
      (should (= (length (car grid)) 3)))))

(ert-deftest drake-pair-two-vars-test ()
  "Test pair plot with two variables."
  (let* ((data '(:x [1 2 3] :y [4 5 6]))
         (plot (drake-plot-pair :data data
                               :vars '(:x :y)
                               :buffer nil)))
    (should (drake-facet-plot-p plot))
    (should (= (drake-facet-plot-rows plot) 2))
    (should (= (drake-facet-plot-cols plot) 2))))

(ert-deftest drake-pair-single-var-test ()
  "Test pair plot with single variable (edge case)."
  (let* ((data '(:x [1 2 3]))
         (plot (drake-plot-pair :data data
                               :vars '(:x)
                               :buffer nil)))
    (should (drake-facet-plot-p plot))
    (should (= (drake-facet-plot-rows plot) 1))
    (should (= (drake-facet-plot-cols plot) 1))))

(ert-deftest drake-pair-diagonal-types-test ()
  "Test that diagonal plots are different from off-diagonal."
  (let* ((data '(:x [1 2 3] :y [4 5 6]))
         (plot (drake-plot-pair :data data
                               :vars '(:x :y)
                               :buffer nil))
         (grid (drake-facet-plot-grid plot)))
    ;; Diagonal (0,0) and (1,1) should be histograms
    (let ((p00 (nth 0 (nth 0 grid)))
          (p11 (nth 1 (nth 1 grid))))
      (should (drake-plot-p p00))
      (should (drake-plot-p p11))
      (should (eq (plist-get (drake-plot-spec p00) :type) 'hist))
      (should (eq (plist-get (drake-plot-spec p11) :type) 'hist)))
    ;; Off-diagonal (0,1) and (1,0) should be scatter
    (let ((p01 (nth 1 (nth 0 grid)))
          (p10 (nth 0 (nth 1 grid))))
      (should (drake-plot-p p01))
      (should (drake-plot-p p10))
      (should (eq (plist-get (drake-plot-spec p01) :type) 'scatter))
      (should (eq (plist-get (drake-plot-spec p10) :type) 'scatter)))))

;;; Hue Support

(ert-deftest drake-pair-with-hue-test ()
  "Test pair plot with hue grouping."
  (let* ((data '(:x [1 2 3 4] :y [4 5 6 7] :species ["A" "A" "B" "B"]))
         (plot (drake-plot-pair :data data
                               :vars '(:x :y)
                               :hue :species
                               :buffer nil)))
    (should (drake-facet-plot-p plot))
    ;; Check that plots have hue
    (let* ((grid (drake-facet-plot-grid plot))
           (p01 (nth 1 (nth 0 grid))))
      (should (plist-get (drake-plot-spec p01) :hue)))))

(ert-deftest drake-pair-hue-with-palette-test ()
  "Test pair plot with hue and custom palette."
  (let* ((data '(:x [1 2 3] :y [4 5 6] :cat ["A" "B" "C"]))
         (plot (drake-plot-pair :data data
                               :vars '(:x :y)
                               :hue :cat
                               :palette 'set1
                               :buffer nil)))
    (should (drake-facet-plot-p plot))))

;;; Rectangular Grids

(ert-deftest drake-pair-rectangular-test ()
  "Test pair plot with rectangular grid (x-vars and y-vars)."
  (let* ((data '(:x [1 2 3] :y [4 5 6] :z [7 8 9]))
         (plot (drake-plot-pair :data data
                               :x-vars '(:x)
                               :y-vars '(:y :z)
                               :buffer nil)))
    (should (drake-facet-plot-p plot))
    ;; Should have 2 rows, 1 column
    (should (= (drake-facet-plot-rows plot) 2))
    (should (= (drake-facet-plot-cols plot) 1))
    (let ((grid (drake-facet-plot-grid plot)))
      (should (= (length grid) 2))
      (should (= (length (car grid)) 1)))))

(ert-deftest drake-pair-rectangular-2x3-test ()
  "Test pair plot with 2x3 rectangular grid."
  (let* ((data '(:a [1 2 3] :b [4 5 6] :c [7 8 9] :d [10 11 12]))
         (plot (drake-plot-pair :data data
                               :x-vars '(:a :b :c)
                               :y-vars '(:c :d)
                               :buffer nil)))
    (should (drake-facet-plot-p plot))
    (should (= (drake-facet-plot-rows plot) 2))
    (should (= (drake-facet-plot-cols plot) 3))))

;;; Corner Mode

(ert-deftest drake-pair-corner-test ()
  "Test pair plot with corner mode (lower triangle only)."
  (let* ((data '(:x [1 2 3] :y [4 5 6] :z [7 8 9]))
         (plot (drake-plot-pair :data data
                               :vars '(:x :y :z)
                               :corner t
                               :buffer nil))
         (grid (drake-facet-plot-grid plot)))
    (should (drake-facet-plot-p plot))
    ;; Upper triangle should be nil
    (should (null (nth 1 (nth 0 grid))))  ; (0,1)
    (should (null (nth 2 (nth 0 grid))))  ; (0,2)
    (should (null (nth 2 (nth 1 grid))))  ; (1,2)
    ;; Lower triangle and diagonal should exist
    (should (drake-plot-p (nth 0 (nth 0 grid))))  ; (0,0)
    (should (drake-plot-p (nth 0 (nth 1 grid))))  ; (1,0)
    (should (drake-plot-p (nth 1 (nth 1 grid))))  ; (1,1)
    (should (drake-plot-p (nth 0 (nth 2 grid))))  ; (2,0)
    (should (drake-plot-p (nth 1 (nth 2 grid))))  ; (2,1)
    (should (drake-plot-p (nth 2 (nth 2 grid)))))) ; (2,2)

(ert-deftest drake-pair-corner-2x2-test ()
  "Test corner mode with 2x2 grid."
  (let* ((data '(:x [1 2 3] :y [4 5 6]))
         (plot (drake-plot-pair :data data
                               :vars '(:x :y)
                               :corner t
                               :buffer nil))
         (grid (drake-facet-plot-grid plot)))
    (should (null (nth 1 (nth 0 grid))))   ; (0,1) upper
    (should (drake-plot-p (nth 0 (nth 0 grid))))  ; (0,0) diagonal
    (should (drake-plot-p (nth 0 (nth 1 grid))))  ; (1,0) lower
    (should (drake-plot-p (nth 1 (nth 1 grid)))))) ; (1,1) diagonal

;;; Plot Types

(ert-deftest drake-pair-kind-scatter-test ()
  "Test pair plot with scatter kind (default)."
  (let* ((data '(:x [1 2 3] :y [4 5 6]))
         (plot (drake-plot-pair :data data
                               :vars '(:x :y)
                               :kind 'scatter
                               :buffer nil))
         (grid (drake-facet-plot-grid plot))
         (p01 (nth 1 (nth 0 grid))))
    (should (eq (plist-get (drake-plot-spec p01) :type) 'scatter))))

(ert-deftest drake-pair-kind-reg-test ()
  "Test pair plot with regression kind."
  (let* ((data '(:x [1 2 3 4 5] :y [2 4 6 8 10]))
         (plot (drake-plot-pair :data data
                               :vars '(:x :y)
                               :kind 'reg
                               :buffer nil))
         (grid (drake-facet-plot-grid plot))
         (p01 (nth 1 (nth 0 grid))))
    (should (eq (plist-get (drake-plot-spec p01) :type) 'lm))))

(ert-deftest drake-pair-diag-hist-test ()
  "Test pair plot with histogram diagonal (default)."
  (let* ((data '(:x [1 2 3] :y [4 5 6]))
         (plot (drake-plot-pair :data data
                               :vars '(:x :y)
                               :diag-kind 'hist
                               :buffer nil))
         (grid (drake-facet-plot-grid plot))
         (p00 (nth 0 (nth 0 grid))))
    (should (eq (plist-get (drake-plot-spec p00) :type) 'hist))))

(ert-deftest drake-pair-diag-none-test ()
  "Test pair plot with no diagonal plots."
  (let* ((data '(:x [1 2 3] :y [4 5 6]))
         (plot (drake-plot-pair :data data
                               :vars '(:x :y)
                               :diag-kind 'none
                               :buffer nil))
         (grid (drake-facet-plot-grid plot)))
    ;; Diagonal should be nil
    (should (null (nth 0 (nth 0 grid))))
    (should (null (nth 1 (nth 1 grid))))))

;;; Different Data Formats

(ert-deftest drake-pair-plist-rows-test ()
  "Test pair plot with plist rows."
  (let* ((data '((:x 1 :y 4) (:x 2 :y 5) (:x 3 :y 6)))
         (plot (drake-plot-pair :data data
                               :vars '(:x :y)
                               :buffer nil)))
    (should (drake-facet-plot-p plot))))

(ert-deftest drake-pair-alist-rows-test ()
  "Test pair plot with alist rows."
  (let* ((data '(((:x . 1) (:y . 4))
                 ((:x . 2) (:y . 5))
                 ((:x . 3) (:y . 6))))
         (plot (drake-plot-pair :data data
                               :vars '(:x :y)
                               :buffer nil)))
    (should (drake-facet-plot-p plot))))

;;; Edge Cases

(ert-deftest drake-pair-missing-variable-test ()
  "Test pair plot with missing variable in data."
  (let ((data '(:x [1 2 3])))
    (should-error (drake-plot-pair :data data
                                  :vars '(:x :y)
                                  :buffer nil))))

(ert-deftest drake-pair-empty-vars-test ()
  "Test pair plot with empty vars list."
  (let ((data '(:x [1 2 3] :y [4 5 6])))
    (should-error (drake-plot-pair :data data
                                  :vars '()
                                  :buffer nil))))

(ert-deftest drake-pair-small-dataset-test ()
  "Test pair plot with very small dataset."
  (let* ((data '(:x [1 2] :y [3 4]))
         (plot (drake-plot-pair :data data
                               :vars '(:x :y)
                               :buffer nil)))
    (should (drake-facet-plot-p plot))))

;;; Integration Tests

(ert-deftest drake-pair-with-title-test ()
  "Test pair plot with overall title."
  (let* ((data '(:x [1 2 3] :y [4 5 6]))
         (plot (drake-plot-pair :data data
                               :vars '(:x :y)
                               :title "My Pair Plot"
                               :buffer nil)))
    (should (drake-facet-plot-p plot))
    (should (equal (plist-get (drake-facet-plot-spec plot) :title) "My Pair Plot"))))

(ert-deftest drake-pair-backend-test ()
  "Test pair plot with different backends."
  (let* ((data '(:x [1 2 3] :y [4 5 6]))
         (plot (drake-plot-pair :data data
                               :vars '(:x :y)
                               :backend 'svg
                               :buffer nil)))
    (should (drake-facet-plot-p plot))))

(ert-deftest drake-pair-complex-scenario-test ()
  "Test pair plot with multiple features combined."
  (let* ((data '(:sepal_length [5.1 4.9 6.2 5.8]
                 :sepal_width [3.5 3.0 2.8 2.7]
                 :petal_length [1.4 1.4 4.5 5.1]
                 :species ["setosa" "setosa" "versicolor" "virginica"]))
         (plot (drake-plot-pair :data data
                               :vars '(:sepal_length :sepal_width :petal_length)
                               :hue :species
                               :kind 'scatter
                               :palette 'set1
                               :corner t
                               :title "Iris Pair Plot"
                               :buffer nil)))
    (should (drake-facet-plot-p plot))
    (should (= (drake-facet-plot-rows plot) 3))
    (should (= (drake-facet-plot-cols plot) 3))))

(provide 'pair-plot-tests)

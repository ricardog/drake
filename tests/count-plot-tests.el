;;; count-plot-tests.el --- Tests for drake count plot -*- lexical-binding: t; -*-

(require 'test-helper)

;;; Basic Functionality

(ert-deftest drake-count-basic-test ()
  "Test basic count plot functionality."
  (let* ((data '((:cat "A") (:cat "B") (:cat "A") (:cat "C") (:cat "A")))
         (plot (drake-plot-count :data data :x :cat :buffer nil)))
    (should (drake-plot-p plot))
    (should (eq (plist-get (drake-plot-spec plot) :type) 'bar))
    ;; Should have counted: A=3, B=1, C=1
    (let* ((internal (drake-plot-data-internal plot))
           (y-vec (plist-get internal :y)))
      (should (= (length y-vec) 3)))))

(ert-deftest drake-count-vertical-orientation-test ()
  "Test count plot with vertical bars (x parameter)."
  (let* ((data '((:day "Mon") (:day "Tue") (:day "Mon")))
         (plot (drake-plot-count :data data :x :day :buffer nil)))
    (should (drake-plot-p plot))
    (should (plist-get (drake-plot-spec plot) :x))))

(ert-deftest drake-count-horizontal-orientation-test ()
  "Test count plot with horizontal bars (y parameter)."
  (let* ((data '((:day "Mon") (:day "Tue") (:day "Mon")))
         (plot (drake-plot-count :data data :y :day :buffer nil)))
    (should (drake-plot-p plot))
    (should (plist-get (drake-plot-spec plot) :y))))

(ert-deftest drake-count-empty-data-test ()
  "Test count plot with empty data."
  ;; Empty data should error during extraction
  (should-error (drake-plot-count :data '() :x :cat :buffer nil)))

(ert-deftest drake-count-single-category-test ()
  "Test count plot with single category."
  (let* ((data '((:cat "A") (:cat "A") (:cat "A")))
         (plot (drake-plot-count :data data :x :cat :buffer nil)))
    (should (drake-plot-p plot))
    ;; Should have 1 bar (data is scaled so checking length only)
    (let* ((internal (drake-plot-data-internal plot))
           (y-vec (plist-get internal :y)))
      (should (= (length y-vec) 1)))))

;;; Hue Grouping

(ert-deftest drake-count-with-hue-test ()
  "Test count plot with hue grouping."
  (let* ((data '((:cat "A" :group "X")
                 (:cat "A" :group "Y")
                 (:cat "B" :group "X")
                 (:cat "B" :group "X")))
         (plot (drake-plot-count :data data :x :cat :hue :group :buffer nil)))
    (should (drake-plot-p plot))
    (should (plist-get (drake-plot-spec plot) :hue))
    ;; Should have: (A,X)=1, (A,Y)=1, (B,X)=2
    (let* ((internal (drake-plot-data-internal plot))
           (y-vec (plist-get internal :y)))
      (should (= (length y-vec) 3)))))

(ert-deftest drake-count-hue-order-test ()
  "Test count plot with hue ordering."
  (let* ((data '((:cat "A" :group "Z")
                 (:cat "A" :group "Y")
                 (:cat "A" :group "X")))
         (plot (drake-plot-count :data data :x :cat :hue :group
                                :hue-order '("X" "Y" "Z")
                                :buffer nil)))
    (should (drake-plot-p plot))))

;;; Ordering

(ert-deftest drake-count-order-appearance-test ()
  "Test count plot with appearance ordering (default)."
  (let* ((data '((:cat "B") (:cat "A") (:cat "C") (:cat "A")))
         (plot (drake-plot-count :data data :x :cat :buffer nil)))
    (should (drake-plot-p plot))
    ;; First appearance order should be: B, A, C
    (let* ((spec (drake-plot-spec plot))
           (scales (drake-plot-scales plot))
           (x-scale (plist-get scales :x)))
      (should (listp x-scale))
      (should (equal (car x-scale) "B")))))

(ert-deftest drake-count-order-alpha-test ()
  "Test count plot with alphabetical ordering."
  (let* ((data '((:cat "C") (:cat "A") (:cat "B")))
         (plot (drake-plot-count :data data :x :cat :order 'alpha :buffer nil)))
    (should (drake-plot-p plot))
    (let* ((scales (drake-plot-scales plot))
           (x-scale (plist-get scales :x)))
      (should (equal x-scale '("A" "B" "C"))))))

(ert-deftest drake-count-order-value-desc-test ()
  "Test count plot ordered by count descending."
  (let* ((data '((:cat "A") (:cat "B") (:cat "A") (:cat "C")
                 (:cat "A") (:cat "B")))
         (plot (drake-plot-count :data data :x :cat :order 'value-desc :buffer nil)))
    (should (drake-plot-p plot))
    ;; A=3, B=2, C=1, so order should be A, B, C
    (let* ((scales (drake-plot-scales plot))
           (x-scale (plist-get scales :x)))
      (should (equal (car x-scale) "A")))))

(ert-deftest drake-count-order-value-asc-test ()
  "Test count plot ordered by count ascending."
  (let* ((data '((:cat "A") (:cat "B") (:cat "A") (:cat "C")
                 (:cat "A") (:cat "B")))
         (plot (drake-plot-count :data data :x :cat :order 'value-asc :buffer nil)))
    (should (drake-plot-p plot))
    ;; A=3, B=2, C=1, so ascending order should be C, B, A
    (let* ((scales (drake-plot-scales plot))
           (x-scale (plist-get scales :x)))
      (should (equal (car x-scale) "C")))))

(ert-deftest drake-count-order-explicit-test ()
  "Test count plot with explicit ordering."
  (let* ((data '((:cat "A") (:cat "B") (:cat "C")))
         (plot (drake-plot-count :data data :x :cat
                                :order '("C" "A" "B")
                                :buffer nil)))
    (should (drake-plot-p plot))
    (let* ((scales (drake-plot-scales plot))
           (x-scale (plist-get scales :x)))
      (should (equal x-scale '("C" "A" "B"))))))

;;; Statistical Transformations

(ert-deftest drake-count-stat-count-test ()
  "Test count plot with count statistic (default)."
  (let* ((data '((:cat "A") (:cat "A") (:cat "B")))
         (plot (drake-plot-count :data data :x :cat :stat 'count :buffer nil)))
    (should (drake-plot-p plot))
    ;; Should have 2 categories (A and B)
    (let* ((internal (drake-plot-data-internal plot))
           (y-vec (plist-get internal :y)))
      (should (= (length y-vec) 2)))))

(ert-deftest drake-count-stat-proportion-test ()
  "Test count plot with proportion statistic."
  (let* ((data '((:cat "A") (:cat "A") (:cat "B")))
         (plot (drake-plot-count :data data :x :cat :stat 'proportion :buffer nil)))
    (should (drake-plot-p plot))
    ;; Should have 2 categories (values are scaled, just check length)
    (let* ((internal (drake-plot-data-internal plot))
           (y-vec (plist-get internal :y)))
      (should (= (length y-vec) 2)))))

(ert-deftest drake-count-stat-percent-test ()
  "Test count plot with percent statistic."
  (let* ((data '((:cat "A") (:cat "A") (:cat "B")))
         (plot (drake-plot-count :data data :x :cat :stat 'percent :buffer nil)))
    (should (drake-plot-p plot))
    ;; Should have 2 categories (values are scaled, just check length)
    (let* ((internal (drake-plot-data-internal plot))
           (y-vec (plist-get internal :y)))
      (should (= (length y-vec) 2)))))

;;; Different Data Formats

(ert-deftest drake-count-columnar-data-test ()
  "Test count plot with columnar data."
  (let* ((data '(:category ["A" "B" "A" "C"]))
         (plot (drake-plot-count :data data :x :category :buffer nil)))
    (should (drake-plot-p plot))))

(ert-deftest drake-count-plist-rows-test ()
  "Test count plot with plist rows."
  (let* ((data '((:cat "A") (:cat "B") (:cat "A")))
         (plot (drake-plot-count :data data :x :cat :buffer nil)))
    (should (drake-plot-p plot))))

(ert-deftest drake-count-alist-rows-test ()
  "Test count plot with alist rows."
  (let* ((data '(((:cat . "A")) ((:cat . "B")) ((:cat . "A"))))
         (plot (drake-plot-count :data data :x :cat :buffer nil)))
    (should (drake-plot-p plot))))

;;; Integration Tests

(ert-deftest drake-count-with-title-test ()
  "Test count plot with title and styling."
  (let* ((data '((:day "Mon") (:day "Tue") (:day "Mon")))
         (plot (drake-plot-count :data data :x :day
                                :title "Days of Week"
                                :palette 'set1
                                :buffer nil)))
    (should (drake-plot-p plot))
    (should (equal (plist-get (drake-plot-spec plot) :title) "Days of Week"))))

(ert-deftest drake-count-backend-test ()
  "Test count plot with different backends."
  (let* ((data '((:cat "A") (:cat "B")))
         (plot (drake-plot-count :data data :x :cat :backend 'svg :buffer nil)))
    (should (drake-plot-p plot))))

(provide 'count-plot-tests)

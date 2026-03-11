;;; drake-tests.el --- Tests for drake core -*- lexical-binding: t; -*-

(require 'test-helper)

(ert-deftest drake--ensure-vector-test ()
  (should (equal (drake--ensure-vector [1 2 3]) [1 2 3]))
  (should (equal (drake--ensure-vector '(1 2 3)) [1 2 3]))
  (should-error (drake--ensure-vector "not a sequence")))

(ert-deftest drake--normalize-data-row-based-test ()
  ;; Test converting list of lists (rows) to columnar vectors
  (let* ((data '((1 10) (2 20) (3 30)))
         (normalized (drake--normalize-data data '(:x 0 :y 1))))
    (should (equal (plist-get normalized :x) [1 2 3]))
    (should (equal (plist-get normalized :y) [10 20 30]))))

(ert-deftest drake--normalize-data-alist-test ()
  ;; Test converting list of alists to columnar vectors
  (let* ((data '(((:x . 1) (:y . 10) (:h . "a"))
                 ((:x . 2) (:y . 20) (:h . "b"))))
         (normalized (drake--normalize-data data '(:x :x :y :y :hue :h))))
    (should (equal (plist-get normalized :x) [1 2]))
    (should (equal (plist-get normalized :y) [10 20]))
    (should (equal (plist-get normalized :hue) ["a" "b"]))))

(ert-deftest drake--normalize-data-plist-rows-test ()
  ;; Test converting list of plists to columnar vectors
  (let* ((data '((:x 1 :y 10) (:x 2 :y 20)))
         (normalized (drake--normalize-data data '(:x :x :y :y))))
    (should (equal (plist-get normalized :x) [1 2]))
    (should (equal (plist-get normalized :y) [10 20]))))

(ert-deftest drake--detect-type-test ()
  (should (eq (drake--detect-type [1 2 3]) 'numeric))
  (should (eq (drake--detect-type ["a" "b" "c"]) 'categorical))
  (should (eq (drake--detect-type [1 "a" 3]) 'categorical)))

(ert-deftest drake--process-hue-test ()
  (let* ((hue-vec ["a" "b" "a"])
         (processed (drake--process-hue hue-vec nil))
         (values (plist-get processed :values))
         (map (plist-get processed :map)))
    (should (= (length values) 3))
    (should (equal (aref values 0) (aref values 2)))
    (should-not (equal (aref values 0) (aref values 1)))
    (should (assoc "a" map))
    (should (assoc "b" map))))

(ert-deftest drake-plot-line-smoke-test ()
  (let* ((data '(:x [1 2 3] :y [10 20 30]))
         (plot (drake-plot-line :data data :x :x :y :y)))
    (should (drake-plot-p plot))
    (should (eq (plist-get (drake-plot-spec plot) :type) 'line))))

(ert-deftest drake-plot-bar-smoke-test ()
  (let* ((data '(:x ["A" "B"] :y [10 20]))
         (plot (drake-plot-bar :data data :x :x :y :y)))
    (should (drake-plot-p plot))
    (should (eq (plist-get (drake-plot-spec plot) :type) 'bar))))

(ert-deftest drake-save-plot-test ()
  (let* ((data '(:x [1 2 3] :y [10 20 30]))
         (plot (drake-plot-scatter :data data :x :x :y :y))
         (temp-file (make-temp-file "drake-save-test-" nil ".svg")))
    (unwind-protect
        (progn
          (drake-save-plot plot temp-file)
          (should (file-exists-p temp-file))
          (with-temp-buffer
            (insert-file-contents temp-file)
            (goto-char (point-min))
            (should (re-search-forward "<svg" nil t))))
      (when (file-exists-p temp-file)
        (delete-file temp-file)))))

(ert-deftest drake-current-plot-buffer-local-test ()
  (let* ((data '(:x [1 2 3] :y [10 20 30]))
         (buffer-name "*drake-test-buffer*")
         (plot (drake-plot-scatter :data data :x :x :y :y :buffer buffer-name)))
    (with-current-buffer buffer-name
      (should (eq drake-current-plot plot)))
    (when (get-buffer buffer-name)
      (kill-buffer buffer-name))))

(ert-deftest drake--extract-column-missing-key-test ()
  (let ((data '(:x [1 2 3])))
    (should-error (drake--extract-column data :nonexistent)
                  :type 'error))
  (let ((data '(((:x . 1)))))
    (should-error (drake--extract-column data :nonexistent)
                  :type 'error))
  (let ((data '((:x 1))))
    (should-error (drake--extract-column data :nonexistent)
                  :type 'error))
  (let ((data '((1))))
    (should-error (drake--extract-column data 1)
                  :type 'error)))

(provide 'drake-tests)

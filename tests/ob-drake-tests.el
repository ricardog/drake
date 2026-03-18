;;; ob-drake-tests.el --- Tests for ob-drake org-babel integration -*- lexical-binding: t; -*-

;;; Commentary:
;; Tests for Drake org-babel integration

;;; Code:

(require 'ert)
(require 'ob-drake)
(require 'drake)
(require 'drake-svg)

;; Disable confirmation prompts for batch testing
(setq org-confirm-babel-evaluate nil)

(defvar drake-test-iris-data
  '(:sepal_length [5.1 4.9 4.7 4.6 5.0]
    :sepal_width [3.5 3.0 3.2 3.1 3.6]
    :species ["setosa" "setosa" "setosa" "setosa" "setosa"])
  "Small iris dataset for testing.")

;;; Basic Execution Tests

(ert-deftest ob-drake-basic-execution-test ()
  "Test basic Drake code block execution."
  (let ((temp-file (make-temp-file "drake-test" nil ".svg")))
    (unwind-protect
        (progn
          (with-temp-buffer
            (org-mode)
            (insert (format "#+BEGIN_SRC drake :file %s\n" temp-file))
            (insert "(drake-plot-scatter :data drake-test-iris-data :x :sepal_length :y :sepal_width)\n")
            (insert "#+END_SRC\n")
            (goto-char (point-min))
            (forward-line)
            (let ((result (org-babel-execute-src-block)))
              (should (string= result temp-file))
              (should (file-exists-p temp-file)))))
      (when (file-exists-p temp-file)
        (delete-file temp-file)))))

(ert-deftest ob-drake-without-file-error-test ()
  "Test that executing without :file parameter gives helpful error."
  (with-temp-buffer
    (org-mode)
    (insert "#+BEGIN_SRC drake\n")
    (insert "(drake-plot-scatter :data drake-test-iris-data :x :sepal_length :y :sepal_width)\n")
    (insert "#+END_SRC\n")
    (goto-char (point-min))
    (forward-line)
    (should-error (org-babel-execute-src-block)
                  :type 'error)))

(ert-deftest ob-drake-expand-body-test ()
  "Test body expansion with variable assignments."
  (let* ((params '((:var . ((mydata . ((1 2 3) (4 5 6)))))))
         (body "(message \"test\")")
         (expanded (org-babel-expand-body:drake body params)))
    (should (string-match-p "(setq mydata" expanded))
    (should (string-match-p "(message \"test\")" expanded))))

;;; Session Tests

(ert-deftest ob-drake-session-initiation-test ()
  "Test Drake session buffer creation."
  (let ((session-buf (org-babel-drake-initiate-session "*test-drake-session*" nil)))
    (unwind-protect
        (progn
          (should (buffer-live-p session-buf))
          (should (string= (buffer-name session-buf) "*test-drake-session*"))
          (with-current-buffer session-buf
            (should (string-match-p "Drake session" (buffer-string)))))
      (when (buffer-live-p session-buf)
        (kill-buffer session-buf)))))

(ert-deftest ob-drake-session-persistence-test ()
  "Test that variables persist across blocks in a session."
  (let ((session-name "*drake-test-session*")
        (temp-file (make-temp-file "drake-test" nil ".svg"))
        (session-buf nil))
    (unwind-protect
        (progn
          ;; First block: set variable (no graphics output)
          (with-temp-buffer
            (org-mode)
            (insert (format "#+BEGIN_SRC drake :session %s :results silent\n" session-name))
            (insert "(setq test-data drake-test-iris-data)\n")
            (insert "#+END_SRC\n")
            (goto-char (point-min))
            (forward-line)
            (org-babel-execute-src-block))

          ;; Second block: use variable
          (with-temp-buffer
            (org-mode)
            (insert (format "#+BEGIN_SRC drake :session %s :file %s\n" session-name temp-file))
            (insert "(drake-plot-scatter :data test-data :x :sepal_length :y :sepal_width)\n")
            (insert "#+END_SRC\n")
            (goto-char (point-min))
            (forward-line)
            (let ((result (org-babel-execute-src-block)))
              (should (string= result temp-file))
              (should (file-exists-p temp-file))))

          (setq session-buf (get-buffer session-name))
          (should (buffer-live-p session-buf)))
      (when (file-exists-p temp-file)
        (delete-file temp-file))
      (when (and session-buf (buffer-live-p session-buf))
        (kill-buffer session-buf)))))

;;; Header Arguments Tests

(ert-deftest ob-drake-theme-header-arg-test ()
  "Test :theme header argument expansion."
  (let* ((params '((:theme . dark)))
         (body "(message \"test\")")
         (expanded (org-babel-expand-body:drake body params)))
    (should (string-match-p "(drake-set-theme 'dark)" expanded))))

(ert-deftest ob-drake-palette-header-arg-test ()
  "Test :palette header argument expansion."
  (let* ((params '((:palette . viridis)))
         (body "(message \"test\")")
         (expanded (org-babel-expand-body:drake body params)))
    (should (string-match-p "(setq drake-default-palette 'viridis)" expanded))))

(ert-deftest ob-drake-var-header-arg-test ()
  "Test :var header argument with variable passing."
  (let* ((params '((:var . ((x . 10) (y . 20)))))
         (body "(+ x y)")
         (expanded (org-babel-expand-body:drake body params)))
    (should (string-match-p "(setq x 10)" expanded))
    (should (string-match-p "(setq y 20)" expanded))
    (should (string-match-p (regexp-quote "(+ x y)") expanded))))

;;; Plot ID Registry Tests

(ert-deftest ob-drake-plot-id-registration-test ()
  "Test that plots with :id are registered."
  (let ((temp-file (make-temp-file "drake-test" nil ".svg")))
    (clrhash drake-org-plot-registry) ;; Clean registry
    (unwind-protect
        (progn
          (with-temp-buffer
            (org-mode)
            (insert (format "#+BEGIN_SRC drake :file %s :id test-plot\n" temp-file))
            (insert "(drake-plot-scatter :data drake-test-iris-data :x :sepal_length :y :sepal_width)\n")
            (insert "#+END_SRC\n")
            (goto-char (point-min))
            (forward-line)
            (org-babel-execute-src-block))

          (should (gethash "test-plot" drake-org-plot-registry))
          (let ((info (gethash "test-plot" drake-org-plot-registry)))
            (should (string= (plist-get info :file) temp-file))))
      (when (file-exists-p temp-file)
        (delete-file temp-file))
      (clrhash drake-org-plot-registry))))

(ert-deftest ob-drake-clear-registry-test ()
  "Test clearing plot registry."
  (puthash "test-1" '(:file "test1.svg") drake-org-plot-registry)
  (puthash "test-2" '(:file "test2.svg") drake-org-plot-registry)
  (should (> (hash-table-count drake-org-plot-registry) 0))

  (drake-org-clear-plot-registry)
  (should (= (hash-table-count drake-org-plot-registry) 0)))

;;; Link Tests

(ert-deftest ob-drake-link-export-html-test ()
  "Test drake: link export to HTML."
  (let ((result (drake-org-link-export "file:plot.svg" "My Plot" 'html)))
    (should (string-match-p "<img src=\"plot.svg\"" result))
    (should (string-match-p "alt=\"My Plot\"" result))))

(ert-deftest ob-drake-link-export-latex-test ()
  "Test drake: link export to LaTeX."
  (let ((result (drake-org-link-export "file:plot.svg" "My Plot" 'latex)))
    (should (string-match-p "\\\\includegraphics" result))
    (should (string-match-p "plot.svg" result))))

(ert-deftest ob-drake-link-export-markdown-test ()
  "Test drake: link export to Markdown."
  (let ((result (drake-org-link-export "file:plot.svg" "My Plot" 'md)))
    (should (string-match-p "!\\[My Plot\\]" result))
    (should (string-match-p "(plot.svg)" result))))

;;; Error Handling Tests

(ert-deftest ob-drake-invalid-code-error-test ()
  "Test error handling for invalid Drake code."
  (with-temp-buffer
    (org-mode)
    (insert "#+BEGIN_SRC drake :file test.svg\n")
    (insert "(this-function-does-not-exist)\n")
    (insert "#+END_SRC\n")
    (goto-char (point-min))
    (forward-line)
    ;; Execution should fail with an error
    (should-error (org-babel-execute-src-block) :type 'error)))

;;; Template Tests

(ert-deftest ob-drake-tempo-templates-loaded-test ()
  "Test that org-tempo templates are registered."
  (when (featurep 'org-tempo)
    (should (assoc "drake" org-structure-template-alist))
    (should (assoc "dscatter" org-structure-template-alist))
    (should (assoc "dline" org-structure-template-alist))
    (should (assoc "dbar" org-structure-template-alist))))

;;; Integration Test

(ert-deftest ob-drake-full-workflow-test ()
  "Test complete workflow: load data, create plot, verify output."
  (let ((temp-file (make-temp-file "drake-test" nil ".svg")))
    (unwind-protect
        (progn
          (with-temp-buffer
            (org-mode)
            ;; Create a complete org document
            (insert "#+TITLE: Test Document\n\n")
            (insert "* Data\n")
            (insert (format "#+BEGIN_SRC drake :file %s :backend svg\n" temp-file))
            (insert "(drake-plot-scatter :data drake-test-iris-data\n")
            (insert "                   :x :sepal_length\n")
            (insert "                   :y :sepal_width\n")
            (insert "                   :title \"Test Plot\")\n")
            (insert "#+END_SRC\n")

            ;; Execute
            (goto-char (point-min))
            (re-search-forward "BEGIN_SRC")
            (let ((result (org-babel-execute-src-block)))
              (should (string= result temp-file))
              (should (file-exists-p temp-file))

              ;; Verify SVG content
              (with-temp-buffer
                (insert-file-contents temp-file)
                (should (string-match-p "<svg" (buffer-string)))
                (should (string-match-p "Test Plot" (buffer-string)))))))
      (when (file-exists-p temp-file)
        (delete-file temp-file)))))

(provide 'ob-drake-tests)

;;; ob-drake-tests.el ends here

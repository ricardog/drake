;;; test-helper.el --- Helper for drake tests -*- lexical-binding: t; -*-

(add-to-list 'load-path (expand-file-name ".." (file-name-directory (or load-file-name (buffer-file-name)))))
(add-to-list 'load-path "/root/src/duckdb-el")

(require 'drake)
(require 'drake-svg)
(require 'drake-gnuplot)
(require 'ert)

;; Load Rust module if available
(when (require 'drake-rust nil t)
  (condition-case err
      (drake-rust-load-module)
    (error (message "Rust module not available: %s" err))))

;; Mock image functions for headless environments
(unless (image-type-available-p 'svg)
  (defun image-type-available-p (type)
    (if (eq type 'svg) t (ert-fail "Unexpected image type check")))
  (defun image-type (obj)
    (if (and (listp obj) (eq (car obj) 'image))
        (plist-get (cdr obj) :type)
      (if (string-match "<svg" obj) 'svg (ert-fail "Not an SVG string"))))
  (defun create-image (file-or-data &optional type data-p &rest props)
    (list 'image :type (or type 'svg) :data file-or-data))
  (defun imagep (obj)
    (and (listp obj) (eq (car obj) 'image)))
  (defun insert-image (img &optional string area slice) t)
  (defun display-buffer (buf &optional action frame) t))

(defun drake-test-get-image-type (img)
  "Extract image type from IMG (image descriptor or mock)."
  (if (and (listp img) (eq (car img) 'image))
      (plist-get (cdr img) :type)
    ;; Fallback for cases where it's a real image object but built-in image-type fails
    (if (fboundp 'image-property)
        (image-property img :type)
      (ert-fail (format "Cannot determine image type of %S" img)))))

(require 'cl-lib)

(defmacro drake-skip-unless-gnuplot ()
  "Skip the current ERT test unless gnuplot backend is available."
  `(unless (gethash 'gnuplot drake--backends)
     (ert-skip "Gnuplot backend not available")))

(provide 'test-helper)

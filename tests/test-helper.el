;;; test-helper.el --- Helper for drake tests -*- lexical-binding: t; -*-

(add-to-list 'load-path (expand-file-name ".." (file-name-directory (or load-file-name (buffer-file-name)))))
(add-to-list 'load-path "/root/src/duckdb-el")

(require 'drake)
(require 'drake-svg)
(require 'drake-gnuplot)
(require 'ert)

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

(require 'cl-lib)

(defmacro drake-skip-unless-gnuplot ()
  "Skip the current ERT test unless gnuplot backend is available."
  `(unless (gethash 'gnuplot drake--backends)
     (ert-skip "Gnuplot backend not available")))

(provide 'test-helper)

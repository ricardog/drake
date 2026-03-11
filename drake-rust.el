;;; drake-rust.el --- Rust backend for drake -*- lexical-binding: t; -*-

(require 'drake)

(defun drake-rust-load-module ()
  "Load the Rust module."
  (unless (featurep 'drake-rust-module)
    (condition-case nil
        (require 'drake-rust-module)
      (error
       ;; Fallback to local file if not in load-path
       (let ((module-file (expand-file-name "drake-rust-module.so" (file-name-directory (or load-file-name default-directory)))))
         (if (file-exists-p module-file)
             (module-load module-file)
           (error "Rust module drake-rust-module.so not found")))))))

(defun drake-rust-render (plot)
  "Render PLOT using the Rust backend."
  (drake-rust-load-module)
  (let* ((spec (drake-plot-spec plot))
         (width (or (plist-get spec :width) drake-default-width))
         (height (or (plist-get spec :height) drake-default-height))
         (xml (drake-rust-module/render plot)))
    (setf (drake-plot-svg-xml plot) xml)
    (condition-case nil
        (create-image xml 'svg t :width width :height height)
      (error (list 'image :type 'svg :data xml)))))

;; Register the backend
(drake-register-backend
 (make-drake-backend
  :name 'rust
  :render-fn #'drake-rust-render
  :supported-types '(scatter line bar hist box violin lm smooth)
  :capabilities '(:high-performance t :vector-data t)))

(provide 'drake-rust)

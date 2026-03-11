;;; drake-rust.el --- Rust backend for drake -*- lexical-binding: t; -*-

(require 'drake)

(defgroup drake-rust nil
  "Rust backend for drake."
  :group 'drake)

(defcustom drake-module-cmake-args ""
  "Arguments given to CMake to compile the drake-rust module."
  :type 'string
  :group 'drake-rust)

(defcustom drake-always-compile-module nil
  "If non-nil, compile the Rust module without asking if it is missing."
  :type 'boolean
  :group 'drake-rust)

(defvar drake-install-buffer-name " *Install drake-rust* "
  "Name of the buffer used for compiling the drake-rust module.")

(defun drake-module--cmake-is-available ()
  "Return t if cmake is available."
  (executable-find "cmake"))

(defun drake-module--cargo-is-available ()
  "Return t if cargo is available."
  (executable-find "cargo"))

(defun drake-module-compile ()
  "Compile the drake-rust module."
  (interactive)
  (cond
   ((not (drake-module--cmake-is-available))
    (error "drake-rust needs CMake to be compiled. Please install CMake"))
   ((not (drake-module--cargo-is-available))
    (error "drake-rust needs Cargo to be compiled. Please install Rust/Cargo"))
   (t
    (let* ((drake-directory
            (file-name-directory (locate-library "drake.el" t)))
           (build-commands
            (concat
             "cd " (shell-quote-argument drake-directory) "; "
             "mkdir -p build; "
             "cd build; "
             "cmake -G 'Unix Makefiles' " drake-module-cmake-args " ..; "
             "cmake --build . --target build; "))
           (buffer (get-buffer-create drake-install-buffer-name)))
      (with-current-buffer buffer
        (let ((inhibit-read-only t))
          (erase-buffer))
        (message "Compiling drake-rust module in %s..." drake-directory)
        (if (zerop (let ((inhibit-read-only t))
                     (call-process "sh" nil buffer t "-c" build-commands)))
            (message "Compilation of `drake-rust' module succeeded")
          (with-current-buffer buffer
            (message "Compilation log: %s" (buffer-string)))
          (error "Compilation of `drake-rust' module failed! See buffer %s" drake-install-buffer-name)))))))

(defun drake-rust-load-module ()
  "Load the Rust module, compiling it if necessary."
  (unless (featurep 'drake-rust-module)
    (condition-case nil
        (require 'drake-rust-module)
      (error
       ;; Fallback to local file if not in load-path
       (let* ((drake-dir (file-name-directory (locate-library "drake.el" t)))
              (module-file (expand-file-name "drake-rust-module.so" drake-dir)))
         (unless (file-exists-p module-file)
           (if (and (drake-module--cmake-is-available)
                    (drake-module--cargo-is-available)
                    (or drake-always-compile-module
                        (y-or-n-p "drake-rust module not found. Compile it now? ")))
               (drake-module-compile)
             (error "Rust module drake-rust-module.so not found and could not be compiled")))
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

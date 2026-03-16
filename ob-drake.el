;;; ob-drake.el --- Org-babel support for Drake plotting -*- lexical-binding: t; -*-

;; Copyright (C) 2024-2026

;; Author: Drake Contributors
;; Keywords: org, babel, plotting, visualization
;; Version: 1.0.0
;; Package-Requires: ((emacs "27.1") (org "9.0"))

;; This file is part of Drake.

;;; Commentary:

;; Org-babel integration for Drake statistical plotting library.
;; Enables execution of Drake code in org-mode source blocks with
;; support for file output, sessions, variable passing, and inline display.
;;
;; Basic usage:
;;
;;   #+BEGIN_SRC drake :file plot.svg
;;   (drake-plot-scatter :data iris :x :sepal_length :y :sepal_width)
;;   #+END_SRC
;;
;; See ORG_INTEGRATION.md for comprehensive documentation.

;;; Code:

(require 'ob)
(require 'ob-ref)
(require 'ob-comint)
(require 'ob-eval)

;; Declare drake functions to avoid compiler warnings
(declare-function drake-plot-scatter "drake")
(declare-function drake-plot-line "drake")
(declare-function drake-plot-bar "drake")
(declare-function drake-save-plot "drake")
(declare-function drake-plot-p "drake")
(declare-function drake-plot-svg-xml "drake")
(declare-function drake-facet-plot-p "drake")
(declare-function drake-facet-plot-svg-xml "drake")

;;; Configuration

(defvar org-babel-default-header-args:drake
  '((:results . "file graphics")
    (:exports . "both")
    (:eval . "never-export"))
  "Default header arguments for Drake code blocks.

:results - \"file graphics\" outputs a file link
:exports - \"both\" exports code and results
:eval - \"never-export\" prevents execution during export")

(defvar drake-org-plot-registry (make-hash-table :test 'equal)
  "Registry mapping plot IDs to their locations and files.
Used for custom drake: links.")

;;; Core Execution

(defun org-babel-execute:drake (body params)
  "Execute Drake code BODY with org-babel PARAMS.

Supported header arguments:
  :file - Output filename (required for graphics)
  :width - Plot width in pixels
  :height - Plot height in pixels
  :backend - Drake backend (svg, gnuplot, rust)
  :theme - Drake theme name
  :palette - Color palette name or list
  :session - Named session for persistent environment
  :var - Variable assignments from other blocks
  :id - Plot ID for drake: link registry

Returns the output file path for graphics results, or the plot
object for value results."
  (require 'drake)

  (let* ((session (cdr (assq :session params)))
         (result-type (cdr (assq :result-type params)))
         (result-params (cdr (assq :result-params params)))
         (full-body (org-babel-expand-body:drake body params))
         (output-file (cdr (assq :file params)))
         (plot-id (cdr (assq :id params))))

    ;; Validate required parameters for graphics output
    (when (and (or (member "file" result-params)
                   (member "graphics" result-params))
               (not output-file))
      (error "Drake graphics output requires :file parameter"))

    ;; Execute code
    (let ((result
           (if (and session (not (string= session "none")))
               (org-babel-drake-evaluate-session session full-body result-type)
             (org-babel-drake-evaluate full-body result-type))))

      ;; Handle file output
      (when output-file
        ;; Result should be a plot object
        (condition-case err
            (progn
              ;; Extract SVG XML from plot object
              (let ((xml (cond
                          ((drake-plot-p result) (drake-plot-svg-xml result))
                          ((drake-facet-plot-p result) (drake-facet-plot-svg-xml result))
                          (t nil))))
                (if xml
                    (with-temp-file output-file
                      (insert xml))
                  (error "Plot does not contain SVG XML data")))

              ;; Register plot if it has an ID
              (when plot-id
                (puthash plot-id
                        (list :file output-file
                              :location (point)
                              :timestamp (current-time))
                        drake-org-plot-registry))
              ;; Return file path for org link
              (setq result output-file))
          (error
           (error "Failed to save Drake plot: %s" (error-message-string err)))))

      result)))

(defun org-babel-expand-body:drake (body params)
  "Expand Drake code BODY by applying variable assignments from PARAMS.

Injects :var parameters as (setq VAR VALUE) forms before the body."
  (let* ((vars (org-babel--get-vars params))
         (backend (cdr (assq :backend params)))
         (theme (cdr (assq :theme params)))
         (palette (cdr (assq :palette params)))
         (width (cdr (assq :width params)))
         (height (cdr (assq :height params)))
         (prologue ""))

    ;; Build prologue with variable assignments
    (when vars
      (setq prologue
            (concat prologue
                    (mapconcat
                     (lambda (var-spec)
                       ;; var-spec can be (name . value) or a list of such pairs
                       (if (and (listp var-spec)
                                (consp (car var-spec))
                                (not (keywordp (car var-spec))))
                           ;; List of pairs: ((x . 10) (y . 20))
                           (mapconcat
                            (lambda (pair)
                              (format "(setq %s %S)" (car pair) (cdr pair)))
                            var-spec
                            "\n")
                         ;; Simple pair: (x . 10)
                         (format "(setq %s %S)" (car var-spec) (cdr var-spec))))
                     vars
                     "\n")
                    "\n")))

    ;; Add theme/palette settings if specified
    (when theme
      (setq prologue
            (concat prologue
                    (format "(drake-set-theme '%s)\n" theme))))

    (when palette
      (setq prologue
            (concat prologue
                    (format "(setq drake-default-palette '%s)\n" palette))))

    ;; Return expanded body
    (concat prologue body)))

;;; Evaluation Functions

(defun org-babel-drake-evaluate (body result-type)
  "Evaluate Drake code BODY without a session.

RESULT-TYPE determines whether to return the value or output.
Creates a clean evaluation context with Drake loaded."
  (condition-case err
      (let ((print-level nil)
            (print-length nil))
        (eval (car (read-from-string body)) t))
    (error
     (format "Drake execution error: %s\n\nCode:\n%s"
             (error-message-string err)
             body))))

(defun org-babel-drake-evaluate-session (session body result-type)
  "Evaluate Drake code BODY in persistent SESSION.

SESSION is a buffer name. RESULT-TYPE determines output format.
Maintains state across multiple code blocks for interactive analysis."
  (let ((session-buf (org-babel-drake-initiate-session session)))
    (with-current-buffer session-buf
      (goto-char (point-max))

      ;; Insert and evaluate code
      (let ((start (point)))
        (insert body "\n")
        (condition-case err
            (let ((print-level nil)
                  (print-length nil))
              ;; Evaluate code in session
              (eval-region start (point))
              ;; Return value of last expression
              (eval (car (read-from-string
                         (buffer-substring-no-properties start (point))))
                   t))
          (error
           (format "Drake session error: %s" (error-message-string err))))))))

(defun org-babel-drake-initiate-session (&optional session _params)
  "Create or return Drake session buffer named SESSION.

If SESSION is nil, returns the default session *drake-session*.
Sessions maintain persistent environments across code blocks."
  (let ((session-name (or session "*drake-session*")))
    (or (get-buffer session-name)
        (save-window-excursion
          (let ((buf (get-buffer-create session-name)))
            (with-current-buffer buf
              (emacs-lisp-mode)
              ;; Load Drake in session
              (eval '(require 'drake) t)
              (insert (format ";; Drake session: %s\n" session-name))
              (insert ";; Initialized at " (current-time-string) "\n\n"))
            buf)))))

(defun org-babel-prep-session:drake (session params)
  "Prepare Drake SESSION with PARAMS.

Initializes the session and evaluates any preamble code."
  (let ((session-buf (org-babel-drake-initiate-session session params)))
    (with-current-buffer session-buf
      ;; Evaluate any :prologue code
      (let ((prologue (cdr (assq :prologue params))))
        (when prologue
          (goto-char (point-max))
          (insert prologue "\n")
          (eval-region (point) (point-max)))))
    session-buf))

;;; Link Support

(defun drake-org-link-follow (path)
  "Follow a drake: link to PATH.

Supports:
  drake:file:path/to/plot.svg - Opens the file
  drake:BLOCK-NAME - Jumps to named src block
  drake:var:VARNAME - Shows plot from session variable
  drake:PLOT-ID - Shows registered plot by ID"
  (cond
   ;; File reference
   ((string-prefix-p "file:" path)
    (let ((file (substring path 5)))
      (if (file-exists-p file)
          (find-file file)
        (error "Drake plot file not found: %s" file))))

   ;; Variable reference in session
   ((string-prefix-p "var:" path)
    (let ((var-name (intern (substring path 4))))
      (message "Drake plot variable: %s (session access not yet implemented)" var-name)))

   ;; Named block reference
   ((save-excursion
      (goto-char (point-min))
      (re-search-forward (format "^[ \t]*#\\+NAME:[ \t]*%s[ \t]*$" (regexp-quote path)) nil t))
    (goto-char (match-beginning 0))
    (org-show-context))

   ;; Plot ID reference
   ((gethash path drake-org-plot-registry)
    (let* ((info (gethash path drake-org-plot-registry))
           (file (plist-get info :file)))
      (if (file-exists-p file)
          (find-file file)
        (error "Drake plot file not found: %s" file))))

   (t
    (error "Unknown drake link: %s" path))))

(defun drake-org-link-export (path desc format)
  "Export drake: link PATH with description DESC for FORMAT.

Resolves named blocks and IDs to their output files, then exports
as appropriate image syntax for HTML, LaTeX, or Markdown."
  (let ((file
         (cond
          ;; Direct file reference
          ((string-prefix-p "file:" path)
           (substring path 5))

          ;; Named block - find its :file parameter
          ((save-excursion
             (goto-char (point-min))
             (when (re-search-forward
                    (format "^[ \t]*#\\+NAME:[ \t]*%s[ \t]*$" (regexp-quote path))
                    nil t)
               (forward-line)
               (when (looking-at "^[ \t]*#\\+BEGIN_SRC[ \t]+drake")
                 (let ((info (org-babel-get-src-block-info)))
                   (cdr (assq :file (nth 2 info))))))))

          ;; Plot ID from registry
          ((gethash path drake-org-plot-registry)
           (plist-get (gethash path drake-org-plot-registry) :file))

          ;; Fallback
          (t path))))

    ;; Export as image
    (pcase format
      ('html
       (format "<img src=\"%s\" alt=\"%s\" />" file (or desc "Drake plot")))
      ('latex
       (format "\\includegraphics[width=0.8\\textwidth]{%s}" file))
      ('md
       (format "![%s](%s)" (or desc "Drake plot") file))
      (_
       (or desc file)))))

(defun drake-org-link-complete ()
  "Provide completion for drake: links.

Returns available plots from:
  - Named drake code blocks
  - Registered plot IDs
  - Plot files in current directory"
  (let ((completions nil))

    ;; Add registered plot IDs
    (maphash (lambda (k _v) (push k completions))
             drake-org-plot-registry)

    ;; Add named drake blocks
    (save-excursion
      (goto-char (point-min))
      (while (re-search-forward "^[ \t]*#\\+NAME:[ \t]*\\([^ \t\n]+\\)" nil t)
        (let ((name (match-string 1)))
          (forward-line)
          (when (looking-at "^[ \t]*#\\+BEGIN_SRC[ \t]+drake")
            (push name completions)))))

    ;; Add SVG files in current directory
    (dolist (file (directory-files "." nil "\\.svg\\'"))
      (push (concat "file:" file) completions))

    (concat "drake:" (completing-read "Drake plot: " completions))))

;; Register drake: link type
(with-eval-after-load 'org
  (org-link-set-parameters "drake"
                           :follow #'drake-org-link-follow
                           :export #'drake-org-link-export
                           :complete #'drake-org-link-complete
                           :face '(:foreground "purple" :underline t)))

;;; Interactive Commands

(defun drake-org-update-plot-at-point ()
  "Re-execute Drake code block at point and update inline image.

Useful for iterative plot development within org documents."
  (interactive)
  (if (org-in-src-block-p)
      (progn
        (org-babel-execute-src-block)
        (org-display-inline-images nil t)
        (message "Drake plot updated"))
    (user-error "Not in a source block")))

(defun drake-org-clear-plot-registry ()
  "Clear the drake plot ID registry.

Useful when plot IDs have become stale after reorganizing an org document."
  (interactive)
  (clrhash drake-org-plot-registry)
  (message "Drake plot registry cleared"))

;;; Inline Display Hook

(defun drake-org-display-inline-images-maybe ()
  "Display inline images after executing Drake code blocks.

Automatically shows plots without requiring manual refresh."
  (when (and (eq major-mode 'org-mode)
             (boundp 'org-babel-current-src-block-language)
             (string= org-babel-current-src-block-language "drake"))
    (org-display-inline-images nil t)))

(add-hook 'org-babel-after-execute-hook #'drake-org-display-inline-images-maybe)

;;; Org-tempo Templates

(with-eval-after-load 'org-tempo
  ;; Basic drake template
  (add-to-list 'org-structure-template-alist
               '("drake" . "src drake :file plot.svg"))

  ;; Scatter plot template
  (add-to-list 'org-structure-template-alist
               '("dscatter" . "src drake :file scatter.svg\n(drake-plot-scatter :data DATA :x :X :y :Y)"))

  ;; Line plot template
  (add-to-list 'org-structure-template-alist
               '("dline" . "src drake :file line.svg\n(drake-plot-line :data DATA :x :X :y :Y)"))

  ;; Bar plot template
  (add-to-list 'org-structure-template-alist
               '("dbar" . "src drake :file bar.svg\n(drake-plot-bar :data DATA :x :X :y :Y)")))

;;; Footer

(provide 'ob-drake)

;;; ob-drake.el ends here

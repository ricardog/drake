;;; drake-palette-browser.el --- Interactive palette browser for drake -*- lexical-binding: t; -*-

;; Author: Ricardo G. <ricardo@example.com>
;; Keywords: data, visualization, color, palettes

;;; Commentary:
;; This module provides an interactive palette browser with visual
;; previews and management features for drake color palettes.

;;; Code:

(require 'drake)
(require 'cl-lib)

;;; Improved Palette Fetching

(defun drake-fetch-palettes-async (callback)
  "Fetch palettes asynchronously and call CALLBACK when done.
CALLBACK is called with (success-p num-palettes error-message)."
  (require 'url)
  (url-retrieve
   drake-palette-url
   (lambda (status)
     (let ((error-msg (plist-get status :error)))
       (if error-msg
           (funcall callback nil 0 (format "Network error: %s" error-msg))
         (condition-case err
             (progn
               (goto-char (point-min))
               (re-search-forward "^$" nil t)
               (let* ((json-object-type 'alist)
                      (raw-data (json-read))
                      (processed nil))
                 (dolist (entry raw-data)
                   (let* ((name (symbol-name (car entry)))
                          (data (cdr entry))
                          (max-k (apply #'max (mapcar (lambda (k-entry)
                                                        (if (string-match "^[0-9]+$" (symbol-name (car k-entry)))
                                                            (string-to-number (symbol-name (car k-entry)))
                                                          0))
                                                      data)))
                          (colors (cdr (assoc (intern (number-to-string max-k)) data))))
                     (when (vectorp colors)
                       (push (cons (intern (downcase name)) (append colors nil)) processed))))
                 (setq drake--palette-cache processed)
                 ;; Save to cache file
                 (let ((cache-dir (expand-file-name "drake" user-emacs-directory)))
                   (unless (file-exists-p cache-dir) (make-directory cache-dir t))
                   (with-temp-file (expand-file-name "palettes-cache.el" cache-dir)
                     (insert ";;; Generated drake palettes cache\n")
                     (insert (format "(setq drake--palette-cache '%S)" processed))))
                 (funcall callback t (length processed) nil)))
           (error
            (funcall callback nil 0 (format "Parse error: %s" (error-message-string err))))))))))

(defun drake-fetch-palettes-improved ()
  "Fetch and cache additional palettes with improved error handling.
This function provides better feedback and handles errors gracefully."
  (interactive)
  (if (not (require 'url nil t))
      (message "Error: url library not available")
    (message "Fetching palettes from %s..." drake-palette-url)
    (drake-fetch-palettes-async
     (lambda (success num-palettes error-msg)
       (if success
           (progn
             (message "Successfully fetched and cached %d palettes!" num-palettes)
             (when (get-buffer "*Drake Palette Browser*")
               (with-current-buffer "*Drake Palette Browser*"
                 (drake-palette-browser-refresh))))
         (message "Failed to fetch palettes: %s" error-msg)
         (when (y-or-n-p "Would you like to view the cache file location? ")
           (let ((cache-dir (expand-file-name "drake" user-emacs-directory)))
             (message "Cache directory: %s" cache-dir)
             (when (y-or-n-p "Open cache directory? ")
               (dired cache-dir)))))))))

;;; Palette Browser UI

(defvar drake-palette-browser-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "RET") 'drake-palette-browser-apply)
    (define-key map (kbd "a") 'drake-palette-browser-apply)
    (define-key map (kbd "c") 'drake-palette-browser-copy-name)
    (define-key map (kbd "f") 'drake-palette-browser-fetch)
    (define-key map (kbd "r") 'drake-palette-browser-refresh)
    (define-key map (kbd "s") 'drake-palette-browser-search)
    (define-key map (kbd "n") 'drake-palette-browser-next)
    (define-key map (kbd "p") 'drake-palette-browser-prev)
    (define-key map (kbd "q") 'quit-window)
    (define-key map (kbd "?") 'drake-palette-browser-help)
    map)
  "Keymap for Drake Palette Browser mode.")

(define-derived-mode drake-palette-browser-mode special-mode "Drake-Palettes"
  "Major mode for browsing Drake color palettes.

\\{drake-palette-browser-mode-map}"
  (setq truncate-lines t)
  (setq buffer-read-only t))

(defun drake-palette-browser ()
  "Open the Drake palette browser."
  (interactive)
  (let ((buf (get-buffer-create "*Drake Palette Browser*")))
    (with-current-buffer buf
      (drake-palette-browser-mode)
      (drake-palette-browser-refresh))
    (switch-to-buffer buf)))

(defun drake-palette-browser-refresh ()
  "Refresh the palette browser display."
  (interactive)
  (let ((inhibit-read-only t)
        (line (line-number-at-pos))
        (col (current-column)))
    (erase-buffer)

    ;; Header
    (insert (propertize "Drake Palette Browser\n" 'face '(:height 1.5 :weight bold)))
    (insert (propertize (make-string 70 ?=) 'face 'shadow) "\n\n")

    ;; Stats
    (drake--load-cache-if-needed)
    (let ((bundled (length drake--bundled-palettes))
          (cached (length drake--palette-cache))
          (user (length drake--user-palettes)))
      (insert (format "Bundled: %d  |  Cached: %d  |  User: %d  |  Total: %d\n\n"
                     bundled cached user (+ bundled cached user))))

    ;; Help
    (insert (propertize "Commands: " 'face 'bold))
    (insert "[RET/a]pply  [c]opy  [f]etch  [r]efresh  [s]earch  [n]ext  [p]rev  [q]uit  [?]help\n")
    (insert (make-string 70 ?-) "\n\n")

    ;; Display palettes
    (drake-palette-browser--display-section "Bundled Palettes" drake--bundled-palettes)
    (when drake--palette-cache
      (insert "\n")
      (drake-palette-browser--display-section "Cached Palettes" drake--palette-cache))
    (when drake--user-palettes
      (insert "\n")
      (drake-palette-browser--display-section "User Palettes" drake--user-palettes))

    ;; Footer
    (insert "\n" (make-string 70 ?-) "\n")
    (insert (propertize "Tip: " 'face 'bold))
    (insert "Press RET on a palette to apply it as the default for new plots.\n")

    ;; Restore position
    (goto-char (point-min))
    (forward-line (1- line))
    (move-to-column col)))

(defun drake-palette-browser--display-section (title palettes)
  "Display a section with TITLE showing PALETTES."
  (insert (propertize title 'face '(:weight bold :underline t)) "\n\n")
  (dolist (entry (sort (copy-sequence palettes)
                      (lambda (a b) (string< (symbol-name (car a))
                                            (symbol-name (car b))))))
    (let ((name (car entry))
          (colors (cdr entry)))
      (insert (propertize (format "  %-20s " (symbol-name name))
                         'drake-palette-name name
                         'face '(:weight bold)))

      ;; Display color swatches
      (dolist (color colors)
        (insert (propertize "  "
                           'face `(:background ,color)
                           'display '(space :width (3))))
        (insert (propertize " " 'face 'default)))

      ;; Add color count
      (insert (propertize (format " (%d colors)" (length colors))
                         'face 'shadow))
      (insert "\n"))))

(defun drake-palette-browser-apply ()
  "Apply the palette at point as the default theme palette."
  (interactive)
  (let ((name (get-text-property (point) 'drake-palette-name)))
    (if name
        (progn
          (let ((theme (drake-get-current-theme)))
            (setf (drake-theme-palette theme) name)
            (message "Applied palette '%s' to current theme (%s)"
                    name (drake-theme-name theme))))
      (message "No palette at point"))))

(defun drake-palette-browser-copy-name ()
  "Copy the name of the palette at point to the kill ring."
  (interactive)
  (let ((name (get-text-property (point) 'drake-palette-name)))
    (if name
        (progn
          (kill-new (symbol-name name))
          (message "Copied palette name: %s" name))
      (message "No palette at point"))))

(defun drake-palette-browser-fetch ()
  "Fetch additional palettes from the web."
  (interactive)
  (drake-fetch-palettes-improved))

(defun drake-palette-browser-search ()
  "Search for palettes by name."
  (interactive)
  (let* ((search-term (read-string "Search palettes: "))
         (all-palettes (append drake--bundled-palettes
                              drake--palette-cache
                              drake--user-palettes))
         (matches (cl-remove-if-not
                   (lambda (entry)
                     (string-match-p (regexp-quote search-term)
                                   (symbol-name (car entry))))
                   all-palettes)))
    (if matches
        (let ((inhibit-read-only t))
          (erase-buffer)
          (insert (propertize "Search Results\n" 'face '(:height 1.5 :weight bold)))
          (insert (propertize (make-string 70 ?=) 'face 'shadow) "\n\n")
          (insert (format "Found %d palette(s) matching '%s'\n\n"
                         (length matches) search-term))
          (insert (propertize "Commands: " 'face 'bold))
          (insert "[RET/a]pply  [c]opy  [r]efresh to exit search\n")
          (insert (make-string 70 ?-) "\n\n")
          (drake-palette-browser--display-section "Matching Palettes" matches))
      (message "No palettes found matching '%s'" search-term))))

(defun drake-palette-browser-next ()
  "Move to next palette."
  (interactive)
  (let ((pos (point)))
    (forward-line 1)
    (while (and (not (eobp))
                (not (get-text-property (point) 'drake-palette-name)))
      (forward-line 1))
    (when (not (get-text-property (point) 'drake-palette-name))
      (goto-char pos))))

(defun drake-palette-browser-prev ()
  "Move to previous palette."
  (interactive)
  (let ((pos (point)))
    (forward-line -1)
    (while (and (not (bobp))
                (not (get-text-property (point) 'drake-palette-name)))
      (forward-line -1))
    (when (not (get-text-property (point) 'drake-palette-name))
      (goto-char pos))))

(defun drake-palette-browser-help ()
  "Show help for palette browser."
  (interactive)
  (let ((help-text
         "Drake Palette Browser Help
=============================

Navigation:
  n, ↓        Move to next palette
  p, ↑        Move to previous palette

Actions:
  RET, a      Apply palette to current theme
  c           Copy palette name to kill ring
  f           Fetch additional palettes from web
  r           Refresh display
  s           Search palettes by name
  q           Quit browser

Palette Types:
  Bundled     Built-in palettes included with Drake
  Cached      Palettes fetched from ColorBrewer (via 'f')
  User        Custom palettes registered via drake-register-palette

Tips:
  - Use 'f' to download 100+ additional ColorBrewer palettes
  - Palettes are cached locally in ~/.emacs.d/drake/
  - Apply a palette to set it as default for current theme
  - Use :palette argument in plots to override theme default

Examples:
  (drake-plot-scatter ... :palette 'viridis)
  (drake-register-palette 'my-colors '(\"#ff0000\" \"#00ff00\"))
"))
    (with-help-window "*Drake Palette Browser Help*"
      (princ help-text))))

;;; Palette Preview

(defun drake-palette-preview (palette-name)
  "Show a visual preview of PALETTE-NAME."
  (interactive
   (list (intern (completing-read "Preview palette: "
                                   (append (mapcar #'car drake--bundled-palettes)
                                          (mapcar #'car drake--palette-cache)
                                          (mapcar #'car drake--user-palettes))
                                   nil t))))
  (let* ((colors (drake--get-palette palette-name))
         (n-colors (length colors))
         (buf (get-buffer-create "*Drake Palette Preview*")))
    (with-current-buffer buf
      (let ((inhibit-read-only t))
        (erase-buffer)
        (special-mode)

        (insert (propertize (format "Palette: %s\n" palette-name)
                           'face '(:height 1.3 :weight bold)))
        (insert (make-string 60 ?=) "\n\n")

        ;; Large color swatches
        (insert (propertize "Color Swatches:\n" 'face 'bold))
        (dotimes (i n-colors)
          (let ((color (nth i colors)))
            (insert (propertize (format " %d " (1+ i))
                               'face `(:background ,color :foreground ,(drake-palette-preview--contrast-color color))
                               'display '(space :width (6) :height (3))))
            (insert " ")))
        (insert "\n\n")

        ;; Hex codes
        (insert (propertize "Hex Codes:\n" 'face 'bold))
        (dotimes (i n-colors)
          (insert (format "%2d: %s\n" (1+ i) (nth i colors))))
        (insert "\n")

        ;; Usage example
        (insert (propertize "Usage:\n" 'face 'bold))
        (insert (format "(drake-plot-scatter :data data :x :x :y :y :palette '%s)\n" palette-name))
        (insert "\n")

        ;; Apply button
        (insert-button "Apply to Current Theme"
                      'action (lambda (_)
                               (let ((theme (drake-get-current-theme)))
                                 (setf (drake-theme-palette theme) palette-name)
                                 (message "Applied palette '%s' to theme '%s'"
                                         palette-name (drake-theme-name theme))))
                      'follow-link t)
        (insert "  ")
        (insert-button "Copy Name"
                      'action (lambda (_)
                               (kill-new (symbol-name palette-name))
                               (message "Copied: %s" palette-name))
                      'follow-link t)))
    (display-buffer buf)))

(defun drake-palette-preview--contrast-color (bg-color)
  "Return black or white depending on BG-COLOR luminance."
  (let* ((rgb (color-name-to-rgb bg-color))
         (r (nth 0 rgb))
         (g (nth 1 rgb))
         (b (nth 2 rgb))
         (luminance (+ (* 0.299 r) (* 0.587 g) (* 0.114 b))))
    (if (> luminance 0.5) "#000000" "#ffffff")))

;;; Palette Management

(defun drake-palette-export (palette-name filename)
  "Export PALETTE-NAME to FILENAME as a list of hex codes."
  (interactive
   (list (intern (completing-read "Export palette: "
                                   (append (mapcar #'car drake--bundled-palettes)
                                          (mapcar #'car drake--palette-cache)
                                          (mapcar #'car drake--user-palettes))
                                   nil t))
         (read-file-name "Export to file: " nil nil nil "palette.txt")))
  (let ((colors (drake--get-palette palette-name)))
    (with-temp-file filename
      (insert (format "# Drake Palette: %s\n" palette-name))
      (insert (format "# %d colors\n\n" (length colors)))
      (dolist (color colors)
        (insert color "\n")))
    (message "Exported palette '%s' to %s" palette-name filename)))

(defun drake-palette-import (filename palette-name)
  "Import palette from FILENAME and register it as PALETTE-NAME."
  (interactive
   (list (read-file-name "Import palette from: ")
         (intern (read-string "Palette name: "))))
  (let ((colors nil))
    (with-temp-buffer
      (insert-file-contents filename)
      (goto-char (point-min))
      (while (re-search-forward "^\\(#[0-9a-fA-F]\\{6\\}\\)" nil t)
        (push (match-string 1) colors)))
    (setq colors (nreverse colors))
    (if colors
        (progn
          (drake-register-palette palette-name colors)
          (message "Imported palette '%s' with %d colors" palette-name (length colors)))
      (error "No valid hex colors found in %s" filename))))

;;; Integration

(defun drake-palette-browser-quick-select ()
  "Quick palette selection with completion and preview."
  (interactive)
  (drake--load-cache-if-needed)
  (let* ((all-palettes (append (mapcar #'car drake--bundled-palettes)
                              (mapcar #'car drake--palette-cache)
                              (mapcar #'car drake--user-palettes)))
         (palette (intern (completing-read "Select palette: " all-palettes nil t))))
    (drake-palette-preview palette)
    (when (y-or-n-p (format "Apply '%s' to current theme? " palette))
      (let ((theme (drake-get-current-theme)))
        (setf (drake-theme-palette theme) palette)
        (message "Applied palette '%s' to theme '%s'"
                palette (drake-theme-name theme))))))

(provide 'drake-palette-browser)
;;; drake-palette-browser.el ends here

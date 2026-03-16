;;; tests/palette-browser-tests.el --- Tests for drake palette browser -*- lexical-binding: t; -*-

(require 'test-helper)
(require 'drake)
(require 'drake-palette-browser)

(ert-deftest drake-palette-browser-load-test ()
  "Test that palette browser loads correctly."
  (should (fboundp 'drake-palette-browser))
  (should (fboundp 'drake-palette-preview))
  (should (fboundp 'drake-palette-browser-quick-select)))

(ert-deftest drake-palette-get-bundled-test ()
  "Test retrieving bundled palettes."
  (let ((viridis (drake--get-palette 'viridis))
        (plasma (drake--get-palette 'plasma)))
    (should (listp viridis))
    (should (> (length viridis) 0))
    (should (listp plasma))
    (should (> (length plasma) 0))
    (should (string-match "^#[0-9a-fA-F]\\{6\\}$" (car viridis)))))

(ert-deftest drake-palette-register-test ()
  "Test registering custom palettes."
  (let ((custom-colors '("#ff0000" "#00ff00" "#0000ff")))
    (drake-register-palette 'test-custom custom-colors)
    (let ((retrieved (drake--get-palette 'test-custom)))
      (should (equal retrieved custom-colors)))
    ;; Clean up
    (setq drake--user-palettes
          (assq-delete-all 'test-custom drake--user-palettes))))

(ert-deftest drake-palette-list-colors-test ()
  "Test that palette colors are valid hex codes."
  (dolist (entry drake--bundled-palettes)
    (let ((name (car entry))
          (colors (cdr entry)))
      (should (symbolp name))
      (should (listp colors))
      (should (> (length colors) 0))
      (dolist (color colors)
        (should (stringp color))
        (should (string-match "^#[0-9a-fA-F]\\{6\\}$" color))))))

(ert-deftest drake-palette-export-import-test ()
  "Test exporting and importing palettes."
  (let* ((temp-file (make-temp-file "drake-palette-test" nil ".txt"))
         (test-palette-name 'test-export)
         (test-colors '("#123456" "#abcdef" "#fedcba")))

    ;; Register test palette
    (drake-register-palette test-palette-name test-colors)

    ;; Export it
    (drake-palette-export test-palette-name temp-file)
    (should (file-exists-p temp-file))

    ;; Import it as a new palette
    (drake-palette-import temp-file 'test-import)

    ;; Verify imported palette
    (let ((imported (drake--get-palette 'test-import)))
      (should (equal imported test-colors)))

    ;; Clean up
    (delete-file temp-file)
    (setq drake--user-palettes
          (assq-delete-all test-palette-name drake--user-palettes))
    (setq drake--user-palettes
          (assq-delete-all 'test-import drake--user-palettes))))

(ert-deftest drake-palette-preview-contrast-test ()
  "Test contrast color calculation for palette preview."
  (should (string= (drake-palette-preview--contrast-color "#ffffff") "#000000"))
  (should (string= (drake-palette-preview--contrast-color "#000000") "#ffffff"))
  (should (string= (drake-palette-preview--contrast-color "#ff0000") "#ffffff"))
  (should (string= (drake-palette-preview--contrast-color "#ffff00") "#000000")))

(ert-deftest drake-palette-browser-buffer-test ()
  "Test that palette browser creates a buffer."
  (drake-palette-browser)
  (should (get-buffer "*Drake Palette Browser*"))
  (with-current-buffer "*Drake Palette Browser*"
    (should (eq major-mode 'drake-palette-browser-mode))
    (should (string-match "Drake Palette Browser" (buffer-string)))
    (should (string-match "Bundled Palettes" (buffer-string))))
  ;; Clean up
  (kill-buffer "*Drake Palette Browser*"))

(ert-deftest drake-palette-preview-buffer-test ()
  "Test that palette preview creates a buffer."
  (drake-palette-preview 'viridis)
  (should (get-buffer "*Drake Palette Preview*"))
  (with-current-buffer "*Drake Palette Preview*"
    (should (string-match "Palette: viridis" (buffer-string)))
    (should (string-match "Color Swatches:" (buffer-string)))
    (should (string-match "Hex Codes:" (buffer-string))))
  ;; Clean up
  (kill-buffer "*Drake Palette Preview*"))

(ert-deftest drake-palette-apply-to-theme-test ()
  "Test applying a palette to current theme."
  (let ((original-theme drake-current-theme))
    (drake-set-theme 'default)
    (let ((theme (drake-get-current-theme)))
      ;; Apply viridis palette
      (setf (drake-theme-palette theme) 'viridis)
      (should (eq (drake-theme-palette theme) 'viridis))

      ;; Verify it's used
      (let ((colors (drake--get-palette nil)))
        (should (equal colors (cdr (assoc 'viridis drake--bundled-palettes))))))

    ;; Restore original theme
    (drake-set-theme original-theme)))

(ert-deftest drake-palette-cache-persistence-test ()
  "Test palette cache persistence."
  (let ((cache-dir (expand-file-name "drake" user-emacs-directory))
        (cache-file (expand-file-name "drake/palettes-cache.el" user-emacs-directory)))

    ;; Ensure directory exists
    (unless (file-exists-p cache-dir)
      (make-directory cache-dir t))

    ;; Create test cache
    (let ((test-cache '((test-palette1 . ("#111111" "#222222"))
                       (test-palette2 . ("#333333" "#444444")))))
      (with-temp-file cache-file
        (insert ";;; Generated drake palettes cache\n")
        (insert (format "(setq drake--palette-cache '%S)" test-cache)))

      ;; Clear in-memory cache and reload
      (setq drake--palette-cache nil)
      (drake--load-cache-if-needed)

      ;; Verify cache was loaded
      (should drake--palette-cache)
      (should (assoc 'test-palette1 drake--palette-cache))
      (should (assoc 'test-palette2 drake--palette-cache)))))

(ert-deftest drake-palette-direct-list-test ()
  "Test using a direct list of colors as a palette."
  (let* ((custom-list '("#aabbcc" "#ddeeff" "#112233"))
         (result (drake--get-palette custom-list)))
    (should (equal result custom-list))))

(ert-deftest drake-palette-color-manager-test ()
  "Test color manager assigns colors correctly."
  (let* ((values '("A" "B" "C"))
         (color-map (drake--color-manager values 'viridis)))
    (should (= (length color-map) 3))
    (should (assoc "A" color-map))
    (should (assoc "B" color-map))
    (should (assoc "C" color-map))
    (dolist (entry color-map)
      (should (string-match "^#[0-9a-fA-F]\\{6\\}$" (cdr entry))))))

(provide 'palette-browser-tests)
;;; palette-browser-tests.el ends here

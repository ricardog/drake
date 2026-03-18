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

;; Issue #1: Test that cached palettes are displayed
(ert-deftest drake-palette-cached-palettes-display-test ()
  "Test that cached palettes are visible in the browser."
  ;; Set up a mock cache with RGB format colors (like ColorBrewer)
  (let ((drake--palette-cache '((testrgb . ("rgb(255,0,0)" "rgb(0,255,0)" "rgb(0,0,255)")))))
    (drake-palette-browser)
    (should (get-buffer "*Drake Palette Browser*"))
    (with-current-buffer "*Drake Palette Browser*"
      ;; Should display cached section when cache exists
      (should (string-match "Cached Palettes" (buffer-string)))
      ;; Should show the palette name
      (should (string-match "testrgb" (buffer-string))))
    (kill-buffer "*Drake Palette Browser*")))

(ert-deftest drake-palette-rgb-to-hex-conversion-test ()
  "Test that RGB colors are properly converted to hex for display."
  (should (equal (drake-palette-browser--rgb-to-hex "rgb(255,0,0)") "#ff0000"))
  (should (equal (drake-palette-browser--rgb-to-hex "rgb(0,255,0)") "#00ff00"))
  (should (equal (drake-palette-browser--rgb-to-hex "rgb(0,0,255)") "#0000ff"))
  (should (equal (drake-palette-browser--rgb-to-hex "rgb(128,128,128)") "#808080"))
  (should (equal (drake-palette-browser--rgb-to-hex "rgb(255,255,255)") "#ffffff"))
  (should (equal (drake-palette-browser--rgb-to-hex "rgb(0,0,0)") "#000000"))
  ;; Hex colors should pass through unchanged
  (should (equal (drake-palette-browser--rgb-to-hex "#abcdef") "#abcdef")))

(ert-deftest drake-palette-fetched-colors-are-hex-test ()
  "Test that fetched palette colors are normalized to hex format."
  ;; Set up cache with RGB format
  (let ((drake--palette-cache '((blues . ("rgb(247,251,255)" "rgb(222,235,247)"))
                                 (reds . ("#ff0000" "#ee0000")))))
    (drake--load-cache-if-needed)
    ;; Get palette - should convert RGB to hex
    (let ((blues-colors (drake--get-palette 'blues))
          (reds-colors (drake--get-palette 'reds)))
      ;; All colors should be valid hex
      (dolist (color blues-colors)
        (should (string-match "^#[0-9a-fA-F]\\{6\\}$" color)))
      (dolist (color reds-colors)
        (should (string-match "^#[0-9a-fA-F]\\{6\\}$" color))))))

;; Issue #2: Test that color swatches have visible width
(ert-deftest drake-palette-swatch-width-test ()
  "Test that color swatches are rendered with visible width."
  (drake-palette-browser)
  (with-current-buffer "*Drake Palette Browser*"
    ;; Look for color swatch display
    (goto-char (point-min))
    ;; Search for palette name line
    (should (search-forward "viridis" nil t))
    ;; Check that swatches use visible characters (not just display property)
    ;; The implementation should use multiple characters like "█" or "  " per swatch
    (let ((line-start (line-beginning-position))
          (line-end (line-end-position)))
      (goto-char line-start)
      ;; Should find swatch characters on the palette line
      (should (re-search-forward "[█▓▒░]\\|  " line-end t))))
  (kill-buffer "*Drake Palette Browser*"))

(ert-deftest drake-palette-swatch-rendering-consistency-test ()
  "Test that swatch rendering works across platforms."
  ;; Test the swatch rendering function directly
  (let ((swatch (drake-palette-browser--render-swatch "#ff0000")))
    (should (stringp swatch))
    (should (> (length swatch) 0))
    ;; Swatch should have a background color face property
    (should (get-text-property 0 'face swatch))))

(provide 'palette-browser-tests)
;;; palette-browser-tests.el ends here

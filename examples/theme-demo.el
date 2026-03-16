;;; theme-demo.el --- Demonstration of drake theming system -*- lexical-binding: t; -*-

;;; Commentary:
;; This file demonstrates the drake theming system, showing how to:
;; 1. Use built-in themes
;; 2. Automatically detect Emacs theme
;; 3. Compare themes side-by-side

;;; Code:

(require 'drake)
(require 'drake-theme)

(defun drake-theme-demo-data ()
  "Generate demo data for theme comparisons."
  (list
   :simple '(:x [1 2 3 4 5 6 7 8 9 10]
             :y [2.3 4.1 5.8 7.2 8.9 10.5 12.1 13.8 15.2 16.9])
   :categorical '(:x ["Mon" "Tue" "Wed" "Thu" "Fri" "Sat" "Sun"]
                  :y [23 45 56 78 34 67 89])
   :grouped '(:x ["Q1" "Q1" "Q2" "Q2" "Q3" "Q3" "Q4" "Q4"]
              :y [100 120 150 160 180 170 200 210]
              :hue ["Product A" "Product B" "Product A" "Product B"
                    "Product A" "Product B" "Product A" "Product B"])))

(defun drake-theme-demo-basic ()
  "Demonstrate basic theme switching."
  (interactive)
  (let ((data (plist-get (drake-theme-demo-data) :simple)))

    ;; Default theme
    (drake-set-theme 'default)
    (drake-plot-scatter :data data :x :x :y :y :title "Default Theme" :backend 'svg)

    ;; Dark theme
    (drake-set-theme 'dark)
    (drake-plot-scatter :data data :x :x :y :y :title "Dark Theme" :backend 'svg)

    ;; Light theme
    (drake-set-theme 'light)
    (drake-plot-scatter :data data :x :x :y :y :title "Light Theme" :backend 'svg)

    ;; Minimal theme
    (drake-set-theme 'minimal)
    (drake-plot-scatter :data data :x :x :y :y :title "Minimal Theme" :backend 'svg)

    ;; Seaborn theme
    (drake-set-theme 'seaborn)
    (drake-plot-scatter :data data :x :x :y :y :title "Seaborn Theme" :backend 'svg)

    ;; Reset to default
    (drake-set-theme 'default)))

(defun drake-theme-demo-palettes ()
  "Demonstrate theme palettes with grouped data."
  (interactive)
  (let ((data (plist-get (drake-theme-demo-data) :grouped)))

    ;; Default palette
    (drake-set-theme 'default)
    (drake-plot-bar :data data :x :x :y :y :hue :hue
                   :title "Default Palette" :backend 'svg)

    ;; Dark theme with viridis
    (drake-set-theme 'dark)
    (drake-plot-bar :data data :x :x :y :y :hue :hue
                   :title "Dark Theme (Viridis Palette)" :backend 'svg)

    ;; Solarized light
    (drake-set-theme 'solarized-light)
    (drake-plot-bar :data data :x :x :y :y :hue :hue
                   :title "Solarized Light" :backend 'svg)

    ;; Solarized dark
    (drake-set-theme 'solarized-dark)
    (drake-plot-bar :data data :x :x :y :y :hue :hue
                   :title "Solarized Dark" :backend 'svg)

    ;; Reset to default
    (drake-set-theme 'default)))

(defun drake-theme-demo-auto ()
  "Demonstrate automatic theme detection."
  (interactive)
  (let ((data (plist-get (drake-theme-demo-data) :simple)))
    (message "Current Emacs background mode: %s" (drake-detect-background-mode))
    (message "Current Emacs theme: %s" (drake-detect-emacs-theme-name))

    ;; Let drake automatically select appropriate theme
    (drake-auto-theme)

    (drake-plot-scatter :data data :x :x :y :y
                       :title (format "Auto-selected: %s" drake-current-theme)
                       :backend 'svg)))

(defun drake-theme-demo-comparison ()
  "Create a comprehensive comparison of all themes."
  (interactive)
  (let ((data (plist-get (drake-theme-demo-data) :categorical))
        (themes '(default light dark minimal seaborn solarized-light solarized-dark high-contrast)))

    (dolist (theme themes)
      (drake-set-theme theme)
      (drake-plot-bar :data data :x :x :y :y
                     :title (format "%s Theme" (capitalize (symbol-name theme)))
                     :xlabel "Day of Week"
                     :ylabel "Sales ($)"
                     :backend 'svg))

    ;; Reset to default
    (drake-set-theme 'default)
    (message "Theme comparison complete!")))

(defun drake-theme-demo-custom ()
  "Demonstrate creating a custom theme."
  (interactive)
  (let ((data (plist-get (drake-theme-demo-data) :simple))
        (custom-theme (make-drake-theme
                      :name 'custom-retro
                      :background "#f5f5dc"  ; Beige
                      :foreground "#2f4f4f"  ; Dark slate gray
                      :grid-color "#d3d3d3"  ; Light gray
                      :grid-style 'dashed
                      :grid-width 1
                      :axis-color "#2f4f4f"
                      :axis-width 2
                      :text-color "#2f4f4f"
                      :font-family "serif"
                      :font-size 11
                      :palette '(("#8b4513" "#cd853f" "#daa520" "#b8860b"
                                 "#808000" "#6b8e23" "#556b2f" "#2e8b57"))
                      :legend-bg "#f5f5dc"
                      :legend-border "#2f4f4f"
                      :legend-opacity 0.95)))

    (drake-set-theme custom-theme)
    (drake-plot-scatter :data data :x :x :y :y
                       :title "Custom Retro Theme"
                       :xlabel "X Values"
                       :ylabel "Y Values"
                       :backend 'svg)

    ;; Show the custom theme is now available
    (message "Custom theme '%s' is now available!" (drake-theme-name custom-theme))
    (message "Available themes: %s" (mapconcat #'symbol-name (drake-list-themes) ", "))

    ;; Reset to default
    (drake-set-theme 'default)))

(defun drake-theme-demo-backends ()
  "Demonstrate themes work across all backends."
  (interactive)
  (let ((data (plist-get (drake-theme-demo-data) :simple)))

    ;; Use dark theme
    (drake-set-theme 'dark)

    ;; SVG backend
    (drake-plot-scatter :data data :x :x :y :y
                       :title "Dark Theme - SVG Backend"
                       :backend 'svg)

    ;; Gnuplot backend
    (when (gethash 'gnuplot drake--backends)
      (drake-plot-scatter :data data :x :x :y :y
                         :title "Dark Theme - Gnuplot Backend"
                         :backend 'gnuplot))

    ;; Rust backend
    (when (gethash 'rust drake--backends)
      (drake-plot-scatter :data data :x :x :y :y
                         :title "Dark Theme - Rust Backend"
                         :backend 'rust))

    ;; Reset to default
    (drake-set-theme 'default)))

(defun drake-theme-demo-all ()
  "Run all theme demonstrations."
  (interactive)
  (message "\n=== Drake Theme System Demo ===\n")

  (message "1. Basic theme switching...")
  (drake-theme-demo-basic)
  (sit-for 1)

  (message "2. Theme palettes...")
  (drake-theme-demo-palettes)
  (sit-for 1)

  (message "3. Automatic theme detection...")
  (drake-theme-demo-auto)
  (sit-for 1)

  (message "4. Custom theme...")
  (drake-theme-demo-custom)
  (sit-for 1)

  (message "5. Cross-backend support...")
  (drake-theme-demo-backends)

  (message "\n=== Demo Complete ===")
  (message "Try these commands:")
  (message "  - (drake-set-theme 'dark)")
  (message "  - (drake-set-theme 'solarized-light)")
  (message "  - (drake-auto-theme)")
  (message "  - (drake-list-themes)")
  (message "  - (drake-preview-theme 'dark)"))

;; Interactive helper
(defun drake-theme-interactive-selector ()
  "Interactively preview and select a theme."
  (interactive)
  (let* ((themes (drake-list-themes))
         (theme (intern (completing-read "Select theme (preview with TAB): "
                                        themes nil t))))
    (drake-preview-theme theme)
    (when (y-or-n-p (format "Apply theme '%s'? " theme))
      (drake-set-theme theme)
      (message "Theme '%s' applied!" theme))))

(provide 'theme-demo)
;;; theme-demo.el ends here

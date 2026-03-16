;;; palette-demo.el --- Demonstration of drake palette system -*- lexical-binding: t; -*-

;;; Commentary:
;; This file demonstrates the drake palette system and palette browser.

;;; Code:

(require 'drake)
(require 'drake-palette-browser)

(defun drake-palette-demo-data ()
  "Generate demo data for palette demonstrations."
  (list
   :categorical '(:x ["Q1" "Q1" "Q2" "Q2" "Q3" "Q3" "Q4" "Q4"]
                  :y [100 120 150 160 180 170 200 210]
                  :group ["North" "South" "North" "South" "North" "South" "North" "South"])
   :multigroup '(:x ["Jan" "Jan" "Jan" "Feb" "Feb" "Feb" "Mar" "Mar" "Mar"]
                 :y [45 52 61 48 55 63 51 58 67]
                 :product ["A" "B" "C" "A" "B" "C" "A" "B" "C"])))

(defun drake-palette-demo-comparison ()
  "Compare different palettes visually."
  (interactive)
  (let ((data (plist-get (drake-palette-demo-data) :categorical))
        (palettes '(viridis magma plasma inferno set1 set2 dark2 paired)))

    (message "Generating palette comparison plots...")

    (dolist (palette palettes)
      (drake-plot-bar :data data
                     :x :x
                     :y :y
                     :hue :group
                     :palette palette
                     :title (format "Palette: %s" (capitalize (symbol-name palette)))
                     :xlabel "Quarter"
                     :ylabel "Revenue ($M)"
                     :backend 'svg)
      (sit-for 0.5))

    (message "Palette comparison complete!")))

(defun drake-palette-demo-browser ()
  "Demonstrate the palette browser."
  (interactive)
  (message "\n=== Drake Palette Browser Demo ===\n")
  (message "Opening palette browser...")
  (drake-palette-browser)
  (message "\nBrowser Commands:")
  (message "  [RET/a] - Apply palette to current theme")
  (message "  [c]     - Copy palette name")
  (message "  [f]     - Fetch additional palettes from web")
  (message "  [r]     - Refresh display")
  (message "  [s]     - Search palettes")
  (message "  [n/p]   - Navigate next/previous")
  (message "  [q]     - Quit browser")
  (message "  [?]     - Show help"))

(defun drake-palette-demo-preview ()
  "Demonstrate palette preview functionality."
  (interactive)
  (message "Previewing various palettes...")

  ;; Preview sequential palettes
  (dolist (palette '(viridis magma plasma))
    (drake-palette-preview palette)
    (message "Preview: %s (sequential, perceptually uniform)" palette)
    (sit-for 2))

  ;; Preview categorical palettes
  (dolist (palette '(set1 set2 dark2))
    (drake-palette-preview palette)
    (message "Preview: %s (categorical, distinct colors)" palette)
    (sit-for 2))

  (message "Preview demo complete!"))

(defun drake-palette-demo-custom ()
  "Demonstrate creating and using custom palettes."
  (interactive)
  (message "Creating custom palettes...")

  ;; Custom brand colors
  (drake-register-palette 'brand-colors
                         '("#1a5490" "#e84a27" "#f39c12" "#27ae60" "#8e44ad"))

  ;; Custom pastel palette
  (drake-register-palette 'pastels
                         '("#ffb3ba" "#bae1ff" "#baffc9" "#ffffba" "#ffdfba"))

  ;; Custom monochrome
  (drake-register-palette 'monochrome
                         '("#000000" "#404040" "#808080" "#c0c0c0" "#ffffff"))

  (message "Registered 3 custom palettes: brand-colors, pastels, monochrome")

  ;; Demonstrate custom palette
  (let ((data (plist-get (drake-palette-demo-data) :multigroup)))
    (drake-plot-bar :data data
                   :x :x
                   :y :y
                   :hue :product
                   :palette 'brand-colors
                   :title "Sales by Product (Custom Brand Colors)"
                   :xlabel "Month"
                   :ylabel "Sales"
                   :backend 'svg))

  (message "\nCustom palettes are now available in the browser!"))

(defun drake-palette-demo-export-import ()
  "Demonstrate exporting and importing palettes."
  (interactive)
  (let ((temp-dir (make-temp-file "drake-palette-demo-" t)))
    (message "Exporting palettes to %s..." temp-dir)

    ;; Export some built-in palettes
    (drake-palette-export 'viridis (expand-file-name "viridis.txt" temp-dir))
    (drake-palette-export 'set1 (expand-file-name "set1.txt" temp-dir))

    (message "Exported 2 palettes")
    (message "Files created:")
    (message "  - %s" (expand-file-name "viridis.txt" temp-dir))
    (message "  - %s" (expand-file-name "set1.txt" temp-dir))

    ;; Import them back with new names
    (drake-palette-import (expand-file-name "viridis.txt" temp-dir) 'viridis-copy)
    (message "Imported viridis as 'viridis-copy'")

    ;; Clean up
    (when (y-or-n-p "Open export directory? ")
      (dired temp-dir))))

(defun drake-palette-demo-quick-select ()
  "Demonstrate quick palette selection."
  (interactive)
  (message "Opening quick palette selector...")
  (message "This provides:")
  (message "  - Completion-based selection")
  (message "  - Instant preview")
  (message "  - One-click apply to theme")
  (sit-for 2)
  (drake-palette-browser-quick-select))

(defun drake-palette-demo-search ()
  "Demonstrate palette search functionality."
  (interactive)
  (message "Palette search allows you to filter by keyword.")
  (message "Try searching for:")
  (message "  - 'blue' - finds Blues, RdBu, etc.")
  (message "  - 'div' - finds diverging palettes")
  (message "  - 'seq' - finds sequential palettes")
  (sit-for 2)
  (drake-palette-browser)
  (with-current-buffer "*Drake Palette Browser*"
    (message "Press 's' to search")))

(defun drake-palette-demo-themed ()
  "Demonstrate how palettes work with themes."
  (interactive)
  (let ((data (plist-get (drake-palette-demo-data) :categorical)))

    (message "Each theme has a default palette...")

    ;; Dark theme uses viridis by default
    (drake-set-theme 'dark)
    (message "Dark theme -> viridis palette (perceptually uniform)")
    (drake-plot-bar :data data :x :x :y :y :hue :group
                   :title "Dark Theme (Default Palette)"
                   :backend 'svg)
    (sit-for 2)

    ;; Light theme uses set1 by default
    (drake-set-theme 'light)
    (message "Light theme -> set1 palette (categorical)")
    (drake-plot-bar :data data :x :x :y :y :hue :group
                   :title "Light Theme (Default Palette)"
                   :backend 'svg)
    (sit-for 2)

    ;; Override with explicit palette
    (message "Can override with :palette argument")
    (drake-plot-bar :data data :x :x :y :y :hue :group
                   :palette 'plasma
                   :title "Light Theme + Plasma Palette"
                   :backend 'svg)

    ;; Reset
    (drake-set-theme 'default)))

(defun drake-palette-demo-colorbrewer ()
  "Demonstrate fetching ColorBrewer palettes."
  (interactive)
  (message "\n=== ColorBrewer Palette Demo ===\n")
  (message "Drake can fetch 100+ additional palettes from ColorBrewer.")
  (message "These include:")
  (message "  - Sequential: Blues, Greens, Oranges, etc.")
  (message "  - Diverging: RdBu, RdYlGn, PuOr, etc.")
  (message "  - Qualitative: Accent, Pastel1, Set3, etc.")
  (message "\nThese palettes are designed by Cynthia Brewer for cartography")
  (message "and are optimized for data visualization.\n")

  (when (y-or-n-p "Fetch ColorBrewer palettes now? (requires internet) ")
    (drake-fetch-palettes-improved)
    (message "\nOnce fetched, palettes are cached locally.")
    (message "Use M-x drake-palette-browser to explore them!")))

(defun drake-palette-demo-all ()
  "Run all palette demonstrations."
  (interactive)
  (message "\n╔════════════════════════════════════════╗")
  (message "║  Drake Palette System Demonstration   ║")
  (message "╚════════════════════════════════════════╝\n")

  (when (y-or-n-p "1. Show palette comparison? ")
    (drake-palette-demo-comparison)
    (sit-for 1))

  (when (y-or-n-p "2. Open palette browser? ")
    (drake-palette-demo-browser)
    (sit-for 1))

  (when (y-or-n-p "3. Demonstrate palette preview? ")
    (drake-palette-demo-preview)
    (sit-for 1))

  (when (y-or-n-p "4. Create custom palettes? ")
    (drake-palette-demo-custom)
    (sit-for 1))

  (when (y-or-n-p "5. Show export/import? ")
    (drake-palette-demo-export-import)
    (sit-for 1))

  (when (y-or-n-p "6. Demonstrate theme integration? ")
    (drake-palette-demo-themed)
    (sit-for 1))

  (message "\n╔════════════════════════════════════════╗")
  (message "║         Demo Complete!                 ║")
  (message "╚════════════════════════════════════════╝\n")
  (message "Try these commands:")
  (message "  M-x drake-palette-browser          - Browse all palettes")
  (message "  M-x drake-palette-preview          - Preview a palette")
  (message "  M-x drake-palette-browser-quick-select  - Quick selection")
  (message "  M-x drake-fetch-palettes-improved  - Download ColorBrewer"))

;;; Interactive Tutorial

(defun drake-palette-tutorial ()
  "Interactive tutorial for the palette system."
  (interactive)
  (with-current-buffer (get-buffer-create "*Drake Palette Tutorial*")
    (erase-buffer)
    (org-mode)
    (insert "#+TITLE: Drake Palette System Tutorial\n\n")
    (insert "* Overview\n\n")
    (insert "Drake includes a comprehensive palette management system with:\n")
    (insert "- 13 built-in palettes\n")
    (insert "- Interactive browser with visual previews\n")
    (insert "- ColorBrewer integration (100+ additional palettes)\n")
    (insert "- Custom palette creation and sharing\n\n")

    (insert "* Quick Start\n\n")
    (insert "** Browse Palettes\n")
    (insert "#+BEGIN_SRC elisp\n")
    (insert "(drake-palette-browser)\n")
    (insert "#+END_SRC\n\n")

    (insert "** Preview a Palette\n")
    (insert "#+BEGIN_SRC elisp\n")
    (insert "(drake-palette-preview 'viridis)\n")
    (insert "#+END_SRC\n\n")

    (insert "** Use in a Plot\n")
    (insert "#+BEGIN_SRC elisp\n")
    (insert "(drake-plot-scatter :data data :x :x :y :y :palette 'plasma)\n")
    (insert "#+END_SRC\n\n")

    (insert "* Built-in Palettes\n\n")
    (insert "** Sequential (Perceptually Uniform)\n")
    (insert "- =viridis= - Default, colorblind-friendly\n")
    (insert "- =magma= - Black to white through purple\n")
    (insert "- =plasma= - Dark blue to yellow\n")
    (insert "- =inferno= - Black to white through red\n\n")

    (insert "** Categorical (Distinct Colors)\n")
    (insert "- =set1= - Bright, high contrast colors\n")
    (insert "- =set2= - Softer, pastel colors\n")
    (insert "- =dark2= - Darker tones\n")
    (insert "- =paired= - Pairs of light/dark colors\n\n")

    (insert "** Diverging\n")
    (insert "- =rdbu= - Red to blue\n")
    (insert "- =spectral= - Multi-color spectrum\n\n")

    (insert "* Advanced Features\n\n")
    (insert "** Custom Palettes\n")
    (insert "#+BEGIN_SRC elisp\n")
    (insert "(drake-register-palette 'my-brand\n")
    (insert "  '(\"#1a5490\" \"#e84a27\" \"#f39c12\"))\n")
    (insert "#+END_SRC\n\n")

    (insert "** Export/Import\n")
    (insert "#+BEGIN_SRC elisp\n")
    (insert "(drake-palette-export 'viridis \"~/my-palette.txt\")\n")
    (insert "(drake-palette-import \"~/my-palette.txt\" 'imported-palette)\n")
    (insert "#+END_SRC\n\n")

    (insert "** Fetch ColorBrewer\n")
    (insert "#+BEGIN_SRC elisp\n")
    (insert "(drake-fetch-palettes-improved)\n")
    (insert "#+END_SRC\n\n")

    (insert "* Tips\n\n")
    (insert "- Use sequential palettes (viridis, plasma) for ordered data\n")
    (insert "- Use categorical palettes (set1, dark2) for unordered categories\n")
    (insert "- Use diverging palettes (rdbu) for data with a meaningful center\n")
    (insert "- Viridis is colorblind-friendly and prints well in grayscale\n")
    (insert "- Press ? in the browser for keyboard shortcuts\n\n")

    (display-buffer (current-buffer))))

(provide 'palette-demo)
;;; palette-demo.el ends here

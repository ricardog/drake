;;; drake-theme.el --- Theming support for drake -*- lexical-binding: t; -*-

;; Author: Ricardo G. <ricardo@example.com>
;; Keywords: data, visualization, themes

;;; Commentary:
;; This module provides comprehensive theming support for drake plots,
;; including automatic theme detection based on Emacs configuration.

;;; Code:

(require 'cl-lib)
(require 'color)

;;; Theme Structure

(cl-defstruct drake-theme
  "Theme definition for drake plots."
  (name 'default)
  (background "#ffffff")
  (foreground "#000000")
  (grid-color "#eeeeee")
  (grid-style 'solid)
  (grid-width 1)
  (axis-color "#000000")
  (axis-width 1)
  (text-color "#000000")
  (font-family "sans-serif")
  (font-size 10)
  (palette nil)  ; Uses default palette if nil
  (legend-bg "#ffffff")
  (legend-border "#cccccc")
  (legend-opacity 0.9))

;;; Built-in Themes

(defvar drake--builtin-themes
  (let ((themes (make-hash-table :test 'eq)))
    ;; Default theme (current behavior)
    (puthash 'default
             (make-drake-theme
              :name 'default
              :background "#ffffff"
              :foreground "#000000"
              :grid-color "#eeeeee"
              :grid-style 'solid
              :grid-width 1
              :axis-color "#000000"
              :axis-width 1
              :text-color "#000000"
              :font-family "sans-serif"
              :font-size 10
              :palette nil
              :legend-bg "#ffffff"
              :legend-border "#cccccc"
              :legend-opacity 0.9)
             themes)

    ;; Light theme (clean, bright)
    (puthash 'light
             (make-drake-theme
              :name 'light
              :background "#ffffff"
              :foreground "#222222"
              :grid-color "#e0e0e0"
              :grid-style 'solid
              :grid-width 1
              :axis-color "#333333"
              :axis-width 1.5
              :text-color "#333333"
              :font-family "sans-serif"
              :font-size 11
              :palette 'set1
              :legend-bg "#ffffff"
              :legend-border "#cccccc"
              :legend-opacity 0.95)
             themes)

    ;; Dark theme
    (puthash 'dark
             (make-drake-theme
              :name 'dark
              :background "#1e1e1e"
              :foreground "#d4d4d4"
              :grid-color "#3e3e3e"
              :grid-style 'solid
              :grid-width 1
              :axis-color "#d4d4d4"
              :axis-width 1
              :text-color "#d4d4d4"
              :font-family "sans-serif"
              :font-size 10
              :palette 'viridis
              :legend-bg "#2d2d2d"
              :legend-border "#555555"
              :legend-opacity 0.9)
             themes)

    ;; Minimal theme (ggplot2-inspired)
    (puthash 'minimal
             (make-drake-theme
              :name 'minimal
              :background "#ffffff"
              :foreground "#000000"
              :grid-color "#f0f0f0"
              :grid-style 'solid
              :grid-width 0.5
              :axis-color "#888888"
              :axis-width 0.5
              :text-color "#333333"
              :font-family "sans-serif"
              :font-size 9
              :palette 'set2
              :legend-bg "#ffffff"
              :legend-border "#e0e0e0"
              :legend-opacity 0.85)
             themes)

    ;; Seaborn-inspired theme
    (puthash 'seaborn
             (make-drake-theme
              :name 'seaborn
              :background "#eaeaf2"
              :foreground "#000000"
              :grid-color "#ffffff"
              :grid-style 'solid
              :grid-width 1
              :axis-color "#000000"
              :axis-width 0
              :text-color "#000000"
              :font-family "sans-serif"
              :font-size 10
              :palette 'dark2
              :legend-bg "#eaeaf2"
              :legend-border "#cccccc"
              :legend-opacity 0.9)
             themes)

    ;; High contrast theme
    (puthash 'high-contrast
             (make-drake-theme
              :name 'high-contrast
              :background "#000000"
              :foreground "#ffffff"
              :grid-color "#444444"
              :grid-style 'dashed
              :grid-width 1
              :axis-color "#ffffff"
              :axis-width 2
              :text-color "#ffffff"
              :font-family "monospace"
              :font-size 10
              :palette 'set1
              :legend-bg "#000000"
              :legend-border "#ffffff"
              :legend-opacity 1.0)
             themes)

    ;; Solarized Light
    (puthash 'solarized-light
             (make-drake-theme
              :name 'solarized-light
              :background "#fdf6e3"
              :foreground "#657b83"
              :grid-color "#eee8d5"
              :grid-style 'solid
              :grid-width 1
              :axis-color "#657b83"
              :axis-width 1
              :text-color "#586e75"
              :font-family "sans-serif"
              :font-size 10
              :palette '(("#dc322f" "#cb4b16" "#b58900" "#859900" "#2aa198" "#268bd2" "#6c71c4" "#d33682"))
              :legend-bg "#fdf6e3"
              :legend-border "#93a1a1"
              :legend-opacity 0.9)
             themes)

    ;; Solarized Dark
    (puthash 'solarized-dark
             (make-drake-theme
              :name 'solarized-dark
              :background "#002b36"
              :foreground "#839496"
              :grid-color "#073642"
              :grid-style 'solid
              :grid-width 1
              :axis-color "#839496"
              :axis-width 1
              :text-color "#93a1a1"
              :font-family "sans-serif"
              :font-size 10
              :palette '(("#dc322f" "#cb4b16" "#b58900" "#859900" "#2aa198" "#268bd2" "#6c71c4" "#d33682"))
              :legend-bg "#002b36"
              :legend-border "#586e75"
              :legend-opacity 0.9)
             themes)

    themes)
  "Built-in drake themes.")

;;; Current Theme

(defvar drake-current-theme 'default
  "The currently active drake theme.")

(defun drake-get-current-theme ()
  "Get the current theme object."
  (or (gethash drake-current-theme drake--builtin-themes)
      (gethash 'default drake--builtin-themes)))

;;; Theme Management

(defun drake-set-theme (theme-name)
  "Set the global drake theme to THEME-NAME.
THEME-NAME can be a symbol (one of the built-in themes) or a drake-theme struct.

Built-in themes:
  - default: Current default drake style
  - light: Clean, bright theme for light backgrounds
  - dark: Theme optimized for dark backgrounds
  - minimal: Minimal grid lines, ggplot2-inspired
  - seaborn: Inspired by Python's seaborn library
  - high-contrast: Maximum contrast for accessibility
  - solarized-light: Based on Solarized Light color scheme
  - solarized-dark: Based on Solarized Dark color scheme

Example:
  (drake-set-theme 'dark)
  (drake-set-theme 'minimal)"
  (interactive
   (list (intern (completing-read "Drake theme: "
                                   '(default light dark minimal seaborn
                                     high-contrast solarized-light solarized-dark)
                                   nil t))))
  (cond
   ((drake-theme-p theme-name)
    ;; Custom theme struct provided
    (puthash (drake-theme-name theme-name) theme-name drake--builtin-themes)
    (setq drake-current-theme (drake-theme-name theme-name)))
   ((gethash theme-name drake--builtin-themes)
    ;; Built-in theme
    (setq drake-current-theme theme-name))
   (t
    (error "Unknown theme: %s" theme-name)))
  (message "Drake theme set to: %s" drake-current-theme))

(defun drake-list-themes ()
  "List all available drake themes."
  (interactive)
  (let ((themes nil))
    (maphash (lambda (k _v) (push k themes)) drake--builtin-themes)
    (setq themes (sort themes #'string<))
    (message "Available drake themes: %s" (mapconcat #'symbol-name themes ", "))
    themes))

;;; Emacs Theme Detection

(defun drake-detect-background-mode ()
  "Detect if Emacs is using a light or dark background.
Returns 'light or 'dark."
  (or frame-background-mode
      (let* ((bg (face-background 'default nil t))
             (rgb (color-name-to-rgb (or bg "#ffffff"))))
        (if rgb
            (let ((luminance (+ (* 0.299 (nth 0 rgb))
                               (* 0.587 (nth 1 rgb))
                               (* 0.114 (nth 2 rgb)))))
              (if (> luminance 0.5) 'light 'dark))
          'light))))

(defun drake-detect-emacs-theme-name ()
  "Try to detect the name of the current Emacs theme.
Returns a symbol or nil if not detected."
  (or (car custom-enabled-themes)
      (when (boundp 'spacemacs-theme)
        spacemacs-theme)))

(defun drake-auto-theme ()
  "Automatically select an appropriate drake theme based on Emacs configuration.
This function detects:
  1. Specific known Emacs themes (e.g., solarized, modus)
  2. Light vs dark background mode
  3. Falls back to 'default' if detection fails

Returns the selected theme name."
  (interactive)
  (let* ((theme-name (drake-detect-emacs-theme-name))
         (bg-mode (drake-detect-background-mode))
         (selected-theme
          (cond
           ;; Specific theme detection
           ((and theme-name (string-match-p "solarized-light" (symbol-name theme-name)))
            'solarized-light)
           ((and theme-name (string-match-p "solarized-dark" (symbol-name theme-name)))
            'solarized-dark)
           ((and theme-name (string-match-p "solarized" (symbol-name theme-name)))
            (if (eq bg-mode 'dark) 'solarized-dark 'solarized-light))
           ((and theme-name (string-match-p "modus-vivendi" (symbol-name theme-name)))
            'dark)
           ((and theme-name (string-match-p "modus-operandi" (symbol-name theme-name)))
            'light)
           ((and theme-name (or (string-match-p "dark" (symbol-name theme-name))
                               (string-match-p "night" (symbol-name theme-name))
                               (string-match-p "black" (symbol-name theme-name))))
            'dark)
           ((and theme-name (or (string-match-p "light" (symbol-name theme-name))
                               (string-match-p "day" (symbol-name theme-name))
                               (string-match-p "white" (symbol-name theme-name))))
            'light)
           ;; Fallback to background mode
           ((eq bg-mode 'dark) 'dark)
           ((eq bg-mode 'light) 'light)
           ;; Ultimate fallback
           (t 'default))))
    (drake-set-theme selected-theme)
    (message "Drake auto-selected theme '%s' (Emacs theme: %s, bg-mode: %s)"
             selected-theme theme-name bg-mode)
    selected-theme))

;;; Theme Preview

(defun drake-preview-theme (theme-name)
  "Preview a drake theme by showing its colors and settings.
THEME-NAME should be a symbol referring to a built-in theme."
  (interactive
   (list (intern (completing-read "Preview theme: "
                                   (drake-list-themes)
                                   nil t))))
  (let ((theme (gethash theme-name drake--builtin-themes)))
    (if theme
        (with-current-buffer (get-buffer-create "*Drake Theme Preview*")
          (erase-buffer)
          (insert (format "Drake Theme: %s\n" (drake-theme-name theme)))
          (insert (make-string 50 ?=) "\n\n")
          (insert (format "Background:    %s\n" (drake-theme-background theme)))
          (insert (format "Foreground:    %s\n" (drake-theme-foreground theme)))
          (insert (format "Grid Color:    %s (%s, width: %d)\n"
                         (drake-theme-grid-color theme)
                         (drake-theme-grid-style theme)
                         (drake-theme-grid-width theme)))
          (insert (format "Axis Color:    %s (width: %d)\n"
                         (drake-theme-axis-color theme)
                         (drake-theme-axis-width theme)))
          (insert (format "Text Color:    %s\n" (drake-theme-text-color theme)))
          (insert (format "Font:          %s, %dpt\n"
                         (drake-theme-font-family theme)
                         (drake-theme-font-size theme)))
          (insert (format "Palette:       %s\n"
                         (or (drake-theme-palette theme) "default")))
          (insert (format "Legend BG:     %s\n" (drake-theme-legend-bg theme)))
          (insert (format "Legend Border: %s\n" (drake-theme-legend-border theme)))
          (insert (format "Legend Opacity: %.2f\n" (drake-theme-legend-opacity theme)))
          (display-buffer (current-buffer)))
      (error "Theme not found: %s" theme-name))))

;;; Helper Functions for Backends

(defun drake-theme-get (property)
  "Get PROPERTY from the current theme.
PROPERTY should be a keyword like :background, :grid-color, etc."
  (let ((theme (drake-get-current-theme)))
    (pcase property
      (:background (drake-theme-background theme))
      (:foreground (drake-theme-foreground theme))
      (:grid-color (drake-theme-grid-color theme))
      (:grid-style (drake-theme-grid-style theme))
      (:grid-width (drake-theme-grid-width theme))
      (:axis-color (drake-theme-axis-color theme))
      (:axis-width (drake-theme-axis-width theme))
      (:text-color (drake-theme-text-color theme))
      (:font-family (drake-theme-font-family theme))
      (:font-size (drake-theme-font-size theme))
      (:palette (drake-theme-palette theme))
      (:legend-bg (drake-theme-legend-bg theme))
      (:legend-border (drake-theme-legend-border theme))
      (:legend-opacity (drake-theme-legend-opacity theme))
      (_ nil))))

(defun drake-theme-grid-dasharray ()
  "Get the SVG dash-array value for the current theme's grid style."
  (if (eq (drake-theme-get :grid-style) 'dashed)
      "5,5"
    "none"))

(provide 'drake-theme)
;;; drake-theme.el ends here

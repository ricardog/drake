;;; tests/theme-tests.el --- Tests for drake theming system -*- lexical-binding: t; -*-

(require 'test-helper)
(require 'drake)
(require 'drake-theme)

(ert-deftest drake-theme-default-test ()
  "Test that default theme is loaded."
  (let ((theme (drake-get-current-theme)))
    (should (drake-theme-p theme))
    (should (eq (drake-theme-name theme) 'default))))

(ert-deftest drake-theme-set-test ()
  "Test setting a theme."
  (drake-set-theme 'dark)
  (should (eq drake-current-theme 'dark))
  (let ((theme (drake-get-current-theme)))
    (should (string= (drake-theme-background theme) "#1e1e1e")))
  ;; Restore default
  (drake-set-theme 'default))

(ert-deftest drake-theme-list-test ()
  "Test listing available themes."
  (let ((themes (drake-list-themes)))
    (should (>= (length themes) 7))
    (should (member 'default themes))
    (should (member 'dark themes))
    (should (member 'light themes))
    (should (member 'minimal themes))
    (should (member 'seaborn themes))))

(ert-deftest drake-theme-get-test ()
  "Test getting theme properties."
  (drake-set-theme 'dark)
  (should (string= (drake-theme-get :background) "#1e1e1e"))
  (should (string= (drake-theme-get :foreground) "#d4d4d4"))
  (should (string= (drake-theme-get :grid-color) "#3e3e3e"))
  (should (eq (drake-theme-get :grid-style) 'solid))
  (should (eq (drake-theme-get :palette) 'viridis))
  ;; Restore default
  (drake-set-theme 'default))

(ert-deftest drake-theme-detect-background-mode-test ()
  "Test background mode detection."
  (let ((mode (drake-detect-background-mode)))
    (should (or (eq mode 'light) (eq mode 'dark)))))

(ert-deftest drake-theme-auto-test ()
  "Test automatic theme selection."
  (let ((selected (drake-auto-theme)))
    (should (symbolp selected))
    (should (gethash selected drake--builtin-themes))
    ;; Restore default
    (drake-set-theme 'default)))

(ert-deftest drake-theme-svg-integration-test ()
  "Test that themes work with SVG backend."
  (drake-set-theme 'dark)
  (let* ((data '(:x [1 2 3 4 5] :y [2 4 6 8 10]))
         (plot (drake-plot-scatter :data data :x :x :y :y :buffer nil :backend 'svg)))
    (should (drake-plot-p plot))
    (should (drake-plot-image plot))
    ;; Check that the SVG contains dark theme colors
    (let ((xml (drake-plot-svg-xml plot)))
      (should (string-match-p "#1e1e1e" xml)))) ;; dark background
  ;; Restore default
  (drake-set-theme 'default))

(ert-deftest drake-theme-palette-integration-test ()
  "Test that theme palettes are used correctly."
  (drake-set-theme 'dark)  ;; Uses viridis palette
  (let* ((data '(:x ["A" "A" "B" "B" "C" "C"]
                 :y [1 2 3 4 5 6]
                 :hue ["X" "Y" "X" "Y" "X" "Y"]))
         (plot (drake-plot-scatter :data data :x :x :y :y :hue :hue :buffer nil :backend 'svg)))
    (should (drake-plot-p plot))
    (should (drake-plot-image plot)))
  ;; Restore default
  (drake-set-theme 'default))

(ert-deftest drake-theme-grid-dasharray-test ()
  "Test grid dasharray helper."
  (drake-set-theme 'default)
  (should (string= (drake-theme-grid-dasharray) "none"))
  (drake-set-theme 'high-contrast)
  (should (string= (drake-theme-grid-dasharray) "5,5"))
  ;; Restore default
  (drake-set-theme 'default))

(ert-deftest drake-theme-solarized-test ()
  "Test solarized themes."
  (drake-set-theme 'solarized-light)
  (should (string= (drake-theme-get :background) "#fdf6e3"))
  (drake-set-theme 'solarized-dark)
  (should (string= (drake-theme-get :background) "#002b36"))
  ;; Restore default
  (drake-set-theme 'default))

(ert-deftest drake-theme-minimal-no-axis-test ()
  "Test that minimal theme can have zero-width axes."
  (drake-set-theme 'seaborn)
  (should (= (drake-theme-get :axis-width) 0))
  ;; Restore default
  (drake-set-theme 'default))

(provide 'theme-tests)
;;; theme-tests.el ends here

;;; tests/color-tests.el --- Tests for drake color system -*- lexical-binding: t; -*-

(require 'test-helper)
(require 'drake)

(ert-deftest drake--get-palette-test ()
  (let ((viridis (drake--get-palette 'viridis))
        (set1 (drake--get-palette 'set1))
        (custom '("#ff0000" "#00ff00")))
    (should (listp viridis))
    (should (> (length viridis) 0))
    (should (equal (drake--get-palette custom) custom))
    ;; Test fallback
    (should (listp (drake--get-palette 'non-existent)))))

(ert-deftest drake--color-manager-test ()
  (let* ((unique '("A" "B" "C"))
         (palette '("#1" "#2"))
         (mapping (drake--color-manager unique palette)))
    (should (= (length mapping) 3))
    (should (equal (cdr (assoc "A" mapping)) "#1"))
    (should (equal (cdr (assoc "B" mapping)) "#2"))
    (should (equal (cdr (assoc "C" mapping)) "#1"))))

(ert-deftest drake-register-palette-test ()
  (drake-register-palette 'my-cool-palette '("#abc" "#def"))
  (should (equal (drake--get-palette 'my-cool-palette) '("#abc" "#def"))))

(provide 'color-tests)

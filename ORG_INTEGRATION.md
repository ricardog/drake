# Drake Org-Mode Integration Design

**Status:** Planned - Not Yet Implemented
**Priority:** CRITICAL (GAP_ANALYSIS.md Section 12)

This document outlines the requirements and design for integrating Drake with Emacs Org-mode, enabling seamless statistical plotting within org documents, notebooks, and literate programming workflows.

---

## Why Org-Mode Integration is Critical

Org-mode is the primary documentation, notebook, and literate programming environment for Emacs users. Without org-babel support, Drake cannot be used in:

- **Research notebooks** - Mixing code, analysis, and visualization
- **Reproducible reports** - Embedding plots in exported documents
- **Literate programming** - Documenting code with visual examples
- **Presentations** - Using org-reveal or org-beamer with plots
- **Teaching materials** - Interactive tutorials with inline plots

**Impact:** Org-babel is the standard expectation for any Emacs data tool. Without it, Drake is isolated from the primary Emacs workflow.

---

## Core Requirements

### 1. Org-Babel Language Backend (`ob-drake.el`)

The foundation of integration. Provides:

```org
#+BEGIN_SRC drake :file plot.svg
(drake-plot-scatter :data iris
                   :x :sepal_length
                   :y :sepal_width
                   :hue :species)
#+END_SRC
```

**Required Functions:**

```elisp
(defun org-babel-execute:drake (body params)
  "Execute Drake code block with PARAMS."
  ;; 1. Extract header arguments (:file, :width, :height, :backend, etc.)
  ;; 2. Set up session if requested
  ;; 3. Evaluate code in proper context
  ;; 4. Handle results based on :results type
  ;; 5. Return appropriate output (file link, value, or output))

(defun org-babel-expand-body:drake (body params)
  "Expand Drake code block, applying variable assignments."
  ;; Inject :var parameters into code
  ;; Handle :session setup code)

(defvar org-babel-default-header-args:drake
  '((:results . "file graphics")
    (:exports . "both")
    (:file . nil))
  "Default header arguments for Drake code blocks.")
```

**Header Arguments to Support:**

- `:file` - Output filename (required for graphics results)
- `:width`, `:height` - Plot dimensions
- `:backend` - Drake backend (svg, gnuplot, rust)
- `:theme` - Drake theme name
- `:palette` - Color palette
- `:session` - Named session for persistent data
- `:var` - Pass variables from other blocks
- `:results` - Result type (file, value, output)
- `:exports` - What to export (code, results, both, none)

---

### 2. Session Support

Allow persistent Drake environment across code blocks:

```org
#+BEGIN_SRC drake :session *drake-analysis*
(setq iris-data (drake-load-csv "datasets/iris.csv.gz"))
#+END_SRC

#+BEGIN_SRC drake :session *drake-analysis*
;; Uses iris-data from previous block
(drake-plot-scatter :data iris-data :x :sepal_length :y :sepal_width)
#+END_SRC
```

**Implementation:**

```elisp
(defun org-babel-drake-initiate-session (&optional session params)
  "Create or return Drake session buffer."
  (let ((session-name (or session "*drake-session*")))
    (or (get-buffer session-name)
        (save-window-excursion
          (let ((buf (get-buffer-create session-name)))
            (with-current-buffer buf
              (emacs-lisp-mode) ;; Or custom drake-session-mode
              ;; Load Drake and dependencies
              (require 'drake)
              buf))))))

(defun org-babel-drake-evaluate (session body &optional result-type)
  "Evaluate BODY in SESSION."
  (if session
      (org-babel-drake-evaluate-session session body result-type)
    (org-babel-drake-evaluate-external body result-type)))
```

---

### 3. Variable Passing (`:var`)

Pass data between code blocks:

```org
#+NAME: data-prep
#+BEGIN_SRC emacs-lisp
'(:x [1 2 3 4 5] :y [2 4 6 8 10])
#+END_SRC

#+BEGIN_SRC drake :var mydata=data-prep :file scatter.svg
(drake-plot-scatter :data mydata :x :x :y :y)
#+END_SRC
```

**Implementation:**

```elisp
(defun org-babel-drake-assign-vars (body params)
  "Inject variable assignments from :var params into BODY."
  (let ((vars (org-babel--get-vars params)))
    (concat
     ;; Generate (setq var-name value) forms
     (mapconcat
      (lambda (pair)
        (format "(setq %s '%S)" (car pair) (cdr pair)))
      vars
      "\n")
     "\n"
     body)))
```

---

### 4. Results Handling

Support multiple result types:

#### File Graphics (Primary Use Case)

```org
#+BEGIN_SRC drake :file plot.svg :results file graphics
(drake-plot-scatter :data iris :x :sepal_length :y :sepal_width)
#+END_SRC

#+RESULTS:
[[file:plot.svg]]
```

**Implementation:**

```elisp
(defun org-babel-execute:drake (body params)
  (let* ((result-type (cdr (assq :results params)))
         (output-file (cdr (assq :file params)))
         (backend (or (cdr (assq :backend params)) 'svg)))

    ;; Evaluate code
    (let ((plot (eval (car (read-from-string body)))))

      (cond
       ;; Graphics output
       ((and output-file (member "graphics" result-type))
        (drake-save-plot plot output-file)
        output-file) ;; Return filename for [[file:...]] link

       ;; Value output
       ((member "value" result-type)
        plot) ;; Return plot object

       ;; Output (stdout)
       ((member "output" result-type)
        (with-temp-buffer
          (insert (format "%S" plot))
          (buffer-string)))))))
```

#### Value Return

```org
#+NAME: my-plot
#+BEGIN_SRC drake :results value
(drake-plot-scatter :data iris :x :sepal_length :y :sepal_width)
#+END_SRC

#+BEGIN_SRC emacs-lisp :var plot=my-plot
;; Further manipulate plot object
(drake-plot-add-title plot "Custom Title")
#+END_SRC
```

---

### 5. Inline Display

Automatically display plots in org buffer:

```elisp
(defun drake-org-display-inline-images ()
  "Display Drake plots inline in org buffer."
  (interactive)
  (org-display-inline-images nil t))

;; Hook after execution
(add-hook 'org-babel-after-execute-hook
          (lambda ()
            (when (eq major-mode 'org-mode)
              (drake-org-display-inline-images))))
```

---

### 6. Export Support

Handle different export backends:

#### HTML Export

```elisp
(defun drake-org-html-export (file)
  "Export Drake plot for HTML."
  (cond
   ((string-suffix-p ".svg" file)
    ;; Inline SVG directly
    (with-temp-buffer
      (insert-file-contents file)
      (buffer-string)))
   (t
    ;; Regular image tag
    (format "<img src=\"%s\" />" file))))
```

#### LaTeX Export

```elisp
(defun drake-org-latex-export (file)
  "Export Drake plot for LaTeX."
  (cond
   ((string-suffix-p ".svg" file)
    ;; Convert SVG to PDF for LaTeX
    (let ((pdf-file (concat (file-name-sans-extension file) ".pdf")))
      (drake-convert-svg-to-pdf file pdf-file)
      (format "\\includegraphics[width=\\textwidth]{%s}" pdf-file)))
   (t
    (format "\\includegraphics[width=\\textwidth]{%s}" file))))
```

#### Markdown Export

```elisp
(defun drake-org-markdown-export (file)
  "Export Drake plot for Markdown."
  (format "![Drake Plot](%s)" file))
```

---

## Advanced Features

### 7. Custom Link Type

Register drake-specific links:

```elisp
(org-link-set-parameters "drake"
  :follow #'drake-org-link-follow
  :export #'drake-org-link-export
  :face '(:foreground "purple" :underline t))

(defun drake-org-link-follow (path)
  "Follow drake: link by opening plot."
  ;; path could be "plot-id" or "file:plot.svg"
  (cond
   ((string-prefix-p "file:" path)
    (find-file (substring path 5)))
   (t
    ;; Look up plot by ID in session
    (drake-org-show-plot path))))
```

**Usage:**

```org
See the [[drake:iris-scatter][iris scatter plot]] for details.

Or link directly: [[drake:file:plot.svg]]
```

---

### 8. Interactive Plot Updates

Re-execute code block and update inline image:

```elisp
(defun drake-org-update-plot-at-point ()
  "Re-execute code block at point and update inline image."
  (interactive)
  (org-babel-execute-src-block)
  (org-display-inline-images t t))

(define-key org-mode-map (kbd "C-c C-v u") #'drake-org-update-plot-at-point)
```

---

### 9. Template System

Provide org-tempo templates for quick insertion:

```elisp
(with-eval-after-load 'org-tempo
  (add-to-list 'org-structure-template-alist
               '("drake" . "src drake :file plot.svg\n"))
  (add-to-list 'org-structure-template-alist
               '("drakescatter" . "src drake :file scatter.svg\n(drake-plot-scatter :data ? :x :x :y :y)"))
  (add-to-list 'org-structure-template-alist
               '("drakeline" . "src drake :file line.svg\n(drake-plot-line :data ? :x :x :y :y)")))
```

**Usage:** Type `<drake` + TAB to insert template

---

### 10. Cache Support

Avoid re-rendering unchanged plots:

```org
#+BEGIN_SRC drake :file plot.svg :cache yes
(drake-plot-scatter :data iris :x :sepal_length :y :sepal_width)
#+END_SRC
```

**Implementation:**

```elisp
(defun org-babel-execute:drake (body params)
  (let* ((cache (assq :cache params))
         (cache-current (and cache (org-babel-sha1-hash params))))
    (if (and cache (equal cache-current (gethash body drake--org-cache)))
        ;; Return cached result
        (gethash body drake--org-results)
      ;; Execute and cache
      (let ((result (drake--execute-code body params)))
        (puthash body cache-current drake--org-cache)
        (puthash body result drake--org-results)
        result))))
```

---

### 11. Error Handling

Provide meaningful error messages:

```elisp
(condition-case err
    (eval (car (read-from-string body)))
  (error
   (format "Drake error: %s\nCode:\n%s"
           (error-message-string err)
           body)))
```

---

### 12. Noweb Reference Support

Reference other code blocks:

```org
#+NAME: load-data
#+BEGIN_SRC emacs-lisp
(drake-load-csv "datasets/iris.csv.gz")
#+END_SRC

#+BEGIN_SRC drake :file plot.svg :noweb yes
(let ((data <<load-data>>))
  (drake-plot-scatter :data data :x :sepal_length :y :sepal_width))
#+END_SRC
```

---

## Implementation Plan

### Phase 1: Minimal Viable Integration (1-2 days)

**Goal:** Basic code execution and file output

1. Create `ob-drake.el` with:
   - `org-babel-execute:drake`
   - `:file` and `:results file graphics` support
   - Basic error handling

2. Register with org-babel:
   ```elisp
   (with-eval-after-load 'org
     (require 'ob-drake))
   ```

3. Test basic workflow:
   ```org
   #+BEGIN_SRC drake :file test.svg
   (drake-plot-scatter :data iris :x :sepal_length :y :sepal_width)
   #+END_SRC
   ```

**Deliverable:** Working code blocks with file output

---

### Phase 2: Enhanced Features (2-3 days)

**Goal:** Session support and variable passing

1. Implement `org-babel-drake-initiate-session`
2. Add `:var` variable passing
3. Support `:width`, `:height`, `:backend`, `:theme` headers
4. Add inline display hook
5. Create org-tempo templates

**Deliverable:** Multi-block workflows with persistent data

---

### Phase 3: Export & Polish (2-3 days)

**Goal:** Professional export and convenience features

1. HTML export with inline SVG
2. LaTeX export with PDF conversion
3. Markdown export
4. Custom link type (`drake:`)
5. Cache support
6. Interactive update command
7. Comprehensive documentation

**Deliverable:** Production-ready org integration

---

## Example Workflows

### Research Notebook

```org
#+TITLE: Iris Dataset Analysis
#+AUTHOR: Researcher
#+DATE: 2026-03-16

* Data Loading

#+BEGIN_SRC drake :session analysis :results output
(setq iris (drake-load-csv "datasets/iris.csv.gz"))
(message "Loaded %d rows" (length (plist-get iris :sepal_length)))
#+END_SRC

#+RESULTS:
: Loaded 150 rows

* Exploratory Visualization

#+BEGIN_SRC drake :session analysis :file iris-scatter.svg
(drake-plot-scatter :data iris
                   :x :sepal_length
                   :y :sepal_width
                   :hue :species
                   :title "Iris Measurements")
#+END_SRC

#+RESULTS:
[[file:iris-scatter.svg]]

* Distribution Analysis

#+BEGIN_SRC drake :session analysis :file iris-violin.svg
(drake-plot-violin :data iris
                  :x :species
                  :y :petal_length
                  :palette 'viridis)
#+END_SRC

#+RESULTS:
[[file:iris-violin.svg]]
```

---

### Reproducible Report

```org
#+TITLE: Q1 Sales Report
#+OPTIONS: toc:nil num:nil
#+LATEX_CLASS: article

* Executive Summary

Sales increased 15% over Q1 2025. See [[drake:sales-trend][trend analysis]].

#+BEGIN_SRC drake :file sales-trend.svg :exports results
(drake-plot-line :data sales
                :x :month
                :y :revenue
                :hue :region
                :theme 'minimal)
#+END_SRC

#+NAME: sales-trend
#+RESULTS:
[[file:sales-trend.svg]]

* Regional Breakdown

#+BEGIN_SRC drake :file sales-bar.svg :backend gnuplot :exports results
(drake-plot-bar :data sales :x :region :y :revenue :palette 'set1)
#+END_SRC

#+RESULTS:
[[file:sales-bar.svg]]
```

---

### Presentation (org-reveal)

```org
#+TITLE: Data Visualization with Drake
#+REVEAL_THEME: moon
#+REVEAL_TRANS: fade

* Introduction

Drake brings statistical plotting to Emacs.

* Example: Scatter Plot

#+BEGIN_SRC drake :file demo-scatter.svg :height 400 :exports results
(drake-plot-scatter :data iris :x :sepal_length :y :sepal_width
                   :hue :species :theme 'dark)
#+END_SRC

#+ATTR_HTML: :width 80%
#+RESULTS:
[[file:demo-scatter.svg]]
```

---

## Testing Strategy

### Unit Tests

```elisp
(ert-deftest ob-drake-basic-execution-test ()
  "Test basic code block execution."
  (with-temp-buffer
    (org-mode)
    (insert "#+BEGIN_SRC drake :file test.svg\n")
    (insert "(drake-plot-scatter :data iris :x :sepal_length :y :sepal_width)\n")
    (insert "#+END_SRC\n")
    (goto-char (point-min))
    (org-babel-execute-src-block)
    (should (file-exists-p "test.svg"))))

(ert-deftest ob-drake-session-test ()
  "Test session support."
  (let ((session-buf (org-babel-drake-initiate-session "*test-session*" nil)))
    (should (buffer-live-p session-buf))
    (kill-buffer session-buf)))

(ert-deftest ob-drake-var-passing-test ()
  "Test variable passing between blocks."
  ;; Test :var functionality
  )
```

---

## Documentation Requirements

1. **User Guide** (`ORG_BABEL_GUIDE.md`)
   - Getting started
   - Header arguments reference
   - Example workflows
   - Troubleshooting

2. **README.md updates**
   - Add "Org-Mode Integration" section
   - Link to detailed guide
   - Show basic example

3. **Docstrings**
   - All `ob-drake.el` functions
   - Interactive commands
   - Header argument descriptions

---

## Dependencies

### Required

- `org` (built-in with Emacs)
- `ob-core` (org-babel core)
- `drake` (this package)

### Optional

- `org-tempo` - For code templates
- `rsvg-convert` - For SVG→PDF conversion (LaTeX export)
- `imagemagick` - Alternative format conversion

---

## Configuration Example

```elisp
;; In user's init.el
(with-eval-after-load 'org
  (require 'ob-drake)

  ;; Add drake to babel languages
  (org-babel-do-load-languages
   'org-babel-load-languages
   '((emacs-lisp . t)
     (python . t)
     (drake . t)))  ;; Enable drake

  ;; Default header args
  (setq org-babel-default-header-args:drake
        '((:results . "file graphics")
          (:exports . "both")
          (:backend . svg)
          (:theme . dark)))

  ;; Auto-display inline images after execution
  (add-hook 'org-babel-after-execute-hook
            (lambda ()
              (when (eq major-mode 'org-mode)
                (org-display-inline-images nil t))))

  ;; Custom keybinding
  (define-key org-mode-map (kbd "C-c C-v u") #'drake-org-update-plot-at-point))
```

---

## Success Criteria

Integration is complete when users can:

1. ✅ Execute drake code in org-babel blocks
2. ✅ See plots inline in org buffer
3. ✅ Export documents with plots (HTML, LaTeX, Markdown)
4. ✅ Use sessions for persistent data across blocks
5. ✅ Pass variables between blocks
6. ✅ Customize plots via header arguments
7. ✅ Update plots interactively
8. ✅ Cache results for unchanged blocks

---

## Comparison with Other Languages

### Python (ob-python)

```org
#+BEGIN_SRC python :results file
import matplotlib.pyplot as plt
plt.plot([1,2,3], [1,4,9])
plt.savefig('plot.png')
'plot.png'
#+END_SRC
```

### R (ob-R)

```org
#+BEGIN_SRC R :file plot.png
plot(iris$Sepal.Length, iris$Sepal.Width)
#+END_SRC
```

### Drake (ob-drake) - Should be equally ergonomic

```org
#+BEGIN_SRC drake :file plot.svg
(drake-plot-scatter :data iris :x :sepal_length :y :sepal_width)
#+END_SRC
```

---

## Potential Challenges

### 1. Plot Object Serialization

**Problem:** Drake returns plot objects, not strings
**Solution:** Detect object type and automatically save to file

### 2. Session Management

**Problem:** Maintaining state across blocks
**Solution:** Use dedicated elisp buffer, inject `(require 'drake)` automatically

### 3. Export Format Conversion

**Problem:** SVG doesn't work well in LaTeX
**Solution:** Auto-convert to PDF when `:backend latex` detected

### 4. Async Execution

**Problem:** Large plots may block Emacs
**Solution:** Future enhancement - async execution with callbacks

---

## Conclusion

Org-mode integration is essential for Drake adoption. The implementation is straightforward—about 400-500 lines in `ob-drake.el`—and follows established patterns from `ob-python.el` and `ob-R.el`.

**Recommended Timeline:**
- Phase 1 (Minimal): 1-2 days
- Phase 2 (Enhanced): 2-3 days
- Phase 3 (Polish): 2-3 days
- **Total: 5-8 days for complete integration**

**Impact:** Unlocks Drake for 90% of Emacs data analysis workflows. Enables notebooks, reports, presentations, and literate programming—the core use cases for statistical plotting in Emacs.

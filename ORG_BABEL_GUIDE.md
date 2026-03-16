# Drake Org-Babel Quick Start Guide

Use Drake plotting directly in your org-mode documents! Execute Drake code in `#+BEGIN_SRC drake` blocks with automatic plot generation and inline display.

## Installation

```elisp
;; In your init.el
(with-eval-after-load 'org
  (require 'ob-drake)

  ;; Add drake to babel languages
  (org-babel-do-load-languages
   'org-babel-load-languages
   '((emacs-lisp . t)
     (drake . t))))
```

## Basic Usage

### Simple Plot

```org
#+BEGIN_SRC drake :file scatter.svg
(drake-plot-scatter :data iris
                   :x :sepal_length
                   :y :sepal_width
                   :hue :species)
#+END_SRC

#+RESULTS:
[[file:scatter.svg]]
```

**Press `C-c C-c` on the block to execute.**

The plot appears inline automatically!

## Common Workflows

### 1. Data Analysis Notebook

```org
#+TITLE: Iris Analysis
#+AUTHOR: Your Name
#+DATE: 2026-03-16

* Load Data

#+BEGIN_SRC drake :session analysis
(setq iris-data (drake-load-csv "datasets/iris.csv.gz"))
#+END_SRC

* Scatter Plot

#+BEGIN_SRC drake :session analysis :file figures/scatter.svg
(drake-plot-scatter :data iris-data
                   :x :sepal_length
                   :y :sepal_width
                   :hue :species
                   :title "Iris Measurements")
#+END_SRC

#+RESULTS:
[[file:figures/scatter.svg]]

* Distribution

#+BEGIN_SRC drake :session analysis :file figures/violin.svg
(drake-plot-violin :data iris-data
                  :x :species
                  :y :petal_length)
#+END_SRC

#+RESULTS:
[[file:figures/violin.svg]]
```

### 2. Passing Variables Between Blocks

```org
#+NAME: prepare-data
#+BEGIN_SRC emacs-lisp
'(:x [1 2 3 4 5] :y [2 4 6 8 10])
#+END_SRC

#+BEGIN_SRC drake :var mydata=prepare-data :file plot.svg
(drake-plot-scatter :data mydata :x :x :y :y)
#+END_SRC
```

### 3. Customizing Plots

```org
#+BEGIN_SRC drake :file custom.svg :theme dark :palette viridis
(drake-plot-scatter :data iris
                   :x :sepal_length
                   :y :sepal_width
                   :hue :species
                   :title "Dark Theme with Viridis")
#+END_SRC
```

### 4. Different Backends

```org
#+BEGIN_SRC drake :file rust-plot.svg :backend rust
;; Use high-performance Rust backend
(drake-plot-scatter :data large-dataset :x :x :y :y)
#+END_SRC

#+BEGIN_SRC drake :file gnuplot.svg :backend gnuplot
;; Use Gnuplot for publication-quality output
(drake-plot-line :data timeseries :x :date :y :value)
#+END_SRC
```

## Header Arguments

| Argument | Description | Example |
|----------|-------------|---------|
| `:file` | Output filename (required) | `:file plot.svg` |
| `:session` | Named session for persistent data | `:session analysis` |
| `:backend` | Drake backend | `:backend rust` |
| `:theme` | Drake theme | `:theme dark` |
| `:palette` | Color palette | `:palette viridis` |
| `:var` | Variable from another block | `:var data=mydata` |
| `:id` | Plot ID for drake: links | `:id fig1` |
| `:exports` | What to export | `:exports results` |

## Sessions

Use sessions to maintain state across multiple blocks:

```org
#+BEGIN_SRC drake :session my-analysis
(setq my-data (drake-load-csv "data.csv"))
(setq filtered (drake-filter my-data :species "setosa"))
#+END_SRC

#+BEGIN_SRC drake :session my-analysis :file plot1.svg
;; Uses 'filtered' from previous block
(drake-plot-scatter :data filtered :x :x :y :y)
#+END_SRC

#+BEGIN_SRC drake :session my-analysis :file plot2.svg
;; Still has access to 'filtered'
(drake-plot-hist :data filtered :x :sepal_length)
#+END_SRC
```

## Custom Links

Create semantic links to plots:

```org
#+BEGIN_SRC drake :file iris-scatter.svg :id fig-scatter
(drake-plot-scatter :data iris :x :sepal_length :y :sepal_width)
#+END_SRC

Later in text:

As shown in [[drake:fig-scatter][Figure 1]], the measurements cluster by species.

Or link directly: [[drake:file:iris-scatter.svg]]
```

**Link types:**
- `[[drake:file:plot.svg]]` - Link to file
- `[[drake:BLOCKNAME]]` - Link to named block
- `[[drake:PLOTID]]` - Link to plot by ID

## Quick Insert Templates

Type these shortcuts and press `TAB`:

- `<drake` → Empty Drake block
- `<dscatter` → Scatter plot template
- `<dline` → Line plot template
- `<dbar` → Bar plot template

## Keybindings

| Key | Command | Description |
|-----|---------|-------------|
| `C-c C-c` | Execute block | Run Drake code |
| `C-c C-o` | Open result | Open plot file |
| `C-c C-v u` | Update plot | Re-execute and refresh |

Add custom keybinding:

```elisp
(define-key org-mode-map (kbd "C-c C-v u") #'drake-org-update-plot-at-point)
```

## Export

Plots automatically export to different formats:

### HTML Export

```org
#+BEGIN_SRC drake :file plot.svg :exports results
(drake-plot-scatter :data iris :x :sepal_length :y :sepal_width)
#+END_SRC
```

Exports as: `<img src="plot.svg" />`

### LaTeX Export

SVG is automatically converted to PDF (requires `rsvg-convert`):

```org
#+BEGIN_SRC drake :file plot.svg
(drake-plot-scatter :data iris :x :sepal_length :y :sepal_width)
#+END_SRC
```

Exports as: `\includegraphics[width=0.8\textwidth]{plot.pdf}`

### Markdown Export

```org
#+BEGIN_SRC drake :file plot.svg :exports results
(drake-plot-scatter :data iris :x :sepal_length :y :sepal_width)
#+END_SRC
```

Exports as: `![Drake Plot](plot.svg)`

## Advanced Configuration

### Default Header Args

```elisp
(setq org-babel-default-header-args:drake
      '((:results . "file graphics")
        (:exports . "both")
        (:backend . svg)
        (:theme . dark)))
```

### Auto-Display Inline Images

```elisp
;; Automatically show plots after execution
(add-hook 'org-babel-after-execute-hook
          (lambda ()
            (when (eq major-mode 'org-mode)
              (org-display-inline-images nil t))))
```

### Custom Session Initialization

```elisp
(defun my-drake-session-setup ()
  "Custom Drake session initialization."
  (require 'drake)
  (drake-set-theme 'dark)
  (setq drake-default-palette 'viridis))

(add-hook 'org-babel-drake-session-hook #'my-drake-session-setup)
```

## Tips & Tricks

### Tip 1: Organize Plots

```org
Create a figures directory:

#+BEGIN_SRC drake :file figures/plot-01-scatter.svg
(drake-plot-scatter :data iris :x :sepal_length :y :sepal_width)
#+END_SRC
```

### Tip 2: Conditional Execution

```org
#+BEGIN_SRC drake :file plot.svg :eval never-export
;; Only executes manually, not during export
(drake-plot-scatter :data iris :x :sepal_length :y :sepal_width)
#+END_SRC
```

### Tip 3: Multiple Plots

```org
#+BEGIN_SRC drake :session batch
(setq data (drake-load-csv "data.csv"))
#+END_SRC

#+BEGIN_SRC drake :session batch :file plot1.svg
(drake-plot-scatter :data data :x :a :y :b)
#+END_SRC

#+BEGIN_SRC drake :session batch :file plot2.svg
(drake-plot-line :data data :x :date :y :value)
#+END_SRC

#+BEGIN_SRC drake :session batch :file plot3.svg
(drake-plot-bar :data data :x :category :y :count)
#+END_SRC
```

### Tip 4: Faceted Plots

```org
#+BEGIN_SRC drake :file facet-grid.svg
(drake-facet :data tips
            :row :sex
            :col :time
            :plot-fn #'drake-plot-scatter
            :args '(:x :total_bill :y :tip))
#+END_SRC
```

## Troubleshooting

### Plot Not Showing

1. Check `:file` parameter is present
2. Run `M-x org-display-inline-images`
3. Verify file was created: `M-x dired figures/`

### Session Not Persisting

1. Check session name is consistent
2. Verify buffer exists: `M-x switch-to-buffer *drake-session*`
3. Clear and restart: Kill session buffer, re-execute first block

### Export Fails

**HTML:** Ensure SVG file exists at correct path

**LaTeX:** Install `rsvg-convert`:
```bash
# Ubuntu/Debian
sudo apt install librsvg2-bin

# macOS
brew install librsvg
```

**Markdown:** Check file paths are relative

### Error Messages

```
Error: Drake graphics output requires :file parameter
```
→ Add `:file plot.svg` to header

```
Error: Drake plot file not found
```
→ Verify `:file` path is correct and directory exists

## Example: Complete Report

```org
#+TITLE: Sales Analysis Report
#+AUTHOR: Data Team
#+DATE: 2026-03-16
#+OPTIONS: toc:nil num:nil

* Executive Summary

Sales increased 15% in Q1 2026. See analysis below.

* Data Preparation

#+BEGIN_SRC drake :session report
(setq sales (drake-load-csv "data/sales-2026-q1.csv"))
(message "Loaded %d records" (length (plist-get sales :date)))
#+END_SRC

#+RESULTS:
: Loaded 8932 records

* Trend Analysis

#+NAME: sales-trend
#+BEGIN_SRC drake :session report :file figures/sales-trend.svg :theme minimal
(drake-plot-line :data sales
                :x :date
                :y :revenue
                :hue :region
                :title "Q1 2026 Sales by Region")
#+END_SRC

#+CAPTION: Quarterly sales trends across all regions
#+RESULTS: sales-trend
[[file:figures/sales-trend.svg]]

As shown in [[drake:sales-trend][Figure 1]], the West region showed
the strongest growth.

* Regional Breakdown

#+BEGIN_SRC drake :session report :file figures/regional-bar.svg
(drake-plot-bar :data sales
               :x :region
               :y :revenue
               :palette 'set1
               :title "Revenue by Region")
#+END_SRC

#+RESULTS:
[[file:figures/regional-bar.svg]]

* Product Performance

#+BEGIN_SRC drake :session report :file figures/facet-products.svg
(drake-facet :data sales
            :row :region
            :col :quarter
            :plot-fn #'drake-plot-bar
            :args '(:x :product :y :revenue)
            :title "Product Performance")
#+END_SRC

#+RESULTS:
[[file:figures/facet-products.svg]]
```

## Further Reading

- **[ORG_INTEGRATION.md](ORG_INTEGRATION.md)** - Complete design documentation
- **[README.md](README.md)** - Drake main documentation
- **[THEMING.md](THEMING.md)** - Theming and styling guide
- **[examples/](examples/)** - More example code

## Getting Help

- Check function docstrings: `C-h f drake-plot-scatter`
- View source: `M-x find-function drake-plot-scatter`
- Report issues: https://github.com/anthropics/drake/issues

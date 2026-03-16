# Drake Gap Analysis

**Date:** 2026-03-16
**Current Stage:** Stage 5 (High Performance & Advanced Features) - Complete

This document identifies features, improvements, and enhancements not currently listed in TODO.md but implied by the specification or commonly expected in statistical plotting libraries.

---

## 1. Missing Aesthetic Mappings

### Status: Not in TODO.md, Partially in Spec

The spec (Section 4.1) mentions "Aesthetic Mapping: Assigning colors, shapes, and sizes" but only `:hue` (color) is currently implemented.

**Missing:**
- [ ] **`:size` mapping** - Map a continuous variable to point/marker size
  - Example: `(drake-plot-scatter :data data :x :x :y :y :size :population)`
  - Use case: Bubble charts showing 3 variables
  - Impact: Medium - Common in exploratory data analysis

- [ ] **`:shape` / `:marker` mapping** - Map categorical variable to point shapes
  - Example: `(drake-plot-scatter :data iris :x :x :y :y :shape :species)`
  - Use case: Distinguish categories without relying only on color
  - Impact: Medium - Improves accessibility (colorblind users)

- [ ] **`:alpha` / `:opacity` mapping** - Control transparency per data point
  - Example: `(drake-plot-scatter :data data :x :x :y :y :alpha :confidence)`
  - Use case: Show data uncertainty, overplotting mitigation
  - Impact: Low-Medium - Advanced feature

- [ ] **`:linestyle` mapping** - Different line styles for line plots
  - Example: `(drake-plot-line :data data :x :x :y :y :style :treatment)`
  - Options: solid, dashed, dotted, dash-dot
  - Impact: Low - Mainly for print-friendly plots

**Priority:** Medium - `:size` and `:shape` are standard features in matplotlib, seaborn, ggplot2

---

## 2. Missing Plot Types

### Status: Not in TODO.md

While core plot types are implemented, several common statistical plots are missing:

- [ ] **Count Plot** - Bar chart of value counts
  - API: `(drake-plot-count :data data :x :category)`
  - Use case: Frequency of categorical values
  - Currently: Must manually aggregate data
  - Impact: High - Very common use case
  - Priority: **High** - Simple to implement, high value

- [ ] **Strip Plot / Swarm Plot** - Alternative to violin/box
  - API: `(drake-plot-strip :data data :x :category :y :value)`
  - Shows individual data points for categorical data
  - Use case: Small-to-medium datasets where individual points matter
  - Impact: Medium
  - Priority: Medium

- [ ] **Heatmap** - 2D matrix visualization
  - API: `(drake-plot-heatmap :data matrix :x :cols :y :rows)`
  - Use case: Correlation matrices, confusion matrices, pivot tables
  - Impact: High - Common in data analysis
  - Priority: **High** - Standard feature

- [ ] **Contour Plot** - For 3D data on 2D plane
  - API: `(drake-plot-contour :data data :x :x :y :y :z :z)`
  - Use case: Density estimation, mathematical functions
  - Impact: Medium
  - Priority: Low - Advanced feature

- [ ] **Pair Plot / Scatter Matrix** - Multiple scatter plots
  - API: `(drake-plot-pair :data iris :vars '(:sepal_length :sepal_width :petal_length))`
  - Use case: Exploratory data analysis, correlation discovery
  - Impact: High - Very useful for EDA
  - Priority: **High** - Can leverage existing faceting

- [ ] **Joint Plot** - Scatter with marginal distributions
  - API: `(drake-plot-joint :data data :x :x :y :y :kind 'scatter)`
  - Shows scatter + histograms/KDE on margins
  - Impact: Medium
  - Priority: Medium

- [ ] **Distribution Plot** - Histogram + KDE overlay
  - API: `(drake-plot-dist :data data :x :value)`
  - Combines histogram bars with smooth KDE curve
  - Impact: Medium
  - Priority: Low - Can be done with layering

- [ ] **Rug Plot** - 1D data density on axis
  - Often used as margin plot or overlay
  - Impact: Low
  - Priority: Low

- [ ] **Residual Plot** - For regression diagnostics
  - API: `(drake-plot-residuals :data data :x :x :y :y)`
  - Shows residuals vs fitted values
  - Impact: Medium - Important for regression analysis
  - Priority: Medium

- [ ] **Q-Q Plot** - Quantile-quantile plot
  - API: `(drake-plot-qq :data data :x :observed)`
  - Tests if data follows theoretical distribution
  - Impact: Medium - Statistical diagnostics
  - Priority: Low - Specialized

**Priority Rankings:**
1. **High:** Count plot, Heatmap, Pair plot
2. **Medium:** Strip plot, Joint plot, Residual plot
3. **Low:** Contour, Distribution, Rug, Q-Q

---

## 3. Missing Violin/Box Plot Options

### Status: Spec mentions `:inner`, not in TODO.md

The spec (Stage 3) mentions `:inner` option for violin plots but it's not implemented.

- [ ] **`:inner` option for violin plots**
  - Options: `'box`, `'quartiles`, `'stick`, `'points`, `nil`
  - Example: `(drake-plot-violin :data tips :x :day :y :total_bill :inner 'box)`
  - Shows additional statistical information inside violin
  - Impact: Medium - Common seaborn feature
  - Priority: Medium

- [ ] **Outlier control for box plots**
  - Options: `:show-outliers`, `:outlier-symbol`, `:outlier-color`
  - Currently: Outliers not shown separately
  - Impact: Low-Medium
  - Priority: Low

---

## 4. Axis and Scale Enhancements

### Status: Partially complete, some missing

While log scales and date/time are done, several axis features are missing:

- [ ] **Axis limits override**
  - API: `:xlim (min . max)`, `:ylim (min . max)`
  - Force specific axis ranges
  - Impact: High - Common need to zoom or compare plots
  - Priority: **High**

- [ ] **Axis breaks/ticks control**
  - API: `:xticks [1 2 3 5 10]`, `:yticks 'auto`
  - Manual tick placement
  - Impact: Medium
  - Priority: Medium

- [ ] **Secondary Y-axis**
  - API: `:y2 :other_var`, `:y2-label "Other"`
  - Two different Y scales on one plot
  - Impact: Medium - Common for dual-scale data
  - Priority: Low-Medium

- [ ] **Aspect ratio control**
  - API: `:aspect 'equal` or `:aspect 1.5`
  - Force specific width/height ratio
  - Impact: Low-Medium - Important for maps, certain plots
  - Priority: Low

- [ ] **Axis label rotation**
  - API: `:xrotation 45`, `:yrotation 0`
  - Rotate tick labels for readability
  - Impact: Medium - Long categorical labels
  - Priority: Medium

- [ ] **Custom axis formatters**
  - API: `:xformat (lambda (val) (format "$%.2f" val))`
  - User-defined label formatting
  - Impact: Medium
  - Priority: Low-Medium

**Priority:** `:xlim`/`:ylim` is **High**, others are Medium-Low

---

## 5. Plot Composition and Layering

### Status: Not in TODO.md, not in spec

No system for combining multiple plot layers on one axis:

- [ ] **Plot layering / overlay**
  - API: `(drake-layer plot1 plot2 :same-axes t)`
  - Combine scatter + line, or histogram + KDE
  - Example: Scatter plot with regression line (currently done via `:type 'lm`)
  - Impact: High - Very flexible, enables complex visualizations
  - Priority: **High**

- [ ] **Subplots / Multiple axes**
  - API: `(drake-subplot (list plot1 plot2) :layout '(2 . 1))`
  - Different from faceting - different data/types
  - Impact: High - Common in reports
  - Priority: Medium (faceting partially covers this)

- [ ] **Annotations**
  - API: `(drake-annotate plot :text "Peak" :x 5 :y 10)`
  - Add arrows, text, shapes to plots
  - Impact: High - Presentation-ready plots
  - Priority: **High**

**Priority:** Annotations are **High**, layering is **High**, subplots are Medium

---

## 6. Data Transformation Helpers

### Status: Not in TODO.md, not in spec

Currently users must pre-process data. Convenience functions would help:

- [ ] **Built-in aggregation**
  - API: `(drake-plot-bar :data tips :x :day :y :total_bill :estimator 'mean)`
  - Currently: Must aggregate manually
  - Options: `'mean`, `'median`, `'sum`, `'count`
  - Impact: High - Very common need
  - Priority: **High**

- [ ] **Binning helper**
  - API: `(drake-bin data :column :age :bins 10)` → returns binned data
  - Currently: Built into histogram but not exposed
  - Impact: Medium
  - Priority: Low

- [ ] **Pivot/reshape helpers**
  - Wide-to-long, long-to-wide transformations
  - Impact: Medium - Data wrangling
  - Priority: Low (users can use separate libraries)

---

## 7. Export and Output

### Status: Partial - SVG save exists, others missing

- [ ] **PDF export**
  - API: `(drake-save-plot plot "plot.pdf")`
  - Currently: Only SVG via `drake-save-plot`
  - Impact: High - Publication-ready format
  - Priority: Medium-High
  - Note: Could shell out to `rsvg-convert` or similar

- [ ] **PNG/bitmap export**
  - API: `(drake-save-plot plot "plot.png" :dpi 300)`
  - Impact: High - Common format
  - Priority: Medium
  - Note: Could use ImageMagick convert

- [ ] **Interactive HTML export**
  - API: `(drake-save-plot plot "plot.html" :interactive t)`
  - Preserve tooltips, add zoom/pan
  - Impact: Medium - Modern web reports
  - Priority: Low

- [ ] **LaTeX/TikZ export**
  - API: `(drake-save-plot plot "plot.tex")`
  - Impact: Low - Academic publications
  - Priority: Low

- [ ] **Batch export**
  - API: `(drake-save-plots plots "output-{i}.svg")`
  - Save multiple plots at once
  - Impact: Medium
  - Priority: Low

**Priority:** PDF and PNG are **Medium-High**, others are Low

---

## 8. Statistical Enhancements

### Status: Basic stats done, advanced missing

- [ ] **Confidence bands for smooth/loess**
  - Already have for linear regression
  - Add for smooth plots
  - Impact: Medium
  - Priority: Medium

- [ ] **Bootstrap confidence intervals**
  - API: `:bootstrap t :n-boot 1000`
  - For regression, distributions
  - Impact: Medium - Statistical rigor
  - Priority: Low

- [ ] **Density comparison tests**
  - Overlay multiple distributions with test statistics
  - Impact: Low - Advanced
  - Priority: Low

- [ ] **Trend line options beyond OLS**
  - LOESS (already have smooth, but not as regression)
  - Polynomial regression
  - Impact: Medium
  - Priority: Low

---

## 9. Performance and Scalability

### Status: Some in TODO.md, gaps exist

- [X] Math offloaded to Rust (DONE)
- [ ] **Adaptive sampling for large datasets**
  - Automatically downsample when >1M points
  - Show representative sample
  - Impact: High - Prevent hangs
  - Priority: **High**

- [ ] **Streaming data support**
  - Update plot as data arrives
  - Impact: Low - Specialized use case
  - Priority: Low

- [ ] **Caching for expensive operations**
  - Cache KDE results, regression calculations
  - Impact: Medium
  - Priority: Low

- [X] Direct DuckDB-to-Rust pipeline (in TODO)

---

## 10. Developer Experience

### Status: Mostly missing from TODO.md

- [ ] **Plot preview without display**
  - API: `(drake-plot-scatter ... :display nil)` → returns plot object only
  - Currently: Always displays in buffer
  - Impact: Medium - Programmatic use
  - Priority: Medium

- [ ] **Plot update/refresh**
  - API: `(drake-update-plot plot :data new-data)`
  - Update existing plot with new data
  - Impact: Medium
  - Priority: Low-Medium

- [ ] **Plot introspection**
  - API: `(drake-plot-summary plot)` → describes plot structure
  - Impact: Low
  - Priority: Low

- [ ] **Declarative plot spec**
  - API: Define plot as data structure, render later
  - `(setq my-spec '(:type scatter :data data :x :x :y :y))`
  - `(drake-render my-spec)`
  - Impact: Medium - Programmatic plot generation
  - Priority: Low

---

## 11. Documentation and Examples

### Status: Partially in TODO.md

TODO.md mentions "Expanded Examples" but specifics missing:

- [ ] **Gallery with screenshots**
  - Visual showcase of all plot types
  - Impact: High - User onboarding
  - Priority: **High**

- [ ] **Cookbook / recipes**
  - Common tasks: "How to make a grouped bar chart"
  - Impact: High
  - Priority: High

- [ ] **Video tutorials**
  - Screencasts showing workflow
  - Impact: Medium
  - Priority: Low

- [ ] **Migration guide from other libraries**
  - "Coming from ggplot2", "Coming from matplotlib"
  - Impact: Medium
  - Priority: Low

---

## 12. Emacs Integration

### Status: Not in TODO.md

- [ ] **Org-mode integration**
  - #+BEGIN_SRC drake ... #+END_SRC
  - Inline plots in org documents
  - Impact: **Critical** - Emacs users expect this
  - Priority: **CRITICAL**

- [ ] **Org-babel support**
  - Execute drake code in org-babel blocks
  - Impact: **Critical**
  - Priority: **CRITICAL**

- [ ] **Results preview in minibuffer**
  - Show plot summary in echo area
  - Impact: Low
  - Priority: Low

- [ ] **Keybindings for plot interaction**
  - `C-c C-s` to save, `C-c C-r` to refresh
  - Impact: Medium
  - Priority: Low-Medium

- [ ] **Transient menu for plot options**
  - Interactive menu to modify plot
  - Impact: Medium
  - Priority: Low

---

## 13. Accessibility

### Status: Some in TODO.md (high-contrast theme), more needed

- [ ] **Alt text for plots**
  - API: `:alt-text "Scatter plot showing positive correlation"`
  - Impact: Medium - Screen readers
  - Priority: Medium

- [ ] **Sonification**
  - Convert plot to audio
  - Impact: Low - Specialized
  - Priority: Low

- [ ] **Pattern fills for colorblind users**
  - Use patterns in addition to colors
  - Impact: Medium
  - Priority: Low-Medium

- [ ] **High DPI support**
  - Retina display optimization
  - Impact: Medium
  - Priority: Low

---

## 14. Configuration and Defaults

### Status: Partially addressed by theming

- [ ] **Plot templates**
  - API: `(drake-load-template 'scientific-publication)`
  - Pre-configured styles for different contexts
  - Impact: Medium
  - Priority: Low-Medium

- [ ] **Save/load plot configurations**
  - Save current settings to file
  - Impact: Low
  - Priority: Low

- [ ] **Per-project defaults**
  - `.drake.el` file in project root
  - Impact: Medium
  - Priority: Low

---

## Summary: Priority-Ordered Recommendations

### Critical Priority
1. **Org-mode / Org-babel integration** - Emacs users expect this
2. **Adaptive sampling for large datasets** - Prevent crashes/hangs

### High Priority (High Impact, Reasonable Effort)
1. **Count plot** - Simple, very common
2. **Heatmap** - Standard feature, high utility
3. **Pair plot** - Leverages faceting, great for EDA
4. **Axis limits (`:xlim`, `:ylim`)** - Common need, simple
5. **Built-in aggregation** - Saves manual data prep
6. **Plot layering/annotations** - Makes plots publication-ready
7. **Gallery with screenshots** - Documentation/onboarding
8. **`:size` aesthetic mapping** - Bubble charts

### Medium Priority
1. **PDF/PNG export** - Publication formats
2. **`:shape` aesthetic mapping** - Accessibility
3. **Confidence bands for smooth** - Complete existing feature
4. **Residual plots** - Regression diagnostics
5. **Strip/swarm plots** - Common alternative to violin
6. **Joint plots** - Useful distribution visualization
7. **Axis rotation** - Long labels
8. **`:inner` for violin plots** - Complete spec
9. **Plot update/refresh** - Interactive analysis

### Low Priority (Specialized or Low Impact)
- Contour plots, Q-Q plots, rug plots
- Secondary Y-axis, aspect ratio
- Bootstrap CI, streaming data
- Sonification, pattern fills
- LaTeX export, plot templates

---

## Estimated Implementation Effort

### Quick Wins (1-2 days each)
- Count plot
- Axis limits
- `:size` mapping
- Plot preview without display
- Alt text support

### Medium Effort (3-7 days each)
- Heatmap
- Pair plot
- Built-in aggregation
- PDF/PNG export
- Org-babel integration
- Annotations

### Large Effort (1-2 weeks each)
- Plot layering system
- Adaptive sampling
- Strip/swarm plots (layout algorithm complex)
- Gallery generation

---

## Conclusion

The drake project has successfully implemented:
- Core plot types (scatter, line, bar, hist, box, violin, lm, smooth)
- Three backends (SVG, Gnuplot, Rust)
- High-performance math (Rust offloading)
- Theming system
- Palette browser
- Faceting
- Log scales, date/time axes

**Major gaps:**
1. **Org-mode integration** (critical for Emacs ecosystem)
2. **Additional plot types** (count, heatmap, pair)
3. **Aesthetic mappings** (size, shape)
4. **Axis controls** (limits, breaks)
5. **Plot composition** (layering, annotations)
6. **Export formats** (PDF, PNG)

**Recommended next steps:**
1. Add org-babel support (critical for adoption)
2. Implement count plot and axis limits (quick wins)
3. Add heatmap and pair plot (high value)
4. Expand export options (PDF/PNG)
5. Implement size/shape mappings
6. Build plot gallery for documentation

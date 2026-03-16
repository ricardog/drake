# Drake Project Roadmap & TODO

## Completed Tasks

### Stage 1-2: Foundations & Aesthetics
- [x] **Basic Scatter, Line, and Bar Plots:** Core plotting functionality.
- [x] **Data Normalization:** Support for columnar plists, row-lists, and alists.
- [x] **Color Management:** Built-in palettes and `:hue` grouping support.
- [x] **Legend Support:** Automatic legend generation with smart placement.

### Stage 3: Statistical Depth
- [x] **True Kernel Density Estimation (KDE):** Proper Gaussian KDE for violin plots (Elisp implementation).
- [x] **Box Plots & Violins:** Statistical distribution visualizations.
- [x] **Composite Layout Engine:** Basic faceting via `drake-facet`.
- [x] **Gnuplot Backend Parity:** Support for all major plot types in `drake-gnuplot.el`.

### Stage 4: Relational Regression & UI
- [x] **Point-level Interactivity:** Tooltips via SVG `<title>` elements (SVG and Rust backends).
- [x] **OLS Regression:** Trend line calculation and visualization.
- [x] **Confidence Intervals:** 95% CI shaded areas for regression lines.
- [x] **Gaussian Smoothing:** `drake-plot-smooth` for trend visualization.

---

## Current & Future Tasks

### Stage 5: High Performance & Optimization
- [x] **Optimize Rust Data Transfer:** Replace `env.call("aref", ...)` loops with direct memory access or more efficient vector transfer methods to handle large datasets (>100k rows) without lag.
- [X] **Offload Math to Rust:** [DONE] Move KDE, OLS regression, and summary statistics calculations from Elisp to the Rust dynamic module. (KDE: 326x faster, OLS: 17-19x faster, Quartiles: 5x faster)
- [ ] **Direct DuckDB-to-Rust Pipeline:** Investigate passing DuckDB result pointers directly to the Rust backend to minimize Elisp-side data manipulation.

### Backend Consistency & Features
- [ ] **Gnuplot Interactivity:** Implement tooltip support for the Gnuplot backend, possibly via SVG post-processing.
- [X] **Native Faceting:** Implement native `multiplot` (Gnuplot) and grid rendering (Rust) for `drake-facet` to improve performance and layout precision. [DONE] **COMPLETE** (All backends support native faceting)
- [X] **Advanced Axis Support:** [DONE] **95% COMPLETE**
    - [X] Date/Time axis scaling and formatting. [DONE] (SVG & Rust backends; Gnuplot has known limitation)
    - [X] Logarithmic scales. [DONE] (All backends)
    - [X] Customizable number formatting (SI prefixes, decimal precision). [DONE] (Rust backend)

### Code Quality & Robustness
- [X] **Hardened Rust Module:** Replace `unwrap()` calls in `rust/src/lib.rs` with proper `Result` handling to prevent Emacs crashes on malformed data.
- [X] **Refactor Data Normalization:** Streamline `drake--normalize-data` and `drake--extract-column` for better maintainability and performance.
- [X] **Enhanced KDE:** Implement automatic bandwidth selection methods beyond Silverman's rule (e.g., Scott's Rule, Cross-validation).

### API & Ergonomics
- [X] **Thematic Styling:** [DONE] Add `drake-set-theme` to globally manage fonts, grid styles, and color schemes. Includes 8 built-in themes and automatic Emacs theme detection with `drake-auto-theme`.
- [ ] **Coordinate Flipping:** Add a `:flip` argument to easily swap X and Y axes (e.g., for horizontal bar charts).
- [X] **Palette Browser:** [DONE] Interactive palette browser with visual previews, search, export/import, and improved ColorBrewer fetching with async support and error handling.
- [X] **Org-Mode Integration:** [DONE] Full org-babel support with `ob-drake.el`. Execute Drake code in org blocks with file output, sessions, variable passing, custom links, and export support for HTML/LaTeX/Markdown.

### Documentation & Testing
- [ ] **Visual Regression Suite:** Implement tests that verify visual consistency across `svg`, `gnuplot`, and `rust` backends.
- [ ] **Expanded Examples:** Add complex real-world examples (e.g., multi-column faceting with mixed plot types).
- [ ] **Continuous ASAN Testing:** Integrate Address Sanitizer checks into the development workflow for the Rust module.

### Infrastructure & Release (Proposed)
- [ ] **CI/CD Pipeline:** Set up GitHub Actions to run ERT tests and `cargo test` on push.
- [ ] **Cross-Platform Compilation:** Update `drake-rust.el` to detect and load `.dylib` (macOS) and `.dll` (Windows) modules.
- [ ] **Linting Suite:** Integrate `clippy` for Rust and `checkdoc`/`package-lint` for Elisp.
- [ ] **Automated Benchmarks:** Create a script to run `examples/performance-bench.el` in CI and track regression.
- [ ] **User Manual:** Generate a Texinfo (`.info`) manual from existing docstrings.

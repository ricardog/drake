# Drake Project TODO

## Stage 3: Statistical Depth
- [x] **True Kernel Density Estimation (KDE):** Replace the current histogram-based approximation with a proper Gaussian KDE for violin plots.
- [x] **Composite Layout Engine:** Implement a way to render the grid of plots returned by `drake-facet` into a single visual layout.
- [x] **Gnuplot Violin Support:** Implement violin plots in the `drake-gnuplot.el` backend.

## Stage 4: Relational Regression & UI
- [ ] **Point-level Interactivity:** Implement Emacs overlays to show specific data values when hovering over individual points in a plot.
- [ ] **Smoothing & Uncertainty:**
    - [x] Basic OLS Regression (Implemented)
    - [x] **Confidence Intervals:** Calculate and visualize the 95% confidence interval (shaded area) for the regression line. (Implemented for SVG and Gnuplot backends)
    - [x] **Smoothing:** Implement Gaussian kernel smoothing. (Implemented as `drake-plot-smooth` for both SVG and Gnuplot)

## Stage 5: High Performance
- [ ] **Rust/C Dynamic Module:** Move core rendering and heavy math to a compiled module for performance with large datasets.

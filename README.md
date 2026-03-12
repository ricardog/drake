# drake
A high performance statistics plotting library for Emacs.

`drake` is a declarative plotting library for Emacs, inspired by Seaborn. It aims to provide high-quality statistical visualizations from DuckDB and SQLite data directly in Emacs.

## Status: Stage 4 (Relational Regression)
- **Plot types:** Scatter, Line, Bar, Histogram, Box, Violin, and Linear Models (`drake-plot-lm`).
- **Features:** Grouping by color (`:hue`), automatic legends, categorical axes, statistical transformations (binning, OLS regression, summary stats), and interactive tooltips.
- **Backends:** 
  - **Native SVG (`svg`)**: Pure Elisp, zero dependencies.
  - **Gnuplot (`gnuplot`)**: High-quality SVG rendering via external `gnuplot`.
  - **Rust (`rust`)**: High-performance rendering for large datasets (Stage 5 preview).

## Backends

`drake` is backend-agnostic. You can switch backends using the `:backend` argument or by changing the default:

```elisp
;; Change the default backend globally
(setq drake-default-backend 'gnuplot)

;; Specify a backend for a single plot
(drake-plot-scatter :data iris :x :sepal_length :y :sepal_width :backend 'rust)
```

### Backend Priority

When multiple backends are loaded, `drake` respects the `drake-default-backend` variable (defaults to `'svg`). While there is no automatic switching between backends based on availability, the recommended order for performance and quality is:

1.  **`rust`**: Fastest rendering, ideal for datasets with >100,000 points. Requires compilation (see below).
2.  **`gnuplot`**: Excellent for high-quality static charts and complex types like Violins or Boxplots. Requires external `gnuplot` executable.
3.  **`svg`**: Best for portability and small-to-medium datasets. Works out-of-the-box in any Emacs with SVG support.

### The Rust Module

The `rust` backend provides a high-performance rendering engine built with the `plotters` crate. Use it when `svg` or `gnuplot` become slow with large datasets.

**Installation:**
To use the Rust backend, you must compile the dynamic module:
```elisp
(require 'drake-rust)
(drake-module-compile) ;; Requires CMake and Cargo/Rust
```

## Color Palettes

`drake` includes a variety of built-in palettes and supports fetching hundreds more.

- **Built-in Palettes:** `viridis` (default), `magma`, `inferno`, `plasma`, `set1`, `set2`, `dark2`, `paired`, `rdbu`, `spectral`, and `blues`.
- **Fetch More:** Run `M-x drake-fetch-palettes` to download the full set of ColorBrewer palettes and cache them locally.
- **Custom Palettes:** You can provide a list of HEX strings directly to the `:palette` argument:
  ```elisp
  (drake-plot-scatter ... :palette '("#ff0000" "#00ff00" "#0000ff"))
  ```
  Or register a custom palette globally:
  ```elisp
  (drake-register-palette 'my-theme '("#1a1a1a" "#bada55" "#abcdef"))
  ```

## Advanced Features

### Faceting (Small Multiples)
Create a grid of plots based on categorical variables using `drake-facet`:
```elisp
(drake-facet :data tips :row :sex :col :time :plot-fn #'drake-plot-scatter :args '(:x :total_bill :y :tip))
```

### Legend Placement
By default, `drake` intelligently places the legend in the emptiest corner of the plot. You can manually override this using the `:legend` argument:
```elisp
(drake-plot-scatter :data tips :x :total_bill :y :tip :hue :sex :legend 'bottom-left)
```
Supported values: `'top-right`, `'top-left`, `'bottom-right`, `'bottom-left`.

### Interactivity
Plots rendered with the `svg` or `gnuplot` backends include interactive tooltips. Hover your mouse over any data point to see its underlying values.

### Saving Plots
You can save any generated plot to an SVG file using `drake-save-plot`:
```elisp
(let ((plot (drake-plot-scatter :data iris :x :sepal_length :y :sepal_width)))
  (drake-save-plot plot "my-plot.svg"))
```

For plots displayed in a buffer, you can also use the interactive command **`M-x drake-save`** from that buffer to save it to a file. This works because `drake` stores the plot object in a buffer-local variable `drake-current-plot`.

## Data Formats

`drake` is optimized for **DuckDB** but supports any common Emacs data shape:
- **Columnar Plists:** `(:x [1 2 3] :y [10 20 30])` (Highest performance).
- **List of Lists (Row-based):** `((1 10) (2 20) (3 30))` (Use positional indices for `:x` and `:y`).
- **List of Alists/Plists:** `((:x 1 :y 10) (:x 2 :y 20))` (Keyword-based access).

## Sample Datasets

`drake` includes several well-known sample datasets in the `datasets/` directory (compressed as `.gz`):
- `iris.csv.gz`, `tips.csv.gz`, `gapminder.csv.gz`, `stocks.csv.gz`, etc.

## Usage

```elisp
(require 'drake)
(require 'drake-svg)

;; Scatter plot with grouping and linear regression
(drake-plot-lm :data iris :x :sepal_length :y :sepal_width :hue :species :title "Iris Regression")
```

## Running Examples

Check the `examples/` directory for ready-to-run Elisp scripts:
- `examples/iris-scatter.el`
- `examples/tips-scatter.el`
- `examples/tips-regression.el`
- `examples/stage2-demo.el`

## Running Tests

```sh
emacs -batch -L . -L tests -l tests/drake-tests.el -f ert-run-tests-batch-and-exit
```

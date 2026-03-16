# drake
A high performance statistics plotting library for Emacs.

`drake` is a declarative plotting library for Emacs, inspired by Seaborn. It aims to provide high-quality statistical visualizations from DuckDB and SQLite data directly in Emacs.

## Status: Stage 5 (High Performance & Advanced Features)
- **Plot types:** Scatter, Line, Bar, Histogram, Box, Violin, and Linear Models (`drake-plot-lm`).
- **Features:** Grouping by color (`:hue`), automatic legends, categorical axes, statistical transformations (binning, OLS regression, summary stats), interactive tooltips, **native faceting**, **logarithmic scales**, and **date/time axes**.
- **Backends:**
  - **Native SVG (`svg`)**: Pure Elisp, zero dependencies.
  - **Gnuplot (`gnuplot`)**: High-quality SVG rendering via external `gnuplot`.
  - **Rust (`rust`)**: High-performance rendering for large datasets (10-13x faster than SVG).

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

## Theming

Drake includes a comprehensive theming system that automatically adapts to your Emacs configuration:

```elisp
;; Automatically match your Emacs theme
(drake-auto-theme)

;; Or manually set a theme
(drake-set-theme 'dark)         ; Dark mode
(drake-set-theme 'light)        ; Light mode
(drake-set-theme 'minimal)      ; ggplot2-inspired
(drake-set-theme 'seaborn)      ; Seaborn-inspired
(drake-set-theme 'solarized-dark)  ; Solarized Dark

;; List all available themes
(drake-list-themes)

;; Preview a theme before applying
(drake-preview-theme 'dark)
```

**Built-in Themes:**
- `default` - Current default Drake style
- `light` - Clean, bright theme for light backgrounds
- `dark` - Professional dark theme (uses Viridis palette)
- `minimal` - ggplot2-inspired with subtle grids
- `seaborn` - Inspired by Python's Seaborn
- `high-contrast` - Maximum contrast for accessibility
- `solarized-light` / `solarized-dark` - Solarized color schemes

**Custom Themes:**
```elisp
(defvar my-theme
  (make-drake-theme
   :name 'my-custom
   :background "#2e3440"
   :foreground "#d8dee9"
   :grid-color "#3b4252"
   :font-size 11
   :palette 'viridis))

(drake-set-theme my-theme)
```

Themes control colors, fonts, grid styles, and default palettes across all plot types and backends. See `THEMING.md` for comprehensive documentation.

## Advanced Features

### Native Faceting (Small Multiples)
Create grids of plots based on categorical variables using `drake-facet`. All backends now use native rendering for optimal performance:

- **Gnuplot**: Uses `multiplot` layout for efficient grid rendering
- **Rust**: Uses plotters' native grid splitting for maximum performance
- **SVG**: Pure Elisp compositor for portability

```elisp
;; Column faceting
(drake-facet :data tips
            :col :time
            :plot-fn #'drake-plot-scatter
            :args '(:x :total_bill :y :tip)
            :backend 'rust)

;; Row and column faceting with overall title
(drake-facet :data tips
            :row :sex
            :col :time
            :plot-fn #'drake-plot-scatter
            :args '(:x :total_bill :y :tip)
            :title "Tips by Gender and Time"
            :backend 'gnuplot)
```

### Logarithmic Scales
Apply logarithmic scaling to either or both axes using `:logx` and `:logy`:

```elisp
;; Logarithmic X axis (useful for exponential data)
(drake-plot-scatter :data data :x :population :y :gdp :logx t)

;; Both axes logarithmic (for power-law relationships)
(drake-plot-scatter :data data :x :magnitude :y :frequency :logx t :logy t)

;; Works with hue grouping and regression
(drake-plot-lm :data data :x :dose :y :response :hue :treatment :logx t)
```

Logarithmic scales are supported across all backends (SVG, Gnuplot, Rust) and work with all plot types including scatter, line, bar, and regression plots.

### Date/Time Axes
Date and time data is automatically detected and formatted appropriately. Supports ISO 8601 format strings:

```elisp
;; Automatic detection from ISO 8601 timestamps
(drake-plot-line :data timeseries
                :x :timestamp  ; e.g., ["2026-01-01 00:00:00" "2026-02-01 00:00:00" ...]
                :y :temperature
                :backend 'rust)

;; Works with hue grouping for multiple time series
(drake-plot-line :data sensors
                :x :timestamp
                :y :reading
                :hue :sensor_id
                :backend 'svg)
```

**Note:** Date/time axes are fully supported in SVG and Rust backends. Gnuplot backend requires raw timestamp data (planned for future enhancement).

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

## Development

### Running Tests

You can run the full test suite using `ctest` from the `build` directory:

```sh
mkdir -p build && cd build
cmake ..
make check
```

Or run a specific test file using Emacs directly:

```sh
emacs -batch -L . -L tests -l tests/drake-tests.el -f ert-run-tests-batch-and-exit
```

### Running Benchmarks

Benchmarks are used to track performance regressions in data normalization, filtering, and rendering backends.

To run all benchmarks:

```sh
cd build
make bench
```

Individual benchmarks can be run via `ctest`:

```sh
cd build
ctest -L BENCHMARK --output-on-failure
```

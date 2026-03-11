
# Technical Specification: `drake.el`

`drake` is a high-level statistical visualization library for Emacs. It provides a declarative, "Seaborn-style" API to transform data from **DuckDB** and **SQLite** into high-quality images without external runtimes (Python/JS).


## 1. Package Specification

### Core Philosophy

* **Data-First:** Functions accept DuckDB-style columnar plists or row-based lists.
* **Declarative:** You define *what* to plot (e.g., `x`, `y`, `hue`), not *how* to draw lines.
* **Backend Agnostic:** The API generates an internal "Plot Object" that can be rendered to SVG (native Elisp) or passed to a dynamic module (Rust/C).

### Function Signature Pattern

All plotting functions follow a consistent signature:
`(drake-plot-type :data DATA :x X :y Y &rest ARGS)`

## 2. Plot Object & Return Value

Every plotting function returns a `drake-plot` structure. This allows for programmatic inspection of the plot's state or re-rendering to different sizes.

```elisp
(cl-defstruct drake-plot
  spec           ;; The original plist of arguments passed to the function
  data-internal  ;; The extracted/normalized columnar vectors
  scales         ;; Mapping functions from data-space to pixel-space
  image          ;; The actual Emacs image object (SVG or Bitmap)
  buffer         ;; The buffer where the plot was rendered
  )

```

---

## 3. The API Definition

### 3.1 Core Plotting Functions

* `drake-plot-scatter`: Relationship between two numeric variables.
* `drake-plot-line`: Trends over time or ordered sequences.
* `drake-plot-bar`: Aggregate estimates (mean/count) across categories.
* `drake-plot-hist`: Univariate frequency distributions.
* `drake-plot-violin`: Density and distribution (Stage 3).
* `drake-plot-box`: Statistical quartiles and outliers (Stage 3).

### 3.2 Arguments

| Argument | Status | Description |
| --- | --- | --- |
| `:data` | **Required** | Plist of vectors (Columnar) or List of lists (Row-based). |
| `:x` | **Required** | Column identifier (Keyword for plists, Integer for rows). |
| `:y` | **Required*** | Dependent variable (required for all but `hist`/`count`). |
| `:hue` | Optional | Column identifier for color grouping. |
| `:palette` | Optional | Symbol naming a color scheme (e.g., `'viridis`). |
| `:title` | Optional | String title for the chart. |
| `:buffer` | Optional | Target buffer name (defaults to `*drake-plot*`). |
| `:width` | Optional | Pixel width (defaults to 600). |
| `:height` | Optional | Pixel height (defaults to 400). |

---

## 4. Backend API Definition

The `drake` architecture separates the **Graph Language** (front-end) from the **Rendering Engine** (backend). This allows the same declarative plot definition to be rendered by pure Elisp for convenience or a C/Rust module for performance.

### 4.1 The Graph Language Protocol

The front-end is responsible for:
1.  **Data Normalization:** Converting various input formats (DuckDB plists, row-lists, alists) into a consistent columnar format.
2.  **Statistical Transformation:** Performing calculations like Histogram binning, Linear Regression, or KDE. The backend should receive "ready-to-draw" data.
3.  **Coordinate Scaling:** Defining the mapping from data-space to normalized space (0.0 to 1.0) or pixel-space.
4.  **Aesthetic Mapping:** Assigning colors (from palettes), shapes, and sizes based on data values (e.g., `:hue`).

### 4.2 Backend Interface (`drake-backend`)

A backend is registered as a `cl-defstruct`:

```elisp
(cl-defstruct drake-backend
  name             ;; Symbol identifying the backend (e.g., 'svg, 'gnuplot)
  render-fn        ;; Function: (lambda (plot) ...) -> emacs-image
  supported-types  ;; List of plot types: '(scatter line bar hist box lm)
  capabilities     ;; Plist of features: '(:interactivity t :high-dpi t)
  )
```

#### The `svg` Backend (Native)
Pure Elisp implementation using `svg.el`. Best for general use when no external tools are available.

#### The `gnuplot` Backend (External)
Generates gnuplot scripts and executes `gnuplot` as a subprocess to render SVGs. Provides high-quality aesthetics and handles complex chart types with more precision.

```elisp
(require 'drake-gnuplot)
;; Render using gnuplot
(drake-plot-scatter :data iris :x :sepal_length :y :sepal_width :backend 'gnuplot)
```

### 4.3 The Data Exchange Format

The `drake-plot` object passed to the backend contains:

*   **`:data-internal`**: A plist of Emacs vectors where each key represents a visual dimension (e.g., `:x`, `:y`, `:color`, `:size`).
*   **`:scales`**: A plist of scale metadata. For numeric scales: `(:x (min . max) :y (min . max))`. For categorical: `(:hue ("Setosa" "Versicolor" "Virginica"))`.
*   **`:spec`**: The original user arguments, providing context like `:title`, `:width`, and `:height`.

### 4.4 Visual Primitives by Plot Type

The backend must interpret the `plot-type` from the `spec` and apply the corresponding visual primitives:

| Plot Type | Visual Primitive | Mapping |
| --- | --- | --- |
| `scatter` | Circles/Points | `x` -> X-coord, `y` -> Y-coord, `hue` -> Fill Color |
| `line` | Connected Paths | `x` -> X-coord, `y` -> Y-coord (ordered by `x`) |
| `bar` | Rectangles | `x` -> Category, `y` -> Height |
| `hist` | Rectangles | `x` -> Bin Edge, `y` -> Frequency |

## 5. Staged Development Plan

### Stage 1: The Duckling (Hybrid Foundation) [DONE]

**Goal:** Get a scatter plot on screen from DuckDB columnar data or basic SQLite rows.

* **Data Support:** Prioritize Columnar Plists (DuckDB). Implement a basic `drake--ensure-vector` utility.
* **Math:** Linear scaling for X and Y axes.
* **Renderer:** Pure Elisp `svg.el`.
* **Options:** Only `:data`, `:x`, `:y`, and `:title`.
* **Visuals:** Points only. No legends, no axis labels yet.
* **Plot Types:** `scatter`.
* **Options:** `:data`, `:x`, `:y`.
* **Backend:** Basic `svg.el` (native Elisp).
* **Milestone:** Query DuckDB, pass two columns of floats, and see dots in an Emacs buffer.

### Stage 2: The Mallard (Aesthetics & Row Formats) [DONE]

**Goal:** Full support for various data shapes and visual polish.

* **Data Support:** Full normalization for SQLite "Row-Lists" (Positional) and "Alist-Rows" (Named).
* **Features:** Implementation of `:hue`. Generate a legend automatically.
* **Plot Types:** Add `drake-plot-bar` and `drake-plot-line`.
* **Visuals:** Add Axis Ticks, Grid Lines, and dynamic Padding.
* **Plot Types:** `bar` (simple counts).
* **Options:** Add `:hue` and `:palette`.
* **Infrastructure:** Build a "Color Manager" that maps unique values in a `:hue` column to specific HEX codes.

### Stage 3: The Canvas (Statistical Depth) [DONE]

**Goal:** High-level statistical visualizations.

* **Math:** Implement **KDE (Kernel Density Estimation)** for violins and **Quartile Calculation** for box plots in Elisp.
* **Plot Types:** `drake-plot-violin`, `drake-plot-box`, and `drake-plot-hist`.
* **Features:** Faceting (creating a grid of small plots).
* **Options:** `:inner`, `:bins`.
* **Logic:** Implement (or wrap in Rust) Kernel Density Estimation (KDE) and Quartile calculations.
* **Visuals:** Add grid lines and axis labels with proper typography.

### Stage 4: Relational Regression & Smoothing [DONE]

* **Goal:** Trend lines and uncertainty.
* **Plot Types:** `lmplot` (Linear Model).
* **Logic:** Implement a simple Ordinary Least Squares (OLS) regression to draw "lines of best fit" over scatter plots.
* **UI:** Add interactive tooltips (using Emacs "overlays") that show data values when the mouse hovers over a point.

### Stage 5: High Performance (The Great Drake)

**Goal:** Scale to millions of rows without UI lag.

* **Architecture:** Move geometry and rendering to a **Rust Dynamic Module** (using `plotters` crate).
* **Features:** Add `:regression t` to scatter plots (Linear Regression).
* **Interactive UI:** Hover tooltips using Emacs overlays to show exact data values under the cursor.

---

## 7. Minimal Implementation Path (Stage 1)

To get running quickly, we start with a **Columnar-first** approach:

```elisp
(defun drake-plot-scatter (&rest args)
  "Basic scatter plot for Columnar data. 
Usage: (drake-plot-scatter :data duck-res :x :age :y :height)"
  (let* ((data (plist-get args :data))
         (x-vec (plist-get data (plist-get args :x)))
         (y-vec (plist-get data (plist-get args :y)))
         ;; 1. Calculate Min/Max for scales
         (x-range (drake--get-range x-vec))
         (y-range (drake--get-range y-vec))
         ;; 2. Generate SVG image
         (svg-img (drake--render-simple-points x-vec y-vec x-range y-range args)))

    ;; 3. Insert into buffer
    (drake--display-in-buffer svg-img (plist-get args :buffer))

    ;; 4. Return the plot object
    (make-drake-plot :spec args :image svg-img :data-internal (list x-vec y-vec))))

```

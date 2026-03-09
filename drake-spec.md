
# Technical Specification: `drake.el` (v2)

`drake` is a high-level statistical visualization library for Emacs. It is designed to be data-agnostic, supporting both columnar and row-based formats seamlessly.

## 1. Package Specification: `drake`

### Core Philosophy

* **Data-First:** Functions accept DuckDB-style columnar plists or row-based lists.
* **Declarative:** You define *what* to plot (e.g., `x`, `y`, `hue`), not *how* to draw lines.
* **Backend Agnostic:** The API generates an internal "Plot Object" that can be rendered to SVG (native Elisp) or passed to a dynamic module (Rust/C).

### Function Signature Pattern

All plotting functions follow a consistent signature:
`(drake-plot-type :data DATA :x X :y Y &rest ARGS)`

#### Common Arguments

| Argument | Type | Requirement | Description |
| --- | --- | --- | --- |
| `:data` | Plist or List | **Required** | The dataset (e.g., your DuckDB `:data` plist). |
| `:x` | Keyword/Int | **Required** | The column key or index for the x-axis. |
| `:y` | Keyword/Int | Optional | The column key or index for the y-axis. |
| `:hue` | Keyword/Int | Optional | Groups data by color/category. |
| `:palette` | Symbol | Optional | Color scheme (e.g., `'viridis`, `'magma`, `'coolwarm`). |
| `:title` | String | Optional | Plot title. |
| `:buffer` | String | Optional | The buffer name to display the plot in. Defaults to `*drake-plot*`. |

---

### Plot Types & Specific Arguments

#### 1. `drake-plot-scatter` & `drake-plot-line`

* **Purpose:** Relational plots.
* **Specific Args:** * `:style`: Map a column to different marker shapes or line dashes.
* `:size`: Map a column to marker size/line width.



#### 2. `drake-plot-bar` & `drake-plot-count`

* **Purpose:** Categorical estimates.
* **Specific Args:**
* `:estimator`: Function to aggregate (default `'mean`).
* `:errorbar`: Boolean or method (e.g., `'sd` for standard deviation).



#### 3. `drake-plot-violin` & `drake-plot-box`

* **Purpose:** Distributional plots.
* **Specific Args:**
* `:inner`: For violins: `'box`, `'quartile`, `'point`, or `nil`.
* `:split`: (Boolean) If using `:hue` with two levels, draws half-violins.



### Return Value

Every function returns a **`drake-plot` struct**.

* In an interactive call, it automatically renders the image to the target buffer.
* In a non-interactive call (Lisp-only), it returns the struct containing the calculated scales, coordinates, and raw SVG/Bitmap data for further manipulation.


## 4. Supported Input Formats

The `:data` argument now accepts three distinct shapes:

| Format | Source | Example Structure |
| --- | --- | --- |
| **Columnar Plist** | DuckDB (Performance) | `(:id [1 2] :val [10.5 20.1])` |
| **Row List (Named)** | DuckDB / SQLite Alist | `((:id 1 :val 10.5) (:id 2 :val 20.1))` |
| **Row List (Positional)** | SQLite / DuckDB Basic | `((1 10.5) (2 20.1))` |

---

## 5. API Surface & Dispatch Logic

### 5.1 The Coordinate Mapping

Because data can be named or positional, the `:x` and `:y` arguments are interpreted based on the data shape:

* If data is **Columnar** or **Named Rows**: `:x` should be a **keyword** (e.g., `:age`).
* If data is **Positional Rows**: `:x` should be an **integer** index (e.g., `0`).

### 5.2 Core Functions

`drake-plot-scatter`, `drake-plot-line`, `drake-plot-bar`, `drake-plot-violin`, `drake-plot-box`.

**Required Arguments:**

* `:data`: One of the three formats above.
* `:x`: Column identifier (Keyword or Integer).
* `:y`: Column identifier (Keyword or Integer).

---

## 6. The Data Normalization Spec (Internal)

To maintain performance, `drake` converts input to **internal columnar vectors** only for the specific columns needed for the current plot.

### Logic Flow:

1. **Identify Format:** Check if `(plistp (car data))` or `(vectorp (cadr data))`.
2. **Extract Column:** - **Columnar:** Direct `plist-get`.
* **Named Row:** Map `(lambda (r) (plist-get r key))` over the list.
* **Positional Row:** Map `(lambda (r) (nth index r))` over the list.


3. **Result:** A standard Elisp vector for the plotting math.

---

## 7. Staged Development Plan

### Stage 1: The Hybrid Foundation

* **Goal:** Implement the `drake--extract-column` dispatcher.
* **Function:** `drake-plot-scatter`.
* **Support:** All 3 data formats but with limited options (no hue/styling).
* **Validation:** Ensure a 10,000-row SQLite list doesn't trigger a massive GC hit during extraction.

### Stage 2: Categorical Dispatching

* **Goal:** Grouping logic.
* **Feature:** Add `:hue` support.
* **Complexity:** The dispatcher must now extract 3 columns (x, y, hue) and align them. If `:hue` points to a column of strings, `drake` must auto-generate a discrete color mapping.

### Stage 3: Statistical Geometry

* **Goal:** Non-linear plots (`drake-plot-violin`, `drake-plot-box`).
* **Math:** Add `drake-stats.el` to calculate quartiles and KDE.
* **Visuals:** Implementation of "Inner" violin styles (quartiles vs points).

### Stage 4: Native Performance (The "Drake-Core" Module)

* **Goal:** Offload extraction.
* **Optimization:** If the data is already in a C-pointer (from DuckDB), pass the pointer directly to the Rust/C `drake` module to avoid Elisp iteration entirely.

---

## 8. Usage Example (The Universal API)

```elisp
;; 1. Using SQLite (Positional Rows)
(drake-plot-scatter :data (sqlite-select db "SELECT age, bmi FROM users")
                    :x 0 :y 1 :title "Positional SQLite")

;; 2. Using DuckDB (Columnar Plist)
(drake-plot-scatter :data (duckdb-select-columns conn "SELECT age, bmi FROM users")
                    :x :age :y :bmi :title "Columnar DuckDB")

;; 3. Using Row-based Plists
(drake-plot-scatter :data '((:age 25 :bmi 22.1) (:age 30 :bmi 24.5))
                    :x :age :y :bmi :title "Named Rows")

```

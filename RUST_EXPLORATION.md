# Technical Exploration: Rust `plotters` Backend for `drake`

This document outlines the strategy for implementing a high-performance Rust-based rendering backend for `drake` (Stage 5).

## 1. Architectural Strategy

Introduce an **optional** high-performance backend, `drake-rust`, that compiles to a standard Emacs dynamic module (`drake-rust.so`, `.dylib`, or `.dll`).

**Project Structure:**
```text
drake/
├── drake.el            # Core (Detects if drake-rust is available)
├── drake-rust.el       # Elisp binding for the module
├── rust/               # New Rust source directory
│   ├── Cargo.toml
│   └── src/
│       └── lib.rs      # Entry point (emacs-module-rs)
└── Makefile            # Updated to build the module
```

## 2. The Rust Module API

The module will expose a high-level function that accepts a serialized version of the `drake-plot` structure.

**Elisp Interface (`drake-rust.el`):**
```elisp
(require 'drake-rust-module) ;; The dynamic module

(defun drake-rust-render (plot)
  "Render PLOT using the Rust backend."
  (let* ((spec (drake-plot-spec plot))
         (data (drake-plot-data-internal plot))
         (payload `((spec . ,spec)
                    (data . ,data))))
    (drake-rust--render-internal payload)))
```

**Rust Function Signature:**
```rust
#[defun]
fn render_internal(env: &Env, payload: Value) -> Result<Value> {
    // 1. Decode payload (spec + data)
    // 2. Setup Plotters drawing area (SVG or BitMap)
    // 3. Render chart
    // 4. Return string (SVG) or byte-string (PNG)
}
```

## 3. Data Transfer & Performance

*   **Current:** Iterating `emacs_value` vectors. Acceptable for 10k-100k points (ms range).
*   **Optimization:** For >1M points, explore passing raw `f64` memory buffers (blobs) from `duckdb-el` directly to Rust for zero-copy access.

## 4. Mapping `drake` to `plotters`

| Drake Feature | Plotters Support | Implementation Plan |
| :--- | :--- | :--- |
| **Scatter/Line** | Native | `PointSeries`, `LineSeries` |
| **Bar/Hist** | Native | `Histogram`, `Rectangle` |
| **Box Plot** | Native | `Boxplot` element (Quartiles calculated in Rust) |
| **Violin** | **None** | **Custom:** Implement "Violin Series" with KDE in Rust. |
| **Facets** | Native | Use `root.split_evenly((rows, cols))` for better performance than SVG stitching. |
| **Output** | SVG/Bitmap | `SVGBackend` (Interactive) / `BitMapBackend` (Fastest) |

## 5. Proposed Implementation Path

1.  **Bootstrapping:** Create `rust/Cargo.toml` with `emacs` and `plotters` dependencies.
2.  **Infrastructure:** Implement `render_internal` to parse `(spec . data)`.
3.  **Scatter Implementation:** First "Hello World" plot from Rust.
4.  **Integration:** Update `drake.el` to support `:backend 'rust`.
5.  **Advanced Features:** Custom Violin renderer and native Facet support.

## 6. Recommendations

*   **Monorepo:** Keep the Rust source in the main `drake` repository for simplified versioning.
*   **KDE Math:** Porting KDE to Rust is high priority as it significantly improves performance over Elisp calculations.
*   **Build System:** Use `cargo build --release` as the standard compilation path for users.

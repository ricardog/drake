# drake
A high performance statistics plotting library for Emacs.

`drake` is a declarative plotting library for Emacs, inspired by Seaborn. It aims to provide high-quality statistical visualizations from DuckDB and SQLite data directly in Emacs.

## Status: Stage 2 (The Mallard)
- **Plot types:** Scatter, Line, and Bar plots.
- **Features:** Grouping by color (`:hue`), automatic legends, categorical axes.
- **Backends:** Native SVG backend (`svg.el`) with grid lines and ticks.
- **Data formats:** 
  - DuckDB columnar plists (plist of vectors).
  - Row-based list of lists (positional indexing).
  - List of alists (named columns).
  - List of plists (named columns).

## Sample Datasets

`drake` includes several well-known sample datasets in the `datasets/` directory (compressed as `.gz`):
- `iris.csv.gz`: The classic Iris flower dataset.
- `tips.csv.gz`: Restaurant tipping data (total bill, tip, etc.).
- `gapminder.csv.gz`: Global development indicators.

## Usage

```elisp
(require 'drake)
(require 'drake-svg)

;; Scatter plot with grouping
(let ((data '((:x 1 :y 10 :group "A")
              (:x 2 :y 15 :group "A")
              (:x 1 :y 12 :group "B")
              (:x 2 :y 18 :group "B"))))
  (drake-plot-scatter :data data :x :x :y :y :hue :group :title "Grouped Points"))

;; Bar plot with categorical X
(let ((data '((:fruit "Apple"  :count 50)
              (:fruit "Banana" :count 80))))
  (drake-plot-bar :data data :x :fruit :y :count :title "Fruit Counts"))
```

## Running Examples

Check the `examples/` directory for ready-to-run Elisp scripts:
- `examples/iris-scatter.el`
- `examples/tips-scatter.el`
- `examples/stage2-demo.el` (Demonstrates new Stage 2 features)

## Running Tests

`drake` uses ERT for testing. You can run tests from the command line:

```sh
emacs -batch -L . -L tests -l tests/drake-tests.el -f ert-run-tests-batch-and-exit
```

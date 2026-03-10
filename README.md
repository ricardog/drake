# drake
A high performance statistics plotting library for Emacs.

`drake` is a declarative plotting library for Emacs, inspired by Seaborn. It aims to provide high-quality statistical visualizations from DuckDB and SQLite data directly in Emacs.

## Status: Stage 1 (The Duckling)
- **Plot types:** Scatter plots.
- **Backends:** Native SVG backend (`svg.el`).
- **Data formats:** DuckDB columnar plists (plist of vectors).

## Sample Datasets

`drake` includes several well-known sample datasets in the `datasets/` directory (compressed as `.gz`):
- `iris.csv.gz`: The classic Iris flower dataset.
- `tips.csv.gz`: Restaurant tipping data (total bill, tip, etc.).
- `gapminder.csv.gz`: Global development indicators.

## Usage

```elisp
(require 'drake)
(require 'drake-svg)
(require 'duckdb)

;; Plotting from a CSV dataset via DuckDB
(let* ((db (duckdb-open ":memory:"))
       (conn (duckdb-connect db)))
  (duckdb-execute conn "CREATE TABLE iris AS SELECT * FROM read_csv_auto('/app/datasets/iris.csv.gz')")
  (let ((data (duckdb-select-columns conn "SELECT sepal_length, sepal_width FROM iris")))
    (drake-plot-scatter :data data :x :sepal_length :y :sepal_width :title "Iris Sepal Comparison"))
  (duckdb-disconnect conn)
  (duckdb-close db))
```

## Running Examples

Check the `examples/` directory for ready-to-run Elisp scripts:
- `examples/iris-scatter.el`
- `examples/tips-scatter.el`

## Running Tests

`drake` uses ERT for testing. You can run tests from the command line:

```sh
emacs -batch -L . -L tests -l tests/drake-tests.el -f ert-run-tests-batch-and-exit
```

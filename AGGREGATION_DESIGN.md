# Drake Aggregation Design

**Context:** Drake is designed to work with DuckDB, which is far more efficient at aggregation than Elisp. This document clarifies the division of labor and identifies where Drake-level aggregation adds value.

---

## Philosophy: Leverage the Database

**Principle:** Do aggregation in SQL whenever possible. Drake should focus on visual aggregation and convenience features that complement, not duplicate, database capabilities.

### DuckDB's Role (Primary Aggregation)
```elisp
;; User should do this in DuckDB:
(duckdb-select-columns conn
  "SELECT species, AVG(sepal_length) as avg_length
   FROM iris
   GROUP BY species")

;; Then plot:
(drake-plot-bar :data result :x :species :y :avg_length)
```

**Benefits:**
- 100-1000x faster than Elisp
- Handles billions of rows
- SQL is expressive and familiar
- Optimized query plans
- Can use indexes, parallel execution

---

## Where Drake-Level Aggregation Makes Sense

### 1. Visual Binning (Essential)

**Use Case:** Histogram bin size is a visual parameter, not a data parameter.

```elisp
;; User shouldn't need to pre-bin in SQL
(drake-plot-hist :data raw-data :x :age :bins 20)

;; Drake bins the data based on visual space
;; Bins might change if you resize the plot!
```

**Why Drake?** Binning depends on plot width, aesthetic choices. Too coupled to visualization.

**Status:** ✅ Already implemented for histograms

**Enhancement Needed:**
```elisp
;; Expose binning for other uses
(drake-plot-bar :data data :x :salary :bins 10 :aggregator 'count)
;; Bin continuous variable into discrete ranges, then count
```

---

### 2. Quick Exploratory Counts (High Value)

**Use Case:** "Just show me the counts" without writing SQL.

```elisp
;; Without Drake aggregation (current):
(let ((result (duckdb-select-columns conn
                "SELECT category, COUNT(*) as count
                 FROM data GROUP BY category")))
  (drake-plot-bar :data result :x :category :y :count))

;; With Drake aggregation (proposed):
(drake-plot-count :data data :x :category)
;; Drake implicitly does COUNT(*) GROUP BY category
```

**Why Drake?**
- Common exploratory task
- Writing SQL breaks flow for simple counts
- Reduces cognitive load for beginners
- Seaborn, ggplot2, plotly all have this

**Implementation:**
```elisp
(defun drake-plot-count (&rest args)
  "Plot counts of categorical variable X.
Equivalent to bar plot with COUNT(*) aggregation."
  (let* ((data (plist-get args :data))
         (x-key (plist-get args :x))
         (hue-key (plist-get args :hue))
         ;; Extract column and count unique values
         (x-vec (drake--extract-column data x-key))
         (hue-vec (when hue-key (drake--extract-column data hue-key)))
         ;; Count combinations
         (counts (drake--count-by x-vec hue-vec)))
    ;; Convert to bar plot format and render
    (apply #'drake-plot-bar (append args (list :data counts :y :count)))))
```

**Priority:** **High** - Very common use case, minimal code

---

### 3. Facet-Level Aggregation (Medium Value)

**Use Case:** Aggregate separately within each facet panel.

```elisp
;; Complex in SQL: Need to GROUP BY row+col variables
(drake-facet :data sales
            :row :region
            :col :quarter
            :plot-fn #'drake-plot-bar
            :args '(:x :product :aggregator mean :value :revenue))
;; Shows mean revenue per product in each region/quarter combo
```

**Why Drake?**
- Faceting structure already known to Drake
- SQL would need complex GROUP BY with CASE statements
- Natural fit with faceting logic

**Current Workaround:** User must pre-aggregate in SQL with GROUP BY region, quarter, product

**Priority:** Medium - Nice to have, but SQL workaround exists

---

### 4. Statistical Annotations (Low Value)

**Use Case:** Add mean line, median marker to existing plot.

```elisp
(drake-plot-box :data data :x :category :y :value
               :show-mean t)  ; Adds red diamond at mean
```

**Why Drake?** Data already in memory, simple calculation

**Priority:** Low - Decorative, low effort to calculate

---

### 5. Binned Aggregation for Continuous X-axis (Medium Value)

**Use Case:** Bar chart of binned continuous variable.

```elisp
;; Show average salary by age group
(drake-plot-bar :data employees
               :x :age
               :y :salary
               :bins 5           ; Divide age into 5 bins
               :aggregator 'mean) ; Show mean salary per bin

;; Alternative explicit syntax:
(drake-plot-bar :data employees
               :x (drake-bin :age :bins 5)
               :y :salary
               :aggregator 'mean)
```

**Current Workaround:**
```sql
SELECT
  FLOOR(age/10)*10 as age_group,
  AVG(salary) as avg_salary
FROM employees
GROUP BY age_group
```

**Why Drake?**
- Bin size is visual parameter
- Quick exploration without SQL
- Common in seaborn (`sns.barplot` with continuous x)

**Priority:** Medium

---

### 6. Multiple Aggregations on Same Data (Low Value)

**Use Case:** Show both mean and std dev.

```elisp
(drake-plot-bar :data data :x :category :y :value
               :aggregator '(mean std)
               :errorbar t)  ; Show error bars from std
```

**Why Drake?** Convenience for common statistical pattern

**Priority:** Low - Can pre-compute in SQL

---

## What Drake Should NOT Do

### ❌ Complex Joins
```elisp
;; NO: This belongs in SQL
(drake-join table1 table2 :on '(:id :customer_id))
```

### ❌ Window Functions
```elisp
;; NO: Use SQL window functions
(drake-lag :data data :column :price :by :date)
```

### ❌ Heavy Statistical Aggregations
```elisp
;; NO: Use DuckDB's statistical functions
;; DuckDB has: STDDEV, VARIANCE, CORR, COVAR, PERCENTILE, etc.
(duckdb-select-columns conn
  "SELECT category,
          PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY value) as p95
   FROM data GROUP BY category")
```

### ❌ String Manipulations
```elisp
;; NO: Use SQL string functions
;; DuckDB has: CONCAT, SUBSTRING, REGEXP_REPLACE, etc.
```

---

## Recommended Implementation

### Phase 1: Count Plot (High Priority)

```elisp
(defun drake-plot-count (&rest args)
  "Bar plot of counts for categorical variable X.

Usage:
  (drake-plot-count :data tips :x :day)
  (drake-plot-count :data tips :x :day :hue :sex)

Equivalent to:
  SELECT day, COUNT(*) FROM tips GROUP BY day"

  (let* ((data (plist-get args :data))
         (x-key (plist-get args :x))
         (hue-key (plist-get args :hue)))
    ;; Aggregate counts
    (let ((aggregated (drake--count-by-group data x-key hue-key)))
      ;; Plot as bar chart
      (apply #'drake-plot-bar
             :data aggregated
             :x x-key
             :y :count
             (drake--filter-keys args '(:hue :palette :title :backend))))))

(defun drake--count-by-group (data x-key hue-key)
  "Count occurrences grouped by X-KEY and optionally HUE-KEY."
  (let ((counts (make-hash-table :test 'equal))
        (x-vec (drake--extract-column data x-key))
        (hue-vec (when hue-key (drake--extract-column data hue-key))))
    ;; Count each combination
    (cl-loop for i from 0 below (length x-vec)
             do (let ((key (if hue-key
                              (cons (aref x-vec i) (aref hue-vec i))
                            (aref x-vec i))))
                  (puthash key (1+ (gethash key counts 0)) counts)))
    ;; Convert hash to columnar data
    (drake--hash-to-columns counts x-key hue-key :count)))
```

**Effort:** 1-2 days
**Value:** High - Very common use case

---

### Phase 2: Binned Bar Charts (Medium Priority)

```elisp
(defun drake-plot-bar-binned (&rest args)
  "Bar chart with automatic binning of continuous X variable.

Usage:
  (drake-plot-bar-binned :data employees
                         :x :age
                         :y :salary
                         :bins 5
                         :aggregator 'mean)

Shows mean salary for 5 age ranges."

  (let* ((bins (or (plist-get args :bins) 10))
         (aggregator (or (plist-get args :aggregator) 'mean))
         (x-key (plist-get args :x))
         (y-key (plist-get args :y)))
    ;; Bin X, aggregate Y
    (let ((binned (drake--bin-and-aggregate data x-key y-key bins aggregator)))
      (apply #'drake-plot-bar
             :data binned
             :x :bin_center
             :y :aggregated
             (drake--filter-keys args '(:hue :palette :title :backend))))))
```

**Effort:** 2-3 days
**Value:** Medium - Common for continuous data exploration

---

### Phase 3: Generic Aggregator for Bar Plots (Low Priority)

```elisp
;; Add :aggregator parameter to drake-plot-bar
(drake-plot-bar :data tips
               :x :day
               :y :total_bill
               :aggregator 'mean)  ; Show mean instead of sum

;; Options: 'mean, 'median, 'sum, 'count, 'min, 'max
```

**Note:** This only makes sense if data is NOT pre-aggregated. User must understand when to use.

**Effort:** 1-2 days
**Value:** Low - Usually better to aggregate in SQL

---

## API Design Principles

### 1. Make Common Things Easy

```elisp
;; Easy: Just count stuff
(drake-plot-count :data data :x :category)

;; Not: Force SQL for simple counts
(duckdb-select-columns conn "SELECT category, COUNT(*) as n FROM ...")
```

### 2. Make Intent Clear

```elisp
;; Clear: This will aggregate
(drake-plot-bar :data raw-data :x :category :aggregator 'mean :y :value)

;; Ambiguous: Is this pre-aggregated?
(drake-plot-bar :data data :x :category :y :value)
```

**Solution:**
- If `:aggregator` is provided → Drake aggregates
- If `:aggregator` is nil (default) → Assume pre-aggregated

### 3. Don't Hide Complexity

```elisp
;; Good: User knows this is happening in Drake
(drake-plot-count :data data :x :category)

;; Bad: Implicitly doing complex aggregation
(drake-plot-bar :data data :x :category :y :value)
;; Does this aggregate? How? User doesn't know!
```

### 4. Provide Escape Hatches

```elisp
;; When Drake aggregation isn't enough:
(let ((result (duckdb-select-columns conn
                "SELECT category,
                        AVG(value) as mean,
                        STDDEV(value) as std,
                        COUNT(*) as n
                 FROM data
                 GROUP BY category")))
  (drake-plot-bar :data result :x :category :y :mean))
```

---

## Documentation Examples

### Tutorial Section: "When to Aggregate in SQL vs Drake"

**Aggregate in DuckDB when:**
- Complex aggregations (multiple columns, window functions)
- Large datasets (>100k rows)
- Need database features (indexes, parallel execution)
- Multiple aggregations on same data

```elisp
;; Good: Complex aggregation in SQL
(let ((sales-summary
       (duckdb-select-columns conn
         "SELECT
            product,
            SUM(quantity) as total_qty,
            AVG(price) as avg_price,
            COUNT(DISTINCT customer) as unique_customers,
            MAX(date) as last_sale
          FROM sales
          GROUP BY product")))
  (drake-plot-bar :data sales-summary :x :product :y :total_qty))
```

**Aggregate in Drake when:**
- Quick exploratory counts
- Visual binning (histograms, binned bar charts)
- Simple aggregations during exploration

```elisp
;; Good: Quick exploration in Drake
(drake-plot-count :data tips :x :day :hue :time)

;; Good: Visual binning
(drake-plot-hist :data tips :x :total_bill :bins 20)

;; Good: Binned bar chart
(drake-plot-bar-binned :data employees :x :age :y :salary :bins 5)
```

---

## Comparison with Other Libraries

### Seaborn (Python)
```python
# Seaborn does implicit aggregation
sns.barplot(data=tips, x="day", y="total_bill", estimator=np.mean)
# Equivalent Drake with SQL:
# SELECT day, AVG(total_bill) FROM tips GROUP BY day

# Drake philosophy: Be explicit
(drake-plot-count :data tips :x :day)  # For counts
# OR pre-aggregate in SQL for complex aggregations
```

### ggplot2 (R)
```r
# ggplot2 uses stat_summary, stat_count
ggplot(tips, aes(x=day)) + geom_bar()  # stat="count" is default
# Equivalent Drake:
(drake-plot-count :data tips :x :day)

ggplot(tips, aes(x=day, y=total_bill)) + stat_summary(fun=mean)
# Equivalent Drake:
# Do in SQL: SELECT day, AVG(total_bill) FROM tips GROUP BY day
```

### Observable Plot
```javascript
// Observable Plot encourages pre-aggregation
Plot.barY(tips, Plot.groupX({y: "mean"}, {x: "day", y: "total_bill"}))
// But also supports on-the-fly aggregation for convenience
```

**Drake should follow Observable Plot's philosophy:**
- Encourage SQL aggregation for complex cases
- Support simple aggregations for convenience
- Be explicit about what's happening

---

## Summary & Recommendations

### Implement (High Value)

1. **`drake-plot-count`** - Categorical frequency plots
   - Essential for exploration
   - Minimal code, high value
   - Every plotting library has this

2. **Expose binning helper** - `(drake--bin :column :bins 10)`
   - Already exists internally for histograms
   - Useful for manual binning before plotting

### Consider (Medium Value)

3. **Binned bar charts** - `drake-plot-bar-binned`
   - Common for continuous x-axis
   - Seaborn/ggplot2 have equivalents

4. **`:aggregator` parameter** - For bar plots
   - Only if data is NOT pre-aggregated
   - Must be explicit and well-documented

### Skip (Low Value)

- Complex aggregations (belongs in SQL)
- Multiple simultaneous aggregations (SQL is clearer)
- Window functions, joins (definitely SQL)

---

## Implementation Priority

**Phase 1 (Do First):**
1. `drake-plot-count` - Highest value, simplest implementation
2. Documentation: "When to Aggregate in SQL vs Drake"

**Phase 2 (Later):**
3. Binned bar charts (`drake-plot-bar-binned`)
4. `:aggregator` parameter (if user feedback shows need)

**Not Recommended:**
- Generic aggregation framework
- Replicating SQL functions in Elisp
- Implicit aggregation (user should know what's happening)

---

## Conclusion

**Key Insight:** Drake's aggregation should focus on *visual convenience* and *quick exploration*, not replicating SQL capabilities.

**Design Philosophy:**
- **Explicit over implicit** - User should know when aggregation happens
- **Convenience over completeness** - Support common cases, not all cases
- **Leverage the database** - SQL is better at heavy lifting
- **Visual concerns first** - Binning, counts, quick exploration

**Recommended Features:**
1. Count plots (`drake-plot-count`) ← Do this
2. Histogram binning (already exists) ← Keep it
3. Binned bar charts ← Consider
4. Bar plot aggregator ← Maybe

This approach respects Drake's architecture while providing meaningful convenience features that complement, rather than duplicate, DuckDB's strengths.

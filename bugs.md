# Drake Bug Tracker

All known bugs have been fixed:

1. ✓ **org-babel-demo.org** - Updated to use `load-csv-for-drake` helper function that uses duckdb-el or csv.el
2. ✓ **drake-palette-browser** - Now displays downloaded ColorBrewer palettes correctly (RGB color format issue fixed)
3. ✓ **MacOS color swatches** - Fixed by using proper face properties with hex colors instead of display properties
4. ✓ **drake-fetch-palettes** - Consolidated into single autoloaded function
5. ✓ **Backend loading** - Drake now auto-loads the default backend when required
6. ✓ **Palette counts** - Documentation updated to reflect correct counts (12 bundled, 35 fetchable)
7. ✓ **Example plots** - Fixed box and violin plots extending past boundaries
8. ✓ **Violin plot data** - SVG polyline format corrected, median lines added
9. ✓ **Categorical ordering** - Added `:order` and `:hue-order` parameters for intuitive axis ordering

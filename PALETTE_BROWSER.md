# Drake Palette Browser

The Drake Palette Browser provides an interactive interface for exploring, managing, and applying color palettes to your visualizations.

## Features

- **Visual Palette Browser** - Browse all available palettes with color swatches
- **Interactive Preview** - See large color swatches and hex codes
- **Quick Selection** - Completion-based palette picker with instant preview
- **Search & Filter** - Find palettes by name
- **Import/Export** - Share palettes between projects
- **ColorBrewer Integration** - Fetch 100+ professional palettes
- **Custom Palettes** - Create and register your own color schemes

## Quick Start

```elisp
;; Open the palette browser
(drake-palette-browser)

;; Preview a specific palette
(drake-palette-preview 'viridis)

;; Quick selection with completion
(drake-palette-browser-quick-select)

;; Fetch additional palettes from ColorBrewer
(drake-fetch-palettes-improved)
```

## Palette Browser

Open the interactive palette browser with:

```elisp
M-x drake-palette-browser
```

### Keyboard Shortcuts

| Key | Action |
|-----|--------|
| `RET`, `a` | Apply palette to current theme |
| `c` | Copy palette name to kill ring |
| `f` | Fetch additional palettes from web |
| `r` | Refresh display |
| `s` | Search palettes by name |
| `n`, `↓` | Move to next palette |
| `p`, `↑` | Move to previous palette |
| `q` | Quit browser |
| `?` | Show help |

### Browser Layout

The browser displays three sections:

1. **Bundled Palettes** - 13 palettes included with Drake
2. **Cached Palettes** - Additional palettes fetched from ColorBrewer
3. **User Palettes** - Custom palettes you've registered

Each palette shows:
- Name
- Color swatches (visual representation)
- Number of colors

### Using the Browser

1. **Browse**: Navigate with `n`/`p` or arrow keys
2. **Preview**: Press `RET` on a palette to see details
3. **Apply**: Press `a` to set as default for current theme
4. **Copy**: Press `c` to copy the palette name

## Palette Preview

View detailed information about a palette:

```elisp
(drake-palette-preview 'viridis)
```

The preview shows:
- Large color swatches
- Hex codes for each color
- Usage example
- Buttons to apply or copy

## Palette Types

### Sequential Palettes

Best for **ordered data** (low to high values).

- **viridis** - Perceptually uniform, colorblind-friendly (default)
- **magma** - Black → white through purple/magenta
- **plasma** - Dark blue → yellow
- **inferno** - Black → white through red/orange

**When to use:**
- Heatmaps
- Choropleth maps
- Continuous value ranges
- Temperature, elevation, density

**Example:**
```elisp
(drake-plot-scatter :data climate
                   :x :date
                   :y :temperature
                   :hue :temperature
                   :palette 'viridis)
```

### Categorical Palettes

Best for **unordered categories** (qualitative differences).

- **set1** - Bright, high contrast colors
- **set2** - Softer, pastel colors
- **dark2** - Darker tones for light backgrounds
- **paired** - Pairs of related colors

**When to use:**
- Different categories/groups
- Comparison between unordered items
- Legends with discrete values

**Example:**
```elisp
(drake-plot-bar :data sales
               :x :quarter
               :y :revenue
               :hue :region
               :palette 'set1)
```

### Diverging Palettes

Best for data with a **meaningful center point**.

- **rdbu** - Red → white → blue
- **spectral** - Multi-color spectrum

**When to use:**
- Data above/below average
- Positive/negative values
- Hot/cold, gain/loss

**Example:**
```elisp
(drake-plot-bar :data changes
               :x :category
               :y :change-pct
               :palette 'rdbu)
```

## ColorBrewer Integration

Drake can fetch 100+ additional palettes from [ColorBrewer](https://colorbrewer2.org):

```elisp
M-x drake-fetch-palettes-improved
```

This downloads palettes in three categories:
- **Sequential**: Blues, Greens, Oranges, Reds, Purples, Grays, etc.
- **Diverging**: BrBG, PiYG, PRGn, PuOr, RdBu, RdGy, RdYlBu, RdYlGn, Spectral
- **Qualitative**: Accent, Dark2, Pastel1, Pastel2, Set1, Set2, Set3

Palettes are cached locally in `~/.emacs.d/drake/palettes-cache.el` for offline use.

### Error Handling

The improved fetch function provides:
- Async downloading with status messages
- Network error detection
- Parse error handling
- Cache file location on failure
- Progress feedback

## Custom Palettes

### Creating Custom Palettes

Register your own color schemes:

```elisp
;; Brand colors
(drake-register-palette 'my-brand
  '("#1a5490" "#e84a27" "#f39c12" "#27ae60" "#8e44ad"))

;; Pastel palette
(drake-register-palette 'pastels
  '("#ffb3ba" "#bae1ff" "#baffc9" "#ffffba" "#ffdfba"))

;; Monochrome
(drake-register-palette 'grayscale
  '("#000000" "#404040" "#808080" "#c0c0c0" "#ffffff"))
```

Custom palettes:
- Appear in the browser under "User Palettes"
- Can be used immediately with `:palette`
- Persist for the session (add to init file for permanence)

### Palette Requirements

When creating palettes:
- Use hex color format: `#RRGGBB`
- Provide at least 2 colors
- More colors = more flexibility
- Colors will cycle if you have more categories than colors

## Exporting and Importing

### Export a Palette

Save a palette to a text file:

```elisp
(drake-palette-export 'viridis "~/my-palette.txt")
```

Creates a file with:
```
# Drake Palette: viridis
# 6 colors

#440154
#414487
#2a788e
#22a884
#7ad151
#fde725
```

### Import a Palette

Load a palette from a text file:

```elisp
(drake-palette-import "~/my-palette.txt" 'imported-colors)
```

The file should contain one hex color per line. Lines starting with `#` (followed by space) are treated as comments.

### Sharing Palettes

1. Export your palette to a file
2. Share the file with collaborators
3. They import it with their own name
4. Palette appears in their browser

## Integration with Themes

Themes can specify a default palette:

```elisp
;; Create theme with default palette
(defvar my-theme
  (make-drake-theme
   :name 'my-theme
   :palette 'plasma  ; Default for this theme
   ...))

(drake-set-theme my-theme)

;; Now all plots use 'plasma' by default (unless overridden)
(drake-plot-scatter :data data :x :x :y :y :hue :category)

;; Override with explicit palette
(drake-plot-scatter :data data :x :x :y :y :hue :category :palette 'set1)
```

Current theme's palette:

```elisp
;; Get current theme's palette
(drake-theme-get :palette)  ; => 'viridis

;; Apply a palette to current theme
(let ((theme (drake-get-current-theme)))
  (setf (drake-theme-palette theme) 'plasma))
```

## Usage in Plots

### Method 1: Explicit Palette

Specify palette directly in plot call:

```elisp
(drake-plot-scatter :data data
                   :x :x
                   :y :y
                   :hue :category
                   :palette 'viridis)
```

### Method 2: Theme Default

Set palette as theme default:

```elisp
(drake-set-theme 'dark)  ; Uses 'viridis by default

(drake-plot-scatter :data data :x :x :y :y :hue :category)
;; Uses viridis automatically
```

### Method 3: Direct Color List

Provide colors directly:

```elisp
(drake-plot-scatter :data data
                   :x :x
                   :y :y
                   :hue :category
                   :palette '("#ff0000" "#00ff00" "#0000ff"))
```

## Best Practices

### Choosing Palettes

1. **Match data type to palette type**
   - Sequential → ordered data
   - Categorical → unordered categories
   - Diverging → data with meaningful center

2. **Consider your audience**
   - Use colorblind-friendly palettes (viridis, plasma)
   - Test in grayscale for print publications
   - High contrast for presentations

3. **Be consistent**
   - Use same palette for related plots
   - Match colors to meaning (red=danger, green=good)

4. **Avoid rainbow palettes**
   - Not perceptually uniform
   - Poor in grayscale
   - Can mislead interpretation

### Accessibility

**Colorblind-Friendly:**
- viridis ✓
- magma ✓
- plasma ✓
- inferno ✓
- set2 ✓

**Avoid for colorblindness:**
- Red-green combinations
- Rainbow palettes

**Test your palette:**
```elisp
;; View in preview to check contrast
(drake-palette-preview 'your-palette)
```

### Performance

Palettes have minimal performance impact:
- Colors are assigned once during data processing
- No performance difference between palettes
- Use as many colors as needed

## API Reference

### Functions

#### `(drake-palette-browser)`
Open the interactive palette browser.

#### `(drake-palette-preview PALETTE-NAME)`
Show detailed preview of a palette with large swatches and hex codes.

#### `(drake-palette-browser-quick-select)`
Quick palette selection with completion and instant preview.

#### `(drake-fetch-palettes-improved)`
Fetch additional palettes from ColorBrewer with improved error handling.

#### `(drake-register-palette NAME COLORS)`
Register a custom palette.
- `NAME`: Symbol naming the palette
- `COLORS`: List of hex color strings

#### `(drake-palette-export PALETTE-NAME FILENAME)`
Export palette to a text file.

#### `(drake-palette-import FILENAME PALETTE-NAME)`
Import palette from a text file.

### Variables

#### `drake-palette-url`
URL for fetching ColorBrewer palettes. Default:
`"https://raw.githubusercontent.com/axismaps/colorbrewer/master/export/colorbrewer.json"`

#### `drake--bundled-palettes`
Alist of built-in palettes.

#### `drake--palette-cache`
Cached palettes from ColorBrewer.

#### `drake--user-palettes`
User-registered custom palettes.

## Examples

### Basic Usage

```elisp
;; Load palette browser
(require 'drake-palette-browser)

;; Browse palettes
(drake-palette-browser)

;; Preview before using
(drake-palette-preview 'plasma)

;; Use in plot
(drake-plot-scatter :data iris
                   :x :sepal_length
                   :y :sepal_width
                   :hue :species
                   :palette 'plasma)
```

### Custom Brand Colors

```elisp
;; Define brand palette
(drake-register-palette 'acme-corp
  '("#003366"  ; Corporate blue
    "#ff6600"  ; Brand orange
    "#00cc66"  ; Success green
    "#cc0000"  ; Warning red
    "#9933cc")) ; Accent purple

;; Use in all company reports
(drake-set-theme 'light)
(let ((theme (drake-get-current-theme)))
  (setf (drake-theme-palette theme) 'acme-corp))

;; Now all plots use brand colors
(drake-plot-bar :data quarterly-data
               :x :quarter
               :y :revenue
               :hue :division)
```

### Seasonal Palettes

```elisp
;; Spring
(drake-register-palette 'spring
  '("#c2e699" "#78c679" "#31a354" "#006837"))

;; Summer
(drake-register-palette 'summer
  '("#fee391" "#fec44f" "#fe9929" "#ec7014" "#cc4c02"))

;; Autumn
(drake-register-palette 'autumn
  '("#fc8d59" "#ef6548" "#d7301f" "#b30000" "#7f0000"))

;; Winter
(drake-register-palette 'winter
  '("#c6dbef" "#9ecae1" "#6baed6" "#4292c6" "#2171b5"))

;; Use seasonally
(let ((season (if (< (nth 4 (decode-time)) 6) 'spring 'autumn)))
  (drake-plot-line :data temperature
                   :x :date
                   :y :temp
                   :palette season))
```

## Troubleshooting

**Q: Fetch fails with network error**
A: Check internet connection. Palettes are cached locally after first fetch, so you can work offline after initial download.

**Q: Colors look wrong**
A: Ensure you're using the right palette type (sequential vs categorical vs diverging) for your data.

**Q: Custom palette doesn't appear**
A: Use `(drake-palette-browser-refresh)` to update the browser display. Custom palettes are session-only unless added to init file.

**Q: Too few colors in palette**
A: Palettes cycle when you have more categories than colors. Register a palette with more colors, or use a different palette.

**Q: How to reset to default**
A:
```elisp
(let ((theme (drake-get-current-theme)))
  (setf (drake-theme-palette theme) nil))
```

## See Also

- `THEMING.md` - Theme system documentation
- `examples/palette-demo.el` - Comprehensive demonstrations
- `examples/theme-demo.el` - Theme and palette integration
- [ColorBrewer](https://colorbrewer2.org) - Original palette source

# Palette Browser Quick Start

Get started with the Drake Palette Browser in 60 seconds!

## Installation

The palette browser is included with Drake. Simply:

```elisp
(require 'drake)
;; drake-palette-browser is autoloaded
```

## Quick Commands

### Open the Browser

```elisp
M-x drake-palette-browser
```

You'll see:
- All bundled palettes with color swatches
- Cached ColorBrewer palettes (if fetched)
- Your custom palettes

**Keyboard shortcuts:**
- `↓` or `n` - Next palette
- `↑` or `p` - Previous palette
- `RET` or `a` - Apply to current theme
- `c` - Copy palette name
- `s` - Search
- `f` - Fetch ColorBrewer palettes
- `q` - Quit

### Preview a Palette

```elisp
M-x drake-palette-preview RET viridis RET
```

Shows:
- Large color swatches
- Hex codes
- Usage example
- Apply/Copy buttons

### Quick Selection

```elisp
M-x drake-palette-browser-quick-select
```

Select with completion, see instant preview, apply in one click.

### Fetch ColorBrewer

```elisp
M-x drake-fetch-palettes-improved
```

Downloads 100+ professional palettes. Cached locally for offline use.

## Usage Examples

### In a Plot

```elisp
;; Use a specific palette
(drake-plot-scatter :data iris
                   :x :sepal_length
                   :y :sepal_width
                   :hue :species
                   :palette 'plasma)

;; Use theme default (set in browser)
(drake-plot-scatter :data iris
                   :x :sepal_length
                   :y :sepal_width
                   :hue :species)
```

### Custom Palette

```elisp
;; Register
(drake-register-palette 'my-colors
  '("#e63946" "#f1faee" "#a8dadc" "#457b9d" "#1d3557"))

;; Now visible in browser and usable immediately
(drake-plot-bar :data data :x :x :y :y :hue :group :palette 'my-colors)
```

### Export/Share

```elisp
;; Export
(drake-palette-export 'viridis "~/my-palette.txt")

;; Send to colleague, they import:
(drake-palette-import "~/received-palette.txt" 'shared-palette)
```

## Common Workflows

### Workflow 1: Explore and Apply

1. `M-x drake-palette-browser`
2. Browse with `n`/`p`
3. Press `RET` on a palette you like
4. Creates plots - they use the selected palette

### Workflow 2: Search for Specific Colors

1. `M-x drake-palette-browser`
2. Press `s`, search "blue"
3. See all palettes with "blue" in name
4. Press `RET` to apply

### Workflow 3: Custom Brand Colors

1. `M-x drake-register-palette`
   - Name: `my-brand`
   - Colors: `'("#1a5490" "#e84a27" "#f39c12")`
2. `M-x drake-palette-browser`
3. Find under "User Palettes"
4. Apply to theme for consistent use

### Workflow 4: Download and Browse ColorBrewer

1. `M-x drake-fetch-palettes-improved`
2. Wait for download (30 seconds)
3. `M-x drake-palette-browser`
4. See 100+ new palettes under "Cached"
5. Explore sequential, diverging, and qualitative palettes

## Palette Types Cheat Sheet

**Sequential** (low → high):
- `viridis`, `plasma`, `magma`, `inferno`
- Use for: heatmaps, ordered data, temperature

**Categorical** (distinct groups):
- `set1`, `set2`, `dark2`, `paired`
- Use for: categories, regions, products

**Diverging** (negative ← center → positive):
- `rdbu`, `spectral`
- Use for: +/-, above/below average, gain/loss

## Tips

💡 **Colorblind-friendly**: viridis, magma, plasma, inferno
💡 **Print-safe**: Avoid pure red/green combinations
💡 **Presentations**: Use high-contrast palettes (set1, dark2)
💡 **Reports**: Use subtle palettes (set2, pastel colors)

## Next Steps

- Read the [Color Palettes](../README.md#color-palettes) section in README for comprehensive documentation
- Run `examples/palette-demo.el` for interactive demonstrations
- Try `M-x drake-palette-tutorial` for an org-mode guide

## Troubleshooting

**Q: Browser shows no palettes**
A: Restart Emacs or `(require 'drake-palette-browser)`

**Q: Fetch fails**
A: Check internet connection. Try again or check `drake-palette-url`

**Q: Custom palette doesn't save**
A: Custom palettes are session-only. Add to init file:
```elisp
(with-eval-after-load 'drake
  (drake-register-palette 'my-colors '("#..." "#...")))
```

---

**Full Documentation**: See the [Color Palettes](../README.md#color-palettes) section in README
**Examples**: See `examples/palette-demo.el`

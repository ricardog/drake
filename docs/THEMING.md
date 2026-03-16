# Drake Theming System

Drake includes a comprehensive theming system that allows you to globally customize the appearance of all your plots, including automatic theme detection based on your Emacs configuration.

## Quick Start

```elisp
;; Set a built-in theme
(drake-set-theme 'dark)

;; Automatically detect and use appropriate theme
(drake-auto-theme)

;; List available themes
(drake-list-themes)

;; Preview a theme before applying
(drake-preview-theme 'solarized-dark)
```

## Built-in Themes

Drake comes with 8 professionally-designed themes:

### `default`
The current default Drake style with light background and clean aesthetics.

### `light`
Clean, bright theme optimized for light backgrounds with enhanced readability.
- **Palette:** Set1 (categorical colors)
- **Best for:** Presentations, documentation

### `dark`
Professional dark theme optimized for dark editor themes.
- **Background:** #1e1e1e
- **Palette:** Viridis (perceptually uniform)
- **Best for:** Dark mode editors, reducing eye strain

### `minimal`
Inspired by ggplot2, features subtle grids and clean lines.
- **Palette:** Set2 (soft colors)
- **Best for:** Academic papers, reports

### `seaborn`
Inspired by Python's Seaborn library, features a light gray background with white grid lines.
- **Background:** #eaeaf2
- **Palette:** Dark2
- **Best for:** Data analysis notebooks

### `high-contrast`
Maximum contrast theme for accessibility and presentations.
- **Background:** Black
- **Text:** White
- **Grid:** Dashed
- **Best for:** Accessibility, projectors, high-contrast displays

### `solarized-light`
Based on the popular Solarized Light color scheme.
- **Background:** #fdf6e3
- **Foreground:** #657b83
- **Best for:** Users of Solarized themes

### `solarized-dark`
Based on the popular Solarized Dark color scheme.
- **Background:** #002b36
- **Foreground:** #839496
- **Best for:** Users of Solarized dark themes

## Automatic Theme Detection

Drake can automatically detect your Emacs theme and select an appropriate plotting theme:

```elisp
(drake-auto-theme)
```

This function:
1. Detects specific known themes (Solarized, Modus, etc.)
2. Falls back to light/dark detection based on `frame-background-mode`
3. Analyzes actual background color luminance if needed

**Tip:** Add `(drake-auto-theme)` to your init file to automatically match your Emacs theme!

## Theme Components

A Drake theme controls these aspects of plot appearance:

| Component | Description | Example |
|-----------|-------------|---------|
| **Background** | Plot background color | `#ffffff` (white) |
| **Foreground** | Main text color | `#000000` (black) |
| **Grid Color** | Grid line color | `#eeeeee` (light gray) |
| **Grid Style** | Solid or dashed | `'solid` or `'dashed` |
| **Grid Width** | Line width in pixels | `1` |
| **Axis Color** | Axis line and tick color | `#000000` |
| **Axis Width** | Axis line width (0 = hidden) | `1` |
| **Text Color** | Labels and titles | `#000000` |
| **Font Family** | Font family name | `"sans-serif"` |
| **Font Size** | Base font size in points | `10` |
| **Palette** | Default color palette | `'viridis` |
| **Legend Background** | Legend box background | `#ffffff` |
| **Legend Border** | Legend box border color | `#cccccc` |
| **Legend Opacity** | Legend transparency | `0.9` |

## Creating Custom Themes

You can create your own themes using `make-drake-theme`:

```elisp
(defvar my-custom-theme
  (make-drake-theme
   :name 'my-custom
   :background "#2e3440"     ; Nord polar night
   :foreground "#d8dee9"     ; Nord snow storm
   :grid-color "#3b4252"
   :grid-style 'solid
   :grid-width 1
   :axis-color "#d8dee9"
   :axis-width 1
   :text-color "#e5e9f0"
   :font-family "sans-serif"
   :font-size 11
   :palette 'viridis
   :legend-bg "#2e3440"
   :legend-border "#4c566a"
   :legend-opacity 0.95))

;; Apply your custom theme
(drake-set-theme my-custom-theme)
```

Once created, your custom theme is automatically added to the available themes and can be reused:

```elisp
(drake-set-theme 'my-custom)
```

## Theme Inheritance

You can create themes based on existing ones:

```elisp
(defvar my-dark-variant
  (let ((base (gethash 'dark drake--builtin-themes)))
    (make-drake-theme
     :name 'my-dark-variant
     :background (drake-theme-background base)
     :foreground (drake-theme-foreground base)
     ;; ... customize specific properties ...
     :font-size 12  ; Larger font
     :palette 'plasma)))  ; Different palette

(drake-set-theme my-dark-variant)
```

## Backend Support

The theming system is supported across all Drake backends:

- **SVG**: Full support for all theme properties
- **Gnuplot**: Support for colors, grid styles, and text (background may be limited)
- **Rust**: Full support (plotters backend)

## Usage Examples

### Match Your Emacs Theme

```elisp
;; In your init.el or .emacs
(with-eval-after-load 'drake
  (drake-auto-theme))
```

### Use Different Themes for Different Contexts

```elisp
;; For presentations
(defun my-drake-presentation-mode ()
  (interactive)
  (drake-set-theme 'high-contrast)
  (setq drake-default-width 1200)
  (setq drake-default-height 800))

;; For reports
(defun my-drake-report-mode ()
  (interactive)
  (drake-set-theme 'minimal)
  (setq drake-default-width 600)
  (setq drake-default-height 400))
```

### Preview Themes Interactively

```elisp
;; Load the theme demo
(load "examples/theme-demo.el")

;; Run interactive selector
(drake-theme-interactive-selector)

;; Or run full demo
(drake-theme-demo-all)
```

## API Reference

### Functions

#### `(drake-set-theme THEME-NAME)`
Set the global Drake theme. THEME-NAME can be a symbol (built-in theme) or a `drake-theme` struct.

#### `(drake-auto-theme)`
Automatically select an appropriate theme based on Emacs configuration.

#### `(drake-list-themes)`
Return a list of all available theme names.

#### `(drake-preview-theme THEME-NAME)`
Display theme properties in a buffer without applying the theme.

#### `(drake-get-current-theme)`
Get the currently active theme object.

#### `(drake-theme-get PROPERTY)`
Get a specific property from the current theme. PROPERTY is a keyword like `:background`, `:grid-color`, etc.

#### `(drake-detect-background-mode)`
Detect if Emacs is using a light or dark background. Returns `'light` or `'dark`.

#### `(drake-detect-emacs-theme-name)`
Try to detect the name of the current Emacs theme.

### Variables

#### `drake-current-theme`
Symbol naming the currently active theme.

#### `drake--builtin-themes`
Hash table containing all built-in themes.

## Tips and Best Practices

1. **Consistency**: Use `drake-auto-theme` to keep your plots consistent with your Emacs theme
2. **Accessibility**: Use `high-contrast` theme for presentations or accessibility needs
3. **Publication**: Use `minimal` or `light` themes for academic papers
4. **Dark Mode**: Use `dark` or `solarized-dark` when working late at night
5. **Color Blindness**: The `viridis` palette (used in `dark` theme) is colorblind-friendly

## Troubleshooting

**Q: Theme colors don't match my Emacs theme exactly**
A: Use `drake-auto-theme` for automatic detection, or create a custom theme matching your specific color scheme.

**Q: Gnuplot backend doesn't show background color**
A: Some gnuplot terminals have limited background support. The foreground elements (grid, axes, text) will still use theme colors.

**Q: How do I reset to default theme?**
A: Simply run `(drake-set-theme 'default)`

**Q: Can I use different themes for different plots?**
A: Themes are global. To use different styles, create separate themes and switch between them, or modify plot properties directly using the `:palette` argument.

## Examples

See `examples/theme-demo.el` for comprehensive demonstrations of:
- Basic theme switching
- Palette comparisons
- Auto-detection
- Custom theme creation
- Cross-backend support

Run the demo:
```elisp
(load "examples/theme-demo.el")
(drake-theme-demo-all)
```

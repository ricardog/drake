use emacs::{defun, Env, Result, Value, IntoLisp, Vector};
use plotters::prelude::*;

emacs::plugin_is_GPL_compatible!();

trait PlottersResultExt<T> {
    fn map_plot_err(self, env: &Env) -> Result<T>;
}

impl<T, E: std::fmt::Display> PlottersResultExt<T> for std::result::Result<T, E> {
    fn map_plot_err(self, env: &Env) -> Result<T> {
        match self {
            Ok(v) => Ok(v),
            Err(e) => {
                let msg = format!("Plotters error: {}", e);
                let data = env.list(&[msg.into_lisp(env)?])?;
                env.signal(env.intern("error")?, (data,))?;
                unreachable!()
            }
        }
    }
}

fn value_to_f64<'e>(value: Value<'e>) -> Result<f64> {
    if !value.is_not_nil() {
        return Ok(f64::NAN);
    }
    // Try converting to float first
    if let Ok(f) = value.into_rust::<f64>() {
        return Ok(f);
    }
    // Fallback to integer
    if let Ok(i) = value.into_rust::<i64>() {
        return Ok(i as f64);
    }
    Ok(f64::NAN)
}

fn value_to_f64_vec<'e>(env: &'e Env, value: Value<'e>) -> Result<Vec<f64>> {
    if !value.is_not_nil() {
        return Ok(Vec::new());
    }
    if let Ok(vector) = value.into_rust::<Vector>() {
        let mut res = Vec::with_capacity(vector.len());
        for val in vector {
            res.push(value_to_f64(val)?);
        }
        Ok(res)
    } else {
        let size: usize = env.call("length", [value])?.into_rust()?;
        let mut res = Vec::with_capacity(size);
        for i in 0..size {
            let idx = (i as i64).into_lisp(env)?;
            let val: Value = env.call("aref", [value, idx])?;
            res.push(value_to_f64(val)?);
        }
        Ok(res)
    }
}

fn value_to_string_vec<'e>(env: &'e Env, value: Value<'e>) -> Result<Vec<String>> {
    if !value.is_not_nil() {
        return Ok(Vec::new());
    }
    if let Ok(vector) = value.into_rust::<Vector>() {
        let mut res = Vec::with_capacity(vector.len());
        for val in vector {
            if val.is_not_nil() {
                res.push(val.into_rust::<String>()?);
            } else {
                res.push("".to_string());
            }
        }
        Ok(res)
    } else {
        let size: usize = env.call("length", [value])?.into_rust()?;
        let mut res = Vec::with_capacity(size);
        for i in 0..size {
            let idx = (i as i64).into_lisp(env)?;
            let val: Value = env.call("aref", [value, idx])?;
            if val.is_not_nil() {
                res.push(val.into_rust::<String>()?);
            } else {
                res.push("".to_string());
            }
        }
        Ok(res)
    }
}

fn get_plist_value<'e>(env: &'e Env, plist: Value<'e>, key: &str) -> Result<Value<'e>> {
    env.call("plist-get", [plist, env.intern(key)?])
}

fn hex_to_rgb(hex: &str) -> RGBColor {
    let hex = hex.trim_start_matches('#');
    if hex.len() == 6 {
        let r = u8::from_str_radix(&hex[0..2], 16).unwrap_or(0);
        let g = u8::from_str_radix(&hex[2..4], 16).unwrap_or(0);
        let b = u8::from_str_radix(&hex[4..6], 16).unwrap_or(0);
        RGBColor(r, g, b)
    } else {
        RGBColor(76, 114, 176) // Default
    }
}

fn value_to_iter<'e>(env: &'e Env, value: Value<'e>) -> Result<Vec<Value<'e>>> {
    if !value.is_not_nil() {
        return Ok(Vec::new());
    }
    if let Ok(vector) = value.into_rust::<Vector>() {
        let mut res = Vec::with_capacity(vector.len());
        for val in vector {
            res.push(val);
        }
        Ok(res)
    } else {
        let mut res = Vec::new();
        let mut curr = value;
        while curr.is_not_nil() && env.call("consp", [curr])?.is_not_nil() {
            res.push(env.call("car", [curr])?);
            curr = env.call("cdr", [curr])?;
        }
        Ok(res)
    }
}

fn format_tick(val: f64, range: (f64, f64), log: bool, kind: &str) -> String {
    let original_val = if log {
        let lmin = (range.0.max(1e-10)).ln();
        let lmax = (range.1.max(1e-10)).ln();
        (lmin + val * (lmax - lmin)).exp()
    } else {
        range.0 + val * (range.1 - range.0)
    };

    if kind == "time" {
        // Simple timestamp to string (we don't have chrono easily here without adding it to Cargo.toml)
        // But we can just show it as a number or implement basic date logic.
        // For now, let's keep it numeric or assume it's already formatted if possible.
        format!("{:.0}", original_val)
    } else {
        if original_val.abs() >= 1_000_000.0 {
            format!("{:.1}M", original_val / 1_000_000.0)
        } else if original_val.abs() >= 1_000.0 {
            format!("{:.1}K", original_val / 1_000.0)
        } else {
            format!("{:.1}", original_val)
        }
    }
}

fn draw_plot_on_area<'e, DB: DrawingBackend>(
    env: &'e Env,
    area: &DrawingArea<DB, plotters::coord::Shift>,
    plot: Value<'e>,
) -> Result<()> {
    let spec = env.call("drake-plot-spec", [plot])?;
    let data_internal = env.call("drake-plot-data-internal", [plot])?;
    let scales = env.call("drake-plot-scales", [plot])?;

    let plot_type_sym: Value = get_plist_value(env, spec, ":type")?;
    let plot_type = env.call("symbol-name", [plot_type_sym])?.into_rust::<String>()?;
    
    let title = get_plist_value(env, spec, ":title")?
        .into_rust::<Option<String>>()?;

    let x_vec = value_to_f64_vec(env, get_plist_value(env, data_internal, ":x")?)?;
    let y_vec = value_to_f64_vec(env, get_plist_value(env, data_internal, ":y")?)?;
    let hue_vec = value_to_string_vec(env, get_plist_value(env, data_internal, ":hue")?)?;
    let extra_val = get_plist_value(env, data_internal, ":extra")?;

    let x_range_val = get_plist_value(env, scales, ":x")?;
    let x_min: f64 = if x_range_val.is_not_nil() && env.call("consp", [x_range_val])?.is_not_nil() { 
        value_to_f64(env.call("car", [x_range_val])?)? 
    } else { 0.0 };
    let x_max: f64 = if x_range_val.is_not_nil() && env.call("consp", [x_range_val])?.is_not_nil() { 
        value_to_f64(env.call("cdr", [x_range_val])?)? 
    } else { 1.0 };

    let y_range_val = get_plist_value(env, scales, ":y")?;
    let y_min: f64 = if y_range_val.is_not_nil() && env.call("consp", [y_range_val])?.is_not_nil() { 
        value_to_f64(env.call("car", [y_range_val])?)? 
    } else { 0.0 };
    let y_max: f64 = if y_range_val.is_not_nil() && env.call("consp", [y_range_val])?.is_not_nil() { 
        value_to_f64(env.call("cdr", [y_range_val])?)? 
    } else { 1.0 };
    let y_diff = if y_max == y_min { 1.0 } else { y_max - y_min };

    let x_type_sym = get_plist_value(env, scales, ":x-type")?;
    let x_type = env.call("symbol-name", [x_type_sym])?.into_rust::<String>()?;
    let y_type_sym = get_plist_value(env, scales, ":y-type")?;
    let y_type = env.call("symbol-name", [y_type_sym])?.into_rust::<String>()?;
    let logx = get_plist_value(env, spec, ":logx")?.is_not_nil();
    let logy = get_plist_value(env, spec, ":logy")?.is_not_nil();

    let margin = 40;
    let chart_area = area.margin(margin, margin, margin, margin);

    if let Some(t) = title {
        let style = ("sans-serif", 15).into_font().into_text_style(area);
        area.draw_text(
            &t,
            &style,
            (area.dim_in_pixel().0 as i32 / 2 - (t.len() as i32 * 4), 15),
        ).map_plot_err(env)?;
    }

    let mut chart = ChartBuilder::on(&chart_area)
        .build_cartesian_2d(0.0..1.0, 0.0..1.0)
        .map_plot_err(env)?;

    chart.configure_mesh()
        .x_label_formatter(&|&v| format_tick(v, (x_min, x_max), logx, &x_type))
        .y_label_formatter(&|&v| format_tick(v, (y_min, y_max), logy, &y_type))
        .draw().map_plot_err(env)?;

    match plot_type.as_str() {
        "scatter" => {
            chart.draw_series(
                x_vec.iter().zip(y_vec.iter()).enumerate().map(|(i, (&x, &y))| {
                    let color = if hue_vec.is_empty() {
                        RGBColor(76, 114, 176)
                    } else {
                        hex_to_rgb(&hue_vec[i % hue_vec.len()])
                    };
                    Circle::new((x, y), 4, color.filled())
                })
            ).map_plot_err(env)?;
        },
        "line" => {
            let color = if hue_vec.is_empty() {
                RGBColor(76, 114, 176)
            } else {
                hex_to_rgb(&hue_vec[0])
            };
            chart.draw_series(std::iter::once(PathElement::new(
                x_vec.iter().zip(y_vec.iter()).map(|(&x, &y)| (x, y)).collect::<Vec<_>>(),
                color,
            ))).map_plot_err(env)?;
        },
        "bar" | "hist" => {
            let n = x_vec.len();
            let bar_width = 0.8 / (n as f64).max(1.0);
            chart.draw_series(
                x_vec.iter().zip(y_vec.iter()).enumerate().map(|(i, (&x, &y))| {
                    let color = if hue_vec.is_empty() {
                        RGBColor(76, 114, 176)
                    } else {
                        hex_to_rgb(&hue_vec[i % hue_vec.len()])
                    };
                    Rectangle::new(
                        [(x - bar_width/2.0, 0.0), (x + bar_width/2.0, y)],
                        color.filled(),
                    )
                })
            ).map_plot_err(env)?;
        },
        "box" => {
            let extra_vec = value_to_iter(env, extra_val)?;
            for (i, plist) in extra_vec.iter().enumerate() {
                let min = value_to_f64(get_plist_value(env, *plist, ":min")?)?;
                let q1 = value_to_f64(get_plist_value(env, *plist, ":q1")?)?;
                let median = value_to_f64(get_plist_value(env, *plist, ":median")?)?;
                let q3 = value_to_f64(get_plist_value(env, *plist, ":q3")?)?;
                let max = value_to_f64(get_plist_value(env, *plist, ":max")?)?;
                
                let x = x_vec[i];
                let color = if hue_vec.is_empty() {
                    RGBColor(76, 114, 176)
                } else {
                    hex_to_rgb(&hue_vec[i % hue_vec.len()])
                };

                let s_min = (min - y_min) / y_diff;
                let s_q1 = (q1 - y_min) / y_diff;
                let s_med = (median - y_min) / y_diff;
                let s_q3 = (q3 - y_min) / y_diff;
                let s_max = (max - y_min) / y_diff;

                let box_width = 0.05;
                chart.draw_series(std::iter::once(Rectangle::new(
                    [(x - box_width, s_q1), (x + box_width, s_q3)],
                    color.mix(0.5).filled(),
                ))).map_plot_err(env)?;
                chart.draw_series(std::iter::once(Rectangle::new(
                    [(x - box_width, s_q1), (x + box_width, s_q3)],
                    color.stroke_width(1),
                ))).map_plot_err(env)?;
                chart.draw_series(std::iter::once(PathElement::new(
                    vec![(x - box_width, s_med), (x + box_width, s_med)],
                    color.stroke_width(2),
                ))).map_plot_err(env)?;
                chart.draw_series(std::iter::once(PathElement::new(
                    vec![(x, s_min), (x, s_q1)],
                    color.stroke_width(1),
                ))).map_plot_err(env)?;
                chart.draw_series(std::iter::once(PathElement::new(
                    vec![(x, s_q3), (x, s_max)],
                    color.stroke_width(1),
                ))).map_plot_err(env)?;
            }
        },
        "violin" => {
            let extra_vec = value_to_iter(env, extra_val)?;
            for (i, plist) in extra_vec.iter().enumerate() {
                let kde_list = get_plist_value(env, *plist, ":kde")?;
                let mut points = Vec::new();
                
                let x_center = x_vec[i];
                let color = if hue_vec.is_empty() {
                    RGBColor(76, 114, 176)
                } else {
                    hex_to_rgb(&hue_vec[i % hue_vec.len()])
                };

                let mut curr = kde_list;
                let mut max_density = 0.0;
                let mut kde_data = Vec::new();
                while curr.is_not_nil() && env.call("consp", [curr])?.is_not_nil() {
                    let pair = env.call("car", [curr])?;
                    let py = value_to_f64(env.call("car", [pair])?)?;
                    let dens = value_to_f64(env.call("cdr", [pair])?)?;
                    if dens > max_density { max_density = dens; }
                    kde_data.push((py, dens));
                    curr = env.call("cdr", [curr])?;
                }

                if max_density > 0.0 {
                    let width_factor = 0.1;
                    for (py, dens) in &kde_data {
                        let sy = (py - y_min) / y_diff;
                        let offset = (dens / max_density) * width_factor;
                        points.push((x_center - offset, sy));
                    }
                    for (py, dens) in kde_data.iter().rev() {
                        let sy = (py - y_min) / y_diff;
                        let offset = (dens / max_density) * width_factor;
                        points.push((x_center + offset, sy));
                    }
                    chart.draw_series(std::iter::once(Polygon::new(points, color.mix(0.5).filled())))
                        .map_plot_err(env)?;
                }
            }
        },
        "lm" => {
            chart.draw_series(
                x_vec.iter().zip(y_vec.iter()).enumerate().map(|(i, (&x, &y))| {
                    let color = if hue_vec.is_empty() {
                        RGBColor(76, 114, 176)
                    } else {
                        hex_to_rgb(&hue_vec[i % hue_vec.len()])
                    };
                    Circle::new((x, y), 4, color.mix(0.7).filled())
                })
            ).map_plot_err(env)?;

            let extra_vec = value_to_iter(env, extra_val)?;
            let hue_map = get_plist_value(env, scales, ":hue")?;
            
            for item in extra_vec {
                let h = env.call("car", [item])?;
                let stats = env.call("cdr", [item])?;
                
                let m = value_to_f64(get_plist_value(env, stats, ":m")?)?;
                let b = value_to_f64(get_plist_value(env, stats, ":b")?)?;
                let se = value_to_f64(get_plist_value(env, stats, ":se")?)?;
                let sxx = value_to_f64(get_plist_value(env, stats, ":sxx")?)?;
                let mean_x = value_to_f64(get_plist_value(env, stats, ":mean-x")?)?;
                let n = value_to_f64(get_plist_value(env, stats, ":n")?)?;

                let h_name = env.call("symbol-name", [h])?.into_rust::<String>()?;
                let color = if h_name == "overall" {
                    RGBColor(76, 114, 176)
                } else {
                    let color_val = env.call("assoc", [h, hue_map])?;
                    if color_val.is_not_nil() {
                        hex_to_rgb(&env.call("cdr", [color_val])?.into_rust::<String>()?)
                    } else {
                        RGBColor(76, 114, 176)
                    }
                };

                if se > 0.0 && sxx > 0.0 && n > 2.0 {
                    let mut ci_points = Vec::new();
                    let steps = 20;
                    
                    for step in 0..=steps {
                        let ratio = step as f64 / steps as f64;
                        let xv = x_min + ratio * (x_max - x_min);
                        let yv = m * xv + b;
                        let se_r = se * ( (1.0/n + (xv - mean_x).powi(2) / sxx).sqrt() );
                        let ci_width = 2.0 * se_r;
                        let sy = (yv + ci_width - y_min) / y_diff;
                        ci_points.push((ratio, sy));
                    }
                    for step in (0..=steps).rev() {
                        let ratio = step as f64 / steps as f64;
                        let xv = x_min + ratio * (x_max - x_min);
                        let yv = m * xv + b;
                        let se_r = se * ( (1.0/n + (xv - mean_x).powi(2) / sxx).sqrt() );
                        let ci_width = 2.0 * se_r;
                        let sy = (yv - ci_width - y_min) / y_diff;
                        ci_points.push((ratio, sy));
                    }
                    chart.draw_series(std::iter::once(Polygon::new(ci_points, color.mix(0.15).filled())))
                        .map_plot_err(env)?;
                }

                let y_at_min = m * x_min + b;
                let y_at_max = m * x_max + b;
                let sy1 = (y_at_min - y_min) / y_diff;
                let sy2 = (y_at_max - y_min) / y_diff;
                
                chart.draw_series(std::iter::once(PathElement::new(
                    vec![(0.0, sy1), (1.0, sy2)],
                    color.stroke_width(2),
                ))).map_plot_err(env)?;
            }
        },
        "smooth" => {
            let orig_x = value_to_f64_vec(env, get_plist_value(env, extra_val, ":original-x")?)?;
            let orig_y = value_to_f64_vec(env, get_plist_value(env, extra_val, ":original-y")?)?;
            let orig_hue = value_to_string_vec(env, get_plist_value(env, extra_val, ":original-hue")?)?;

            chart.draw_series(
                orig_x.iter().zip(orig_y.iter()).enumerate().map(|(i, (&x, &y))| {
                    let sx = (x - x_min) / (x_max - x_min).max(1.0);
                    let sy = (y - y_min) / y_diff;
                    let color = if orig_hue.is_empty() {
                        RGBColor(76, 114, 176)
                    } else {
                        hex_to_rgb(&orig_hue[i % orig_hue.len()])
                    };
                    Circle::new((sx, sy), 3, color.mix(0.4).filled())
                })
            ).map_plot_err(env)?;

            chart.draw_series(std::iter::once(PathElement::new(
                x_vec.iter().zip(y_vec.iter()).map(|(&x, &y)| (x, y)).collect::<Vec<_>>(),
                RGBColor(76, 114, 176).stroke_width(2),
            ))).map_plot_err(env)?;
        },
        _ => {
            let msg = format!("Unsupported plot type in Rust: {}", plot_type);
            let data = env.list(&[msg.into_lisp(env)?])?;
            env.signal(env.intern("error")?, (data,))?;
            unreachable!()
        }
    }

    Ok(())
}

#[defun]
pub fn render(env: &Env, plot: Value) -> Result<String> {
    let spec = env.call("drake-plot-spec", [plot])?;
    let width = get_plist_value(env, spec, ":width")?
        .into_rust::<i32>().unwrap_or(600);
    let height = get_plist_value(env, spec, ":height")?
        .into_rust::<i32>().unwrap_or(400);

    let mut buffer = String::new();
    {
        let root = SVGBackend::with_string(&mut buffer, (width as u32, height as u32))
            .into_drawing_area();
        root.fill(&WHITE).map_plot_err(env)?;

        draw_plot_on_area(env, &root, plot)?;
    }

    Ok(buffer)
}

#[defun]
pub fn render_facet(env: &Env, fplot: Value) -> Result<String> {
    let title = env.call("drake-facet-plot-title", [fplot])?.into_rust::<Option<String>>()?;
    let rows = env.call("drake-facet-plot-rows", [fplot])?.into_rust::<i32>()?;
    let cols = env.call("drake-facet-plot-cols", [fplot])?.into_rust::<i32>()?;
    let grid = env.call("drake-facet-plot-grid", [fplot])?;

    // Determine dimensions from the first plot in grid
    let first_row = env.call("car", [grid])?;
    let first_plot = env.call("car", [first_row])?;
    let spec = env.call("drake-plot-spec", [first_plot])?;
    let p_width = get_plist_value(env, spec, ":width")?.into_rust::<i32>().unwrap_or(400);
    let p_height = get_plist_value(env, spec, ":height")?.into_rust::<i32>().unwrap_or(300);

    let total_width = p_width * cols;
    let total_height = p_height * rows + if title.is_some() { 40 } else { 0 };

    let mut buffer = String::new();
    {
        let root = SVGBackend::with_string(&mut buffer, (total_width as u32, total_height as u32))
            .into_drawing_area();
        root.fill(&WHITE).map_plot_err(env)?;

        let mut body_area = root.clone();
        if let Some(t) = title {
            let (top, body) = root.split_vertically(40);
            let style = ("sans-serif", 25).into_font().into_text_style(&top);
            top.draw_text(
                &t,
                &style,
                (total_width as i32 / 2 - (t.len() as i32 * 6), 30),
            ).map_plot_err(env)?;
            body_area = body;
        }

        let sub_areas = body_area.split_evenly((rows as usize, cols as usize));
        
        let mut r_curr = grid;
        for r in 0..rows {
            let mut c_curr = env.call("car", [r_curr])?;
            for c in 0..cols {
                let plot = env.call("car", [c_curr])?;
                let area = &sub_areas[r as usize * cols as usize + c as usize];
                draw_plot_on_area(env, area, plot)?;
                c_curr = env.call("cdr", [c_curr])?;
            }
            r_curr = env.call("cdr", [r_curr])?;
        }
    }

    Ok(buffer)
}

// ============================================================================
// Mathematical Operations for Statistical Computing
// ============================================================================

/// Gaussian kernel function for KDE
fn gaussian_kernel(u: f64) -> f64 {
    use std::f64::consts::PI;
    (-0.5 * u * u).exp() / (2.0 * PI).sqrt()
}

/// Calculate standard deviation of a dataset
fn standard_deviation(data: &[f64]) -> f64 {
    if data.is_empty() {
        return 0.0;
    }
    let n = data.len() as f64;
    let mean: f64 = data.iter().sum::<f64>() / n;
    let variance: f64 = data.iter()
        .map(|x| (x - mean).powi(2))
        .sum::<f64>() / (n - 1.0).max(1.0);
    variance.sqrt().max(0.0001)
}

/// Calculate bandwidth using Scott's rule
fn kde_scott_bandwidth(data: &[f64]) -> f64 {
    let n = data.len() as f64;
    let sd = standard_deviation(data);
    sd * n.powf(-0.2)
}

/// Calculate bandwidth using Silverman's rule
fn kde_silverman_bandwidth(data: &[f64]) -> f64 {
    let n = data.len() as f64;
    let sd = standard_deviation(data);
    1.06 * sd * n.powf(-0.2)
}

/// Estimate density at a point using KDE
fn kde_estimate_density(x: f64, data: &[f64], bandwidth: f64) -> f64 {
    let n = data.len() as f64;
    let sum: f64 = data.iter()
        .map(|&xi| gaussian_kernel((x - xi) / bandwidth))
        .sum();
    sum / (n * bandwidth)
}

#[defun]
pub fn kde_compute<'e>(env: &'e Env, data: Value<'e>, method: Value<'e>, grid_size: Value<'e>) -> Result<Value<'e>> {
    // Convert data vector
    let data_vec = value_to_f64_vec(env, data)?;
    if data_vec.is_empty() {
        return env.list(&[]);
    }

    // Get method (scott or silverman)
    let method_str = if method.is_not_nil() {
        env.call("symbol-name", [method])?.into_rust::<String>()?
    } else {
        "scott".to_string()
    };

    // Get grid size (default 100)
    let grid_points: usize = if grid_size.is_not_nil() {
        grid_size.into_rust::<i64>()? as usize
    } else {
        100
    };

    // Calculate bandwidth
    let bandwidth = if method_str == "silverman" {
        kde_silverman_bandwidth(&data_vec)
    } else {
        kde_scott_bandwidth(&data_vec)
    };

    // Find min and max
    let min_val = data_vec.iter().fold(f64::INFINITY, |a, &b| a.min(b));
    let max_val = data_vec.iter().fold(f64::NEG_INFINITY, |a, &b| a.max(b));
    let range = max_val - min_val;

    // Generate grid points and estimate density
    let mut result = Vec::new();
    for i in 0..grid_points {
        let x = min_val + (i as f64 / (grid_points - 1) as f64) * range;
        let density = kde_estimate_density(x, &data_vec, bandwidth);
        result.push(env.cons(x.into_lisp(env)?, density.into_lisp(env)?)?);
    }

    env.list(&result)
}

#[defun]
pub fn ols_regression<'e>(env: &'e Env, points: Value<'e>) -> Result<Value<'e>> {
    // Convert points list to vectors
    let mut x_vals = Vec::new();
    let mut y_vals = Vec::new();

    let mut curr = points;
    while curr.is_not_nil() {
        let point = env.call("car", [curr])?;
        let x = env.call("car", [point])?.into_rust::<f64>()?;
        let y = env.call("cdr", [point])?.into_rust::<f64>()?;
        x_vals.push(x);
        y_vals.push(y);
        curr = env.call("cdr", [curr])?;
    }

    if x_vals.is_empty() {
        return env.list(&[
            0.0.into_lisp(env)?,  // slope
            0.0.into_lisp(env)?,  // intercept
            0.0.into_lisp(env)?,  // r-squared
        ]);
    }

    let n = x_vals.len() as f64;

    // Calculate means
    let mean_x: f64 = x_vals.iter().sum::<f64>() / n;
    let mean_y: f64 = y_vals.iter().sum::<f64>() / n;

    // Calculate slope and intercept
    let mut numerator = 0.0;
    let mut denominator = 0.0;

    for i in 0..x_vals.len() {
        let dx = x_vals[i] - mean_x;
        let dy = y_vals[i] - mean_y;
        numerator += dx * dy;
        denominator += dx * dx;
    }

    let slope = if denominator.abs() < 1e-10 {
        0.0
    } else {
        numerator / denominator
    };

    let intercept = mean_y - slope * mean_x;

    // Calculate R-squared
    let mut ss_res = 0.0;
    let mut ss_tot = 0.0;

    for i in 0..x_vals.len() {
        let y_pred = slope * x_vals[i] + intercept;
        ss_res += (y_vals[i] - y_pred).powi(2);
        ss_tot += (y_vals[i] - mean_y).powi(2);
    }

    let r_squared = if ss_tot.abs() < 1e-10 {
        0.0
    } else {
        1.0 - (ss_res / ss_tot)
    };

    // Return plist: (:slope m :intercept b :r-squared r2)
    env.list(&[
        env.intern(":slope")?,
        slope.into_lisp(env)?,
        env.intern(":intercept")?,
        intercept.into_lisp(env)?,
        env.intern(":r-squared")?,
        r_squared.into_lisp(env)?,
    ])
}

#[defun]
pub fn compute_quartiles<'e>(env: &'e Env, data: Value<'e>) -> Result<Value<'e>> {
    // Convert data vector
    let mut data_vec = value_to_f64_vec(env, data)?;

    if data_vec.is_empty() {
        return env.list(&[
            env.intern(":min")?, 0.0.into_lisp(env)?,
            env.intern(":q1")?, 0.0.into_lisp(env)?,
            env.intern(":median")?, 0.0.into_lisp(env)?,
            env.intern(":q3")?, 0.0.into_lisp(env)?,
            env.intern(":max")?, 0.0.into_lisp(env)?,
        ]);
    }

    // Sort the data
    data_vec.sort_by(|a, b| a.partial_cmp(b).unwrap_or(std::cmp::Ordering::Equal));

    let n = data_vec.len();
    let min_val = data_vec[0];
    let max_val = data_vec[n - 1];

    // Helper function to calculate quantile
    let quantile = |q: f64| -> f64 {
        let pos = q * (n - 1) as f64;
        let lower = pos.floor() as usize;
        let upper = pos.ceil() as usize;
        let weight = pos - lower as f64;

        if lower == upper {
            data_vec[lower]
        } else {
            data_vec[lower] * (1.0 - weight) + data_vec[upper] * weight
        }
    };

    let q1 = quantile(0.25);
    let median = quantile(0.5);
    let q3 = quantile(0.75);

    // Return plist
    env.list(&[
        env.intern(":min")?, min_val.into_lisp(env)?,
        env.intern(":q1")?, q1.into_lisp(env)?,
        env.intern(":median")?, median.into_lisp(env)?,
        env.intern(":q3")?, q3.into_lisp(env)?,
        env.intern(":max")?, max_val.into_lisp(env)?,
    ])
}

#[emacs::module(name = "drake-rust-module", separator = "/")]
fn init(env: &Env) -> Result<()> {
    env.message("Drake Rust Module Initialized")?;
    Ok(())
}

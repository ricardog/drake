use emacs::{defun, Env, Result, Value, IntoLisp};
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
    let size: usize = env.call("length", [value])?.into_rust()?;
    let mut res = Vec::with_capacity(size);
    for i in 0..size {
        let idx = (i as i64).into_lisp(env)?;
        let val: Value = env.call("aref", [value, idx])?;
        res.push(value_to_f64(val)?);
    }
    Ok(res)
}

fn value_to_string_vec<'e>(env: &'e Env, value: Value<'e>) -> Result<Vec<String>> {
    if !value.is_not_nil() {
        return Ok(Vec::new());
    }
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
    if env.call("vectorp", [value])?.is_not_nil() {
        let size: usize = env.call("length", [value])?.into_rust()?;
        let mut res = Vec::with_capacity(size);
        for i in 0..size {
            res.push(env.call("aref", [value, (i as i64).into_lisp(env)?])?);
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

#[defun]
pub fn render(env: &Env, plot: Value) -> Result<String> {
    let spec = env.call("drake-plot-spec", [plot])?;
    let data_internal = env.call("drake-plot-data-internal", [plot])?;
    let scales = env.call("drake-plot-scales", [plot])?;

    let plot_type_sym: Value = get_plist_value(env, spec, ":type")?;
    let plot_type = env.call("symbol-name", [plot_type_sym])?.into_rust::<String>()?;
    
    let width = get_plist_value(env, spec, ":width")?
        .into_rust::<i32>().unwrap_or(600);
    let height = get_plist_value(env, spec, ":height")?
        .into_rust::<i32>().unwrap_or(400);
    let title = get_plist_value(env, spec, ":title")?
        .into_rust::<Option<String>>()?;

    let x_vec = value_to_f64_vec(env, get_plist_value(env, data_internal, ":x")?)?;
    let y_vec = value_to_f64_vec(env, get_plist_value(env, data_internal, ":y")?)?;
    let hue_vec = value_to_string_vec(env, get_plist_value(env, data_internal, ":hue")?)?;
    let extra_val = get_plist_value(env, data_internal, ":extra")?;

    let x_range = get_plist_value(env, scales, ":x")?;
    let x_min: f64 = if x_range.is_not_nil() { value_to_f64(env.call("car", [x_range])?)? } else { 0.0 };
    let x_max: f64 = if x_range.is_not_nil() { value_to_f64(env.call("cdr", [x_range])?)? } else { 1.0 };

    let y_range = get_plist_value(env, scales, ":y")?;
    let y_min: f64 = if y_range.is_not_nil() { value_to_f64(env.call("car", [y_range])?)? } else { 0.0 };
    let y_max: f64 = if y_range.is_not_nil() { value_to_f64(env.call("cdr", [y_range])?)? } else { 1.0 };
    let y_diff = if y_max == y_min { 1.0 } else { y_max - y_min };

    let mut buffer = String::new();
    {
        let root = SVGBackend::with_string(&mut buffer, (width as u32, height as u32))
            .into_drawing_area();
        root.fill(&WHITE).map_plot_err(env)?;

        let margin = 60;
        let chart_area = root.margin(margin, margin, margin, margin);

        if let Some(t) = title {
            let style = ("sans-serif", 20).into_font().into_text_style(&root);
            root.draw_text(
                &t,
                &style,
                (width / 2 - (t.len() as i32 * 5), 20),
            ).map_plot_err(env)?;
        }

        let mut chart = ChartBuilder::on(&chart_area)
            .build_cartesian_2d(0.0..1.0, 0.0..1.0)
            .map_plot_err(env)?;

        chart.configure_mesh().draw().map_plot_err(env)?;

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
                        let x_diff = x_max - x_min;
                        
                        for step in 0..=steps {
                            let ratio = step as f64 / steps as f64;
                            let xv = x_min + ratio * x_diff;
                            let yv = m * xv + b;
                            let se_r = se * ( (1.0/n + (xv - mean_x).powi(2) / sxx).sqrt() );
                            let ci_width = 2.0 * se_r;
                            let sy = (yv + ci_width - y_min) / y_diff;
                            ci_points.push((ratio, sy));
                        }
                        for step in (0..=steps).rev() {
                            let ratio = step as f64 / steps as f64;
                            let xv = x_min + ratio * x_diff;
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
    }

    Ok(buffer)
}

#[emacs::module(name = "drake-rust-module", separator = "/")]
fn init(env: &Env) -> Result<()> {
    env.message("Drake Rust Module Initialized")?;
    Ok(())
}

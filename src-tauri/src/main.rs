#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

mod cli;
mod profile;
mod window;

use base64::Engine;
use clap::Parser;
use cli::Args;
use profile::WindowState;
use std::path::PathBuf;
use tauri::Manager;

// ── JS injetado no webapp (comportamento de browser) ─────────────────────────

const DEFAULT_USER_AGENT: &str = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36";

const BROWSER_BEHAVIOR_JS: &str = r#"
    if (window.__CLAW_BROWSER_INJECTED__) return;
    window.__CLAW_BROWSER_INJECTED__ = true;

    document.addEventListener('click', function(e) {
        const link = e.target.closest('a[href]');
        if (!link) return;
        const href = link.getAttribute('href');
        if (!href || href === '#' || href.startsWith('javascript:') || href.startsWith('#')) return;

        const target = link.getAttribute('target');
        if (target === '_blank' || target === '_new') {
            e.preventDefault();
            location.href = link.href;
        }
    }, false);

    window.open = function(url, _target, _features) {
        if (!url) return null;
        if (!url.startsWith('http') && !url.startsWith('//') &&
            !url.startsWith('data:') && !url.startsWith('blob:')) {
            try { url = new URL(url, location.origin).href; }
            catch (_) { url = location.href; }
        }
        location.href = url;
        return null;
    };

    HTMLFormElement.prototype.submit = (function(original) {
        return function() {
            const target = this.getAttribute('target');
            if (target === '_blank' || target === '_new') {
                this.removeAttribute('target');
                original.call(this);
                this.setAttribute('target', target);
                return;
            }
            original.call(this);
        };
    })(HTMLFormElement.prototype.submit);

    Object.defineProperty(navigator, 'userAgent', {
        value: 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        writable: false,
        configurable: false,
    });
"#;

// ── Helpers internos ──────────────────────────────────────────────────────────

fn find_script() -> Result<PathBuf, String> {
    // 1. Variável de ambiente explícita
    if let Ok(dir) = std::env::var("CLAW_SCRIPT_DIR") {
        let script = PathBuf::from(dir).join("create_app.sh");
        if script.exists() { return Ok(script); }
    }

    // 2. Mesmo diretório do executável
    if let Ok(exe) = std::env::current_exe() {
        if let Some(dir) = exe.parent() {
            let script = dir.join("create_app.sh");
            if script.exists() { return Ok(script); }
        }
    }

    // 3. Diretório de recursos instalado localmente (~/.local/share/claw-launcher)
    if let Some(share_dir) = dirs::data_local_dir() {
        let script = share_dir.join("claw-launcher").join("create_app.sh");
        if script.exists() { return Ok(script); }
    }

    // 4. Pastas de cloud storage conhecidas
    if let Some(home) = dirs::home_dir() {
        for cloud in ["GoogleDrive", "OneDrive"] {
            let script = home
                .join(cloud)
                .join("App-Prontos/Claw_Launcher_Linux_App_Rust-main/create_app.sh");
            if script.exists() { return Ok(script); }
        }
    }

    Err("create_app.sh não encontrado. Execute via ./create_app.sh".to_string())
}

fn strip_ansi(input: &str) -> String {
    let mut out = String::with_capacity(input.len());
    let mut chars = input.chars().peekable();
    while let Some(c) = chars.next() {
        if c == '\x1b' && chars.peek() == Some(&'[') {
            chars.next();
            for c2 in chars.by_ref() {
                if c2.is_alphabetic() { break; }
            }
        } else {
            out.push(c);
        }
    }
    out
}

fn run_sh(args: &[&str]) -> Result<String, String> {
    let script = find_script()?;
    let script_dir = script.parent().unwrap().to_path_buf();
    let out = std::process::Command::new("bash")
        .arg(&script)
        .args(args)
        .env("CLAW_SCRIPT_DIR", &script_dir)
        .output()
        .map_err(|e| e.to_string())?;
    let combined = format!(
        "{}{}",
        String::from_utf8_lossy(&out.stdout),
        String::from_utf8_lossy(&out.stderr),
    );
    let clean = strip_ansi(&combined);
    if out.status.success() { Ok(clean) } else { Err(clean) }
}

/// Resolve o path do .desktop de uma instância instalada.
fn desktop_path(app_id: &str) -> PathBuf {
    dirs::data_local_dir()
        .unwrap_or_else(|| {
            dirs::home_dir()
                .unwrap_or_else(|| PathBuf::from("/tmp"))
                .join(".local/share")
        })
        .join("applications")
        .join(format!("{}.desktop", app_id))
}

// ── Comandos Tauri ────────────────────────────────────────────────────────────

#[tauri::command]
fn launch_app(url: String, app_id: String, name: String) -> Result<(), String> {
    let exe = std::env::current_exe().map_err(|e| e.to_string())?;
    std::process::Command::new(exe)
        .args(["--url", &url, "--app-id", &app_id, "--name", &name])
        .spawn()
        .map_err(|e| e.to_string())?;
    Ok(())
}

#[tauri::command]
fn script_available() -> bool {
    find_script().is_ok()
}

#[tauri::command]
fn list_instances_gui() -> Result<String, String> {
    run_sh(&["list-json"])
}

#[tauri::command]
fn list_icons_gui() -> Result<Vec<String>, String> {
    let base_dir = match find_script() {
        Ok(script_path) => script_path.parent().map(|p| p.to_path_buf()).unwrap_or_else(|| PathBuf::from(".")),
        Err(_) => {
            if let Ok(dir) = std::env::var("CLAW_SCRIPT_DIR") {
                PathBuf::from(dir)
            } else {
                PathBuf::from(".")
            }
        }
    };
    let icon_dir = base_dir.join("ICON");
    if !icon_dir.exists() { return Ok(vec![]); }
    let mut icons: Vec<String> = std::fs::read_dir(&icon_dir)
        .map_err(|e| e.to_string())?
        .flatten()
        .filter_map(|e| {
            let p = e.path();
            if p.extension().and_then(|x| x.to_str()) == Some("png") {
                p.file_stem().map(|s| s.to_string_lossy().into_owned())
            } else {
                None
            }
        })
        .collect();
    icons.sort();
    Ok(icons)
}

#[tauri::command]
fn get_icon_base64(name: String) -> Result<String, String> {
    let script = find_script()?;
    let icon_dir = script
        .parent()
        .ok_or("Erro ao localizar pasta pai do script")?
        .join("ICON");

    let icon_path = ["png", "jpg", "jpeg", "svg"]
        .iter()
        .map(|ext| icon_dir.join(format!("{}.{}", name, ext)))
        .find(|p| p.exists())
        .ok_or_else(|| format!("Ícone '{}' não encontrado em {:?}", name, icon_dir))?;

    let bytes = std::fs::read(&icon_path)
        .map_err(|e| format!("Erro ao ler {:?}: {}", icon_path, e))?;

    let mime = match icon_path.extension().and_then(|e| e.to_str()) {
        Some("jpg") | Some("jpeg") => "image/jpeg",
        Some("svg")                => "image/svg+xml",
        _                          => "image/png",
    };

    Ok(format!(
        "data:{};base64,{}",
        mime,
        base64::engine::general_purpose::STANDARD.encode(&bytes)
    ))
}

#[tauri::command]
fn create_app_gui(name: String, url: String, icon: String) -> Result<String, String> {
    run_sh(&["create-install", &name, &url, &icon])
}

#[tauri::command]
fn uninstall_app_gui(app_id: String, clean_data: bool, del_folder: bool) -> Result<String, String> {
    run_sh(&[
        "uninstall-id",
        &app_id,
        if clean_data { "s" } else { "n" },
        if del_folder { "s" } else { "n" },
    ])
}

#[tauri::command]
fn clear_cache_gui(app_id: String) -> Result<String, String> {
    run_sh(&["clear-cache-id", &app_id])
}

#[tauri::command]
fn manage_onenote_gui() -> Result<String, String> {
    if desktop_path("Claw_OneNote").exists() {
        run_sh(&["uninstall-id", "Claw_OneNote", "n", "n"])
    } else {
        run_sh(&["create-install", "OneNote", "https://onenote.cloud.microsoft/pt-br/", "onenote"])
    }
}

#[tauri::command]
fn onenote_installed() -> bool {
    desktop_path("Claw_OneNote").exists()
}

#[tauri::command]
fn build_gui() -> Result<String, String> {
    run_sh(&["build-silent"])
}

#[tauri::command]
fn clean_builds_gui() -> Result<String, String> {
    run_sh(&["clean"])
}

#[tauri::command]
fn purge_all_gui() -> Result<String, String> {
    run_sh(&["purge-force"])
}

// ── Main ──────────────────────────────────────────────────────────────────────

fn main() {
    let args = Args::parse();
    let is_gui = args.is_gui_mode();

    if !is_gui {
        let profile_path = args.profile_path();
        let cache_path   = args.cache_path();

        // Corrigido: profile_path é o diretório do app, não seu parent
        std::env::set_var("XDG_DATA_HOME", &profile_path);
        std::env::set_var("XDG_CACHE_HOME", &cache_path);

        if let Err(e) = WindowState::init_directories(&profile_path, &cache_path) {
            eprintln!("Erro ao inicializar diretórios: {}", e);
            std::process::exit(1);
        }
    }

    #[cfg(target_os = "linux")]
    {
        std::env::set_var("WEBKIT_DISABLE_DMABUF_RENDERER", "1");
        std::env::set_var("WEBKIT_MEMORY_PRESSURE_SETTINGS", "256,512,1024");
    }

    let lang       = std::env::var("LANG").unwrap_or_else(|_| "en".to_string());
    let reload_label = if lang.starts_with("pt") { "Recarregar" } else { "Reload" };

    let app_id  = args.app_id.clone().unwrap_or_default();
    let name    = args.name.clone().unwrap_or_default();
    let profile = args.profile_path();

    let parsed_url: Option<url::Url> = if !is_gui {
        match args.url.as_ref().unwrap().parse() {
            Ok(u)  => Some(u),
            Err(e) => { eprintln!("URL inválida: {}", e); std::process::exit(1); }
        }
    } else {
        None
    };

    tauri::Builder::default()
        .setup(move |app| {
            // Registra o nome do processo no GLib (necessário para isolamento no GNOME/KDE)
            #[cfg(target_os = "linux")]
            if !is_gui {
                unsafe {
                    extern "C" { fn g_set_prgname(p: *const std::os::raw::c_char); }
                    if let Ok(c) = std::ffi::CString::new(app_id.as_str()) {
                        g_set_prgname(c.as_ptr());
                    }
                }
            }

            let reload_item = tauri::menu::MenuItemBuilder::with_id("reload", reload_label)
                .accelerator("F5")
                .build(app)?;
            let menu = tauri::menu::MenuBuilder::new(app).item(&reload_item).build()?;
            app.set_menu(menu)?;

            let app_id_for_menu = app_id.clone();
            app.on_menu_event(move |handle, event| {
                if event.id() == "reload" {
                    if let Some(win) = handle.get_webview_window(&app_id_for_menu) {
                        let _ = win.eval("location.reload()");
                    }
                }
            });

            if is_gui {
                window::build_launcher_window(app)?;
            } else {
                let url    = parsed_url.unwrap();
                let window = window::build_webapp_window(
                    app,
                    &app_id,
                    &name,
                    url,
                    &profile,
                    DEFAULT_USER_AGENT,
                    BROWSER_BEHAVIOR_JS,
                )?;

                // Restaura tamanho e posição salvos
                if let Ok(state) = WindowState::load(&profile) {
                    let _ = window.set_size(tauri::Size::Physical(tauri::PhysicalSize {
                        width: state.width as u32, height: state.height as u32,
                    }));
                    if state.x >= 0 && state.y >= 0 {
                        let _ = window.set_position(tauri::Position::Physical(
                            tauri::PhysicalPosition { x: state.x, y: state.y },
                        ));
                    }
                }

                // Persiste tamanho e posição ao fechar
                let profile_close  = profile.clone();
                let window_for_save = window.clone();
                window.on_window_event(move |event| {
                    if let tauri::WindowEvent::CloseRequested { .. } = event {
                        if let Ok(size) = window_for_save.inner_size() {
                            let pos = window_for_save.outer_position()
                                .unwrap_or(tauri::PhysicalPosition { x: 0, y: 0 });
                            let _ = WindowState {
                                width:  size.width  as f64,
                                height: size.height as f64,
                                x: pos.x,
                                y: pos.y,
                            }
                            .save(&profile_close);
                        }
                    }
                });
            }

            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            launch_app,
            script_available,
            list_instances_gui,
            list_icons_gui,
            get_icon_base64,
            create_app_gui,
            uninstall_app_gui,
            clear_cache_gui,
            manage_onenote_gui,
            onenote_installed,
            build_gui,
            clean_builds_gui,
            purge_all_gui,
        ])
        .build(tauri::generate_context!())
        .expect("Erro ao construir aplicativo")
        .run(|_app_handle, _event| {});
}
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

mod cli;
mod profile;
mod window;

use cli::Args;
use clap::Parser;
use tauri::Manager;
use profile::WindowState;
use std::path::PathBuf;
use base64::Engine;

// ── Helpers internos ──────────────────────────────────────────────────────────

fn find_script() -> Result<PathBuf, String> {
    if let Ok(dir) = std::env::var("CLAW_SCRIPT_DIR") {
        let script = PathBuf::from(&dir).join("create_app.sh");
        if script.exists() { return Ok(script); }
    }
    
    let home = std::env::var("HOME").unwrap_or_default();
    if !home.is_empty() {
        let config_file = PathBuf::from(&home).join(".config/claw-launcher/repo_path.txt");
        if config_file.exists() {
            if let Ok(content) = std::fs::read_to_string(&config_file) {
                let repo_dir = PathBuf::from(content.trim());
                let script = repo_dir.join("create_app.sh");
                if script.exists() { return Ok(script); }
            }
        }
    }

    if let Ok(exe) = std::env::current_exe() {
        if let Some(dir) = exe.parent() {
            let script = dir.join("create_app.sh");
            if script.exists() { return Ok(script); }
        }
    }
    
    let common_paths = vec![
        PathBuf::from(&home).join("GoogleDrive/Claw_Launcher_Linux_App_Rust-main/create_app.sh"),
        PathBuf::from(&home).join("OneDrive/Claw_Launcher_Linux_App_Rust-main/create_app.sh"),
        PathBuf::from(&home).join("GoogleDrive/App-Prontos/Claw_Launcher_Linux_App_Rust-main/create_app.sh"),
        PathBuf::from(&home).join("OneDrive/App-Prontos/Claw_Launcher_Linux_App_Rust-main/create_app.sh"),
        PathBuf::from("/opt/claw-launcher/create_app.sh"),
        PathBuf::from("/usr/local/bin/../claw-launcher/create_app.sh"),
    ];
    
    for path in common_paths {
        if path.exists() {
            if path.parent().is_some() { return Ok(path); }
        }
    }
    
    Err("create_app.sh não encontrado. Certifique-se de executar a GUI via ./create_app.sh".to_string())
}

fn strip_ansi(input: &str) -> String {
    let mut out = String::with_capacity(input.len());
    let mut chars = input.chars().peekable();
    while let Some(c) = chars.next() {
        if c == '\x1b' && chars.peek() == Some(&'[') {
            chars.next();
            for c2 in chars.by_ref() { if c2.is_alphabetic() { break; } }
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
        String::from_utf8_lossy(&out.stderr)
    );
    let clean = strip_ansi(&combined);
    if out.status.success() { Ok(clean) } else { Err(clean) }
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
    let dir = std::env::var("CLAW_SCRIPT_DIR")
        .map(PathBuf::from)
        .unwrap_or_else(|_| PathBuf::from("."));
    let icon_dir = dir.join("ICON");
    if !icon_dir.exists() { return Ok(vec![]); }
    let mut icons: Vec<String> = std::fs::read_dir(&icon_dir)
        .map_err(|e| e.to_string())?
        .flatten()
        .filter_map(|e| {
            let p = e.path();
            if p.extension().and_then(|x| x.to_str()) == Some("png") {
                p.file_stem().map(|s| s.to_string_lossy().to_string())
            } else { None }
        })
        .collect();
    icons.sort();
    Ok(icons)
}

#[tauri::command]
fn get_icon_base64(name: String) -> Result<String, String> {
    let script = find_script()?;
    let icon_dir = script.parent()
        .ok_or("Erro ao localizar pasta pai")?
        .join("ICON");

    let extensions = vec!["png", "jpg", "jpeg", "svg"];
    let mut icon_path = None;
    
    for ext in &extensions {
        let path = icon_dir.join(format!("{}.{}", name, ext));
        if path.exists() {
            icon_path = Some(path);
            break;
        }
    }

    let icon_path = icon_path.ok_or(format!(
        "Ícone '{}' não encontrado em {:?}.", name, icon_dir
    ))?;

    let bytes = std::fs::read(&icon_path).map_err(|e| e.to_string())?;
    let base64 = base64::engine::general_purpose::STANDARD.encode(&bytes);
    
    let mime_type = icon_path
        .extension()
        .and_then(|ext| ext.to_str())
        .map(|ext| {
            match ext.to_lowercase().as_str() {
                "jpg" | "jpeg" => "image/jpeg",
                "svg" => "image/svg+xml",
                _ => "image/png",
            }
        })
        .unwrap_or("image/png");
    
    Ok(format!("data:{};base64,{}", mime_type, base64))
}

#[tauri::command]
fn create_app_gui(name: String, url: String, icon: String) -> Result<String, String> {
    run_sh(&["create-install", &name, &url, &icon])
}

#[tauri::command]
fn uninstall_app_gui(app_id: String, clean_data: bool, del_folder: bool) -> Result<String, String> {
    run_sh(&[
        "uninstall-id", &app_id,
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
    let home = std::env::var("HOME").unwrap_or_default();
    let desktop = format!("{}/.local/share/applications/Claw_OneNote.desktop", home);
    if std::path::Path::new(&desktop).exists() {
        run_sh(&["uninstall-id", "Claw_OneNote", "n", "n"])
    } else {
        run_sh(&["create-install", "OneNote", "https://onenote.cloud.microsoft/", "onenote"])
    }
}

#[tauri::command]
fn onenote_installed() -> bool {
    let home = std::env::var("HOME").unwrap_or_default();
    std::path::Path::new(&format!("{}/.local/share/applications/Claw_OneNote.desktop", home)).exists()
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

#[tauri::command]
fn load_microsoft_session() -> Option<profile::SessaoMicrosoft> {
    profile::carregar_sessao_local().ok()
}

#[tauri::command]
fn save_microsoft_session(sessao: profile::SessaoMicrosoft) -> Result<(), String> {
    profile::log_autenticacao("Salvando nova sessão de autenticação no disco...");
    profile::salvar_sessao_local(&sessao).map_err(|e| e.to_string())
}

// ── Main ──────────────────────────────────────────────────────────────────────

fn main() {
    let args = Args::parse();
    let is_gui = args.is_gui_mode();

    let profile_path = args.profile_path();
    let cache_path   = args.cache_path();

    if !is_gui {
        // CORREÇÃO 1: Vinculação precisa sem truncamento por parent(). 
        // Garante isolamento estrito de sandbox por App ID no WebKitGTK.
        std::env::set_var("XDG_DATA_HOME", &profile_path);
        std::env::set_var("XDG_CACHE_HOME", &cache_path);
        
        if let Err(e) = WindowState::init_directories(&profile_path, &cache_path) {
            eprintln!("Erro ao inicializar diretórios: {}", e);
            std::process::exit(1);
        }
    }

    #[cfg(target_os = "linux")]
    std::env::set_var("WEBKIT_DISABLE_DMABUF_RENDERER", "1");
    #[cfg(target_os = "linux")]
    std::env::set_var("WEBKIT_MEMORY_PRESSURE_SETTINGS", "256,512,1024");

    let lang = std::env::var("LANG").unwrap_or_else(|_| "en".to_string());
    let is_pt = lang.starts_with("pt");
    let reload_label = if is_pt { "Recarregar" } else { "Reload" };

    let app_id  = args.app_id.clone().unwrap_or_default();
    let name    = args.name.clone().unwrap_or_default();

    let parsed_url: Option<url::Url> = if !is_gui {
        match args.url.as_ref().unwrap().parse() {
            Ok(u)  => Some(u),
            Err(e) => { eprintln!("URL inválida: {}", e); std::process::exit(1); }
        }
    } else { None };

    tauri::Builder::default()
        .setup(move |app| {
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
                .accelerator("F5").build(app)?;
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
                let app_id_lower = app_id.to_lowercase();
                let processar_auth = app_id_lower.contains("onenote") 
                    || app_id_lower.contains("onedrive")
                    || dirs::home_dir()
                        .map(|h| h.join(".claw").join("cache").join("semantic_cache.json").exists())
                        .unwrap_or(false);

                if processar_auth {
                    profile::log_autenticacao(&format!("Iniciando aplicativo ID: {}. Verificando sessão local...", app_id));
                    if let Ok(sessao) = profile::carregar_sessao_local() {
                        if profile::s_expirou(&sessao) {
                            match profile::renovar_sessao_silenciosa(&sessao) {
                                Ok(nova_sessao) => {
                                    if let Err(e) = profile::salvar_sessao_local(&nova_sessao) {
                                        profile::log_autenticacao(&format!("Erro ao salvar sessão local: {}", e));
                                    }
                                }
                                Err(e) => {
                                    profile::log_autenticacao(&format!("Renovação silenciosa falhou: {}. Login interativo necessário.", e));
                                }
                            }
                        } else {
                            profile::log_autenticacao("Sessão local válida.");
                        }
                    }
                }

                let url = parsed_url.unwrap();
                let window = window::build_webapp_window(app, &app_id, &name, url, &profile_path)?;

                if let Ok(state) = WindowState::load(&profile_path) {
                    let _ = window.set_size(tauri::Size::Physical(tauri::PhysicalSize {
                        width: state.width as u32, height: state.height as u32,
                    }));
                    if state.x >= 0 && state.y >= 0 {
                        let _ = window.set_position(tauri::Position::Physical(
                            tauri::PhysicalPosition { x: state.x, y: state.y },
                        ));
                    }
                }

                let profile_close = profile_path.clone();
                let window_clone  = window.clone();
                
                // CORREÇÃO 2: Unificação síncrona real de fechamento e flush de memória
                window.on_window_event(move |event| {
                    if let tauri::WindowEvent::CloseRequested { api: _api, .. } = event {
                        // Força a execução imediata do flush javascript de tokens capturados antes da janela sumir
                        let _ = window_clone.eval("if(typeof window.__CLAW_FLUSH_SESSAO__ === 'function') { window.__CLAW_FLUSH_SESSAO__(); }");
                        
                        // Consolida o estado de geometria
                        if let Ok(size) = window_clone.inner_size() {
                            let pos = window_clone.outer_position().unwrap_or(tauri::PhysicalPosition { x: 0, y: 0 });
                            let _ = WindowState {
                                width: size.width as f64, height: size.height as f64,
                                x: pos.x, y: pos.y,
                            }.save(&profile_close);
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
            load_microsoft_session,
            save_microsoft_session,
        ])
        .build(tauri::generate_context!())
        .expect("Erro ao construir aplicativo")
        .run(|_app_handle, _event| {});
}
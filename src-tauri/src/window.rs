use std::path::Path;
use tauri::{App, Url, WebviewWindow};

/// Constrói a janela principal do launcher (modo GUI).
pub fn build_launcher_window(app: &mut App) -> Result<WebviewWindow, tauri::Error> {
    let window = tauri::WebviewWindowBuilder::new(
        app,
        "main",
        tauri::WebviewUrl::App("index.html".into()),
    )
    .title("Claw Launcher")
    .inner_size(1200.0, 800.0)
    .min_inner_size(800.0, 600.0)
    .resizable(true)
    .fullscreen(false)
    .build()?;

    #[cfg(debug_assertions)]
    window.open_devtools();

    Ok(window)
}

/// Constrói a janela de webapp isolado (modo CLI).
pub fn build_webapp_window(
    app: &mut App,
    app_id: &str,
    name: &str,
    url: Url,
    profile_path: &Path,
) -> Result<WebviewWindow, tauri::Error> {
    let _ = std::fs::create_dir_all(profile_path);

    tauri::WebviewWindowBuilder::new(app, app_id, tauri::WebviewUrl::External(url))
        .title(name)
        .inner_size(1024.0, 768.0)
        .min_inner_size(640.0, 480.0)
        .resizable(true)
        .fullscreen(false)
        .build()
}
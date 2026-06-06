use tauri::{App, WebviewWindow, Url};
use std::path::Path;

/// Constrói a janela do launcher (interface GUI principal)
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

/// Constrói a janela do webapp isolado
pub fn build_webapp_window(
    app: &mut App,
    app_id: &str,
    name: &str,
    url: Url,
    profile_path: &Path,
) -> Result<WebviewWindow, tauri::Error> {
    let webview_url = tauri::WebviewUrl::External(url);
    
    // Cria diretório de dados se não existir
    let _ = std::fs::create_dir_all(profile_path);
    
    let window = tauri::WebviewWindowBuilder::new(app, app_id, webview_url)
        .title(name)
        .inner_size(1024.0, 768.0)
        .min_inner_size(640.0, 480.0)
        .resizable(true)
        .fullscreen(false)
        .build()?;
    
    // Configuração de dados para persistência
    if let Ok(data_dir) = std::env::var("XDG_DATA_HOME") {
        let webkit_path = format!("{}/{}/webkit", data_dir, app_id);
        let _ = std::fs::create_dir_all(&webkit_path);
    }
    
    Ok(window)
}


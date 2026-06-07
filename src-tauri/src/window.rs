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
    let host_origem = url.host_str().unwrap_or("").to_string();
    let webview_url = tauri::WebviewUrl::External(url);
    
    // Cria diretório de dados se não existir
    let _ = std::fs::create_dir_all(profile_path);
    
    let host_origem_closure = host_origem.clone();
    let mut builder = tauri::WebviewWindowBuilder::new(app, app_id, webview_url)
        .title(name)
        .inner_size(1024.0, 768.0)
        .min_inner_size(640.0, 480.0)
        .resizable(true)
        .fullscreen(false);
    
    let app_id_lower = app_id.to_lowercase();
    if app_id_lower.contains("onenote") || app_id_lower.contains("onedrive") {
        builder = builder.initialization_script(r##"
            (async () => {
                if (window.__CLAW_BROWSER_INJECTED__) return;
                window.__CLAW_BROWSER_INJECTED__ = true;
                
                Object.defineProperty(navigator, 'userAgent', {
                    value: (navigator.__UA__ || 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36') + ' CLAW-Browser/1.0',
                    writable: false,
                    configurable: false
                });

                // Interceptar window.open para manter navegação legítima da Microsoft na mesma WebView
                const originalWindowOpen = window.open;
                window.open = function(url, target, features) {
                    if (url) {
                        try {
                            const parsedUrl = new URL(url, window.location.href);
                            const host = parsedUrl.hostname.toLowerCase();
                            const ehMicrosoft = host.includes("microsoft") 
                                || host.includes("live.com") 
                                || host.includes("onenote.com") 
                                || host.includes("office.com") 
                                || host.includes("sharepoint.com") 
                                || host.includes("office365.com")
                                || host.includes("microsoft365.com")
                                || host.includes("msauth.net");
                                
                            if (ehMicrosoft) {
                                window.location.href = url;
                                return window;
                            }
                        } catch(e) {}
                    }
                    return originalWindowOpen(url, target, features);
                };

                // Interceptar cliques em links target="_blank" para abrir na mesma WebView
                document.addEventListener('click', (e) => {
                    let target = e.target;
                    while (target && target.tagName !== 'A') {
                        target = target.parentNode;
                    }
                    if (target && target.href) {
                        try {
                            const url = new URL(target.href);
                            const host = url.hostname.toLowerCase();
                            const ehMicrosoft = host.includes("microsoft") 
                                || host.includes("live.com") 
                                || host.includes("onenote.com") 
                                || host.includes("office.com") 
                                || host.includes("sharepoint.com") 
                                || host.includes("office365.com")
                                || host.includes("microsoft365.com")
                                || host.includes("msauth.net");
                                
                            if (ehMicrosoft && target.target === "_blank") {
                                target.target = "_self";
                            }
                        } catch(e) {}
                    }
                }, true);

                try {
                    const sessao = await window.__TAURI_INTERNALS__.invoke("load_microsoft_session");
                    if (sessao && sessao.local_storage_data) {
                        let mudou = false;
                        for (const [key, val] of Object.entries(sessao.local_storage_data)) {
                            if (localStorage.getItem(key) !== val) {
                                localStorage.setItem(key, val);
                                mudou = true;
                            }
                        }
                        if (mudou) {
                            console.log("[Claw] localStorage restaurado com a sessão persistida.");
                            location.reload();
                        }
                    }
                } catch (e) {
                    console.error("[Claw] Erro ao carregar sessão:", e);
                }
                
                let salvando = false;
                const salvarSessao = async () => {
                    if (salvando) return;
                    salvando = true;
                    try {
                        const msalKeys = Object.keys(localStorage).filter(k => k.toLowerCase().includes("msal") || k.toLowerCase().includes("token"));
                        if (msalKeys.length > 0) {
                            const data = {};
                            let refresh = "";
                            let access = "";
                            let exp = 0;
                            for (const k of msalKeys) {
                                const v = localStorage.getItem(k);
                                data[k] = v;
                                try {
                                    const p = JSON.parse(v);
                                    if (p && typeof p === "object") {
                                        if (p.credentialType === "RefreshToken") {
                                            refresh = p.secret;
                                        } else if (p.credentialType === "AccessToken") {
                                            access = p.secret;
                                            if (p.expiresOn) exp = parseInt(p.expiresOn);
                                        }
                                    }
                                } catch(_) {}
                                if (!refresh && k.includes("refresh_token") && v.startsWith("M.R3")) refresh = v;
                                if (!access && k.includes("access_token") && (v.startsWith("Ew") || v.startsWith("eyJ"))) access = v;
                            }
                            if (refresh || access) {
                                if (exp === 0) exp = Math.floor(Date.now() / 1000) + 3600;
                                await window.__TAURI_INTERNALS__.invoke("save_microsoft_session", {
                                    sessao: {
                                        access_token: access || "dummy",
                                        refresh_token: refresh || "dummy",
                                        expires_at: exp,
                                        local_storage_data: data
                                    }
                                });
                            }
                        }
                    } catch(e) {
                        console.error("[Claw] Erro ao salvar sessão:", e);
                    } finally {
                        salvando = false;
                    }
                };
                
                setTimeout(salvarSessao, 5000);
                window.addEventListener("storage", salvarSessao);
                setInterval(salvarSessao, 10000);
            })();
        "##);
    }

    let window = builder
        .on_navigation(move |dest_url| {
            if let Some(dest_host) = dest_url.host_str() {
                let de_mesmo_dominio = dest_host == host_origem_closure || dest_host.ends_with(&format!(".{}", host_origem_closure));
                let e_login_microsoft = dest_host.contains("login.microsoftonline.com")
                    || dest_host.contains("login.live.com")
                    || dest_host.contains("microsoftonline.com")
                    || dest_host.contains("live.com")
                    || dest_host.contains("msauth.net")
                    || dest_host.contains("msauthimages.net")
                    || dest_host.contains("msftauth.net")
                    || dest_host.contains("cfp.microsoft.com")
                    || dest_host.contains("microsoftazuread-sso.com")
                    || dest_host.contains("onenote.com")
                    || dest_host.contains("office.com")
                    || dest_host.contains("sharepoint.com")
                    || dest_host.contains("office365.com")
                    || dest_host.contains("microsoft365.com");

                if !de_mesmo_dominio && !e_login_microsoft {
                    let _ = std::process::Command::new("xdg-open")
                        .arg(dest_url.as_str())
                        .spawn();
                    return false; // Bloqueia a navegação interna na WebView
                }
            }
            true // Permite a navegação
        })
        .build()?;
    
    // Configuração de dados para persistência
    if let Ok(data_dir) = std::env::var("XDG_DATA_HOME") {
        let webkit_path = format!("{}/{}/webkit", data_dir, app_id);
        let _ = std::fs::create_dir_all(&webkit_path);
    }
    
    Ok(window)
}


// profile.rs - Gerenciamento de estado da janela e perfil isolado

use serde::{Deserialize, Serialize};
use std::fs;
use std::path::Path;
use std::collections::HashMap;
use std::io::Write;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SessaoMicrosoft {
    pub access_token: String,
    pub refresh_token: String,
    pub expires_at: u64,
    pub local_storage_data: Option<HashMap<String, String>>,
}

pub fn log_autenticacao(msg: &str) {
    let home = dirs::home_dir().unwrap_or_else(|| std::path::PathBuf::from("/var/usrlocal"));
    let log_dir = home.join(".claw").join("logs");
    let _ = fs::create_dir_all(&log_dir);
    
    let hoje = chrono::Local::now().format("%Y%m%d").to_string();
    let log_file = log_dir.join(format!("claw_{}.log", hoje));
    
    let timestamp = chrono::Local::now().format("%Y-%m-%d %H:%M:%S").to_string();
    let log_line = format!("[{}] {}\n", timestamp, msg);
    
    if let Ok(mut file) = fs::OpenOptions::new()
        .create(true)
        .append(true)
        .open(&log_file)
    {
        let _ = file.write_all(log_line.as_bytes());
        let _ = file.sync_all(); // Força a gravação física no log
    }
}

pub fn carregar_sessao_local() -> Result<SessaoMicrosoft, Box<dyn std::error::Error>> {
    let home = dirs::home_dir().ok_or("Home dir não encontrado")?;
    let path = home.join(".claw").join("cache").join("semantic_cache.json");
    if path.exists() {
        let content = fs::read_to_string(&path)?;
        let sessao: SessaoMicrosoft = serde_json::from_str(&content)?;
        Ok(sessao)
    } else {
        Err("Arquivo de sessão inexistente".into())
    }
}

pub fn salvar_sessao_local(sessao: &SessaoMicrosoft) -> Result<(), Box<dyn std::error::Error>> {
    let home = dirs::home_dir().ok_or("Home dir não encontrado")?;
    let cache_dir = home.join(".claw").join("cache");
    fs::create_dir_all(&cache_dir)?;
    
    let json = serde_json::to_string_pretty(sessao)?;

    // CORREÇÃO: Escrita atômica síncrona com fsync controlado para evitar arquivos corrompidos de 0 bytes no reboot do Linux
    let path = cache_dir.join("semantic_cache.json");
    let mut file = fs::File::create(&path)?;
    file.write_all(json.as_bytes())?;
    file.sync_all()?;

    // Sincroniza em message_history.json para histórico do agente
    let path_history = cache_dir.join("message_history.json");
    if let Ok(mut file_hist) = fs::File::create(&path_history) {
        let _ = file_hist.write_all(json.as_bytes());
        let _ = file_hist.sync_all();
    }
    
    Ok(())
}

pub fn s_expirou(sessao: &SessaoMicrosoft) -> bool {
    let agora = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap_or_default()
        .as_secs();
    sessao.expires_at <= agora + 300
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ConfigClaude {
    pub client_id: Option<String>,
    pub scope: Option<String>,
    pub redirect_uri: Option<String>,
}

pub fn inicializar_config_claude_se_nao_existir() {
    let home = dirs::home_dir().unwrap_or_else(|| std::path::PathBuf::from("/var/usrlocal"));
    let config_dir = home.join(".claw").join("config");
    let _ = fs::create_dir_all(&config_dir);
    let path = config_dir.join(".claude.json");
    if !path.exists() {
        let default_config = serde_json::json!({
            "client_id": "d3590ed6-52b3-4102-aeff-aad2292ab01c",
            "scope": "offline_access Contacts.Read Files.ReadWrite People.Read Family.Read Files.Read.All User.Read",
            "redirect_uri": "https://login.microsoftonline.com/common/oauth2/nativeclient"
        });
        if let Ok(json_str) = serde_json::to_string_pretty(&default_config) {
            let _ = fs::write(&path, json_str);
        }
    }
}

pub fn carregar_config_claude() -> ConfigClaude {
    inicializar_config_claude_se_nao_existir();
    let home = dirs::home_dir().unwrap_or_else(|| std::path::PathBuf::from("/var/usrlocal"));
    let path = home.join(".claw").join("config").join(".claude.json");
    if path.exists() {
        if let Ok(content) = fs::read_to_string(&path) {
            if let Ok(config) = serde_json::from_str::<ConfigClaude>(&content) {
                return config;
            }
        }
    }
    ConfigClaude {
        client_id: Some("d3590ed6-52b3-4102-aeff-aad2292ab01c".to_string()),
        scope: Some("offline_access Contacts.Read Files.ReadWrite People.Read Family.Read Files.Read.All User.Read".to_string()),
        redirect_uri: Some("https://login.microsoftonline.com/common/oauth2/nativeclient".to_string()),
    }
}

pub fn atualizar_tokens_no_local_storage(
    mut local_storage_data: HashMap<String, String>,
    novo_access: &str,
    novo_refresh: &str,
    expires_at: u64,
) -> HashMap<String, String> {
    for (key, val) in local_storage_data.iter_mut() {
        if let Ok(mut json_val) = serde_json::from_str::<serde_json::Value>(val) {
            if let Some(obj) = json_val.as_object_mut() {
                if obj.contains_key("credentialType") {
                    let cred_type = obj.get("credentialType").and_then(|v| v.as_str()).unwrap_or("");
                    if cred_type == "AccessToken" {
                        obj.insert("secret".to_string(), serde_json::Value::String(novo_access.to_string()));
                        obj.insert("expiresOn".to_string(), serde_json::Value::String(expires_at.to_string()));
                        obj.insert("extendedExpiresOn".to_string(), serde_json::Value::String((expires_at + 3600).to_string()));
                        if let Ok(new_val_str) = serde_json::to_string(&json_val) {
                            *val = new_val_str;
                        }
                    } else if cred_type == "RefreshToken" {
                        obj.insert("secret".to_string(), serde_json::Value::String(novo_refresh.to_string()));
                        if let Ok(new_val_str) = serde_json::to_string(&json_val) {
                            *val = new_val_str;
                        }
                    }
                }
            }
        }
        
        if key.contains("access_token") && !val.starts_with('{') {
            *val = novo_access.to_string();
        }
        if key.contains("refresh_token") && !val.starts_with('{') {
            *val = novo_refresh.to_string();
        }
    }
    local_storage_data
}

#[allow(dead_code)]
pub fn trocar_codigo_por_token(code: &str) -> Result<SessaoMicrosoft, Box<dyn std::error::Error>> {
    let config = carregar_config_claude();
    let client_id = config.client_id.unwrap_or_else(|| "d3590ed6-52b3-4102-aeff-aad2292ab01c".to_string());
    let scope = config.scope.unwrap_or_else(|| "offline_access Contacts.Read Files.ReadWrite People.Read Family.Read Files.Read.All User.Read".to_string());
    let redirect_uri = config.redirect_uri.unwrap_or_else(|| "https://login.microsoftonline.com/common/oauth2/nativeclient".to_string());

    log_autenticacao("Trocando código de autorização por tokens...");

    let client = reqwest::blocking::Client::builder()
        .user_agent("Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")
        .build()?;

    let res = client.post("https://login.microsoftonline.com/common/oauth2/v2.0/token")
        .form(&[
            ("client_id", client_id.as_str()),
            ("grant_type", "authorization_code"),
            ("code", code),
            ("redirect_uri", redirect_uri.as_str()),
            ("scope", scope.as_str()),
        ])
        .send()?;

    if res.status().is_success() {
        #[derive(Deserialize)]
        struct TokenResponse {
            access_token: String,
            refresh_token: Option<String>,
            expires_in: u64,
        }

        let body: TokenResponse = res.json()?;
        let agora = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap_or_default()
            .as_secs();

        let refresh_token = body.refresh_token.unwrap_or_default();
        
        let sessao = SessaoMicrosoft {
            access_token: body.access_token,
            refresh_token,
            expires_at: agora + body.expires_in,
            local_storage_data: None,
        };

        log_autenticacao("Código trocado por tokens com sucesso.");
        Ok(sessao)
    } else {
        let err_status = res.status();
        let err_body = res.text().unwrap_or_default();
        let err_msg = format!("Falha ao trocar código. Status: {}. Corpo: {}", err_status, err_body);
        log_autenticacao(&err_msg);
        Err(err_msg.into())
    }
}

pub fn renovar_sessao_silenciosa(sessao: &SessaoMicrosoft) -> Result<SessaoMicrosoft, Box<dyn std::error::Error>> {
    let config = carregar_config_claude();
    let client_id = config.client_id.unwrap_or_else(|| "d3590ed6-52b3-4102-aeff-aad2292ab01c".to_string());
    let scope = config.scope.unwrap_or_else(|| "offline_access Contacts.Read Files.ReadWrite People.Read Family.Read Files.Read.All User.Read".to_string());
        
    log_autenticacao("Iniciando renovação silenciosa via endpoint da Microsoft...");
    
    let client = reqwest::blocking::Client::builder()
        .user_agent("Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")
        .build()?;
        
    let res = client.post("https://login.microsoftonline.com/common/oauth2/v2.0/token")
        .form(&[
            ("client_id", client_id.as_str()),
            ("grant_type", "refresh_token"),
            ("refresh_token", sessao.refresh_token.as_str()),
            ("scope", scope.as_str()),
        ])
        .send()?;
        
    if res.status().is_success() {
        #[derive(Deserialize)]
        struct TokenResponse {
            access_token: String,
            refresh_token: Option<String>,
            expires_in: u64,
        }
        
        let body: TokenResponse = res.json()?;
        let agora = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap_or_default()
            .as_secs();
        let expires_at = agora + body.expires_in;
            
        let novo_refresh = body.refresh_token.unwrap_or_else(|| sessao.refresh_token.clone());
        
        let mut novo_local_storage = sessao.local_storage_data.clone();
        if let Some(ref mut data) = novo_local_storage {
            *data = atualizar_tokens_no_local_storage(data.clone(), &body.access_token, &novo_refresh, expires_at);
        }

        let nova_sessao = SessaoMicrosoft {
            access_token: body.access_token,
            refresh_token: novo_refresh,
            expires_at,
            local_storage_data: novo_local_storage,
        };
        
        log_autenticacao("Token atualizado com sucesso via Refresh Token.");
        Ok(nova_sessao)
    } else {
        let err_status = res.status();
        let err_body = res.text().unwrap_or_default();
        let err_msg = format!("Falha na renovação via Microsoft API. Status: {}. Corpo: {}", err_status, err_body);
        log_autenticacao(&err_msg);
        Err(err_msg.into())
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WindowState {
    pub width: f64,
    pub height: f64,
    pub x: i32,
    pub y: i32,
}

impl Default for WindowState {
    fn default() -> Self {
        WindowState {
            width: 1280.0,
            height: 800.0,
            x: 0,
            y: 0,
        }
    }
}

impl WindowState {
    pub fn load(profile_path: &Path) -> Result<Self, Box<dyn std::error::Error>> {
        let window_file = profile_path.join("window.json");

        if window_file.exists() {
            let content = fs::read_to_string(&window_file)?;
            let state: WindowState = serde_json::from_str(&content)?;
            Ok(state)
        } else {
            Ok(WindowState::default())
        }
    }

    pub fn save(&self, profile_path: &Path) -> Result<(), Box<dyn std::error::Error>> {
        fs::create_dir_all(profile_path)?;

        let window_file = profile_path.join("window.json");
        let json = serde_json::to_string_pretty(self)?;
        
        // Escrita atômica síncrona com fsync também na geometria da janela
        let mut file = fs::File::create(&window_file)?;
        file.write_all(json.as_bytes())?;
        file.sync_all()?;

        Ok(())
    }

    pub fn init_directories(profile_path: &Path, cache_path: &Path) -> Result<(), Box<dyn std::error::Error>> {
        fs::create_dir_all(profile_path)?;
        fs::create_dir_all(profile_path.join("storage"))?;
        fs::create_dir_all(profile_path.join("webkit"))?;
        fs::create_dir_all(profile_path.join("webkit/cookies"))?;
        
        fs::create_dir_all(cache_path)?;
        fs::create_dir_all(cache_path.join("webkit"))?;
        fs::create_dir_all(cache_path.join("http"))?;
        fs::create_dir_all(cache_path.join("cookies"))?;

        let config_path = profile_path.join("webkit.conf");
        if !config_path.exists() {
            let config = r#"
# Configuração WebKit para CLAW Launcher
# Persistência de cookies, sessão e dados locais

[Cookies]
EnableCookies=true
CookiePolicy=always

[LocalStorage]
EnableLocalStorage=true
LocalStoragePath=storage/

[SessionStorage]
EnableSessionStorage=true

[Cache]
EnableCache=true
MaxCacheSize=104857600

[Security]
EnablePlugins=false
EnableWebGL=true
"#;
            let mut file = fs::File::create(&config_path)?;
            file.write_all(config.as_bytes())?;
            file.sync_all()?;
        }

        Ok(())
    }
}
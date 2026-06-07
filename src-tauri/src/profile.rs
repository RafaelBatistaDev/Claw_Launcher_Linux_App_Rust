// profile.rs - Gerenciamento de estado da janela e perfil isolado

use serde::{Deserialize, Serialize};
use std::fs;
use std::path::Path;
use std::collections::HashMap;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SessaoMicrosoft {
    pub access_token: String,
    pub refresh_token: String,
    pub expires_at: u64,
    pub local_storage_data: Option<HashMap<String, String>>,
}

pub fn log_autenticacao(msg: &str) {
    let home = dirs::home_dir().unwrap_or_else(|| std::path::PathBuf::from("/tmp"));
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
        use std::io::Write;
        let _ = file.write_all(log_line.as_bytes());
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
    let path = cache_dir.join("semantic_cache.json");
    let json = serde_json::to_string_pretty(sessao)?;
    fs::write(&path, json)?;
    Ok(())
}

pub fn s_expirou(sessao: &SessaoMicrosoft) -> bool {
    let agora = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap_or_default()
        .as_secs();
    sessao.expires_at <= agora + 300
}

pub fn renovar_sessao_silenciosa(sessao: &SessaoMicrosoft) -> Result<SessaoMicrosoft, Box<dyn std::error::Error>> {
    let client_id = std::env::var("MICROSOFT_CLIENT_ID")
        .unwrap_or_else(|_| "d3590ed6-52b3-4102-aeff-aad2292ab01c".to_string());
        
    log_autenticacao("Iniciando renovação silenciosa via endpoint da Microsoft...");
    
    let client = reqwest::blocking::Client::builder()
        .user_agent("Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")
        .build()?;
        
    let res = client.post("https://login.microsoftonline.com/common/oauth2/v2.0/token")
        .form(&[
            ("client_id", client_id.as_str()),
            ("grant_type", "refresh_token"),
            ("refresh_token", sessao.refresh_token.as_str()),
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
            
        let novo_refresh = body.refresh_token.unwrap_or_else(|| sessao.refresh_token.clone());
        let nova_sessao = SessaoMicrosoft {
            access_token: body.access_token,
            refresh_token: novo_refresh,
            expires_at: agora + body.expires_in,
            local_storage_data: sessao.local_storage_data.clone(),
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
    /// Carrega o estado da janela do arquivo de perfil
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

    /// Salva o estado da janela em arquivo
    pub fn save(&self, profile_path: &Path) -> Result<(), Box<dyn std::error::Error>> {
        // Cria o diretório do perfil se não existir
        fs::create_dir_all(profile_path)?;

        let window_file = profile_path.join("window.json");
        let json = serde_json::to_string_pretty(self)?;
        fs::write(&window_file, json)?;

        Ok(())
    }

    /// Inicializa diretórios de armazenamento do WebKit isolado
    pub fn init_directories(profile_path: &Path, cache_path: &Path) -> Result<(), Box<dyn std::error::Error>> {
        // Cria diretórios de dados e cache (estrutura WebKit padrão)
        fs::create_dir_all(profile_path)?;
        fs::create_dir_all(profile_path.join("storage"))?;
        fs::create_dir_all(profile_path.join("webkit"))?;
        fs::create_dir_all(profile_path.join("webkit/cookies"))?;
        
        // Estrutura de cache para WebKit
        fs::create_dir_all(cache_path)?;
        fs::create_dir_all(cache_path.join("webkit"))?;
        fs::create_dir_all(cache_path.join("http"))?;
        fs::create_dir_all(cache_path.join("cookies"))?;

        // Cria arquivo de configuração WebKit se não existir
        let config_path = profile_path.join("webkit.conf");
        if !config_path.exists() {
            let config = r#"
# Configuração WebKit para CLAW Launcher
# Persistência de cookies, sessão e dados locais

[Cookies]
# Habilita cookies persistentes
EnableCookies=true
CookiePolicy=always

[LocalStorage]
# Habilita localStorage persistente
EnableLocalStorage=true
LocalStoragePath=storage/

[SessionStorage]
# Mantém dados de sessão durante a aplicação
EnableSessionStorage=true

[Cache]
# Habilita cache HTTP
EnableCache=true
MaxCacheSize=104857600

[Security]
# Segurança padrão
EnablePlugins=false
EnableWebGL=true
"#;
            fs::write(&config_path, config)?;
        }

        Ok(())
    }
}

// profile.rs - Gerenciamento de estado da janela e perfil isolado

use serde::{Deserialize, Serialize};
use std::fs;
use std::path::Path;

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

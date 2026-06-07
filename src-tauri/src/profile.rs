use serde::{Deserialize, Serialize};
use std::{fs, path::Path};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WindowState {
    pub width:  f64,
    pub height: f64,
    pub x:      i32,
    pub y:      i32,
}

impl Default for WindowState {
    fn default() -> Self {
        Self { width: 1280.0, height: 800.0, x: 0, y: 0 }
    }
}

impl WindowState {
    /// Carrega o estado da janela do perfil, ou retorna o padrão se ausente.
    pub fn load(profile_path: &Path) -> Result<Self, Box<dyn std::error::Error>> {
        let path = profile_path.join("window.json");
        if !path.exists() {
            return Ok(Self::default());
        }
        let content = fs::read_to_string(&path)?;
        Ok(serde_json::from_str(&content)?)
    }

    /// Persiste o estado da janela em `profile_path/window.json`.
    pub fn save(&self, profile_path: &Path) -> Result<(), Box<dyn std::error::Error>> {
        fs::create_dir_all(profile_path)?;
        fs::write(
            profile_path.join("window.json"),
            serde_json::to_string_pretty(self)?,
        )?;
        Ok(())
    }

    /// Inicializa a estrutura de diretórios XDG para dados e cache WebKit.
    pub fn init_directories(
        profile_path: &Path,
        cache_path: &Path,
    ) -> Result<(), Box<dyn std::error::Error>> {
        for sub in ["", "storage", "webkit", "webkit/cookies"] {
            fs::create_dir_all(profile_path.join(sub))?;
        }
        for sub in ["", "webkit", "http", "cookies"] {
            fs::create_dir_all(cache_path.join(sub))?;
        }
        Ok(())
    }
}
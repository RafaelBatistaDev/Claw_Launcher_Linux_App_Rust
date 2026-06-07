use clap::Parser;
use std::path::PathBuf;

#[derive(Parser, Debug, Clone)]
#[command(name = "claw-launcher")]
#[command(about = "WebApp Launcher for Fedora Kinoite", long_about = None)]
pub struct Args {
    #[arg(long)] pub url:     Option<String>,
    #[arg(long)] pub app_id:  Option<String>,
    #[arg(long)] pub name:    Option<String>,
    #[arg(long)] pub profile: Option<PathBuf>,
}

impl Args {
    pub fn is_gui_mode(&self) -> bool {
        self.url.is_none() || self.app_id.is_none() || self.name.is_none()
    }

    pub fn profile_path(&self) -> PathBuf {
        let id = self.app_id.as_deref().unwrap_or("claw-launcher");
        self.profile.clone().unwrap_or_else(|| {
            dirs::data_local_dir()
                .unwrap_or_else(fallback_home)
                .join(id)
        })
    }

    pub fn cache_path(&self) -> PathBuf {
        let id = self.app_id.as_deref().unwrap_or("claw-launcher");
        dirs::cache_dir()
            .unwrap_or_else(fallback_home)
            .join(id)
    }
}

/// Fallback seguro quando dirs falha — nunca usa /tmp para evitar perda de dados.
fn fallback_home() -> PathBuf {
    dirs::home_dir()
        .unwrap_or_else(|| PathBuf::from("/tmp"))
        .join(".local")
        .join("share")
}
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
    /// Determina se o Launcher deve abrir a interface de gerenciamento principal (GUI)
    pub fn is_gui_mode(&self) -> bool {
        self.url.is_none() || self.app_id.is_none() || self.name.is_none()
    }

    /// Resolve o diretório do perfil de dados persistentes isolados (Cookies/LocalStorage do WebKit)
    pub fn profile_path(&self) -> PathBuf {
        let id = self.app_id.as_deref().unwrap_or("claw-launcher");
        match &self.profile {
            Some(p) => p.clone(),
            None => {
                // Prioriza a pasta de dados persistentes do usuário, evitando caminhos voláteis no Fedora Atomic
                let mut p = dirs::data_local_dir().unwrap_or_else(|| {
                    let home = std::env::var("HOME").unwrap_or_else(|_| "/var/usrlocal".to_string());
                    PathBuf::from(home).join(".local").join("share")
                });
                // Unifica sob a árvore do ecossistema Claw para webapps isolados
                p.push("claw");
                p.push("profiles");
                p.push(id);
                p
            }
        }
    }

    /// Resolve o diretório de cache persistente onde as sessões extraídas e logs residem
    pub fn cache_path(&self) -> PathBuf {
        let id = self.app_id.as_deref().unwrap_or("claw-launcher");
        let mut p = dirs::cache_dir().unwrap_or_else(|| {
            let home = std::env::var("HOME").unwrap_or_else(|_| "/tmp".to_string());
            PathBuf::from(home).join(".cache")
        });
        p.push("claw");
        p.push(id);
        p
    }
}
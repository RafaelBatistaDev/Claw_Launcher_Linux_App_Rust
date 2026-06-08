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
        if let Some(p) = &self.profile {
            return p.clone();
        }

        let id = self.app_id.as_deref().unwrap_or("claw-launcher");

        if let Some(custom_dir) = crate::read_data_dir_from_conf(id) {
            return custom_dir;
        }

        let mut p = dirs::data_local_dir().unwrap_or_else(||
            PathBuf::from(std::env::var("HOME").unwrap_or("/tmp".into()))
                .join(".local").join("share"));
        p.push(id);
        p
    }

    pub fn cache_path(&self) -> PathBuf {
        let id = self.app_id.as_deref().unwrap_or("claw-launcher");
        let mut p = dirs::cache_dir().unwrap_or_else(||
            PathBuf::from(std::env::var("HOME").unwrap_or("/tmp".into())).join(".cache"));
        p.push(id);
        p
    }
}
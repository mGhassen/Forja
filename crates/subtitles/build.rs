#[path = "../tmdb/build_dotenv.rs"]
mod build_dotenv;

fn main() {
    build_dotenv::emit_dotenv_env();
}

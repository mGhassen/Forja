#[path = "build_dotenv.rs"]
mod build_dotenv;

fn main() {
    build_dotenv::emit_tmdb_env();
}

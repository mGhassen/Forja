use serde::Serialize;

#[derive(Debug, Clone, Serialize, PartialEq)]
pub struct MusicTrack {
    pub id: String,
    pub title: String,
    pub artist: String,
    pub album: String,
    pub cover: String,
    pub duration: i64,
}

#[derive(Debug, Clone, Serialize, PartialEq)]
pub struct MusicAlbum {
    pub id: String,
    pub title: String,
    pub artist: String,
    pub cover: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub nb_tracks: Option<i64>,
}

#[derive(Debug, Clone, Serialize, PartialEq)]
pub struct AudioStream {
    pub url: String,
    pub bitrate: f64,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub mime_type: Option<String>,
}

-- SQLite Script
-- Based on MySQL Script
-- Modified for SQLite compatibility

-- -----------------------------------------------------
-- Table Asset
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS Asset (
  file_hash BLOB NOT NULL,
  mime_type TEXT NULL DEFAULT NULL,

  -- 利用 instr 找到 '/' 的位置，再用 substr 切割
  -- 例如 'audio/flac' -> instr 會回傳 6，substr 從 1 取 5 個字元 -> 'audio'
  asset_type TEXT GENERATED ALWAYS AS (
    CASE 
      WHEN instr(mime_type, '/') > 0 THEN substr(mime_type, 1, instr(mime_type, '/') - 1)
      ELSE mime_type 
    END
  ) VIRTUAL,
  file_size INTEGER NULL DEFAULT NULL,
  created_at TEXT NULL DEFAULT NULL,
  PRIMARY KEY (file_hash)
); 

-- -----------------------------------------------------
-- Table Image
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS Image (
  image_hash BLOB NOT NULL,
  file_hash BLOB NOT NULL,
  width INTEGER NULL DEFAULT NULL,
  height INTEGER NULL DEFAULT NULL,
  dominant_color TEXT NULL DEFAULT NULL,
  PRIMARY KEY (image_hash, file_hash),
  CONSTRAINT fk_Image_Asset
    FOREIGN KEY (file_hash)
    REFERENCES Asset (file_hash)
    ON DELETE CASCADE
    ON UPDATE CASCADE
);

-- -----------------------------------------------------
-- Table Audio
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS Audio (
  pcm_hash BLOB NOT NULL,
  parent_hash BLOB NULL DEFAULT NULL,
  quality_score INTEGER NULL DEFAULT NULL,
  bit_depth INTEGER NULL DEFAULT NULL,
  sample_rate INTEGER NULL,
  channels INTEGER NULL DEFAULT NULL,
  duration REAL NULL DEFAULT NULL,
  integrated_loudness DECIMAL(5,2) NULL DEFAULT NULL,
  true_peak REAL NULL DEFAULT NULL,
  PRIMARY KEY (pcm_hash),
  CONSTRAINT fk_Audio_Parent
    FOREIGN KEY (parent_hash)
    REFERENCES Audio (pcm_hash)
    ON DELETE SET NULL
    ON UPDATE CASCADE
);

-- -----------------------------------------------------
-- Table Text
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS Text (
  text_hash BLOB NOT NULL,
  file_hash BLOB NOT NULL,
  language TEXT NULL DEFAULT NULL,
  encoding TEXT NULL DEFAULT 'utf-8',
  format TEXT NULL DEFAULT NULL CHECK( format IN ('lrc', 'txt', 'srt', 'ttml') ),
  PRIMARY KEY (text_hash, file_hash),
  CONSTRAINT fk_Text_Asset
    FOREIGN KEY (file_hash)
    REFERENCES Asset (file_hash)
    ON DELETE CASCADE
    ON UPDATE CASCADE
);

-- -----------------------------------------------------
-- Table Entity
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS Entity (
  id TEXT NOT NULL,
  entity_type TEXT NULL CHECK( entity_type IN ('track', 'album', 'artist', 'work', 'playlist') ),
  created_at TEXT NULL,
  updated_at TEXT NULL,
  PRIMARY KEY (id)
);

-- -----------------------------------------------------
-- Table Artist
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS Artist (
  id TEXT NOT NULL,
  name TEXT NOT NULL,
  musicbrainz_id TEXT NULL DEFAULT NULL,
  spotify_id TEXT NULL DEFAULT NULL,
  ytm_id TEXT NULL DEFAULT NULL,
  PRIMARY KEY (id),
  CONSTRAINT fk_Artist_Entity
    FOREIGN KEY (id)
    REFERENCES Entity (id)
    ON DELETE CASCADE
    ON UPDATE CASCADE
);

-- -----------------------------------------------------
-- Table Work
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS Work (
  id TEXT NOT NULL,
  title TEXT NOT NULL,
  composition_start_year INTEGER NULL,
  composition_end_year INTEGER NULL,
  composition_date_text TEXT NULL,
  iswc TEXT NULL,
  musicbrainz_id TEXT NULL,
  PRIMARY KEY (id),
  CONSTRAINT fk_Work_Entity
    FOREIGN KEY (id)
    REFERENCES Entity (id)
    ON DELETE CASCADE
    ON UPDATE CASCADE
);

-- -----------------------------------------------------
-- Table Work_Artist
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS Work_Artist (
  work_id TEXT NOT NULL,
  artist_id TEXT NOT NULL,
  role TEXT NULL DEFAULT NULL CHECK( role IN ('composer', 'lyricist', 'arranger', 'librettist') ),
  PRIMARY KEY (work_id, artist_id),
  CONSTRAINT fk_WorkArtist_Work
    FOREIGN KEY (work_id)
    REFERENCES Work (id)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
  CONSTRAINT fk_WorkArtist_Artist
    FOREIGN KEY (artist_id)
    REFERENCES Artist (id)
    ON DELETE CASCADE
    ON UPDATE CASCADE
);

-- -----------------------------------------------------
-- Table Track
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS Track (
  id TEXT NOT NULL,
  work_id TEXT NULL DEFAULT NULL,
  pcm_hash BLOB NOT NULL,
  title TEXT NULL,
  recording_year INTEGER NULL,
  recording_month INTEGER NULL,
  recording_day INTEGER NULL,
  recording_location TEXT NULL,
  isrc TEXT NULL,
  spotify_id TEXT NULL,
  PRIMARY KEY (id, pcm_hash),
  CONSTRAINT fk_Track_Work
    FOREIGN KEY (work_id)
    REFERENCES Work (id)
    ON DELETE SET NULL
    ON UPDATE CASCADE,
  CONSTRAINT fk_Track_Audio
    FOREIGN KEY (pcm_hash)
    REFERENCES Audio (pcm_hash)
    ON DELETE SET NULL
    ON UPDATE CASCADE,
  CONSTRAINT fk_Track_Entity
    FOREIGN KEY (id)
    REFERENCES Entity (id)
    ON DELETE CASCADE
    ON UPDATE CASCADE
);

-- -----------------------------------------------------
-- Table Album
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS Album (
  id TEXT NOT NULL,
  title TEXT NOT NULL,
  release_year INTEGER NULL DEFAULT NULL,
  release_month INTEGER NULL DEFAULT NULL,
  release_day INTEGER NULL DEFAULT NULL,
  PRIMARY KEY (id),
  CONSTRAINT fk_Album_Entity
    FOREIGN KEY (id)
    REFERENCES Entity (id)
    ON DELETE CASCADE
    ON UPDATE CASCADE
);

-- -----------------------------------------------------
-- Table Track_Album
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS Track_Album (
  track_id TEXT NOT NULL,
  album_id TEXT NOT NULL,
  track_number INTEGER NULL DEFAULT NULL,
  disc_number INTEGER NULL DEFAULT NULL,
  PRIMARY KEY (track_id, album_id),
  CONSTRAINT fk_TrackAlbum_Track
    FOREIGN KEY (track_id)
    REFERENCES Track (id)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
  CONSTRAINT fk_TrackAlbum_Album
    FOREIGN KEY (album_id)
    REFERENCES Album (id)
    ON DELETE CASCADE
    ON UPDATE CASCADE
);

-- -----------------------------------------------------
-- Table Track_Artist
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS Track_Artist (
  track_id TEXT NOT NULL,
  artist_id TEXT NOT NULL,
  role TEXT NULL DEFAULT NULL CHECK( role IN ('main', 'featured', 'remixer', 'producer', 'conductor', 'performer', 'engineer') ),
  position INTEGER NULL DEFAULT NULL,
  PRIMARY KEY (track_id, artist_id),
  CONSTRAINT fk_TrackArtist_Track
    FOREIGN KEY (track_id)
    REFERENCES Track (id)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
  CONSTRAINT fk_TrackArtist_Artist
    FOREIGN KEY (artist_id)
    REFERENCES Artist (id)
    ON DELETE CASCADE
    ON UPDATE CASCADE
);

-- -----------------------------------------------------
-- Table Playlist
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS Playlist (
  id TEXT NOT NULL,
  title TEXT NOT NULL,
  description TEXT NULL DEFAULT NULL,
  PRIMARY KEY (id),
  CONSTRAINT fk_Playlist_Entity
    FOREIGN KEY (id)
    REFERENCES Entity (id)
    ON DELETE CASCADE
    ON UPDATE CASCADE
);

-- -----------------------------------------------------
-- Table Tracks_Playlist
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS Tracks_Playlist (
  playlist_id TEXT NOT NULL,
  track_id TEXT NOT NULL,
  position INTEGER UNSIGNED NULL DEFAULT NULL,
  added_at TEXT NULL DEFAULT NULL,
  PRIMARY KEY (playlist_id, track_id),
  CONSTRAINT fk_TracksPlaylist_Playlist
    FOREIGN KEY (playlist_id)
    REFERENCES Playlist (id)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
  CONSTRAINT fk_TracksPlaylist_Track
    FOREIGN KEY (track_id)
    REFERENCES Track (id)
    ON DELETE CASCADE
    ON UPDATE CASCADE
);

-- -----------------------------------------------------
-- Table Audio_Asset
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS Audio_Asset (
  pcm_hash BLOB NOT NULL,
  file_hash BLOB NOT NULL,
  PRIMARY KEY (pcm_hash, file_hash),
  CONSTRAINT fk_AudioAsset_Audio
    FOREIGN KEY (pcm_hash)
    REFERENCES Audio (pcm_hash)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
  CONSTRAINT fk_AudioAsset_Asset
    FOREIGN KEY (file_hash)
    REFERENCES Asset (file_hash)
    ON DELETE CASCADE
    ON UPDATE CASCADE
);

-- -----------------------------------------------------
-- Table Source_Data
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS Source_Data (
  id TEXT NOT NULL,
  file_hash BLOB NOT NULL,
  source_type TEXT NULL DEFAULT NULL,
  original_path TEXT NULL DEFAULT NULL,
  created_at TEXT NULL DEFAULT NULL,
  note TEXT NULL,
  PRIMARY KEY (id),
  CONSTRAINT fk_SourceData_Asset
    FOREIGN KEY (file_hash)
    REFERENCES Asset (file_hash)
    ON DELETE CASCADE
    ON UPDATE CASCADE
);

-- -----------------------------------------------------
-- Table Entity_Images
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS Entity_Images (
  entity_id TEXT NOT NULL,
  image_hash BLOB NOT NULL,
  role TEXT NULL CHECK( role IN ('front', 'back', 'leaflet', 'medium', 'matrix', 'spine', 'tray', 'sleeve', 'artist_avatar', 'artist_banner', 'artist_logo', 'live', 'studio', 'series_logo', 'thumbnail', 'other') ),
  PRIMARY KEY (entity_id, image_hash),
  CONSTRAINT fk_EntityImages_Image
    FOREIGN KEY (image_hash)
    REFERENCES Image (image_hash)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT fk_EntityImages_Entity
    FOREIGN KEY (entity_id)
    REFERENCES Entity (id)
    ON DELETE CASCADE
    ON UPDATE CASCADE
);

-- -----------------------------------------------------
-- Table Entity_Text
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS Entity_Text (
  entity_id TEXT NOT NULL,
  text_hash BLOB NOT NULL,
  role TEXT NULL CHECK( role IN ('lyrics', 'lyrics_translation', 'lyrics_transliteration', 'description', 'biography', 'liner_notes', 'credits', 'review', 'trivia', 'other') ),
  language TEXT NULL,
  PRIMARY KEY (entity_id, text_hash),
  CONSTRAINT fk_EntityText_Text
    FOREIGN KEY (text_hash)
    REFERENCES Text (text_hash)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT fk_EntityText_Entity
    FOREIGN KEY (entity_id)
    REFERENCES Entity (id)
    ON DELETE CASCADE
    ON UPDATE CASCADE
);

-- -----------------------------------------------------
-- Table Album_Artist
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS Album_Artist (
  album_id TEXT NOT NULL,
  artist_id TEXT NOT NULL,
  role TEXT NULL CHECK( role IN ('main', 'composer', 'conductor', 'compiler') ),
  PRIMARY KEY (album_id, artist_id),
  CONSTRAINT fk_AlbumArtist_Artist
    FOREIGN KEY (artist_id)
    REFERENCES Artist (id)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT fk_AlbumArtist_Album
    FOREIGN KEY (album_id)
    REFERENCES Album (id)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION
);

-- -----------------------------------------------------
-- Table Tag
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS Tag (
  id TEXT NOT NULL,
  name TEXT NULL,
  category TEXT NULL CHECK( category IN ('genre', 'tag') ),
  PRIMARY KEY (id)
);

-- -----------------------------------------------------
-- Table Entity_Tag
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS Entity_Tag (
  entity_id TEXT NOT NULL,
  tag_id TEXT NULL,
  PRIMARY KEY (entity_id),
  CONSTRAINT fk_EntityTag_Entity
    FOREIGN KEY (entity_id)
    REFERENCES Entity (id)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT fk_EntityTag_Tag
    FOREIGN KEY (tag_id)
    REFERENCES Tag (id)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION
);

-- ==========================================
-- 手動建立的外鍵與效能索引
-- ==========================================

-- 1. 單一 PK 表中的外鍵索引
CREATE INDEX idx_Image_file_hash ON Image(file_hash);
CREATE INDEX idx_Text_file_hash ON Text(file_hash);
CREATE INDEX idx_Audio_parent_hash ON Audio(parent_hash);
CREATE INDEX idx_Track_work_id ON Track(work_id);
CREATE INDEX idx_Track_pcm_hash ON Track(pcm_hash);

-- 2. Junction Tables (複合主鍵) 的第二外鍵索引
CREATE INDEX idx_Work_Artist_artist_id ON Work_Artist(artist_id);
CREATE INDEX idx_Track_Album_album_id ON Track_Album(album_id);
CREATE INDEX idx_Track_Artist_artist_id ON Track_Artist(artist_id);
CREATE INDEX idx_Tracks_Playlist_track_id ON Tracks_Playlist(track_id);
CREATE INDEX idx_Audio_Asset_file_hash ON Audio_Asset(file_hash);
CREATE INDEX idx_Entity_Images_image_hash ON Entity_Images(image_hash);
CREATE INDEX idx_Entity_Text_text_hash ON Entity_Text(text_hash);
CREATE INDEX idx_Album_Artist_artist_id ON Album_Artist(artist_id);
CREATE INDEX idx_Entity_Tag_tag_id ON Entity_Tag(tag_id);

-- 3. 其他非外鍵但常被查詢的效能索引
CREATE INDEX idx_Asset_asset_type ON Asset(asset_type);
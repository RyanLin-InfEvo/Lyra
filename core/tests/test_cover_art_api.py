# SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
#
# SPDX-License-Identifier: AGPL-3.0-or-later

import os
import uuid
import subprocess
from base_test_case import BaseLyraTestCase

class TestCoverArtApi(BaseLyraTestCase):

    def create_audio_with_cover_art(self, output_mp3_path, title="Cover Art Track", artist="Cover Art Artist", album="Cover Art Album"):
        cover_jpg_path = os.path.join(self.test_db_dir, f"temp_cover_{uuid.uuid4().hex[:8]}.jpg")
        cmd_img = [
            "ffmpeg", "-y", "-v", "error",
            "-f", "lavfi", "-i", "color=c=blue:s=128x128",
            "-vframes", "1", cover_jpg_path
        ]
        subprocess.run(cmd_img, check=True)

        audio_wav_path = os.path.join(self.test_db_dir, f"temp_audio_{uuid.uuid4().hex[:8]}.wav")
        cmd_wav = [
            "ffmpeg", "-y", "-v", "error",
            "-f", "lavfi", "-i", "sine=frequency=440:duration=1.0",
            audio_wav_path
        ]
        subprocess.run(cmd_wav, check=True)

        cmd_combine = [
            "ffmpeg", "-y", "-v", "error",
            "-i", audio_wav_path,
            "-i", cover_jpg_path,
            "-map", "0:0", "-map", "1:0",
            "-c:a", "mp3", "-c:v", "copy",
            "-metadata", f"title={title}",
            "-metadata", f"artist={artist}",
            "-metadata", f"album={album}",
            "-disposition:v", "attached_pic",
            output_mp3_path
        ]
        subprocess.run(cmd_combine, check=True)

    def create_audio_without_cover_art(self, output_mp3_path, title="No Cover Track", artist="No Cover Artist", album="No Cover Album"):
        audio_wav_path = os.path.join(self.test_db_dir, f"temp_audio_{uuid.uuid4().hex[:8]}.wav")
        cmd_wav = [
            "ffmpeg", "-y", "-v", "error",
            "-f", "lavfi", "-i", "sine=frequency=880:duration=1.0",
            audio_wav_path
        ]
        subprocess.run(cmd_wav, check=True)

        cmd_combine = [
            "ffmpeg", "-y", "-v", "error",
            "-i", audio_wav_path,
            "-c:a", "mp3",
            "-metadata", f"title={title}",
            "-metadata", f"artist={artist}",
            "-metadata", f"album={album}",
            output_mp3_path
        ]
        subprocess.run(cmd_combine, check=True)

    def test_get_album_cover(self):
        mp3_path = os.path.join(self.test_db_dir, "album_cover_test.mp3")
        self.create_audio_with_cover_art(mp3_path, title="Album Track", artist="Album Artist", album="Test Album API")

        # Import track
        res_import = self.dispatch("ImportTrack", {"source_path": mp3_path})
        self.assertResponseCode(res_import, 200)
        data_import = res_import.get("data", {})
        album_id = data_import["album_id"]
        cover_hash = data_import["cover_image_hash"]

        # Call GetAlbumCover
        res_cover = self.dispatch("GetAlbumCover", {"album_id": album_id})
        self.assertResponseCode(res_cover, 200)

        data = res_cover.get("data", {})
        self.assertEqual(data["image_hash"], cover_hash)
        self.assertTrue(len(data["file_hash"]) > 0)
        self.assertTrue(os.path.exists(data["path"]), f"Cover file path does not exist: {data['path']}")
        self.assertIn("image/", data["mime_type"])

    def test_get_track_cover_direct(self):
        mp3_path = os.path.join(self.test_db_dir, "track_cover_direct.mp3")
        self.create_audio_with_cover_art(mp3_path, title="Direct Track", artist="Direct Artist", album="Direct Album")

        # Import track
        res_import = self.dispatch("ImportTrack", {"source_path": mp3_path})
        self.assertResponseCode(res_import, 200)
        data_import = res_import.get("data", {})
        track_id = data_import["track_id"]
        cover_hash = data_import["cover_image_hash"]

        # Call GetTrackCover
        res_cover = self.dispatch("GetTrackCover", {"track_id": track_id})
        self.assertResponseCode(res_cover, 200)

        data = res_cover.get("data", {})
        self.assertEqual(data["image_hash"], cover_hash)
        self.assertTrue(os.path.exists(data["path"]), f"Track cover path does not exist: {data['path']}")
        self.assertIn("image/", data["mime_type"])

    def test_get_track_cover_fallback_to_album(self):
        # 1. Import Track 1 WITH cover art into "Shared Fallback Album"
        mp3_with_cover = os.path.join(self.test_db_dir, "track_with_cover.mp3")
        self.create_audio_with_cover_art(mp3_with_cover, title="Track With Cover", artist="Fallback Artist", album="Shared Fallback Album")

        res1 = self.dispatch("ImportTrack", {"source_path": mp3_with_cover})
        self.assertResponseCode(res1, 200)
        album_id = res1["data"]["album_id"]
        album_cover_hash = res1["data"]["cover_image_hash"]

        # 2. Import Track 2 WITHOUT cover art into the same "Shared Fallback Album"
        mp3_no_cover = os.path.join(self.test_db_dir, "track_no_cover.mp3")
        self.create_audio_without_cover_art(mp3_no_cover, title="Track No Cover", artist="Fallback Artist", album="Shared Fallback Album")

        res2 = self.dispatch("ImportTrack", {"source_path": mp3_no_cover})
        self.assertResponseCode(res2, 200)
        track_id_no_cover = res2["data"]["track_id"]
        self.assertEqual(res2["data"]["album_id"], album_id)
        self.assertNotIn("cover_image_hash", res2["data"])

        # 3. Call GetTrackCover for Track 2 (which has no direct cover) -> should fallback to album's cover
        res_fallback = self.dispatch("GetTrackCover", {"track_id": track_id_no_cover})
        self.assertResponseCode(res_fallback, 200)

        data = res_fallback.get("data", {})
        self.assertEqual(data["image_hash"], album_cover_hash)
        self.assertTrue(os.path.exists(data["path"]))

    def test_get_cover_not_found(self):
        # Non-existent album
        res_album_err = self.dispatch("GetAlbumCover", {"album_id": str(uuid.uuid4())})
        self.assertResponseCode(res_album_err, 404)

        # Track with no cover and no album cover
        mp3_no_cover = os.path.join(self.test_db_dir, "orphan_no_cover.mp3")
        self.create_audio_without_cover_art(mp3_no_cover, title="Orphan Track", artist="Orphan Artist", album="Orphan Album No Cover")
        res_import = self.dispatch("ImportTrack", {"source_path": mp3_no_cover})
        self.assertResponseCode(res_import, 200)
        orphan_track_id = res_import["data"]["track_id"]

        res_track_err = self.dispatch("GetTrackCover", {"track_id": orphan_track_id})
        self.assertResponseCode(res_track_err, 404)

    def test_get_artist_cover(self):
        # 1. Non-existent artist
        res_err = self.dispatch("GetArtistCover", {"artist_id": str(uuid.uuid4())})
        self.assertResponseCode(res_err, 404)
        self.assertEqual(res_err["error"]["type"], "ArtistNotFound")

        # 2. Create Artist
        res_artist = self.dispatch("CreateArtist", {"name": "Cover Artist Test"})
        self.assertResponseCode(res_artist, 201)
        artist_id = res_artist["data"]["id"]

        # Artist with no albums / no cover art
        res_no_cover = self.dispatch("GetArtistCover", {"artist_id": artist_id})
        self.assertResponseCode(res_no_cover, 404)

        # 3. Create audio with cover art and import track
        mp3_path = os.path.join(self.test_db_dir, "artist_cover_track.mp3")
        self.create_audio_with_cover_art(mp3_path, title="Artist Track", artist="Cover Artist Test", album="Artist Cover Album")
        res_import = self.dispatch("ImportTrack", {"source_path": mp3_path})
        self.assertResponseCode(res_import, 200)
        track_id = res_import["data"]["track_id"]
        album_cover_hash = res_import["data"]["cover_image_hash"]

        # Associate track with artist
        res_link = self.dispatch("AddTrackArtist", {"track_id": track_id, "artist_id": artist_id, "role": "main"})
        self.assertResponseCode(res_link, 201)

        # Call GetArtistCover -> should fallback to artist's latest album cover
        res_fallback = self.dispatch("GetArtistCover", {"artist_id": artist_id})
        self.assertResponseCode(res_fallback, 200)
        self.assertEqual(res_fallback["data"]["image_hash"], album_cover_hash)
        self.assertTrue(os.path.exists(res_fallback["data"]["path"]))

        # 4. Link an 'artist_avatar' image directly to artist via SQLite DB
        import sqlite3
        db_path = os.path.join(self.test_db_dir, "lyra.db")
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        cursor.execute(
            "INSERT INTO Entity_Images (entity_id, image_hash, role) VALUES (?, ?, ?)",
            (artist_id, album_cover_hash, "artist_avatar")
        )
        conn.commit()
        conn.close()

        # Call GetArtistCover -> should return direct avatar image
        res_avatar = self.dispatch("GetArtistCover", {"artist_id": artist_id})
        self.assertResponseCode(res_avatar, 200)
        self.assertEqual(res_avatar["data"]["image_hash"], album_cover_hash)

    def test_get_playlist_cover(self):
        # 1. Non-existent playlist
        res_err = self.dispatch("GetPlaylistCover", {"playlist_id": str(uuid.uuid4())})
        self.assertResponseCode(res_err, 404)
        self.assertEqual(res_err["error"]["type"], "PlaylistNotFound")

        # 2. Create Playlist
        res_pl = self.dispatch("CreatePlaylist", {"title": "Test Cover Playlist"})
        self.assertResponseCode(res_pl, 201)
        playlist_id = res_pl["data"]["id"]

        # Empty playlist -> 404
        res_empty = self.dispatch("GetPlaylistCover", {"playlist_id": playlist_id})
        self.assertResponseCode(res_empty, 404)

        # 3. Import track with cover art
        mp3_path = os.path.join(self.test_db_dir, "playlist_cover_track.mp3")
        self.create_audio_with_cover_art(mp3_path, title="Playlist Track", artist="Playlist Artist", album="Playlist Album")
        res_import = self.dispatch("ImportTrack", {"source_path": mp3_path})
        self.assertResponseCode(res_import, 200)
        track_id = res_import["data"]["track_id"]
        cover_hash = res_import["data"]["cover_image_hash"]

        # Add track to playlist
        res_add = self.dispatch("AddPlaylistTrack", {"playlist_id": playlist_id, "track_id": track_id})
        self.assertResponseCode(res_add, 201)

        # Call GetPlaylistCover -> should fallback to first track's cover
        res_cover = self.dispatch("GetPlaylistCover", {"playlist_id": playlist_id})
        self.assertResponseCode(res_cover, 200)
        self.assertEqual(res_cover["data"]["image_hash"], cover_hash)

        # 4. Link custom image directly to playlist
        import sqlite3
        db_path = os.path.join(self.test_db_dir, "lyra.db")
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        cursor.execute(
            "INSERT INTO Entity_Images (entity_id, image_hash, role) VALUES (?, ?, ?)",
            (playlist_id, cover_hash, "front")
        )
        conn.commit()
        conn.close()

        # Call GetPlaylistCover -> should return direct playlist image
        res_custom = self.dispatch("GetPlaylistCover", {"playlist_id": playlist_id})
        self.assertResponseCode(res_custom, 200)
        self.assertEqual(res_custom["data"]["image_hash"], cover_hash)

    def test_get_entity_images(self):
        # 1. Non-existent entity
        res_err = self.dispatch("GetEntityImages", {"entity_id": str(uuid.uuid4())})
        self.assertResponseCode(res_err, 404)
        self.assertEqual(res_err["error"]["type"], "NotFound")

        # 2. Import track with cover art
        mp3_path = os.path.join(self.test_db_dir, "entity_images_track.mp3")
        self.create_audio_with_cover_art(mp3_path, title="Entity Images Track", artist="Entity Artist", album="Entity Album")
        res_import = self.dispatch("ImportTrack", {"source_path": mp3_path})
        self.assertResponseCode(res_import, 200)
        track_id = res_import["data"]["track_id"]
        cover_hash = res_import["data"]["cover_image_hash"]

        # 3. GetEntityImages without role filter
        res_all = self.dispatch("GetEntityImages", {"entity_id": track_id})
        self.assertResponseCode(res_all, 200)
        items = res_all.get("data", [])
        self.assertGreater(len(items), 0)
        self.assertEqual(items[0]["image_hash"], cover_hash)
        self.assertEqual(items[0]["role"], "front")

        # 4. GetEntityImages with matching role filter
        res_front = self.dispatch("GetEntityImages", {"entity_id": track_id, "role": "front"})
        self.assertResponseCode(res_front, 200)
        items_front = res_front.get("data", [])
        self.assertEqual(len(items_front), 1)
        self.assertEqual(items_front[0]["image_hash"], cover_hash)

        # 5. GetEntityImages with non-matching role filter
        res_avatar = self.dispatch("GetEntityImages", {"entity_id": track_id, "role": "artist_avatar"})
        self.assertResponseCode(res_avatar, 200)
        self.assertEqual(len(res_avatar.get("data", [])), 0)

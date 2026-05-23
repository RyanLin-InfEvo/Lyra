# SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
#
# SPDX-License-Identifier: AGPL-3.0-or-later

import uuid
from base_test_case import BaseLyraTestCase

class TestPlaylistController(BaseLyraTestCase):

    # -----------
    # Create Test
    # -----------
    def test_playlist_create_success(self):
        """Test successful Playlist creation"""
        title = "My Awesome Playlist"
        res = self.dispatch("CreatePlaylist", {"title": title, "description": "A great playlist"})
        
        self.assertEqual(res["code"], 201)
        self.assertEqual(res["data"]["title"], title)
        self.assertTrue("id" in res["data"])

    def test_playlist_create_missing_required(self):
        """Test missing required fields"""
        res = self.dispatch("CreatePlaylist", {"description": "Missing title"})
        self.assertEqual(res["code"], 400)
        self.assertEqual(res["error"]["type"], "MissingParameter")

    # --------
    # Get Test
    # --------
    def test_playlist_get_success(self):
        """Test successful retrieval of an existing Playlist"""
        res_create = self.dispatch("CreatePlaylist", {"title": "Get Target Playlist"})
        self.assertEqual(res_create["code"], 201)

        res_get = self.dispatch("GetPlaylist", {"id": res_create["data"]["id"]})
        self.assertEqual(res_get["code"], 200)
        self.assertEqual(res_get["data"]["id"], res_create["data"]["id"])
        self.assertEqual(res_get["data"]["title"], "Get Target Playlist")

    def test_playlist_get_not_found(self):
        """Test fetching a non-existent Playlist"""
        res = self.dispatch("GetPlaylist", {"id": str(uuid.uuid4())})
        self.assertEqual(res["code"], 404)
        self.assertEqual(res["error"]["type"], "PlaylistNotFound")

    # -----------
    # Update Test
    # -----------
    def test_playlist_update_success(self):
        """Test successful update of an existing playlist"""
        res_create = self.dispatch("CreatePlaylist", {"title": "Old Title"})
        self.assertEqual(res_create["code"], 201)

        updated_title = "New Title"
        real_id = res_create["data"]["id"]
        res_update = self.dispatch("UpdatePlaylist", {"id": real_id, "title": updated_title})
        self.assertEqual(res_update["code"], 200)
        
        res_get = self.dispatch("GetPlaylist", {"id": real_id})
        self.assertEqual(res_get["data"]["title"], updated_title)

    def test_playlist_update_no_fields(self):
        """Test playlist update with no update fields"""
        real_id = str(uuid.uuid4())
        res = self.dispatch("UpdatePlaylist", {"id": real_id})
        self.assertEqual(res["code"], 400)

    # ----------------------
    # Playlist-Track Tests
    # ----------------------
    def test_add_playlist_track_success(self):
        """Test successful addition of a track to a playlist"""
        res_playlist = self.dispatch("CreatePlaylist", {"title": "My Playlist"})
        res_track = self.dispatch("CreateTrack", {"pcm_hash": "Hash PT 1", "title": "Track PT 1"})
        
        playlist_id = res_playlist["data"]["id"]
        track_id = res_track["data"]["id"]
        
        res_add = self.dispatch("AddPlaylistTrack", {
            "playlist_id": playlist_id, 
            "track_id": track_id,
            "position": 1
        })
        self.assertEqual(res_add["code"], 201)

    def test_get_playlist_tracks_success(self):
        """Test fetching tracks of a playlist"""
        res_playlist = self.dispatch("CreatePlaylist", {"title": "My Playlist 2"})
        res_track1 = self.dispatch("CreateTrack", {"pcm_hash": "Hash PT 2", "title": "Track PT 2"})
        res_track2 = self.dispatch("CreateTrack", {"pcm_hash": "Hash PT 3", "title": "Track PT 3"})
        
        playlist_id = res_playlist["data"]["id"]
        track_id1 = res_track1["data"]["id"]
        track_id2 = res_track2["data"]["id"]
        
        self.dispatch("AddPlaylistTrack", {"playlist_id": playlist_id, "track_id": track_id1, "position": 1})
        self.dispatch("AddPlaylistTrack", {"playlist_id": playlist_id, "track_id": track_id2, "position": 2})
        
        res_get = self.dispatch("GetPlaylistTracks", {"id": playlist_id})
        self.assertEqual(res_get["code"], 200)
        self.assertEqual(len(res_get["data"]), 2)
        self.assertEqual(res_get["data"][0], track_id1)
        self.assertEqual(res_get["data"][1], track_id2)

    def test_remove_playlist_track_success(self):
        """Test successful removal of a track from a playlist"""
        res_playlist = self.dispatch("CreatePlaylist", {"title": "My Playlist 3"})
        res_track = self.dispatch("CreateTrack", {"pcm_hash": "Hash PT 4", "title": "Track PT 4"})
        
        playlist_id = res_playlist["data"]["id"]
        track_id = res_track["data"]["id"]
        
        self.dispatch("AddPlaylistTrack", {"playlist_id": playlist_id, "track_id": track_id})
        
        res_remove = self.dispatch("RemovePlaylistTrack", {
            "playlist_id": playlist_id,
            "track_id": track_id
        })
        self.assertEqual(res_remove["code"], 200)
        
        res_get = self.dispatch("GetPlaylistTracks", {"id": playlist_id})
        self.assertEqual(len(res_get["data"]), 0)

    def test_add_playlist_track_playlist_not_found(self):
        """Test AddPlaylistTrack with non-existent playlist ID: Should return 404 (PlaylistNotFound)"""
        res_track = self.dispatch("CreateTrack", {"pcm_hash": "Hash PT NF 1", "title": "Track For Playlist NF"})
        track_id = res_track["data"]["id"]
        non_existent_playlist_id = str(uuid.uuid4())
        
        res = self.dispatch("AddPlaylistTrack", {
            "playlist_id": non_existent_playlist_id,
            "track_id": track_id
        })
        self.assertEqual(res["code"], 404)
        self.assertEqual(res["error"]["type"], "PlaylistNotFound")

    def test_add_playlist_track_track_not_found(self):
        """Test AddPlaylistTrack with non-existent track ID: Should return 404 (TrackNotFound)"""
        res_playlist = self.dispatch("CreatePlaylist", {"title": "Playlist For Track NF"})
        playlist_id = res_playlist["data"]["id"]
        non_existent_track_id = str(uuid.uuid4())
        
        res = self.dispatch("AddPlaylistTrack", {
            "playlist_id": playlist_id,
            "track_id": non_existent_track_id
        })
        self.assertEqual(res["code"], 404)
        self.assertEqual(res["error"]["type"], "TrackNotFound")

    def test_remove_playlist_track_relation_not_found(self):
        """Test RemovePlaylistTrack with non-existent relation: Should return 404 (RelationNotFound)"""
        res_playlist = self.dispatch("CreatePlaylist", {"title": "Playlist For Relation NF"})
        res_track = self.dispatch("CreateTrack", {"pcm_hash": "Hash PT NF 2", "title": "Track For Relation NF"})
        playlist_id = res_playlist["data"]["id"]
        track_id = res_track["data"]["id"]
        
        res = self.dispatch("RemovePlaylistTrack", {
            "playlist_id": playlist_id,
            "track_id": track_id
        })
        self.assertEqual(res["code"], 404)
        self.assertEqual(res["error"]["type"], "RelationNotFound")
        self.assertEqual(res["error"]["message"], "Track not found in playlist.")

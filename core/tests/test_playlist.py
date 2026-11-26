# SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
#
# SPDX-License-Identifier: AGPL-3.0-or-later

import os
import sqlite3
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
        
        self.assertResponseCode(res, 201)
        self.assertEqual(res["data"]["title"], title)
        self.assertTrue("id" in res["data"])

    def test_playlist_create_missing_required(self):
        """Test missing required fields"""
        res = self.dispatch("CreatePlaylist", {"description": "Missing title"})
        self.assertValidationError(res, expected_type="MissingParameter")

    # --------
    # Get Test
    # --------
    def test_playlist_get_success(self):
        """Test successful retrieval of an existing Playlist"""
        res_create = self.dispatch("CreatePlaylist", {"title": "Get Target Playlist"})
        self.assertResponseCode(res_create, 201)

        res_get = self.dispatch("GetPlaylist", {"id": res_create["data"]["id"]})
        self.assertResponseCode(res_get, 200)
        self.assertEqual(res_get["data"]["id"], res_create["data"]["id"])
        self.assertEqual(res_get["data"]["title"], "Get Target Playlist")

    def test_playlist_get_not_found(self):
        """Test fetching a non-existent Playlist"""
        res = self.dispatch("GetPlaylist", {"id": str(uuid.uuid4())})
        self.assertResponseCode(res, 404)
        self.assertEqual(res["error"]["type"], "PlaylistNotFound")

    # -----------
    # Update Test
    # -----------
    def test_playlist_update_success(self):
        """Test successful update of an existing playlist"""
        res_create = self.dispatch("CreatePlaylist", {"title": "Old Title"})
        self.assertResponseCode(res_create, 201)

        updated_title = "New Title"
        real_id = res_create["data"]["id"]
        res_update = self.dispatch("UpdatePlaylist", {"id": real_id, "title": updated_title})
        self.assertResponseCode(res_update, 200)
        
        res_get = self.dispatch("GetPlaylist", {"id": real_id})
        self.assertEqual(res_get["data"]["title"], updated_title)

    def test_playlist_update_no_fields(self):
        """Test playlist update with no update fields"""
        real_id = str(uuid.uuid4())
        res = self.dispatch("UpdatePlaylist", {"id": real_id})
        self.assertValidationError(res, expected_type="InvalidValue")

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
        self.assertResponseCode(res_add, 201)

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
        self.assertResponseCode(res_get, 200)
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
        self.assertResponseCode(res_remove, 200)
        
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
        self.assertResponseCode(res, 404)
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
        self.assertResponseCode(res, 404)
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
        self.assertResponseCode(res, 404)
        self.assertEqual(res["error"]["type"], "RelationNotFound")
        self.assertEqual(res["error"]["message"], "Track not found in playlist.")

    # ----------------------------
    # Delete & Reorder Tests
    # ----------------------------
    def test_delete_playlist_transactional(self):
        """Test DeletePlaylist atomically deletes Playlist_Track, Playlist, and Entity while preserving Tracks."""
        res_pl = self.dispatch("CreatePlaylist", {"title": "To Delete"})
        self.assertResponseCode(res_pl, 201)
        pl_id = res_pl["data"]["id"]

        res_t = self.dispatch("CreateTrack", {"pcm_hash": "pcm-del-pl", "title": "Survivor Track"})
        self.assertResponseCode(res_t, 201)
        track_id = res_t["data"]["id"]
        self.assertResponseCode(self.dispatch("AddPlaylistTrack", {"playlist_id": pl_id, "track_id": track_id, "position": 0}), 201)

        # Passing Track UUID must fail with PlaylistNotFound and leave Track intact
        res_wrong_entity = self.dispatch("DeletePlaylist", {"id": track_id})
        self.assertResponseCode(res_wrong_entity, 404)
        self.assertEqual(res_wrong_entity["error"]["type"], "PlaylistNotFound")
        self.assertResponseCode(self.dispatch("GetTrack", {"id": track_id}), 200)

        # Conflicting id vs playlist_id -> 400 InvalidValue
        self.assertValidationError(
            self.dispatch("DeletePlaylist", {"id": pl_id, "playlist_id": str(uuid.uuid4())}),
            expected_type="InvalidValue",
        )
        self.assertValidationError(self.dispatch("DeletePlaylist", {}), expected_type="MissingParameter")
        self.assertValidationError(self.dispatch("DeletePlaylist", {"id": None, "playlist_id": None}), expected_type="MissingParameter")
        self.assertValidationError(self.dispatch("DeletePlaylist", {"id": "not-a-uuid"}), expected_type="InvalidValue")

        # Assign a tag to verify Entity_Tag cascade deletion alongside Playlist_Track/Playlist/Entity
        res_tag = self.dispatch("tag.create", {"name": "PlaylistTagDelete"})
        self.assertResponseCode(res_tag, 201)
        tag_id = res_tag["data"]["id"]
        self.assertResponseCode(
            self.dispatch("tag.assign", {"entity_id": pl_id, "tag_id": tag_id, "entity_type": "playlist"}),
            201,
        )

        # Valid deletion via playlist_id
        res_del = self.dispatch("DeletePlaylist", {"playlist_id": pl_id})
        self.assertResponseCode(res_del, 200)
        self.assertEqual(res_del["data"]["id"], pl_id)

        # Verify Playlist gone and Track still exists
        res_get_pl = self.dispatch("GetPlaylist", {"id": pl_id})
        self.assertResponseCode(res_get_pl, 404)
        self.assertEqual(res_get_pl["error"]["type"], "PlaylistNotFound")
        self.assertResponseCode(self.dispatch("GetTrack", {"id": track_id}), 200)

        # Verify SQLite Entity, Playlist, Playlist_Track, and Entity_Tag rows are completely removed
        db_path = os.path.join(self.test_db_dir, "lyra.db")
        conn = sqlite3.connect(db_path)
        conn.execute("PRAGMA wal_checkpoint(PASSIVE);")
        cur = conn.cursor()
        self.assertEqual(cur.execute("SELECT COUNT(*) FROM Playlist WHERE id = ?", (pl_id,)).fetchone()[0], 0)
        self.assertEqual(cur.execute("SELECT COUNT(*) FROM Playlist_Track WHERE playlist_id = ?", (pl_id,)).fetchone()[0], 0)
        self.assertEqual(cur.execute("SELECT COUNT(*) FROM Entity WHERE id = ?", (pl_id,)).fetchone()[0], 0)
        self.assertEqual(cur.execute("SELECT COUNT(*) FROM Entity_Tag WHERE entity_id = ?", (pl_id,)).fetchone()[0], 0)
        conn.close()

        # Matching pair {"id": pl2, "playlist_id": pl2} -> 200
        res_pl2 = self.dispatch("CreatePlaylist", {"title": "Pair Delete"})
        self.assertResponseCode(res_pl2, 201)
        pl2_id = res_pl2["data"]["id"]
        res_del2 = self.dispatch("DeletePlaylist", {"id": pl2_id, "playlist_id": pl2_id})
        self.assertResponseCode(res_del2, 200)
        self.assertEqual(res_del2["data"]["id"], pl2_id)

        # Idempotency: deleting again returns 404 PlaylistNotFound
        res_again = self.dispatch("DeletePlaylist", {"id": pl_id})
        self.assertResponseCode(res_again, 404)
        self.assertEqual(res_again["error"]["type"], "PlaylistNotFound")

    def test_reorder_playlist_tracks_and_rollback(self):
        """Test ReorderPlaylistTracks moves tracks atomically and preserves order on out-of-bounds errors."""
        res_pl = self.dispatch("CreatePlaylist", {"title": "Reorder Playlist"})
        self.assertResponseCode(res_pl, 201)
        pl_id = res_pl["data"]["id"]

        # Empty playlist -> 400 OutOfRange
        res_empty = self.dispatch("ReorderPlaylistTracks", {"playlist_id": pl_id, "old_index": 0, "new_index": 0})
        self.assertValidationError(res_empty, expected_type="OutOfRange")

        t1 = self.dispatch("CreateTrack", {"pcm_hash": "pcm-ro-1", "title": "Track 1"})["data"]["id"]
        t2 = self.dispatch("CreateTrack", {"pcm_hash": "pcm-ro-2", "title": "Track 2"})["data"]["id"]
        t3 = self.dispatch("CreateTrack", {"pcm_hash": "pcm-ro-3", "title": "Track 3"})["data"]["id"]
        self.assertResponseCode(self.dispatch("AddPlaylistTrack", {"playlist_id": pl_id, "track_id": t1, "position": 0}), 201)
        self.assertResponseCode(self.dispatch("AddPlaylistTrack", {"playlist_id": pl_id, "track_id": t2, "position": 1}), 201)
        self.assertResponseCode(self.dispatch("AddPlaylistTrack", {"playlist_id": pl_id, "track_id": t3, "position": 2}), 201)

        # Forward move: 0 -> 2 => [t2, t3, t1]
        res_fwd = self.dispatch("ReorderPlaylistTracks", {"playlist_id": pl_id, "old_index": 0, "new_index": 2})
        self.assertResponseCode(res_fwd, 200)
        self.assertEqual(res_fwd["data"]["track_ids"], [t2, t3, t1])
        self.assertEqual(self.dispatch("GetPlaylistTracks", {"id": pl_id})["data"], [t2, t3, t1])

        # Backward move: 2 -> 0 => [t1, t2, t3]
        res_bwd = self.dispatch("ReorderPlaylistTracks", {"playlist_id": pl_id, "old_index": 2, "new_index": 0})
        self.assertResponseCode(res_bwd, 200)
        self.assertEqual(res_bwd["data"]["track_ids"], [t1, t2, t3])
        self.assertEqual(self.dispatch("GetPlaylistTracks", {"id": pl_id})["data"], [t1, t2, t3])

        # Same-index no-op: 1 -> 1 => [t1, t2, t3]
        res_noop = self.dispatch("ReorderPlaylistTracks", {"playlist_id": pl_id, "old_index": 1, "new_index": 1})
        self.assertResponseCode(res_noop, 200)
        self.assertEqual(res_noop["data"]["track_ids"], [t1, t2, t3])

        # Invalid/out-of-bounds indices (including new_index == count == 3 and INT32/UINT64 overflow) -> 400 OutOfRange & order preserved
        for old_i, new_i in ((-1, 0), (0, -1), (3, 0), (0, 3), (2147483648, 0), (0, 18446744073709551615)):
            res_bad = self.dispatch("ReorderPlaylistTracks", {
                "playlist_id": pl_id,
                "old_index": old_i,
                "new_index": new_i,
            })
            self.assertValidationError(res_bad, expected_type="OutOfRange")
            self.assertEqual(self.dispatch("GetPlaylistTracks", {"id": pl_id})["data"], [t1, t2, t3])

        # Non-existent playlist & wrong-entity-type UUID (Track UUID) -> 404 PlaylistNotFound
        for bad_pl_id in (str(uuid.uuid4()), t1):
            res_404 = self.dispatch("ReorderPlaylistTracks", {
                "playlist_id": bad_pl_id,
                "old_index": 0,
                "new_index": 1,
            })
            self.assertResponseCode(res_404, 404)
            self.assertEqual(res_404["error"]["type"], "PlaylistNotFound")

        # Type mismatch / missing required / null
        for bad_val in ("0", 1.5, True):
            self.assertValidationError(
                self.dispatch("ReorderPlaylistTracks", {"playlist_id": pl_id, "old_index": bad_val, "new_index": 1}),
                expected_type="InvalidValue",
            )
        self.assertValidationError(
            self.dispatch("ReorderPlaylistTracks", {"playlist_id": pl_id, "old_index": 0}),
            expected_type="MissingParameter",
        )
        self.assertValidationError(
            self.dispatch("ReorderPlaylistTracks", {"playlist_id": pl_id, "old_index": None, "new_index": 1}),
            expected_type="MissingParameter",
        )

        # NULL-position append + reorder: omitted position (NULL) must sort LAST, then reorder cleanly
        res_pl_null = self.dispatch("CreatePlaylist", {"title": "Null Pos Reorder"})
        self.assertResponseCode(res_pl_null, 201)
        pl_null_id = res_pl_null["data"]["id"]
        self.assertResponseCode(self.dispatch("AddPlaylistTrack", {"playlist_id": pl_null_id, "track_id": t1, "position": 0}), 201)
        self.assertResponseCode(self.dispatch("AddPlaylistTrack", {"playlist_id": pl_null_id, "track_id": t2, "position": 1}), 201)
        self.assertResponseCode(self.dispatch("AddPlaylistTrack", {"playlist_id": pl_null_id, "track_id": t3}), 201)
        self.assertEqual(self.dispatch("GetPlaylistTracks", {"id": pl_null_id})["data"], [t1, t2, t3])

        res_reord_null = self.dispatch("ReorderPlaylistTracks", {"playlist_id": pl_null_id, "old_index": 2, "new_index": 0})
        self.assertResponseCode(res_reord_null, 200)
        self.assertEqual(res_reord_null["data"]["track_ids"], [t3, t1, t2])
        self.assertEqual(self.dispatch("GetPlaylistTracks", {"id": pl_null_id})["data"], [t3, t1, t2])

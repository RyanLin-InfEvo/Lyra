# SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
#
# SPDX-License-Identifier: AGPL-3.0-or-later

import uuid
from base_test_case import BaseLyraTestCase

class TestExactQueries(BaseLyraTestCase):

    def test_get_tracks_by_title(self):
        """Test GetTracksByTitle command"""
        title = "Duplicate Track Title"
        # Create two tracks with identical titles
        t1 = self.dispatch("CreateTrack", {"pcm_hash": "pcm_hash_t1", "title": title})
        self.assertResponseCode(t1, 201)
        t2 = self.dispatch("CreateTrack", {"pcm_hash": "pcm_hash_t2", "title": title})
        self.assertResponseCode(t2, 201)

        # Create another track with a different title
        t3 = self.dispatch("CreateTrack", {"pcm_hash": "pcm_hash_t3", "title": "Different Title"})
        self.assertResponseCode(t3, 201)

        # Query tracks by title
        res = self.dispatch("GetTracksByTitle", {"title": title})
        self.assertResponseCode(res, 200)
        self.assertTrue(isinstance(res["data"], list))
        self.assertEqual(len(res["data"]), 2)
        
        ids = [item["id"] for item in res["data"]]
        self.assertIn(t1["data"]["id"], ids)
        self.assertIn(t2["data"]["id"], ids)
        self.assertNotIn(t3["data"]["id"], ids)

        # Test validation error on empty title
        err_res = self.dispatch("GetTracksByTitle", {"title": ""})
        self.assertValidationError(err_res, expected_type="InvalidValue")

        # Test validation error on missing title
        err_res2 = self.dispatch("GetTracksByTitle", {})
        self.assertValidationError(err_res2, expected_type="MissingParameter")

    def test_get_artists_by_name(self):
        """Test GetArtistsByName command"""
        name = "Duplicate Artist Name"
        a1 = self.dispatch("CreateArtist", {"name": name})
        self.assertResponseCode(a1, 201)
        a2 = self.dispatch("CreateArtist", {"name": name})
        self.assertResponseCode(a2, 201)
        a3 = self.dispatch("CreateArtist", {"name": "Other Artist"})
        self.assertResponseCode(a3, 201)

        res = self.dispatch("GetArtistsByName", {"name": name})
        self.assertResponseCode(res, 200)
        self.assertTrue(isinstance(res["data"], list))
        self.assertEqual(len(res["data"]), 2)

        ids = [item["id"] for item in res["data"]]
        self.assertIn(a1["data"]["id"], ids)
        self.assertIn(a2["data"]["id"], ids)
        self.assertNotIn(a3["data"]["id"], ids)

        err_res = self.dispatch("GetArtistsByName", {"name": ""})
        self.assertValidationError(err_res, expected_type="InvalidValue")

    def test_get_albums_by_title(self):
        """Test GetAlbumsByTitle command"""
        title = "Duplicate Album Title"
        al1 = self.dispatch("CreateAlbum", {"title": title})
        self.assertResponseCode(al1, 201)
        al2 = self.dispatch("CreateAlbum", {"title": title})
        self.assertResponseCode(al2, 201)
        al3 = self.dispatch("CreateAlbum", {"title": "Other Album"})
        self.assertResponseCode(al3, 201)

        res = self.dispatch("GetAlbumsByTitle", {"title": title})
        self.assertResponseCode(res, 200)
        self.assertTrue(isinstance(res["data"], list))
        self.assertEqual(len(res["data"]), 2)

        ids = [item["id"] for item in res["data"]]
        self.assertIn(al1["data"]["id"], ids)
        self.assertIn(al2["data"]["id"], ids)
        self.assertNotIn(al3["data"]["id"], ids)

        err_res = self.dispatch("GetAlbumsByTitle", {"title": ""})
        self.assertValidationError(err_res, expected_type="InvalidValue")

    def test_get_works_by_title(self):
        """Test GetWorksByTitle command"""
        title = "Duplicate Work Title"
        w1 = self.dispatch("CreateWork", {"title": title})
        self.assertResponseCode(w1, 201)
        w2 = self.dispatch("CreateWork", {"title": title})
        self.assertResponseCode(w2, 201)
        w3 = self.dispatch("CreateWork", {"title": "Other Work"})
        self.assertResponseCode(w3, 201)

        res = self.dispatch("GetWorksByTitle", {"title": title})
        self.assertResponseCode(res, 200)
        self.assertTrue(isinstance(res["data"], list))
        self.assertEqual(len(res["data"]), 2)

        ids = [item["id"] for item in res["data"]]
        self.assertIn(w1["data"]["id"], ids)
        self.assertIn(w2["data"]["id"], ids)
        self.assertNotIn(w3["data"]["id"], ids)

        err_res = self.dispatch("GetWorksByTitle", {"title": ""})
        self.assertValidationError(err_res, expected_type="InvalidValue")

    def test_get_playlists_by_title(self):
        """Test GetPlaylistsByTitle command"""
        title = "Duplicate Playlist Title"
        p1 = self.dispatch("CreatePlaylist", {"title": title})
        self.assertResponseCode(p1, 201)
        p2 = self.dispatch("CreatePlaylist", {"title": title})
        self.assertResponseCode(p2, 201)
        p3 = self.dispatch("CreatePlaylist", {"title": "Other Playlist"})
        self.assertResponseCode(p3, 201)

        res = self.dispatch("GetPlaylistsByTitle", {"title": title})
        self.assertResponseCode(res, 200)
        self.assertTrue(isinstance(res["data"], list))
        self.assertEqual(len(res["data"]), 2)

        ids = [item["id"] for item in res["data"]]
        self.assertIn(p1["data"]["id"], ids)
        self.assertIn(p2["data"]["id"], ids)
        self.assertNotIn(p3["data"]["id"], ids)

        err_res = self.dispatch("GetPlaylistsByTitle", {"title": ""})
        self.assertValidationError(err_res, expected_type="InvalidValue")

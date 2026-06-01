# SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
#
# SPDX-License-Identifier: AGPL-3.0-or-later

import uuid
from base_test_case import BaseLyraTestCase

class TestListAPIs(BaseLyraTestCase):

    def setUp(self):
        super().setUp()

    def test_list_tracks_pagination_and_sorting(self):  #TODO
        """Test pagination and sorting logic on tracks"""
        titles = ["Banana", "Apple", "Elderberry", "Cherry", "Date"]
        created_ids = []
        for t in titles:
            res = self.dispatch("CreateTrack", {"pcm_hash": f"hash_{t}", "title": t})
            self.assertEqual(res["code"], 201)
            created_ids.append(res["data"]["id"])

        # Default list (limit=20, offset=0) should be sorted by title ASC
        res_list = self.dispatch("ListTracks", {})
        self.assertEqual(res_list["code"], 200)
        self.assertEqual(res_list["data"]["total"], 5)
        self.assertEqual(len(res_list["data"]["items"]), 5)
        
        sorted_titles = sorted(titles)
        for i, item in enumerate(res_list["data"]["items"]):
            self.assertEqual(item["title"], sorted_titles[i])

        # Pagination: limit=2
        res_limit2 = self.dispatch("ListTracks", {"limit": 2})
        self.assertEqual(res_limit2["code"], 200)
        self.assertEqual(res_limit2["data"]["total"], 5)
        self.assertEqual(len(res_limit2["data"]["items"]), 2)
        self.assertEqual(res_limit2["data"]["items"][0]["title"], sorted_titles[0])
        self.assertEqual(res_limit2["data"]["items"][1]["title"], sorted_titles[1])

        # Pagination: limit=2, offset=2
        res_offset2 = self.dispatch("ListTracks", {"limit": 2, "offset": 2})
        self.assertEqual(res_offset2["code"], 200)
        self.assertEqual(res_offset2["data"]["total"], 5)
        self.assertEqual(len(res_offset2["data"]["items"]), 2)
        self.assertEqual(res_offset2["data"]["items"][0]["title"], sorted_titles[2])
        self.assertEqual(res_offset2["data"]["items"][1]["title"], sorted_titles[3])

    def test_list_tracks_search_and_escaping(self):
        """Test search query matching and wildcard escaping"""
        special_titles = [
            "Normal Track",
            "Track%Percent",
            "Track_Underscore",
            "Track\\Backslash"
        ]
        for t in special_titles:
            res = self.dispatch("CreateTrack", {"pcm_hash": f"hash_{uuid.uuid4().hex[:6]}", "title": t})
            self.assertEqual(res["code"], 201)

        # 1. Search for normal substring
        res = self.dispatch("ListTracks", {"search": "Normal"})
        self.assertEqual(res["code"], 200)
        self.assertEqual(res["data"]["total"], 1)
        self.assertEqual(res["data"]["items"][0]["title"], "Normal Track")

        # 2. Search for % literally (escaped)
        res = self.dispatch("ListTracks", {"search": "%"})
        self.assertEqual(res["code"], 200)
        self.assertEqual(res["data"]["total"], 1)
        self.assertEqual(res["data"]["items"][0]["title"], "Track%Percent")

        # 3. Search for _ literally (escaped)
        res = self.dispatch("ListTracks", {"search": "_"})
        self.assertEqual(res["code"], 200)
        self.assertEqual(res["data"]["total"], 1)
        self.assertEqual(res["data"]["items"][0]["title"], "Track_Underscore")

        # 4. Search for \ literally (escaped)
        res = self.dispatch("ListTracks", {"search": "\\"})
        self.assertEqual(res["code"], 200)
        self.assertEqual(res["data"]["total"], 1)
        self.assertEqual(res["data"]["items"][0]["title"], "Track\\Backslash")

        # 5. Empty or whitespace search should be treated as nullopt (return all items)
        res = self.dispatch("ListTracks", {"search": "   "})
        self.assertEqual(res["code"], 200)
        self.assertGreaterEqual(res["data"]["total"], 4)

    def test_list_validation_errors(self):
        """Test listing validation constraints (offset, limit)"""
        # Negative offset
        res = self.dispatch("ListTracks", {"offset": -1})
        self.assertEqual(res["code"], 400)
        self.assertEqual(res["error"]["type"], "OutOfRange")

        # Negative limit
        res = self.dispatch("ListTracks", {"limit": -5})
        self.assertEqual(res["code"], 400)
        self.assertEqual(res["error"]["type"], "OutOfRange")

        # Limit zero
        res = self.dispatch("ListTracks", {"limit": 0})
        self.assertEqual(res["code"], 400)
        self.assertEqual(res["error"]["type"], "OutOfRange")

        # Limit > 100
        res = self.dispatch("ListTracks", {"limit": 101})
        self.assertEqual(res["code"], 400)
        self.assertEqual(res["error"]["type"], "OutOfRange")

    def test_list_all_entities(self):
        """Test listing for Artists, Albums, Playlists, and Works"""
        # 1. Artists (matches "name")
        for name in ["Artist B", "Artist A"]:
            self.assertEqual(self.dispatch("CreateArtist", {"name": name})["code"], 201)
        res = self.dispatch("ListArtists", {"limit": 10})
        self.assertEqual(res["code"], 200)
        self.assertEqual(res["data"]["total"], 2)
        self.assertEqual(res["data"]["items"][0]["name"], "Artist A")
        self.assertEqual(res["data"]["items"][1]["name"], "Artist B")

        # 2. Albums (matches "title")
        for title in ["Album B", "Album A"]:
            self.assertEqual(self.dispatch("CreateAlbum", {"title": title})["code"], 201)
        res = self.dispatch("ListAlbums", {"limit": 10})
        self.assertEqual(res["code"], 200)
        self.assertEqual(res["data"]["total"], 2)
        self.assertEqual(res["data"]["items"][0]["title"], "Album A")
        self.assertEqual(res["data"]["items"][1]["title"], "Album B")

        # 3. Playlists (matches "title")
        for title in ["Playlist B", "Playlist A"]:
            self.assertEqual(self.dispatch("CreatePlaylist", {"title": title})["code"], 201)
        res = self.dispatch("ListPlaylists", {"limit": 10})
        self.assertEqual(res["code"], 200)
        self.assertEqual(res["data"]["total"], 2)
        self.assertEqual(res["data"]["items"][0]["title"], "Playlist A")
        self.assertEqual(res["data"]["items"][1]["title"], "Playlist B")

        # 4. Works (matches "title")
        for title in ["Work B", "Work A"]:
            self.assertEqual(self.dispatch("CreateWork", {"title": title})["code"], 201)
        res = self.dispatch("ListWorks", {"limit": 10})
        self.assertEqual(res["code"], 200)
        self.assertEqual(res["data"]["total"], 2)
        self.assertEqual(res["data"]["items"][0]["title"], "Work A")
        self.assertEqual(res["data"]["items"][1]["title"], "Work B")

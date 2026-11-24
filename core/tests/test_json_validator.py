# SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
#
# SPDX-License-Identifier: AGPL-3.0-or-later

import os
import struct
import uuid
import unittest
import wave
from base_test_case import BaseLyraTestCase

class TestJsonValidator(BaseLyraTestCase):

    def test_missing_required_field(self):
        """Test missing required field: Should return 400 with MissingParameter"""
        # ArtistController::create requires 'name'
        res = self.dispatch("CreateArtist", {})
        self.assertValidationError(res, expected_type="MissingParameter", expected_message_content="Missing required field")

    def test_type_mismatch_string(self):
        """Test type mismatch for String field"""
        # ArtistController::create requires 'name' (String)
        res = self.dispatch("CreateArtist", {"name": 1234})
        self.assertValidationError(res, expected_type="InvalidValue", expected_message_content="is not a expected type")

    def test_type_mismatch_number(self):
        """Test type mismatch for Number field"""
        # TrackController::create optional 'duration' (Number)
        res = self.dispatch("CreateTrack", {
            "pcm_hash": "hash_123",
            "title": "Title",
            "duration": "180" # String instead of Number
        })
        self.assertValidationError(res, expected_type="InvalidValue", expected_message_content="is not a expected type")

    def test_string_format_uuid(self):
        """Test invalid UUID format"""
        # ArtistController::get requires 'id' (StringFormat::UUID)
        res = self.dispatch("GetArtist", {"id": "invalid-uuid-format"})
        self.assertValidationError(res, expected_type="InvalidValue", expected_message_content="not a vaild UUID")

    def test_string_empty(self):
        """Test empty string validation"""
        # TrackController::create requires 'pcm_hash' not to be empty
        res = self.dispatch("CreateTrack", {
            "pcm_hash": "",
            "title": "Title" # title is optional but we test required string
        })
        self.assertValidationError(res, expected_type="InvalidValue", expected_message_content="should not be empty")

    def test_valid_json_payload(self):
        """Test valid payload passes JsonValidator completely"""
        res = self.dispatch("CreateTrack", {
            "pcm_hash": "hash_abc",
            "duration": 180
        })
        self.assertResponseCode(res, 201)

    def assert_structured_error(self, res, msg_context):
        """Helper: verify the response is a proper structured 400 error, not a catch-all leak."""
        self.assertResponseCode(res, 400, f"[{msg_context}] Expected 400, got: {res}")
        self.assertIn("error", res, f"[{msg_context}] Missing 'error' key: {res}")
        self.assertIn("type", res["error"], f"[{msg_context}] Missing error.type (catch-all leak): {res}")
        self.assertEqual(
            res["error"]["type"], "InvalidCommandFormat",
            f"[{msg_context}] Expected InvalidCommandFormat, got: {res['error']}"
        )
        # Must NOT contain raw C++ exception leak
        self.assertNotIn(
            "json.exception", res["error"].get("message", ""),
            f"[{msg_context}] Raw nlohmann exception leaked: {res['error']['message']}"
        )

    def test_params_null(self):
        """params: null → should return structured InvalidCommandFormat error"""
        res = self.raw_dispatch({"command": "CreateArtist", "params": None})
        self.assert_structured_error(res, "params=null")

    def test_params_array(self):
        """params: [] → should return structured InvalidCommandFormat error"""
        res = self.raw_dispatch({"command": "CreateArtist", "params": []})
        self.assert_structured_error(res, "params=array")

    def test_params_number(self):
        """params: 42 → should return structured InvalidCommandFormat error"""
        res = self.raw_dispatch({"command": "CreateArtist", "params": 42})
        self.assert_structured_error(res, "params=number")

    def test_params_string(self):
        """params: 'hello' → should return structured InvalidCommandFormat error"""
        res = self.raw_dispatch({"command": "CreateArtist", "params": "hello"})
        self.assert_structured_error(res, "params=string")

    def test_artist_name_empty(self):
        """Test empty artist name validation"""
        res = self.dispatch("CreateArtist", {"name": ""})
        self.assertValidationError(res, expected_type="InvalidValue", expected_message_content="should not be empty")

    def _write_dummy_wav(self, filename: str, byte_val: int = 1) -> str:
        path = os.path.join(self.test_db_dir, filename)
        with wave.open(path, "wb") as wf:
            wf.setnchannels(1)
            wf.setsampwidth(2)
            wf.setframerate(44100)
            wf.writeframes(struct.pack("<h", byte_val) * 22050)
        return path

    def test_single_line_text_control_char_rejections(self):
        """All SingleLineText fields across router handlers reject C0/C1/DEL/newline/tab/NUL characters."""
        bad_single = ["a\nb", "a\tb", "a\rb", "a\x1bb", "a\x00b", "a\x7fb", "a\u0085b"]

        artist_id = self.dispatch("CreateArtist", {"name": "Val Artist"})["data"]["id"]
        pcm_hash = f"pcm-val-{uuid.uuid4().hex[:8]}"
        self.assertResponseCode(
            self.dispatch("CreateAudio", {"pcm_hash": pcm_hash, "sample_rate": 44100}),
            201,
        )
        file_hash = uuid.uuid4().hex + uuid.uuid4().hex
        self.assertResponseCode(
            self.dispatch(
                "CreateAsset",
                {
                    "file_hash": file_hash,
                    "pcm_hash": pcm_hash,
                    "mime_type": "audio/flac",
                    "asset_type": "audio",
                    "file_size": 100,
                },
            ),
            201,
        )
        track_id = self.dispatch("CreateTrack", {"pcm_hash": pcm_hash, "title": "Val Track"})["data"]["id"]
        album_id = self.dispatch("CreateAlbum", {"title": "Val Album"})["data"]["id"]
        work_id = self.dispatch("CreateWork", {"title": "Val Work"})["data"]["id"]
        playlist_id = self.dispatch("CreatePlaylist", {"title": "Val Playlist"})["data"]["id"]
        tag_id = self.dispatch("tag.create", {"name": "Val Tag"})["data"]["id"]
        valid_wav = self._write_dummy_wav("sl_valid.wav", byte_val=33)

        cases = [
            ("CreateArtist", lambda b: {"name": b}),
            ("CreateArtist", lambda b: {"name": "ok", "musicbrainz_id": b}),
            ("CreateArtist", lambda b: {"name": "ok", "ytm_id": b}),
            ("CreateArtist", lambda b: {"name": "ok", "spotify_id": b}),
            ("UpdateArtist", lambda b: {"id": artist_id, "name": b}),
            ("UpdateArtist", lambda b: {"id": artist_id, "musicbrainz_id": b}),
            ("UpdateArtist", lambda b: {"id": artist_id, "ytm_id": b}),
            ("UpdateArtist", lambda b: {"id": artist_id, "spotify_id": b}),
            ("CreateTrack", lambda b: {"pcm_hash": b}),
            ("CreateTrack", lambda b: {"pcm_hash": pcm_hash, "title": b}),
            ("CreateTrack", lambda b: {"pcm_hash": pcm_hash, "recording_location": b}),
            ("CreateTrack", lambda b: {"pcm_hash": pcm_hash, "isrc": b}),
            ("CreateTrack", lambda b: {"pcm_hash": pcm_hash, "musicbrainz_id": b}),
            ("CreateTrack", lambda b: {"pcm_hash": pcm_hash, "ytm_id": b}),
            ("CreateTrack", lambda b: {"pcm_hash": pcm_hash, "spotify_id": b}),
            ("UpdateTrack", lambda b: {"id": track_id, "pcm_hash": b}),
            ("UpdateTrack", lambda b: {"id": track_id, "title": b}),
            ("UpdateTrack", lambda b: {"id": track_id, "recording_location": b}),
            ("UpdateTrack", lambda b: {"id": track_id, "isrc": b}),
            ("UpdateTrack", lambda b: {"id": track_id, "musicbrainz_id": b}),
            ("UpdateTrack", lambda b: {"id": track_id, "ytm_id": b}),
            ("UpdateTrack", lambda b: {"id": track_id, "spotify_id": b}),
            ("CreateAlbum", lambda b: {"title": b}),
            ("UpdateAlbum", lambda b: {"id": album_id, "title": b}),
            ("CreateWork", lambda b: {"title": b}),
            ("CreateWork", lambda b: {"title": "ok", "composition_date_text": b}),
            ("CreateWork", lambda b: {"title": "ok", "iswc": b}),
            ("CreateWork", lambda b: {"title": "ok", "musicbrainz_id": b}),
            ("UpdateWork", lambda b: {"id": work_id, "title": b}),
            ("UpdateWork", lambda b: {"id": work_id, "composition_date_text": b}),
            ("UpdateWork", lambda b: {"id": work_id, "iswc": b}),
            ("UpdateWork", lambda b: {"id": work_id, "musicbrainz_id": b}),
            ("AddTrackArtist", lambda b: {"track_id": track_id, "artist_id": artist_id, "role": b}),
            ("UpdateTrackArtist", lambda b: {"track_id": track_id, "artist_id": artist_id, "role": b}),
            ("CreatePlaylist", lambda b: {"title": b}),
            ("UpdatePlaylist", lambda b: {"id": playlist_id, "title": b}),
            ("ImportTrack", lambda b: {"source_path": b}),
            ("ImportTrack", lambda b: {"source_path": valid_wav, "source_type": b}),
            ("IngestAsset", lambda b: {"source_path": b}),
            ("IngestAsset", lambda b: {"source_path": valid_wav, "source_type": b}),
            ("CreateAsset", lambda b: {"file_hash": b}),
            ("CreateAsset", lambda b: {"file_hash": "fh", "pcm_hash": b}),
            ("CreateAsset", lambda b: {"file_hash": "fh", "mime_type": b}),
            ("CreateAsset", lambda b: {"file_hash": "fh", "asset_type": b}),
            ("GetAsset", lambda b: {"file_hash": b}),
            ("UpdateAsset", lambda b: {"file_hash": b, "mime_type": "audio/flac"}),
            ("UpdateAsset", lambda b: {"file_hash": file_hash, "mime_type": b}),
            ("UpdateAsset", lambda b: {"file_hash": file_hash, "asset_type": b}),
            ("CreateAudio", lambda b: {"pcm_hash": b}),
            ("CreateAudio", lambda b: {"pcm_hash": "ph", "parent_hash": b}),
            ("GetAudio", lambda b: {"pcm_hash": b}),
            ("UpdateAudio", lambda b: {"pcm_hash": b, "quality_score": 10}),
            ("UpdateAudio", lambda b: {"pcm_hash": pcm_hash, "parent_hash": b}),
            ("GetResourcePath", lambda b: {"file_hash": b}),
            ("GetResourcePath", lambda b: {"pcm_hash": b}),
            ("GetResourcePath", lambda b: {"pcm_hash": pcm_hash, "preferred_format": b}),
            ("GetResourcePath", lambda b: {"pcm_hash": pcm_hash, "format": b}),
            ("GetEntityImages", lambda b: {"entity_id": track_id, "role": b}),
            ("audio.set_output_device", lambda b: {"device_id": b}),
            ("ListTracks", lambda b: {"search": b}),
            ("ListArtists", lambda b: {"search": b}),
            ("ListAlbums", lambda b: {"search": b}),
            ("ListWorks", lambda b: {"search": b}),
            ("ListPlaylists", lambda b: {"search": b}),
            ("ListAssets", lambda b: {"search": b}),
            ("ListAudio", lambda b: {"search": b}),
            ("GetTracksByTitle", lambda b: {"title": b}),
            ("GetArtistsByName", lambda b: {"name": b}),
            ("GetAlbumsByTitle", lambda b: {"title": b}),
            ("GetWorksByTitle", lambda b: {"title": b}),
            ("GetPlaylistsByTitle", lambda b: {"title": b}),
            ("tag.create", lambda b: {"name": b}),
            ("tag.create", lambda b: {"name": "valid", "category": b}),
            ("tag.list", lambda b: {"category": b}),
            ("tag.assign", lambda b: {"entity_id": track_id, "tag_id": tag_id, "entity_type": b}),
            ("tag.remove", lambda b: {"entity_id": track_id, "tag_id": tag_id, "entity_type": b}),
            ("tag.get_entity_tags", lambda b: {"entity_id": track_id, "entity_type": b}),
            ("source_data.get_by_asset", lambda b: {"file_hash": b}),
            ("source_data.create", lambda b: {"file_hash": b}),
            ("source_data.create", lambda b: {"file_hash": file_hash, "source_type": b}),
            ("source_data.create", lambda b: {"file_hash": file_hash, "original_path": b}),
        ]

        for cmd, payload_fn in cases:
            for bad in bad_single:
                res = self.dispatch(cmd, payload_fn(bad))
                self.assertValidationError(
                    res,
                    expected_type="InvalidValue",
                    expected_message_content="must be valid UTF-8 without control characters",
                )

    def test_multiline_text_acceptance_and_control_char_rejections(self):
        """MultilineText fields accept \\n, \\t, \\r and reject disallowed control chars."""
        valid_multiline = "line1\nline2\tcol\r\nline3\rline4"
        bad_multiline = ["a\x1bb", "a\x0bb", "a\x00b", "a\u0085b"]
        multi_msg = "must be valid UTF-8 without control characters other than tab, LF, or CR"

        # Playlist description
        pl_create = self.dispatch("CreatePlaylist", {"title": "ML Playlist", "description": valid_multiline})
        self.assertResponseCode(pl_create, 201)
        pl_id = pl_create["data"]["id"]
        self.assertEqual(self.dispatch("GetPlaylist", {"id": pl_id})["data"]["description"], valid_multiline)

        pl_update = self.dispatch("UpdatePlaylist", {"id": pl_id, "description": "upd\n\t\rtext"})
        self.assertResponseCode(pl_update, 200)
        self.assertEqual(self.dispatch("GetPlaylist", {"id": pl_id})["data"]["description"], "upd\n\t\rtext")

        for bad in bad_multiline:
            self.assertValidationError(
                self.dispatch("CreatePlaylist", {"title": "Bad PL", "description": bad}),
                expected_type="InvalidValue",
                expected_message_content=multi_msg,
            )
            self.assertValidationError(
                self.dispatch("UpdatePlaylist", {"id": pl_id, "description": bad}),
                expected_type="InvalidValue",
                expected_message_content=multi_msg,
            )

        # ImportTrack & IngestAsset note
        wav_imp = self._write_dummy_wav("ml_import.wav", byte_val=11)
        imp_res = self.dispatch("ImportTrack", {"source_path": wav_imp, "note": valid_multiline})
        self.assertResponseCode(imp_res, 200)

        wav_ing = self._write_dummy_wav("ml_ingest.wav", byte_val=22)
        ing_res = self.dispatch("IngestAsset", {"source_path": wav_ing, "note": valid_multiline})
        self.assertResponseCode(ing_res, 200)
        ing_hash = ing_res["data"]["asset"]["file_hash"]
        self.assertEqual(
            self.dispatch("source_data.get_by_asset", {"file_hash": ing_hash})["data"]["note"],
            valid_multiline,
        )

        for bad in bad_multiline:
            self.assertValidationError(
                self.dispatch("ImportTrack", {"source_path": wav_imp, "note": bad}),
                expected_type="InvalidValue",
                expected_message_content=multi_msg,
            )
            self.assertValidationError(
                self.dispatch("IngestAsset", {"source_path": wav_ing, "note": bad}),
                expected_type="InvalidValue",
                expected_message_content=multi_msg,
            )

        # source_data.create note (including empty string "")
        sd_ok = self.dispatch("source_data.create", {"file_hash": ing_hash, "note": valid_multiline})
        self.assertResponseCode(sd_ok, 201)
        self.assertEqual(sd_ok["data"]["note"], valid_multiline)

        sd_empty = self.dispatch("source_data.create", {"file_hash": ing_hash, "note": ""})
        self.assertResponseCode(sd_empty, 201)
        self.assertEqual(sd_empty["data"]["note"], "")

        for bad in bad_multiline:
            self.assertValidationError(
                self.dispatch("source_data.create", {"file_hash": ing_hash, "note": bad}),
                expected_type="InvalidValue",
                expected_message_content=multi_msg,
            )

    def test_null_safety_regressions(self):
        """Optional fields explicitly set to null must not trigger JSON type exceptions."""
        asset_res = self.dispatch(
            "CreateAsset",
            {
                "file_hash": f"null-pcm-{uuid.uuid4().hex[:8]}",
                "pcm_hash": None,
                "mime_type": "text/plain",
                "asset_type": "text",
                "file_size": 12,
            },
        )
        self.assertResponseCode(asset_res, 201)

        track_id = self.dispatch("CreateTrack", {"pcm_hash": f"pcm-null-{uuid.uuid4().hex[:8]}", "title": "NullTest"})["data"]["id"]
        artist_id = self.dispatch("CreateArtist", {"name": "NullTestArtist"})["data"]["id"]
        self.assertResponseCode(
            self.dispatch("AddTrackArtist", {"track_id": track_id, "artist_id": artist_id, "role": "main"}),
            201,
        )
        upd_ta = self.dispatch(
            "UpdateTrackArtist",
            {"track_id": track_id, "artist_id": artist_id, "role": None, "position": 2},
        )
        self.assertResponseCode(upd_ta, 200)

        playlist_id = self.dispatch("CreatePlaylist", {"title": "NullPosPlaylist"})["data"]["id"]
        add_pt = self.dispatch(
            "AddPlaylistTrack",
            {"playlist_id": playlist_id, "track_id": track_id, "position": None},
        )
        self.assertResponseCode(add_pt, 201)

    def test_null_and_extra_fields_on_create_update_remove(self):
        """CRITICAL-1: Null optional fields and client-ignored id/created_at/assets must never throw InvalidCommandFormat."""
        fh = f"crit1-asset-{uuid.uuid4().hex[:8]}"
        res_asset = self.dispatch(
            "CreateAsset",
            {
                "file_hash": fh,
                "mime_type": None,
                "asset_type": None,
                "file_size": None,
                "created_at": None,
            },
        )
        self.assertResponseCode(res_asset, 201)
        got_asset = self.dispatch("GetAsset", {"file_hash": fh})
        self.assertResponseCode(got_asset, 200)
        self.assertEqual(got_asset["data"]["mime_type"], "")
        self.assertEqual(got_asset["data"]["asset_type"], "")
        self.assertEqual(got_asset["data"]["file_size"], 0)

        res_asset_extra = self.dispatch(
            "CreateAsset",
            {
                "file_hash": f"crit1-asset2-{uuid.uuid4().hex[:8]}",
                "created_at": 123,
            },
        )
        self.assertResponseCode(res_asset_extra, 201)

        orig_created_at = self.dispatch("GetAsset", {"file_hash": fh})["data"]["created_at"]
        res_upd_asset_ok = self.dispatch(
            "UpdateAsset",
            {"file_hash": fh, "mime_type": "audio/wav", "created_at": 123},
        )
        self.assertResponseCode(res_upd_asset_ok, 200)
        self.assertEqual(self.dispatch("GetAsset", {"file_hash": fh})["data"]["created_at"], orig_created_at)

        res_upd_asset_only_created = self.dispatch(
            "UpdateAsset",
            {"file_hash": fh, "created_at": "bad\n\x00"},
        )
        self.assertValidationError(
            res_upd_asset_only_created,
            expected_type="InvalidValue",
            expected_message_content="No fields provided to update",
        )
        self.assertEqual(self.dispatch("GetAsset", {"file_hash": fh})["data"]["created_at"], orig_created_at)

        pcm = f"crit1-pcm-{uuid.uuid4().hex[:8]}"
        res_audio = self.dispatch(
            "CreateAudio",
            {
                "pcm_hash": pcm,
                "parent_hash": None,
                "quality_score": None,
                "bit_depth": None,
                "sample_rate": None,
                "channels": None,
                "duration": None,
                "integrated_loudness": None,
                "true_peak": None,
                "assets": "bad",
            },
        )
        self.assertResponseCode(res_audio, 201)
        got_audio = self.dispatch("GetAudio", {"pcm_hash": pcm})
        self.assertResponseCode(got_audio, 200)
        self.assertEqual(got_audio["data"]["parent_hash"], "")
        self.assertEqual(got_audio["data"]["quality_score"], 0)
        self.assertEqual(got_audio["data"]["bit_depth"], 0)
        self.assertEqual(got_audio["data"]["sample_rate"], 0)
        self.assertEqual(got_audio["data"]["channels"], 0)
        self.assertEqual(got_audio["data"]["duration"], 0.0)
        self.assertEqual(got_audio["data"]["integrated_loudness"], 0.0)
        self.assertEqual(got_audio["data"]["true_peak"], 0.0)
        self.assertEqual(got_audio["data"]["assets"], [])
        res_audio_null_assets = self.dispatch(
            "CreateAudio",
            {"pcm_hash": f"crit1-pcm2-{uuid.uuid4().hex[:8]}", "assets": None},
        )
        self.assertResponseCode(res_audio_null_assets, 201)

        for bad_id in (None, 123):
            self.assertResponseCode(self.dispatch("CreateArtist", {"id": bad_id, "name": "Crit1Artist"}), 201)
            self.assertResponseCode(self.dispatch("CreateTrack", {"id": bad_id, "pcm_hash": pcm}), 201)
            self.assertResponseCode(self.dispatch("CreateAlbum", {"id": bad_id, "title": "Crit1Album"}), 201)
            self.assertResponseCode(self.dispatch("CreateWork", {"id": bad_id, "title": "Crit1Work"}), 201)
            self.assertResponseCode(self.dispatch("CreatePlaylist", {"id": bad_id, "title": "Crit1PL"}), 201)

        tid = self.dispatch("CreateTrack", {"pcm_hash": pcm})["data"]["id"]
        aid = self.dispatch("CreateArtist", {"name": "RemTA"})["data"]["id"]
        self.assertResponseCode(
            self.dispatch("AddTrackArtist", {"track_id": tid, "artist_id": aid, "role": "main"}),
            201,
        )
        res_rem_ta = self.dispatch(
            "RemoveTrackArtist",
            {"track_id": tid, "artist_id": aid, "position": "bad", "role": 123},
        )
        self.assertResponseCode(res_rem_ta, 200)

    def test_empty_optional_fields_allowed(self):
        """CRITICAL-2 & MEDIUM-1: Empty strings work for clearing/defaulting optional fields."""
        parent_pcm = f"empty-parent-{uuid.uuid4().hex[:8]}"
        child_pcm = f"empty-child-{uuid.uuid4().hex[:8]}"
        self.assertResponseCode(self.dispatch("CreateAudio", {"pcm_hash": parent_pcm, "parent_hash": ""}), 201)
        self.assertResponseCode(self.dispatch("CreateAudio", {"pcm_hash": child_pcm, "parent_hash": parent_pcm}), 201)
        self.assertResponseCode(self.dispatch("UpdateAudio", {"pcm_hash": child_pcm, "parent_hash": ""}), 200)
        self.assertEqual(self.dispatch("GetAudio", {"pcm_hash": child_pcm})["data"]["parent_hash"], "")

        fh = f"empty-asset-{uuid.uuid4().hex[:8]}"
        self.assertResponseCode(self.dispatch("CreateAsset", {"file_hash": fh, "mime_type": "", "asset_type": ""}), 201)
        self.assertResponseCode(self.dispatch("UpdateAsset", {"file_hash": fh, "mime_type": "", "asset_type": ""}), 200)

        pl = self.dispatch("CreatePlaylist", {"title": "EmptyDesc", "description": ""})
        self.assertResponseCode(pl, 201)
        self.assertResponseCode(self.dispatch("UpdatePlaylist", {"id": pl["data"]["id"], "description": ""}), 200)

        wav_empty = self._write_dummy_wav("empty_opt_fields.wav", byte_val=44)
        self.assertResponseCode(
            self.dispatch("ImportTrack", {"source_path": wav_empty, "source_type": "", "note": ""}),
            200,
        )
        wav_empty2 = self._write_dummy_wav("empty_opt_fields2.wav", byte_val=55)
        self.assertResponseCode(
            self.dispatch("IngestAsset", {"source_path": wav_empty2, "source_type": "", "note": ""}),
            200,
        )

    def test_non_object_params_and_root_requests(self):
        """MEDIUM-4: Router::route rejects non-object params uniformly while preserving 404 UnknownCommand."""
        for cmd in (
            "audio.pause",
            "audio.resume",
            "audio.stop",
            "audio.get_state",
            "audio.list_devices",
            "system.get_config",
            "audio.seek",
            "audio.set_volume",
            "audio.preload_next",
        ):
            for bad_params in ([], 123, "bad", None):
                res = self.raw_dispatch({"command": cmd, "params": bad_params})
                self.assertValidationError(
                    res,
                    expected_type="InvalidCommandFormat",
                    expected_message_content="'params' must be a JSON object",
                )

        res_unknown = self.raw_dispatch({"command": "NoSuchCmd", "params": []})
        self.assertResponseCode(res_unknown, 404)
        self.assertEqual(res_unknown["error"]["type"], "UnknownCommand")

        res_root_arr = self.raw_dispatch([])
        self.assertValidationError(
            res_root_arr,
            expected_type="InvalidCommandFormat",
            expected_message_content="Missing or invalid 'command' field",
        )

    def test_integer_narrowing_and_wraparound_bounds(self):
        """MEDIUM-5 & Audit Findings 1/3/7: 64-bit overflow, uint64_t wraparound, negative Audio fields, and empty UpdateTrackArtist."""
        UINT64_MAX = 18446744073709551615
        INT64_MAX_PLUS_1 = 9223372036854775808
        INT_MIN_MINUS_1 = -2147483649

        self.assertValidationError(
            self.dispatch("ListTracks", {"offset": -1}),
            expected_type="OutOfRange",
            expected_message_content="must be >= 0",
        )
        self.assertValidationError(
            self.dispatch("ListTracks", {"offset": 4294967296}),
            expected_type="OutOfRange",
            expected_message_content="must be <= 2147483647",
        )
        self.assertValidationError(
            self.dispatch("ListTracks", {"offset": UINT64_MAX}),
            expected_type="OutOfRange",
            expected_message_content="must be <= 2147483647",
        )
        for bad_limit in (0, -1):
            self.assertValidationError(
                self.dispatch("ListTracks", {"limit": bad_limit}),
                expected_type="OutOfRange",
                expected_message_content="must be >= 1",
            )
        self.assertValidationError(
            self.dispatch("ListTracks", {"limit": 4294967297}),
            expected_type="OutOfRange",
            expected_message_content="must be <= 100",
        )
        self.assertValidationError(
            self.dispatch("ListTracks", {"limit": UINT64_MAX}),
            expected_type="OutOfRange",
            expected_message_content="must be <= 100",
        )

        pcm = f"int-bounds-{uuid.uuid4().hex[:8]}"
        tid = self.dispatch("CreateTrack", {"pcm_hash": pcm, "title": "Bounds"})["data"]["id"]
        for bad_dur, expected_msg in (
            (-1, "must be >= 0"),
            (4294967296, "must be <= 4294967295"),
            (UINT64_MAX, "must be <= 4294967295"),
            (INT64_MAX_PLUS_1, "must be <= 4294967295"),
        ):
            self.assertValidationError(
                self.dispatch("CreateTrack", {"pcm_hash": pcm, "duration": bad_dur}),
                expected_type="OutOfRange",
                expected_message_content=expected_msg,
            )
            self.assertValidationError(
                self.dispatch("UpdateTrack", {"id": tid, "duration": bad_dur}),
                expected_type="OutOfRange",
                expected_message_content=expected_msg,
            )

        # End-to-end uint32_t > INT32_MAX Track.duration round-trip (CreateTrack/UpdateTrack -> GetTrack)
        res_u32_track = self.dispatch(
            "CreateTrack",
            {"pcm_hash": pcm, "title": "LongTrack", "duration": 3000000000},
        )
        self.assertResponseCode(res_u32_track, 201)
        u32_tid = res_u32_track["data"]["id"]
        got_u32 = self.dispatch("GetTrack", {"id": u32_tid})
        self.assertResponseCode(got_u32, 200)
        self.assertEqual(got_u32["data"]["duration"], 3000000000)

        res_u32_upd = self.dispatch("UpdateTrack", {"id": u32_tid, "duration": 4294967295})
        self.assertResponseCode(res_u32_upd, 200)
        got_u32_upd = self.dispatch("GetTrack", {"id": u32_tid})
        self.assertResponseCode(got_u32_upd, 200)
        self.assertEqual(got_u32_upd["data"]["duration"], 4294967295)

        fh = f"int-asset-{uuid.uuid4().hex[:8]}"
        self.assertResponseCode(self.dispatch("CreateAsset", {"file_hash": fh}), 201)
        for bad_size, expected_msg in (
            (-1, "must be >= 0"),
            (2147483648, "must be <= 2147483647"),
            (UINT64_MAX, "must be <= 2147483647"),
            (INT64_MAX_PLUS_1, "must be <= 2147483647"),
        ):
            self.assertValidationError(
                self.dispatch("CreateAsset", {"file_hash": "fh2", "file_size": bad_size}),
                expected_type="OutOfRange",
                expected_message_content=expected_msg,
            )
            self.assertValidationError(
                self.dispatch("UpdateAsset", {"file_hash": fh, "file_size": bad_size}),
                expected_type="OutOfRange",
                expected_message_content=expected_msg,
            )

        aud_pcm = f"int-aud-{uuid.uuid4().hex[:8]}"
        self.assertResponseCode(self.dispatch("CreateAudio", {"pcm_hash": aud_pcm}), 201)
        for aud_field in ("quality_score", "bit_depth", "sample_rate", "channels"):
            for bad_int, expected_msg in (
                (-1, "must be >= 0"),
                (2147483648, "must be <= 2147483647"),
                (UINT64_MAX, "must be <= 2147483647"),
                (INT64_MAX_PLUS_1, "must be <= 2147483647"),
            ):
                self.assertValidationError(
                    self.dispatch("CreateAudio", {"pcm_hash": f"{aud_pcm}-new", aud_field: bad_int}),
                    expected_type="OutOfRange",
                    expected_message_content=expected_msg,
                )
                self.assertValidationError(
                    self.dispatch("UpdateAudio", {"pcm_hash": aud_pcm, aud_field: bad_int}),
                    expected_type="OutOfRange",
                    expected_message_content=expected_msg,
                )
        for cmd, key in (("CreateAudio", f"{aud_pcm}-negdur"), ("UpdateAudio", aud_pcm)):
            self.assertValidationError(
                self.dispatch(cmd, {"pcm_hash": key, "duration": -1.0}),
                expected_type="OutOfRange",
                expected_message_content="must be >= 0",
            )

        art_id = self.dispatch("CreateArtist", {"name": f"BoundsArtist-{uuid.uuid4().hex[:8]}"})["data"]["id"]
        self.assertResponseCode(
            self.dispatch("AddTrackArtist", {"track_id": tid, "artist_id": art_id, "role": "main", "position": 1}),
            201,
        )
        pl_id = self.dispatch("CreatePlaylist", {"title": "BoundsPL"})["data"]["id"]
        for bad_pos, expected_msg in (
            (INT_MIN_MINUS_1, "must be >= -2147483648"),
            (2147483648, "must be <= 2147483647"),
            (UINT64_MAX, "must be <= 2147483647"),
            (INT64_MAX_PLUS_1, "must be <= 2147483647"),
        ):
            self.assertValidationError(
                self.dispatch("AddTrackArtist", {"track_id": tid, "artist_id": art_id, "role": "main", "position": bad_pos}),
                expected_type="OutOfRange",
                expected_message_content=expected_msg,
            )
            self.assertValidationError(
                self.dispatch("UpdateTrackArtist", {"track_id": tid, "artist_id": art_id, "position": bad_pos}),
                expected_type="OutOfRange",
                expected_message_content=expected_msg,
            )
            self.assertValidationError(
                self.dispatch("AddPlaylistTrack", {"playlist_id": pl_id, "track_id": tid, "position": bad_pos}),
                expected_type="OutOfRange",
                expected_message_content=expected_msg,
            )

        # Empty UpdateTrackArtist (all optional fields omitted or null) -> InvalidValue
        self.assertValidationError(
            self.dispatch("UpdateTrackArtist", {"track_id": tid, "artist_id": art_id, "role": None, "position": None}),
            expected_type="InvalidValue",
            expected_message_content="No fields provided to update.",
        )

        # ConfigurationService integer uint64_t > INT64_MAX wraparound must fail on upper limit, not "cannot be negative"
        self.assertValidationError(
            self.dispatch("system.set_config", {"database": {"mmap_size_bytes": UINT64_MAX}}),
            expected_type="OutOfRange",
            expected_message_content="exceeds maximum allowed limit",
        )
        for cfg_key in ("cache_size_kb", "busy_timeout_ms", "wal_autocheckpoint"):
            self.assertValidationError(
                self.dispatch("system.set_config", {"database": {cfg_key: UINT64_MAX}}),
                expected_type="OutOfRange",
                expected_message_content="exceeds maximum integer value",
            )
        self.assertValidationError(
            self.dispatch("system.set_config", {"audio": {"buffer_size_frames": UINT64_MAX}}),
            expected_type="OutOfRange",
            expected_message_content="must be between",
        )

    def test_system_set_config_control_char_validation(self):
        """HIGH-4: system.set_config rejects control characters and invalid UTF-8 in string settings."""
        for bad in ("bad\nval", "bad\rval", "bad\tval", "bad\x1bval", "bad\x00val", "bad\x7fval", "bad\u0085val"):
            self.assertValidationError(
                self.dispatch("system.set_config", {"audio": {"output_device_id": bad}}),
                expected_type="InvalidValue",
                expected_message_content="must be valid UTF-8 without control characters",
            )
            self.assertValidationError(
                self.dispatch("system.set_config", {"storage": {"storage_root": bad}}),
                expected_type="InvalidValue",
                expected_message_content="must be valid UTF-8 without control characters",
            )

    def test_overlong_source_path_no_filesystem_exception(self):
        """Audit Finding 2: overlong source_path must not leak uncaught filesystem_error via C API catch-all."""
        overlong_path = "/" + ("a" * 5000) + ".wav"
        self.assertValidationError(
            self.dispatch("IngestAsset", {"source_path": overlong_path}),
            expected_type="InvalidValue",
            expected_message_content="Source path does not exist or is not a regular file",
        )
        self.assertValidationError(
            self.dispatch("ImportTrack", {"source_path": overlong_path}),
            expected_type="InvalidValue",
            expected_message_content="Failed to extract metadata",
        )


if __name__ == "__main__":
    unittest.main()

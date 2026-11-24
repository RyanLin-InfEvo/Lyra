# SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
#
# SPDX-License-Identifier: AGPL-3.0-or-later

import os
import tempfile
import uuid
import wave
from base_test_case import BaseLyraTestCase


def _write_dummy_wav(filepath: str, duration_sec: float = 0.5, sample_rate: int = 44100, channels: int = 2, byte_val: int = 0):
    num_frames = int(duration_sec * sample_rate)
    with wave.open(filepath, "wb") as wf:
        wf.setnchannels(channels)
        wf.setsampwidth(2)
        wf.setframerate(sample_rate)
        wf.writeframes(bytes([byte_val]) * (num_frames * channels * 2))


class TestSourceData(BaseLyraTestCase):

    def _create_asset(self) -> str:
        file_hash = uuid.uuid4().hex + uuid.uuid4().hex
        res = self.dispatch(
            "CreateAsset",
            {
                "file_hash": file_hash,
                "mime_type": "audio/flac",
                "asset_type": "audio",
                "file_size": 2048,
            },
        )
        self.assertResponseCode(res, 201)
        return file_hash

    def test_source_data_create_and_get_by_asset(self):
        file_hash = self._create_asset()

        # Existing asset with no Source_Data returns 404 NotFound
        res_empty = self.dispatch("source_data.get_by_asset", {"file_hash": file_hash})
        self.assertResponseCode(res_empty, 404)
        self.assertEqual(res_empty["error"]["type"], "NotFound")

        # Create using full UI-compatible payload (including empty id & client created_at)
        res_create = self.dispatch(
            "source_data.create",
            {
                "id": "",
                "file_hash": file_hash,
                "source_type": "cd_rip",
                "original_path": "/rips/kind_of_blue/01.flac",
                "created_at": "2000-01-01T00:00:00Z",
                "note": "EAC AccurateRip v2",
            },
        )
        self.assertResponseCode(res_create, 201)
        data = res_create["data"]
        self.assertEqual(len(data["id"]), 36)
        self.assertEqual(data["file_hash"], file_hash)
        self.assertEqual(data["source_type"], "cd_rip")
        self.assertEqual(data["original_path"], "/rips/kind_of_blue/01.flac")
        self.assertEqual(data["note"], "EAC AccurateRip v2")
        self.assertTrue(len(data["created_at"]) > 0)
        self.assertNotEqual(data["created_at"], "2000-01-01T00:00:00Z")

        # Retrieve via source_data.get_by_asset
        res_get = self.dispatch("source_data.get_by_asset", {"file_hash": file_hash})
        self.assertResponseCode(res_get, 200)
        self.assertEqual(res_get["data"]["id"], data["id"])
        self.assertEqual(res_get["data"]["source_type"], "cd_rip")
        self.assertEqual(res_get["data"]["original_path"], "/rips/kind_of_blue/01.flac")
        self.assertEqual(res_get["data"]["note"], "EAC AccurateRip v2")

        # Create a second record with empty optional strings (UI default values) -> get_by_asset returns latest
        res_create2 = self.dispatch(
            "source_data.create",
            {
                "id": "",
                "file_hash": file_hash,
                "source_type": "digital_download",
                "original_path": "",
                "note": "",
            },
        )
        self.assertResponseCode(res_create2, 201)
        res_get2 = self.dispatch("source_data.get_by_asset", {"file_hash": file_hash})
        self.assertResponseCode(res_get2, 200)
        self.assertEqual(res_get2["data"]["id"], res_create2["data"]["id"])
        self.assertEqual(res_get2["data"]["source_type"], "digital_download")
        self.assertEqual(res_get2["data"]["original_path"], "")
        self.assertEqual(res_get2["data"]["note"], "")

    def test_source_data_missing_asset_and_validation_errors(self):
        missing_hash = uuid.uuid4().hex + uuid.uuid4().hex

        res_create_missing = self.dispatch(
            "source_data.create",
            {"file_hash": missing_hash, "source_type": "local_import"},
        )
        self.assertResponseCode(res_create_missing, 404)
        self.assertEqual(res_create_missing["error"]["type"], "AssetNotFound")

        res_get_missing = self.dispatch("source_data.get_by_asset", {"file_hash": missing_hash})
        self.assertResponseCode(res_get_missing, 404)
        self.assertEqual(res_get_missing["error"]["type"], "AssetNotFound")

        # Parameter validation for source_data.create
        self.assertValidationError(self.dispatch("source_data.create", []), expected_type="InvalidCommandFormat")
        self.assertValidationError(self.dispatch("source_data.create", {}), expected_type="MissingParameter")
        self.assertValidationError(self.dispatch("source_data.create", {"file_hash": None}), expected_type="MissingParameter")
        self.assertValidationError(self.dispatch("source_data.create", {"file_hash": ""}), expected_type="InvalidValue")
        self.assertValidationError(self.dispatch("source_data.create", {"file_hash": "   "}), expected_type="InvalidValue")
        self.assertValidationError(self.dispatch("source_data.create", {"file_hash": 123}), expected_type="InvalidValue")

        file_hash = self._create_asset()
        # Explicit null optional fields should succeed and map to empty strings
        res_null_opts = self.dispatch(
            "source_data.create",
            {"file_hash": file_hash, "source_type": None, "original_path": None, "note": None},
        )
        self.assertResponseCode(res_null_opts, 201)
        self.assertEqual(res_null_opts["data"]["source_type"], "")
        self.assertEqual(res_null_opts["data"]["original_path"], "")
        self.assertEqual(res_null_opts["data"]["note"], "")

        self.assertValidationError(
            self.dispatch("source_data.create", {"file_hash": file_hash, "source_type": 42}),
            expected_type="InvalidValue",
        )
        self.assertValidationError(
            self.dispatch("source_data.create", {"file_hash": file_hash, "original_path": ["bad"]}),
            expected_type="InvalidValue",
        )
        self.assertValidationError(
            self.dispatch("source_data.create", {"file_hash": file_hash, "note": {"k": "v"}}),
            expected_type="InvalidValue",
        )

        # Parameter validation for source_data.get_by_asset
        self.assertValidationError(self.dispatch("source_data.get_by_asset", []), expected_type="InvalidCommandFormat")
        self.assertValidationError(self.dispatch("source_data.get_by_asset", {}), expected_type="MissingParameter")
        self.assertValidationError(self.dispatch("source_data.get_by_asset", {"file_hash": None}), expected_type="MissingParameter")
        self.assertValidationError(self.dispatch("source_data.get_by_asset", {"file_hash": ""}), expected_type="InvalidValue")
        self.assertValidationError(self.dispatch("source_data.get_by_asset", {"file_hash": "  "}), expected_type="InvalidValue")
        self.assertValidationError(self.dispatch("source_data.get_by_asset", {"file_hash": 999}), expected_type="InvalidValue")

    def test_ingest_asset_and_import_track_auto_record_source_data(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            # 1. IngestAsset auto-records Source_Data
            wav1 = os.path.join(tmpdir, "ingest_provenance_test.wav")
            _write_dummy_wav(wav1, duration_sec=0.5, byte_val=1)

            ingest_res = self.dispatch("IngestAsset", {"source_path": wav1})
            self.assertResponseCode(ingest_res, 200)
            file_hash = ingest_res["data"]["asset"]["file_hash"]

            sd_res = self.dispatch("source_data.get_by_asset", {"file_hash": file_hash})
            self.assertResponseCode(sd_res, 200)
            self.assertEqual(sd_res["data"]["file_hash"], file_hash)
            self.assertEqual(sd_res["data"]["source_type"], "")
            self.assertEqual(sd_res["data"]["original_path"], wav1)
            self.assertTrue(len(sd_res["data"]["id"]) == 36)
            self.assertTrue(len(sd_res["data"]["created_at"]) > 0)

            # 2. ImportTrack auto-records Source_Data
            wav2 = os.path.join(tmpdir, "import_provenance_test.wav")
            _write_dummy_wav(wav2, duration_sec=0.6, byte_val=2)

            import_res = self.dispatch("ImportTrack", {"source_path": wav2})
            self.assertResponseCode(import_res, 200)

            # Find newly created asset hash for wav2
            assets_res = self.dispatch("ListAssets", {"offset": 0, "limit": 50})
            self.assertResponseCode(assets_res, 200)
            matched = []
            for asset in assets_res["data"]["items"]:
                sd = self.dispatch("source_data.get_by_asset", {"file_hash": asset["file_hash"]})
                if sd["code"] == 200 and sd["data"]["original_path"] == wav2:
                    matched.append(sd["data"])
            self.assertEqual(len(matched), 1)
            self.assertEqual(matched[0]["source_type"], "")
            self.assertEqual(matched[0]["original_path"], wav2)
            self.assertEqual(matched[0]["note"], "")

            # 3. IngestAsset with custom source_type and note
            wav3 = os.path.join(tmpdir, "cd_rip_provenance_test.wav")
            _write_dummy_wav(wav3, duration_sec=0.7, byte_val=3)

            ingest_custom = self.dispatch(
                "IngestAsset",
                {
                    "source_path": wav3,
                    "source_type": "CD RIP",
                    "note": "Exact Audio Copy v1.6",
                },
            )
            self.assertResponseCode(ingest_custom, 200)
            file_hash3 = ingest_custom["data"]["asset"]["file_hash"]
            sd_res3 = self.dispatch("source_data.get_by_asset", {"file_hash": file_hash3})
            self.assertResponseCode(sd_res3, 200)
            self.assertEqual(sd_res3["data"]["source_type"], "CD RIP")
            self.assertEqual(sd_res3["data"]["note"], "Exact Audio Copy v1.6")
            self.assertEqual(sd_res3["data"]["original_path"], wav3)

            # 4. ImportTrack with custom source_type and note
            wav4 = os.path.join(tmpdir, "yt_music_provenance_test.wav")
            _write_dummy_wav(wav4, duration_sec=0.8, byte_val=4)

            import_custom = self.dispatch(
                "ImportTrack",
                {
                    "source_path": wav4,
                    "source_type": "YouTube Music",
                    "note": "Batch download 2026-11",
                },
            )
            self.assertResponseCode(import_custom, 200)

            assets_res2 = self.dispatch("ListAssets", {"offset": 0, "limit": 50})
            self.assertResponseCode(assets_res2, 200)
            matched_yt = []
            for asset in assets_res2["data"]["items"]:
                sd = self.dispatch("source_data.get_by_asset", {"file_hash": asset["file_hash"]})
                if sd["code"] == 200 and sd["data"]["original_path"] == wav4:
                    matched_yt.append(sd["data"])
            self.assertEqual(len(matched_yt), 1)
            self.assertEqual(matched_yt[0]["source_type"], "YouTube Music")
            self.assertEqual(matched_yt[0]["note"], "Batch download 2026-11")

            # 5. Null / blank source_type falls back to "" (SQL NULL) and null note falls back to ""
            wav5 = os.path.join(tmpdir, "null_fallback_provenance_test.wav")
            _write_dummy_wav(wav5, duration_sec=0.9, byte_val=5)

            ingest_null = self.dispatch(
                "IngestAsset",
                {"source_path": wav5, "source_type": None, "note": None},
            )
            self.assertResponseCode(ingest_null, 200)
            sd_res5 = self.dispatch(
                "source_data.get_by_asset",
                {"file_hash": ingest_null["data"]["asset"]["file_hash"]},
            )
            self.assertResponseCode(sd_res5, 200)
            self.assertEqual(sd_res5["data"]["source_type"], "")
            self.assertEqual(sd_res5["data"]["note"], "")

            wav6 = os.path.join(tmpdir, "blank_fallback_provenance_test.wav")
            _write_dummy_wav(wav6, duration_sec=1.0, byte_val=6)

            import_blank = self.dispatch(
                "ImportTrack",
                {"source_path": wav6, "source_type": "   ", "note": "Keep note"},
            )
            self.assertResponseCode(import_blank, 200)
            assets_res3 = self.dispatch("ListAssets", {"offset": 0, "limit": 50})
            matched_blank = []
            for asset in assets_res3["data"]["items"]:
                sd = self.dispatch("source_data.get_by_asset", {"file_hash": asset["file_hash"]})
                if sd["code"] == 200 and sd["data"]["original_path"] == wav6:
                    matched_blank.append(sd["data"])
            self.assertEqual(len(matched_blank), 1)
            self.assertEqual(matched_blank[0]["source_type"], "")
            self.assertEqual(matched_blank[0]["note"], "Keep note")

            # 6. Invalid types for source_type and note fail fast with InvalidValue
            self.assertValidationError(
                self.dispatch("IngestAsset", {"source_path": wav1, "source_type": 123}),
                expected_type="InvalidValue",
            )
            self.assertValidationError(
                self.dispatch("IngestAsset", {"source_path": wav1, "note": ["bad"]}),
                expected_type="InvalidValue",
            )
            self.assertValidationError(
                self.dispatch("ImportTrack", {"source_path": wav1, "source_type": {"k": "v"}}),
                expected_type="InvalidValue",
            )
            self.assertValidationError(
                self.dispatch("ImportTrack", {"source_path": wav1, "note": True}),
                expected_type="InvalidValue",
            )

    def test_source_data_text_format_validation(self):
        """Test SingleLineText and MultilineText validation rules on source_data.* endpoints."""
        file_hash = self._create_asset()

        single_msg = "must be valid UTF-8 without control characters"
        multi_msg = "must be valid UTF-8 without control characters other than tab, LF, or CR"

        for bad_single in ("a\nb", "a\tb", "a\rb", "a\x1bb", "a\x00b", "a\x7fb", "a\u0085b"):
            self.assertValidationError(
                self.dispatch("source_data.get_by_asset", {"file_hash": bad_single}),
                expected_type="InvalidValue",
                expected_message_content=single_msg,
            )
            self.assertValidationError(
                self.dispatch("source_data.create", {"file_hash": bad_single}),
                expected_type="InvalidValue",
                expected_message_content=single_msg,
            )
            self.assertValidationError(
                self.dispatch("source_data.create", {"file_hash": file_hash, "source_type": bad_single}),
                expected_type="InvalidValue",
                expected_message_content=single_msg,
            )
            self.assertValidationError(
                self.dispatch("source_data.create", {"file_hash": file_hash, "original_path": bad_single}),
                expected_type="InvalidValue",
                expected_message_content=single_msg,
            )

        # Multiline note allows \n, \t, \r, and ""
        valid_note = "EAC Log:\n\tTrack 1\r\nCRCs matched"
        res_ok = self.dispatch(
            "source_data.create",
            {"file_hash": file_hash, "source_type": "", "original_path": "", "note": valid_note},
        )
        self.assertResponseCode(res_ok, 201)
        self.assertEqual(res_ok["data"]["note"], valid_note)

        # Disallowed control chars in note rejected
        for bad_multi in ("note\x1b[31m", "note\x0bline", "note\x00nul", "note\u0085nel"):
            self.assertValidationError(
                self.dispatch("source_data.create", {"file_hash": file_hash, "note": bad_multi}),
                expected_type="InvalidValue",
                expected_message_content=multi_msg,
            )

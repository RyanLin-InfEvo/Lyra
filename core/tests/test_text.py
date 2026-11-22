# SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
#
# SPDX-License-Identifier: AGPL-3.0-or-later

import hashlib
import os
import subprocess
import tempfile
import uuid
from base_test_case import BaseLyraTestCase


class TestTextDomain(BaseLyraTestCase):

    def _create_track(self, title="Lyrics Test Track") -> str:
        pcm_hash = uuid.uuid4().hex + uuid.uuid4().hex
        res = self.dispatch("CreateTrack", {"pcm_hash": pcm_hash, "title": title})
        self.assertResponseCode(res, 201)
        return res["data"]["id"]

    def _create_album(self, title="Lyrics Test Album") -> str:
        res = self.dispatch("CreateAlbum", {"title": title})
        self.assertResponseCode(res, 201)
        return res["data"]["id"]

    @staticmethod
    def _create_audio_with_tags(out_path: str, tags: dict, codec_args=None, stream_tags: bool = False):
        wav_path = out_path + ".src.wav"
        subprocess.run(
            ["ffmpeg", "-y", "-f", "lavfi", "-i", "sine=frequency=440:duration=0.4", wav_path],
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        cmd = ["ffmpeg", "-y", "-i", wav_path]
        if codec_args:
            cmd.extend(codec_args)
        meta_flag = "-metadata:s:a:0" if stream_tags else "-metadata"
        for k, v in tags.items():
            cmd.extend([meta_flag, f"{k}={v}"])
        cmd.append(out_path)
        subprocess.run(cmd, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        if os.path.exists(wav_path):
            os.remove(wav_path)

    @staticmethod
    def _create_mp3_with_uslt(out_path: str, uslt_frames):
        wav_path = out_path + ".src.wav"
        raw_mp3_path = out_path + ".raw.mp3"
        subprocess.run(
            ["ffmpeg", "-y", "-f", "lavfi", "-i", "sine=frequency=440:duration=0.4", wav_path],
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        subprocess.run(
            ["ffmpeg", "-y", "-i", wav_path, "-c:a", "libmp3lame", "-id3v2_version", "0", raw_mp3_path],
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        with open(raw_mp3_path, "rb") as f:
            mp3_bytes = f.read()
        if os.path.exists(wav_path):
            os.remove(wav_path)
        if os.path.exists(raw_mp3_path):
            os.remove(raw_mp3_path)

        if len(mp3_bytes) >= 10 and mp3_bytes[:3] == b"ID3":
            existing_size = (
                ((mp3_bytes[6] & 0x7F) << 21)
                | ((mp3_bytes[7] & 0x7F) << 14)
                | ((mp3_bytes[8] & 0x7F) << 7)
                | (mp3_bytes[9] & 0x7F)
            )
            mp3_bytes = mp3_bytes[10 + existing_size :]

        def _synchsafe(n: int) -> bytes:
            return bytes([(n >> 21) & 0x7F, (n >> 14) & 0x7F, (n >> 7) & 0x7F, n & 0x7F])

        frames_buf = bytearray()
        for lang, desc, text in uslt_frames:
            lang_bytes = lang.encode("ascii") if isinstance(lang, str) else bytes(lang)
            assert len(lang_bytes) == 3
            payload = b"\x03" + lang_bytes + desc.encode("utf-8") + b"\x00" + text.encode("utf-8")
            frames_buf.extend(b"USLT")
            frames_buf.extend(_synchsafe(len(payload)))
            frames_buf.extend(b"\x00\x00")
            frames_buf.extend(payload)

        header = b"ID3\x04\x00\x00" + _synchsafe(len(frames_buf))
        with open(out_path, "wb") as f:
            f.write(header)
            f.write(frames_buf)
            f.write(mp3_bytes)

    def test_text_save_get_dedup_and_attach_mode(self):
        track_id = self._create_track("Chinese LRC Track")
        album_id = self._create_album("Shared Liner Album")

        crlf_lrc = "[00:01.00]夜空中最亮的星\r\n[00:06.25]能否聽清 🎵\r\n"
        lf_lrc = "[00:01.00]夜空中最亮的星\n[00:06.25]能否聽清 🎵\n"
        expected_file_hash = hashlib.sha256(lf_lrc.encode("utf-8")).hexdigest()

        # 1. Save UTF-8 Chinese LRC (CRLF normalized to LF)
        res_save = self.dispatch(
            "text.save",
            {
                "entity_id": track_id,
                "role": "lyrics",
                "format": "lrc",
                "language": "zh-TW",
                "content": crlf_lrc,
            },
        )
        self.assertResponseCode(res_save, 201)
        d1 = res_save["data"]
        self.assertEqual(d1["file_hash"], expected_file_hash)
        self.assertEqual(d1["format"], "lrc")
        self.assertEqual(d1["language"], "zh-TW")
        self.assertEqual(d1["encoding"], "utf-8")
        self.assertEqual(d1["role"], "lyrics")
        self.assertEqual(d1["existing_same_slot_count"], 0)

        # 2. Retrieve by entity_id (single match -> 200)
        res_get = self.dispatch("text.get", {"entity_id": track_id})
        self.assertResponseCode(res_get, 200)
        self.assertEqual(res_get["data"]["text_hash"], d1["text_hash"])
        self.assertEqual(res_get["data"]["content"], lf_lrc)
        self.assertEqual(res_get["data"]["role"], "lyrics")

        # 3. Save identical bytes with format='txt' and different language -> same file_hash, single physical CAS file
        res_save_txt = self.dispatch(
            "text.save",
            {
                "entity_id": track_id,
                "role": "lyrics_translation",
                "format": "txt",
                "language": "en",
                "content": lf_lrc,
            },
        )
        self.assertResponseCode(res_save_txt, 201)
        d2 = res_save_txt["data"]
        self.assertEqual(d2["file_hash"], expected_file_hash)
        self.assertNotEqual(d2["text_hash"], d1["text_hash"])
        self.assertEqual(d2["existing_same_slot_count"], 0)

        cas_dir = os.path.join(self.test_db_dir, "objects", expected_file_hash[:2], expected_file_hash[2:4])
        matching_files = [f for f in os.listdir(cas_dir) if f.startswith(expected_file_hash)]
        self.assertEqual(len(matching_files), 1, f"Expected 1 CAS file, got {matching_files}")

        # 4. Attach existing text_hash onto an Album (role='liner_notes') without duplicating CAS file
        res_attach = self.dispatch(
            "text.save",
            {
                "entity_id": album_id,
                "role": "liner_notes",
                "text_hash": d2["text_hash"],
            },
        )
        self.assertResponseCode(res_attach, 201)
        self.assertEqual(res_attach["data"]["text_hash"], d2["text_hash"])
        self.assertEqual(res_attach["data"]["role"], "liner_notes")
        self.assertEqual(res_attach["data"]["format"], "txt")
        self.assertEqual(res_attach["data"]["language"], "en")

        res_get_album = self.dispatch("text.get", {"entity_id": album_id})
        self.assertResponseCode(res_get_album, 200)
        self.assertEqual(res_get_album["data"]["content"], lf_lrc)
        self.assertEqual(res_get_album["data"]["role"], "liner_notes")

        # 5. Direct fetch by text_hash -> role is None (JSON null)
        res_by_hash = self.dispatch("text.get", {"text_hash": d1["text_hash"]})
        self.assertResponseCode(res_by_hash, 200)
        self.assertIsNone(res_by_hash["data"]["role"])
        self.assertEqual(res_by_hash["data"]["content"], lf_lrc)

        # 6. Support srt and ttml formats
        res_srt = self.dispatch(
            "text.save",
            {
                "entity_id": album_id,
                "role": "description",
                "format": "srt",
                "content": "1\n00:00:01,000 --> 00:00:03,000\nSubtitle line",
            },
        )
        self.assertResponseCode(res_srt, 201)
        self.assertEqual(res_srt["data"]["format"], "srt")

        res_ttml = self.dispatch(
            "text.save",
            {
                "entity_id": album_id,
                "role": "credits",
                "format": "ttml",
                "content": "<tt><body><p>Credits</p></body></tt>",
            },
        )
        self.assertResponseCode(res_ttml, 201)
        self.assertEqual(res_ttml["data"]["format"], "ttml")

    def test_duplicate_slot_conflict_listing_and_unlink(self):
        track_id = self._create_track("Multi Version Lyrics Track")

        # First zh-TW lyrics -> count = 0
        s1 = self.dispatch(
            "text.save",
            {
                "entity_id": track_id,
                "role": "lyrics",
                "format": "lrc",
                "language": "zh-TW",
                "content": "[00:01.00]版本一",
            },
        )
        self.assertResponseCode(s1, 201)
        self.assertEqual(s1["data"]["existing_same_slot_count"], 0)
        h1 = s1["data"]["text_hash"]

        # Second zh-TW lyrics -> preserved old, count = 1
        s2 = self.dispatch(
            "text.save",
            {
                "entity_id": track_id,
                "role": "lyrics",
                "format": "lrc",
                "language": "zh-TW",
                "content": "[00:01.00]版本二",
            },
        )
        self.assertResponseCode(s2, 201)
        self.assertEqual(s2["data"]["existing_same_slot_count"], 1)
        h2 = s2["data"]["text_hash"]

        # Third zh-TW lyrics -> count = 2
        s3 = self.dispatch(
            "text.save",
            {
                "entity_id": track_id,
                "role": "lyrics",
                "format": "lrc",
                "language": "zh-TW",
                "content": "[00:01.00]版本三",
            },
        )
        self.assertResponseCode(s3, 201)
        self.assertEqual(s3["data"]["existing_same_slot_count"], 2)
        h3 = s3["data"]["text_hash"]

        # Ambiguous text.get({entity_id}) -> 409 Conflict
        res_conflict = self.dispatch("text.get", {"entity_id": track_id})
        self.assertResponseCode(res_conflict, 409)
        self.assertEqual(res_conflict["error"]["type"], "Conflict")

        # Still ambiguous even with role & language -> 409 Conflict
        res_conflict2 = self.dispatch(
            "text.get", {"entity_id": track_id, "role": "lyrics", "language": "zh-TW"}
        )
        self.assertResponseCode(res_conflict2, 409)
        self.assertEqual(res_conflict2["error"]["type"], "Conflict")

        # Add an English translation to verify filtering in text.get_entity_texts
        s_en = self.dispatch(
            "text.save",
            {
                "entity_id": track_id,
                "role": "lyrics_translation",
                "format": "txt",
                "language": "en",
                "content": "English translation",
            },
        )
        self.assertResponseCode(s_en, 201)
        h_en = s_en["data"]["text_hash"]

        # Narrowing to lyrics_translation returns 200
        res_en = self.dispatch(
            "text.get", {"entity_id": track_id, "role": "lyrics_translation"}
        )
        self.assertResponseCode(res_en, 200)
        self.assertEqual(res_en["data"]["content"], "English translation")

        # text.get_entity_texts returns metadata only (no 'content')
        list_all = self.dispatch("text.get_entity_texts", {"entity_id": track_id})
        self.assertResponseCode(list_all, 200)
        self.assertEqual(len(list_all["data"]), 4)
        for item in list_all["data"]:
            self.assertNotIn("content", item)

        list_zh = self.dispatch(
            "text.get_entity_texts",
            {"entity_id": track_id, "role": "lyrics", "language": "zh-TW"},
        )
        self.assertResponseCode(list_zh, 200)
        self.assertEqual({x["text_hash"] for x in list_zh["data"]}, {h1, h2, h3})

        # Unlink h1 and h2 -> only h3 remains under role='lyrics'
        u1 = self.dispatch("text.unlink", {"entity_id": track_id, "text_hash": h1})
        self.assertResponseCode(u1, 200)
        u2 = self.dispatch("text.unlink", {"entity_id": track_id, "text_hash": h2})
        self.assertResponseCode(u2, 200)

        # Unlinking again returns 404 RelationNotFound
        u2_again = self.dispatch("text.unlink", {"entity_id": track_id, "text_hash": h2})
        self.assertResponseCode(u2_again, 404)
        self.assertEqual(u2_again["error"]["type"], "RelationNotFound")

        # Now text.get with role='lyrics' succeeds uniquely
        res_unique = self.dispatch("text.get", {"entity_id": track_id, "role": "lyrics"})
        self.assertResponseCode(res_unique, 200)
        self.assertEqual(res_unique["data"]["text_hash"], h3)
        self.assertEqual(res_unique["data"]["content"], "[00:01.00]版本三")

        # Cleanup translation too -> no lyrics left -> 404 NotFound
        self.assertResponseCode(
            self.dispatch("text.unlink", {"entity_id": track_id, "text_hash": h_en}), 200
        )
        self.assertResponseCode(
            self.dispatch("text.unlink", {"entity_id": track_id, "text_hash": h3}), 200
        )
        res_empty = self.dispatch("text.get", {"entity_id": track_id})
        self.assertResponseCode(res_empty, 404)
        self.assertEqual(res_empty["error"]["type"], "NotFound")

    def test_validation_and_error_boundary_fuzzing(self):
        track_id = self._create_track("Validation Track")
        saved = self.dispatch(
            "text.save",
            {
                "entity_id": track_id,
                "role": "lyrics",
                "format": "txt",
                "content": "Valid line",
            },
        )
        self.assertResponseCode(saved, 201)
        valid_hash = saved["data"]["text_hash"]

        missing_uuid = str(uuid.uuid4())
        missing_hash = "0" * 64

        # Non-object params
        for cmd in ["text.save", "text.get", "text.get_entity_texts", "text.unlink"]:
            self.assertValidationError(self.dispatch(cmd, []), expected_type="InvalidCommandFormat")

        # text.save errors
        self.assertValidationError(
            self.dispatch("text.save", {"role": "lyrics", "format": "txt", "content": "x"}),
            expected_type="MissingParameter",
        )
        self.assertValidationError(
            self.dispatch("text.save", {"entity_id": "not-a-uuid", "role": "lyrics", "format": "txt", "content": "x"}),
            expected_type="InvalidValue",
        )
        self.assertValidationError(
            self.dispatch("text.save", {"entity_id": track_id, "role": "invalid_role", "format": "txt", "content": "x"}),
            expected_type="InvalidValue",
        )
        # XOR neither & both
        self.assertValidationError(
            self.dispatch("text.save", {"entity_id": track_id, "role": "lyrics"}),
            expected_type="MissingParameter",
        )
        self.assertValidationError(
            self.dispatch(
                "text.save",
                {
                    "entity_id": track_id,
                    "role": "lyrics",
                    "content": "hello",
                    "text_hash": valid_hash,
                    "format": "txt",
                },
            ),
            expected_type="InvalidValue",
        )
        # Missing or invalid format in content mode
        self.assertValidationError(
            self.dispatch("text.save", {"entity_id": track_id, "role": "lyrics", "content": "hello"}),
            expected_type="MissingParameter",
        )
        self.assertValidationError(
            self.dispatch("text.save", {"entity_id": track_id, "role": "lyrics", "format": "pdf", "content": "hello"}),
            expected_type="InvalidValue",
        )
        # Blank or empty content
        self.assertValidationError(
            self.dispatch("text.save", {"entity_id": track_id, "role": "lyrics", "format": "txt", "content": ""}),
            expected_type="InvalidValue",
        )
        self.assertValidationError(
            self.dispatch("text.save", {"entity_id": track_id, "role": "lyrics", "format": "txt", "content": " \r\n\t "}),
            expected_type="InvalidValue",
        )
        # Oversized content (> 2 MiB)
        oversized = "a" * (2 * 1024 * 1024 + 1)
        self.assertValidationError(
            self.dispatch("text.save", {"entity_id": track_id, "role": "lyrics", "format": "txt", "content": oversized}),
            expected_type="OutOfRange",
        )
        # Attach mode rejecting format or language
        self.assertValidationError(
            self.dispatch(
                "text.save",
                {"entity_id": track_id, "role": "lyrics", "text_hash": valid_hash, "format": "txt"},
            ),
            expected_type="InvalidValue",
        )
        self.assertValidationError(
            self.dispatch(
                "text.save",
                {"entity_id": track_id, "role": "lyrics", "text_hash": valid_hash, "language": "en"},
            ),
            expected_type="InvalidValue",
        )
        self.assertValidationError(
            self.dispatch("text.save", {"entity_id": track_id, "role": "lyrics", "text_hash": "   "}),
            expected_type="InvalidValue",
        )
        # Nonexistent entity / text_hash -> 404 NotFound
        res_no_ent = self.dispatch(
            "text.save",
            {"entity_id": missing_uuid, "role": "lyrics", "format": "txt", "content": "hi"},
        )
        self.assertResponseCode(res_no_ent, 404)
        self.assertEqual(res_no_ent["error"]["type"], "NotFound")

        res_no_hash = self.dispatch(
            "text.save",
            {"entity_id": track_id, "role": "lyrics", "text_hash": missing_hash},
        )
        self.assertResponseCode(res_no_hash, 404)
        self.assertEqual(res_no_hash["error"]["type"], "NotFound")

        # text.get validation errors
        self.assertValidationError(self.dispatch("text.get", {}), expected_type="MissingParameter")
        self.assertValidationError(
            self.dispatch("text.get", {"entity_id": track_id, "text_hash": valid_hash}),
            expected_type="InvalidValue",
        )
        self.assertValidationError(
            self.dispatch("text.get", {"text_hash": valid_hash, "role": "lyrics"}),
            expected_type="InvalidValue",
        )
        self.assertValidationError(
            self.dispatch("text.get", {"text_hash": valid_hash, "language": "en"}),
            expected_type="InvalidValue",
        )
        self.assertValidationError(
            self.dispatch("text.get", {"entity_id": track_id, "role": "bad_role"}),
            expected_type="InvalidValue",
        )
        self.assertValidationError(
            self.dispatch("text.get", {"entity_id": track_id, "language": "   "}),
            expected_type="InvalidValue",
        )
        res_get_no_ent = self.dispatch("text.get", {"entity_id": missing_uuid})
        self.assertResponseCode(res_get_no_ent, 404)
        self.assertEqual(res_get_no_ent["error"]["type"], "NotFound")

        res_get_no_hash = self.dispatch("text.get", {"text_hash": missing_hash})
        self.assertResponseCode(res_get_no_hash, 404)
        self.assertEqual(res_get_no_hash["error"]["type"], "NotFound")

        # text.get_entity_texts & text.unlink missing entity / invalid inputs
        res_list_no_ent = self.dispatch("text.get_entity_texts", {"entity_id": missing_uuid})
        self.assertResponseCode(res_list_no_ent, 404)
        self.assertEqual(res_list_no_ent["error"]["type"], "NotFound")

        self.assertValidationError(
            self.dispatch("text.get_entity_texts", {"entity_id": track_id, "role": "bad_role"}),
            expected_type="InvalidValue",
        )
        self.assertValidationError(
            self.dispatch("text.unlink", {"entity_id": track_id, "text_hash": "  "}),
            expected_type="InvalidValue",
        )
        res_unlink_no_ent = self.dispatch("text.unlink", {"entity_id": missing_uuid, "text_hash": valid_hash})
        self.assertResponseCode(res_unlink_no_ent, 404)
        self.assertEqual(res_unlink_no_ent["error"]["type"], "NotFound")

    def test_import_track_embedded_lyrics_and_no_sidecar_scan(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            # 1. FLAC with embedded LRC lyrics -> imported by default, undoable via text.unlink
            flac_path = os.path.join(tmpdir, "embedded_lrc.flac")
            lrc_body = "[00:02.00]晴天\n[00:05.50]微風吹過 🌿"
            self._create_audio_with_tags(flac_path, {"title": "Sunny", "lyrics": lrc_body})

            imp_flac = self.dispatch("ImportTrack", {"source_path": flac_path})
            self.assertResponseCode(imp_flac, 200)
            track_id_flac = imp_flac["data"]["track_id"]
            imported_texts = imp_flac["data"]["imported_texts"]
            self.assertEqual(len(imported_texts), 1)
            self.assertEqual(imported_texts[0]["format"], "lrc")
            self.assertEqual(imported_texts[0]["role"], "lyrics")

            got_lrc = self.dispatch("text.get", {"entity_id": track_id_flac, "role": "lyrics"})
            self.assertResponseCode(got_lrc, 200)
            self.assertEqual(got_lrc["data"]["content"], lrc_body)

            # UI undo workflow
            unlink_res = self.dispatch(
                "text.unlink",
                {"entity_id": track_id_flac, "text_hash": imported_texts[0]["text_hash"]},
            )
            self.assertResponseCode(unlink_res, 200)
            res_after_unlink = self.dispatch("text.get", {"entity_id": track_id_flac})
            self.assertResponseCode(res_after_unlink, 404)
            self.assertEqual(res_after_unlink["error"]["type"], "NotFound")

            # 2. MP3 with ID3v2 USLT (lyrics-eng + lyrics-jpn) -> both extracted with language codes
            mp3_path = os.path.join(tmpdir, "multi_lang.mp3")
            self._create_audio_with_tags(
                mp3_path,
                {
                    "title": "Bilingual Song",
                    "lyrics-eng": "Hello world",
                    "lyrics-jpn": "[00:01.00]こんにちは",
                },
                codec_args=["-c:a", "libmp3lame", "-id3v2_version", "3"],
            )
            imp_mp3 = self.dispatch("ImportTrack", {"source_path": mp3_path})
            self.assertResponseCode(imp_mp3, 200)
            track_id_mp3 = imp_mp3["data"]["track_id"]
            self.assertEqual(len(imp_mp3["data"]["imported_texts"]), 2)
            by_lang = {item["language"]: item for item in imp_mp3["data"]["imported_texts"]}
            self.assertEqual(by_lang["eng"]["format"], "txt")
            self.assertEqual(by_lang["jpn"]["format"], "lrc")

            # Verify text.get ambiguity & language disambiguation
            res_ambiguous = self.dispatch("text.get", {"entity_id": track_id_mp3})
            self.assertResponseCode(res_ambiguous, 409)
            self.assertEqual(res_ambiguous["error"]["type"], "Conflict")
            got_jpn = self.dispatch("text.get", {"entity_id": track_id_mp3, "language": "jpn"})
            self.assertResponseCode(got_jpn, 200)
            self.assertEqual(got_jpn["data"]["content"], "[00:01.00]こんにちは")

            # 2b. MP3 with real binary ID3v2.4 USLT frames (FFmpeg lyrics-<desc>-<lang> & NUL lang)
            uslt_mp3_path = os.path.join(tmpdir, "uslt_real.mp3")
            self._create_mp3_with_uslt(
                uslt_mp3_path,
                [
                    ("eng", "Live Version", "English live verse"),
                    ("jpn", "TV", "[00:01.00]日本語"),
                    (b"\x00\x00\x00", "", "NUL untagged lyrics"),
                    ("und", "Main", "Undetermined main lyrics"),
                ],
            )
            imp_uslt = self.dispatch("ImportTrack", {"source_path": uslt_mp3_path})
            self.assertResponseCode(imp_uslt, 200)
            track_id_uslt = imp_uslt["data"]["track_id"]
            self.assertEqual(len(imp_uslt["data"]["imported_texts"]), 4)
            got_uslt_jpn = self.dispatch("text.get", {"entity_id": track_id_uslt, "language": "jpn"})
            self.assertResponseCode(got_uslt_jpn, 200)
            self.assertEqual(got_uslt_jpn["data"]["content"], "[00:01.00]日本語")
            self.assertEqual(got_uslt_jpn["data"]["format"], "lrc")
            got_uslt_eng = self.dispatch("text.get", {"entity_id": track_id_uslt, "language": "eng"})
            self.assertResponseCode(got_uslt_eng, 200)
            self.assertEqual(got_uslt_eng["data"]["content"], "English live verse")
            self.assertEqual(got_uslt_eng["data"]["format"], "txt")
            untagged_uslt = self.dispatch("text.get_entity_texts", {"entity_id": track_id_uslt, "language": ""})
            self.assertResponseCode(untagged_uslt, 200)
            self.assertEqual(len(untagged_uslt["data"]), 2)

            # 3. import_embedded_lyrics = False skips extraction cleanly
            imp_skip = self.dispatch(
                "ImportTrack", {"source_path": flac_path, "import_embedded_lyrics": False}
            )
            self.assertResponseCode(imp_skip, 200)
            self.assertEqual(imp_skip["data"]["imported_texts"], [])
            texts_skip = self.dispatch(
                "text.get_entity_texts", {"entity_id": imp_skip["data"]["track_id"]}
            )
            self.assertResponseCode(texts_skip, 200)
            self.assertEqual(texts_skip["data"], [])

            # 4. Track with NO embedded lyrics and a sibling .lrc file -> Track imports cleanly, sidecar NOT auto-imported
            no_lyrics_flac = os.path.join(tmpdir, "no_embedded.flac")
            sibling_lrc = os.path.join(tmpdir, "no_embedded.lrc")
            self._create_audio_with_tags(no_lyrics_flac, {"title": "Instrumental"})
            with open(sibling_lrc, "w", encoding="utf-8") as f:
                f.write("[00:01.00]Sidecar should NOT be auto-imported by Core")

            imp_no_lyr = self.dispatch("ImportTrack", {"source_path": no_lyrics_flac})
            self.assertResponseCode(imp_no_lyr, 200)
            self.assertEqual(imp_no_lyr["data"]["imported_texts"], [])
            texts_no_lyr = self.dispatch(
                "text.get_entity_texts", {"entity_id": imp_no_lyr["data"]["track_id"]}
            )
            self.assertResponseCode(texts_no_lyr, 200)
            self.assertEqual(texts_no_lyr["data"], [])

            # 5. Invalid type for import_embedded_lyrics -> 400 InvalidValue
            self.assertValidationError(
                self.dispatch(
                    "ImportTrack",
                    {"source_path": flac_path, "import_embedded_lyrics": "yes"},
                ),
                expected_type="InvalidValue",
            )

            # 6. [MED-2] FLAC with non-lyric metadata (including false-positive regions/ISO-639-2 words/trailing dash) -> NOT imported
            meta_only_flac = os.path.join(tmpdir, "non_lyric_tags.flac")
            self._create_audio_with_tags(
                meta_only_flac,
                {
                    "title": "Meta Only",
                    "lyrics-author": "Bob Dylan",
                    "lyrics-url": "https://example.com",
                    "lyrics-web-link": "https://example.com/web",
                    "lyrics-sub-title": "Subtitle",
                    "lyrics-alt-source": "Mirror",
                    "lyrics-raw-data": "RawData",
                    "lyrics-foo-bar": "FooBar",
                    "lyrics-no-go": "NoGo",
                    "lyrics-en-ok": "EnOk",
                    "lyrics-id-000": "IdZero",
                    "lyrics-source-alt": "https://mirror.example.com",
                    "lyrics-cover-art": "ArtCredit",
                    "lyrics-author-": "TrailingDash",
                    "lyrics-": "EmptyDash",
                },
            )
            imp_meta_only = self.dispatch("ImportTrack", {"source_path": meta_only_flac})
            self.assertResponseCode(imp_meta_only, 200)
            self.assertEqual(imp_meta_only["data"]["imported_texts"], [])

            # 6b. Ogg Vorbis exercising streams[*].tags end-to-end (valid BCP-47 extlang accepted; false positives ignored)
            ogg_path = os.path.join(tmpdir, "stream_tags.ogg")
            self._create_audio_with_tags(
                ogg_path,
                {
                    "title": "Ogg Stream Lyrics",
                    "lyrics-en": "Stream Eng",
                    "lyrics-zh-cmn-hant-tw": "Stream 中文",
                    "lyrics-source-alt": "Ignored",
                    "lyrics-no-go": "Ignored",
                },
                codec_args=["-c:a", "libvorbis"],
                stream_tags=True,
            )
            imp_ogg = self.dispatch("ImportTrack", {"source_path": ogg_path})
            self.assertResponseCode(imp_ogg, 200)
            self.assertEqual(len(imp_ogg["data"]["imported_texts"]), 2)
            ogg_langs = {x["language"] for x in imp_ogg["data"]["imported_texts"]}
            self.assertEqual(ogg_langs, {"en", "zh-cmn-Hant-TW"})

            # 7. FLAC with one malformed embedded lyric (C1 mojibake U+0092) + one valid lyric ->
            #    Track still imports (200), malformed lyric skipped cleanly, valid lyric imported
            mixed_ctrl_flac = os.path.join(tmpdir, "mixed_ctrl_lyrics.flac")
            self._create_audio_with_tags(
                mixed_ctrl_flac,
                {
                    "title": "Mixed Control Lyrics",
                    "lyrics-en": "don\u0092t stop",
                    "lyrics-ja": "[00:01.00]Valid",
                },
            )
            imp_mixed = self.dispatch("ImportTrack", {"source_path": mixed_ctrl_flac})
            self.assertResponseCode(imp_mixed, 200)
            self.assertEqual(len(imp_mixed["data"]["imported_texts"]), 1)
            self.assertEqual(imp_mixed["data"]["imported_texts"][0]["language"], "ja")

    def test_audit_regression_cases(self):
        track_id = self._create_track("Audit Regression Track")
        missing_uuid = str(uuid.uuid4())

        # [HIGH-2] language validation: embedded NUL, oversized > 64, non-string
        self.assertValidationError(
            self.dispatch(
                "text.save",
                {
                    "entity_id": track_id,
                    "role": "lyrics",
                    "format": "txt",
                    "content": "hello",
                    "language": "en\u0000bad",
                },
            ),
            expected_type="InvalidValue",
        )
        self.assertValidationError(
            self.dispatch(
                "text.save",
                {
                    "entity_id": track_id,
                    "role": "lyrics",
                    "format": "txt",
                    "content": "hello",
                    "language": "a" * 65,
                },
            ),
            expected_type="InvalidValue",
        )
        self.assertValidationError(
            self.dispatch(
                "text.save",
                {
                    "entity_id": track_id,
                    "role": "lyrics",
                    "format": "txt",
                    "content": "hello",
                    "language": 123,
                },
            ),
            expected_type="InvalidValue",
        )
        # [LOW-1] whitespace-only language rejected uniformly across text.save & text.get
        self.assertValidationError(
            self.dispatch(
                "text.save",
                {
                    "entity_id": track_id,
                    "role": "lyrics",
                    "format": "txt",
                    "content": "hello",
                    "language": "   ",
                },
            ),
            expected_type="InvalidValue",
        )
        # C1 control characters in language rejected across text.save, text.get, text.get_entity_texts
        for bad_lang in ("zh\u0080-TW", "en\u009f"):
            self.assertValidationError(
                self.dispatch(
                    "text.save",
                    {
                        "entity_id": track_id,
                        "role": "lyrics",
                        "format": "txt",
                        "content": "hello",
                        "language": bad_lang,
                    },
                ),
                expected_type="InvalidValue",
            )
            self.assertValidationError(
                self.dispatch(
                    "text.get",
                    {"entity_id": track_id, "language": bad_lang},
                ),
                expected_type="InvalidValue",
            )
            self.assertValidationError(
                self.dispatch(
                    "text.get_entity_texts",
                    {"entity_id": track_id, "language": bad_lang},
                ),
                expected_type="InvalidValue",
            )

        # Disallowed C0/C1 control characters in content rejected by text.save
        for bad_content in (
            "line1\x0bline2",
            "line1\x0cline2",
            "line1\x1b[31mred",
            "end\x7f",
            "don\u0092t stop",
            "nel\u0085line",
        ):
            self.assertValidationError(
                self.dispatch(
                    "text.save",
                    {
                        "entity_id": track_id,
                        "role": "lyrics",
                        "format": "txt",
                        "content": bad_content,
                    },
                ),
                expected_type="InvalidValue",
            )

        # Valid multiline content with tab, CRLF, U+00A0, and ZWJ emoji accepted
        res_valid_multiline = self.dispatch(
            "text.save",
            {
                "entity_id": track_id,
                "role": "lyrics",
                "format": "txt",
                "language": "en",
                "content": "hello\tworld\r\n\u00a0👨‍👩‍👧‍👦",
            },
        )
        self.assertResponseCode(res_valid_multiline, 201)

        # Empty string and null language still normalize cleanly to ""
        res_empty_lang = self.dispatch(
            "text.save",
            {
                "entity_id": track_id,
                "role": "description",
                "format": "txt",
                "content": "empty lang desc",
                "language": "",
            },
        )
        self.assertResponseCode(res_empty_lang, 201)
        self.assertEqual(res_empty_lang["data"]["language"], "")
        res_null_lang = self.dispatch(
            "text.save",
            {
                "entity_id": track_id,
                "role": "review",
                "format": "txt",
                "content": "null lang review",
                "language": None,
            },
        )
        self.assertResponseCode(res_null_lang, 201)
        self.assertEqual(res_null_lang["data"]["language"], "")

        # [MED-4] Fail-fast validation before DB lookup (nonexistent entity + blank content -> 400 InvalidValue)
        self.assertValidationError(
            self.dispatch(
                "text.save",
                {
                    "entity_id": missing_uuid,
                    "role": "lyrics",
                    "format": "txt",
                    "content": "   ",
                },
            ),
            expected_type="InvalidValue",
        )

        # [MED-6] Tag entity cannot accept text attachments / queries / unlinks -> 404 NotFound
        tag_res = self.dispatch("tag.create", {"name": f"Tag_{uuid.uuid4().hex[:6]}"})
        self.assertResponseCode(tag_res, 201)
        tag_id = tag_res["data"]["id"]
        res_tag_attach = self.dispatch(
            "text.save",
            {
                "entity_id": tag_id,
                "role": "lyrics",
                "format": "txt",
                "content": "should fail on tag entity",
            },
        )
        self.assertResponseCode(res_tag_attach, 404)
        self.assertEqual(res_tag_attach["error"]["type"], "NotFound")

        res_tag_get = self.dispatch("text.get", {"entity_id": tag_id})
        self.assertResponseCode(res_tag_get, 404)
        self.assertEqual(res_tag_get["error"]["type"], "NotFound")

        res_tag_list = self.dispatch("text.get_entity_texts", {"entity_id": tag_id})
        self.assertResponseCode(res_tag_list, 404)
        self.assertEqual(res_tag_list["error"]["type"], "NotFound")

        # [HIGH-3] Untagged language ("") filtering and disambiguation
        s_untagged = self.dispatch(
            "text.save",
            {"entity_id": track_id, "role": "lyrics", "format": "txt", "content": "Untagged version"},
        )
        self.assertResponseCode(s_untagged, 201)
        s_en = self.dispatch(
            "text.save",
            {
                "entity_id": track_id,
                "role": "lyrics",
                "format": "txt",
                "language": "en",
                "content": "English version",
            },
        )
        self.assertResponseCode(s_en, 201)

        res_tag_unlink = self.dispatch(
            "text.unlink",
            {"entity_id": tag_id, "text_hash": s_en["data"]["text_hash"]},
        )
        self.assertResponseCode(res_tag_unlink, 404)
        self.assertEqual(res_tag_unlink["error"]["type"], "NotFound")

        # Non-string language and text_hash + empty language -> 400 InvalidValue
        self.assertValidationError(
            self.dispatch("text.get", {"entity_id": track_id, "language": 123}),
            expected_type="InvalidValue",
        )
        self.assertValidationError(
            self.dispatch("text.get_entity_texts", {"entity_id": track_id, "language": 123}),
            expected_type="InvalidValue",
        )
        self.assertValidationError(
            self.dispatch("text.get", {"text_hash": s_en["data"]["text_hash"], "language": ""}),
            expected_type="InvalidValue",
        )

        list_untagged = self.dispatch(
            "text.get_entity_texts",
            {"entity_id": track_id, "role": "lyrics", "language": ""},
        )
        self.assertResponseCode(list_untagged, 200)
        self.assertEqual(len(list_untagged["data"]), 1)
        self.assertEqual(list_untagged["data"][0]["text_hash"], s_untagged["data"]["text_hash"])

        get_untagged = self.dispatch(
            "text.get",
            {"entity_id": track_id, "role": "lyrics", "language": ""},
        )
        self.assertResponseCode(get_untagged, 200)
        self.assertEqual(get_untagged["data"]["content"], "Untagged version")

        # [LOW-4] Role whitespace trimming asymmetry: " lyrics " rejected uniformly
        self.assertValidationError(
            self.dispatch("text.get", {"entity_id": track_id, "role": " lyrics "}),
            expected_type="InvalidValue",
        )
        self.assertValidationError(
            self.dispatch("text.get_entity_texts", {"entity_id": track_id, "role": " lyrics "}),
            expected_type="InvalidValue",
        )

        # [MED-7] text.get_entity_texts & text.unlink missing params / invalid UUID / blank language
        self.assertValidationError(
            self.dispatch("text.get_entity_texts", {}), expected_type="MissingParameter"
        )
        self.assertValidationError(
            self.dispatch("text.get_entity_texts", {"entity_id": track_id, "language": "   "}),
            expected_type="InvalidValue",
        )
        self.assertValidationError(
            self.dispatch("text.unlink", {"entity_id": "bad-uuid", "text_hash": s_en["data"]["text_hash"]}),
            expected_type="InvalidValue",
        )
        self.assertValidationError(
            self.dispatch("text.unlink", {"entity_id": track_id}), expected_type="MissingParameter"
        )

        # Reject C0/C1 control characters, NUL, and outer spaces in text_hash (fail-fast 400 InvalidValue before DB lookup, not 404)
        for bad_hash in (
            " " + s_en["data"]["text_hash"],
            s_en["data"]["text_hash"] + " ",
            "abc\x1b",
            "abc\u0080",
            "abc\n",
            "\tabc",
            "abc\r",
            "abc\u0000def",
        ):
            self.assertValidationError(
                self.dispatch("text.get", {"text_hash": bad_hash}),
                expected_type="InvalidValue",
            )
            self.assertValidationError(
                self.dispatch("text.unlink", {"entity_id": track_id, "text_hash": bad_hash}),
                expected_type="InvalidValue",
            )
            self.assertValidationError(
                self.dispatch(
                    "text.save",
                    {"entity_id": track_id, "role": "lyrics", "text_hash": bad_hash},
                ),
                expected_type="InvalidValue",
            )

        # Embedded NUL in content over FFI -> 400 InvalidValue
        self.assertValidationError(
            self.dispatch(
                "text.save",
                {"entity_id": track_id, "role": "lyrics", "format": "txt", "content": "line1\u0000line2"},
            ),
            expected_type="InvalidValue",
        )

        # C0 whitespace/DEL in language -> 400 InvalidValue
        for bad_lang in ("en\tUS", "en\nUS", "en\rUS", "en\x7fUS"):
            self.assertValidationError(
                self.dispatch(
                    "text.save",
                    {
                        "entity_id": track_id,
                        "role": "lyrics",
                        "format": "txt",
                        "content": "hello",
                        "language": bad_lang,
                    },
                ),
                expected_type="InvalidValue",
            )

        # Attach-mode text.save rejects "language": "" (400 InvalidValue) while allowing "language": None (201)
        self.assertValidationError(
            self.dispatch(
                "text.save",
                {
                    "entity_id": track_id,
                    "role": "other",
                    "text_hash": s_en["data"]["text_hash"],
                    "language": "",
                },
            ),
            expected_type="InvalidValue",
        )
        res_attach_null_lang = self.dispatch(
            "text.save",
            {
                "entity_id": track_id,
                "role": "other",
                "text_hash": s_en["data"]["text_hash"],
                "language": None,
            },
        )
        self.assertResponseCode(res_attach_null_lang, 201)
        self.assertEqual(res_attach_null_lang["data"]["role"], "other")

        # Re-attaching the same (entity_id, text_hash) with a new role updates role in place (no duplicate row)
        list_other = self.dispatch(
            "text.get_entity_texts",
            {"entity_id": track_id, "role": "other"},
        )
        self.assertResponseCode(list_other, 200)
        self.assertIn(s_en["data"]["text_hash"], [x["text_hash"] for x in list_other["data"]])

        list_lyrics_en = self.dispatch(
            "text.get_entity_texts",
            {"entity_id": track_id, "role": "lyrics", "language": "en"},
        )
        self.assertResponseCode(list_lyrics_en, 200)
        self.assertNotIn(s_en["data"]["text_hash"], [x["text_hash"] for x in list_lyrics_en["data"]])

        # Size-check precedence preserved at RPC layer even with control chars or invalid language
        self.assertValidationError(
            self.dispatch(
                "text.save",
                {
                    "entity_id": track_id,
                    "role": "lyrics",
                    "format": "txt",
                    "content": ("a" * (2 * 1024 * 1024)) + "\x1b",
                },
            ),
            expected_type="OutOfRange",
        )
        self.assertValidationError(
            self.dispatch(
                "text.save",
                {
                    "entity_id": track_id,
                    "role": "lyrics",
                    "format": "txt",
                    "content": ("a" * (2 * 1024 * 1024)) + "x",
                    "language": "en\x01",
                },
            ),
            expected_type="OutOfRange",
        )

        # [MED-7] Missing physical CAS blob -> 404 AssetNotFound
        fhash = s_en["data"]["file_hash"]
        cas_dir = os.path.join(self.test_db_dir, "objects", fhash[:2], fhash[2:4])
        for fname in os.listdir(cas_dir):
            if fname.startswith(fhash):
                os.remove(os.path.join(cas_dir, fname))
        res_missing_cas = self.dispatch("text.get", {"text_hash": s_en["data"]["text_hash"]})
        self.assertResponseCode(res_missing_cas, 404)
        self.assertEqual(res_missing_cas["error"]["type"], "AssetNotFound")

        # Untagged (language == "") second save reports existing_same_slot_count > 0
        s_untagged2 = self.dispatch(
            "text.save",
            {
                "entity_id": track_id,
                "role": "lyrics",
                "format": "txt",
                "language": "",
                "content": "Second untagged version",
            },
        )
        self.assertResponseCode(s_untagged2, 201)
        self.assertGreater(s_untagged2["data"]["existing_same_slot_count"], 0)

        # Outer-whitespace trimming symmetry on language across text.save / text.get / text.get_entity_texts
        s_trim_lang = self.dispatch(
            "text.save",
            {
                "entity_id": track_id,
                "role": "lyrics",
                "format": "txt",
                "language": " zh-TW ",
                "content": "繁體中文歌詞",
            },
        )
        self.assertResponseCode(s_trim_lang, 201)
        self.assertEqual(s_trim_lang["data"]["language"], "zh-TW")

        get_trim_lang = self.dispatch(
            "text.get",
            {"entity_id": track_id, "role": "lyrics", "language": " zh-TW "},
        )
        self.assertResponseCode(get_trim_lang, 200)
        self.assertEqual(get_trim_lang["data"]["language"], "zh-TW")
        self.assertEqual(get_trim_lang["data"]["text_hash"], s_trim_lang["data"]["text_hash"])

        list_trim_lang = self.dispatch(
            "text.get_entity_texts",
            {"entity_id": track_id, "role": "lyrics", "language": " zh-TW "},
        )
        self.assertResponseCode(list_trim_lang, 200)
        self.assertEqual(len(list_trim_lang["data"]), 1)
        self.assertEqual(list_trim_lang["data"][0]["text_hash"], s_trim_lang["data"]["text_hash"])

        # Corrupted CAS UTF-8 bytes on disk -> 400 OperationFailed on text.get over FFI
        s_corrupt = self.dispatch(
            "text.save",
            {
                "entity_id": track_id,
                "role": "liner_notes",
                "format": "txt",
                "language": "en",
                "content": "Valid UTF-8 before disk corruption",
            },
        )
        self.assertResponseCode(s_corrupt, 201)
        corrupt_fhash = s_corrupt["data"]["file_hash"]
        corrupt_cas_dir = os.path.join(self.test_db_dir, "objects", corrupt_fhash[:2], corrupt_fhash[2:4])
        for fname in os.listdir(corrupt_cas_dir):
            if fname.startswith(corrupt_fhash):
                fpath = os.path.join(corrupt_cas_dir, fname)
                os.chmod(fpath, 0o644)
                with open(fpath, "wb") as bf:
                    bf.write(b"\xff\xfe")
        res_corrupt = self.dispatch("text.get", {"text_hash": s_corrupt["data"]["text_hash"]})
        self.assertResponseCode(res_corrupt, 400)
        self.assertEqual(res_corrupt["error"]["type"], "OperationFailed")

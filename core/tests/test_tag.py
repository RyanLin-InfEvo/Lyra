# SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
#
# SPDX-License-Identifier: AGPL-3.0-or-later

import uuid
from base_test_case import BaseLyraTestCase


class TestTagController(BaseLyraTestCase):

    def test_tag_create_default_and_custom_categories(self):
        res_default = self.dispatch("tag.create", {"name": "Live Recording"})
        self.assertResponseCode(res_default, 201)
        self.assertEqual(res_default["data"]["name"], "Live Recording")
        self.assertEqual(res_default["data"]["category"], "general")
        self.assertTrue("id" in res_default["data"] and len(res_default["data"]["id"]) == 36)
        self.assertTrue("created_at" in res_default["data"] and res_default["data"]["created_at"] is not None)

        for cat in ["general", "mood", "era", "style", "quality", "genre"]:
            res = self.dispatch("tag.create", {"id": "", "name": f"Tag {cat}", "category": cat})
            self.assertResponseCode(res, 201)
            self.assertEqual(res["data"]["category"], cat)

    def test_tag_create_validation_errors(self):
        res_missing = self.dispatch("tag.create", {})
        self.assertValidationError(res_missing, expected_type="MissingParameter")

        res_null = self.dispatch("tag.create", {"name": None})
        self.assertValidationError(res_null, expected_type="MissingParameter")

        res_empty = self.dispatch("tag.create", {"name": ""})
        self.assertValidationError(res_empty, expected_type="InvalidValue")

        res_blank = self.dispatch("tag.create", {"name": "   "})
        self.assertValidationError(res_blank, expected_type="InvalidValue")

        res_bad_type = self.dispatch("tag.create", {"name": 123})
        self.assertValidationError(res_bad_type, expected_type="InvalidValue")

        res_bad_cat = self.dispatch("tag.create", {"name": "Jazz", "category": ""})
        self.assertValidationError(res_bad_cat, expected_type="InvalidValue")

    def test_tag_list_filters_and_pagination(self):
        prefix = f"Filter_{uuid.uuid4().hex[:8]}"
        self.dispatch("tag.create", {"name": f"{prefix}_Post-Bop", "category": "genre"})
        self.dispatch("tag.create", {"name": f"{prefix}_Cool Jazz", "category": "genre"})
        self.dispatch("tag.create", {"name": f"{prefix}_Melancholic", "category": "mood"})

        res_all = self.dispatch("tag.list", {"offset": 0, "limit": 2, "search": prefix})
        self.assertResponseCode(res_all, 200)
        self.assertEqual(res_all["data"]["total"], 3)
        self.assertEqual(len(res_all["data"]["items"]), 2)

        res_cat = self.dispatch("tag.list", {"search": prefix, "category": "genre"})
        self.assertResponseCode(res_cat, 200)
        self.assertEqual(res_cat["data"]["total"], 2)

        res_search = self.dispatch("tag.list", {"search": f"{prefix}_Cool", "category": "genre"})
        self.assertResponseCode(res_search, 200)
        self.assertEqual(res_search["data"]["total"], 1)
        self.assertEqual(res_search["data"]["items"][0]["name"], f"{prefix}_Cool Jazz")

        res_bad_offset = self.dispatch("tag.list", {"offset": -1})
        self.assertValidationError(res_bad_offset, expected_type="OutOfRange")

        res_bad_cat = self.dispatch("tag.list", {"category": 42})
        self.assertValidationError(res_bad_cat, expected_type="InvalidValue")

    def test_tag_delete(self):
        created = self.dispatch("tag.create", {"name": "Temp Tag"})
        self.assertResponseCode(created, 201)
        tag_id = created["data"]["id"]

        res_del = self.dispatch("tag.delete", {"id": tag_id})
        self.assertResponseCode(res_del, 200)

        res_del_again = self.dispatch("tag.delete", {"id": tag_id})
        self.assertResponseCode(res_del_again, 404)
        self.assertEqual(res_del_again["error"]["type"], "TagNotFound")

        res_bad_uuid = self.dispatch("tag.delete", {"id": "not-a-uuid"})
        self.assertValidationError(res_bad_uuid, expected_type="InvalidValue")

        res_missing = self.dispatch("tag.delete", {})
        self.assertValidationError(res_missing, expected_type="MissingParameter")

    def test_tag_assign_remove_and_get_entity_tags(self):
        artist = self.dispatch("CreateArtist", {"name": "Bill Evans"})
        self.assertResponseCode(artist, 201)
        artist_id = artist["data"]["id"]

        t1 = self.dispatch("tag.create", {"name": "Modal Jazz", "category": "genre"})["data"]["id"]
        t2 = self.dispatch("tag.create", {"name": "1960s", "category": "era"})["data"]["id"]

        # Assign multiple tags to the same entity
        res_a1 = self.dispatch("tag.assign", {"entity_id": artist_id, "tag_id": t1, "entity_type": "artist"})
        self.assertResponseCode(res_a1, 201)
        res_a2 = self.dispatch("tag.assign", {"entity_id": artist_id, "tag_id": t2})
        self.assertResponseCode(res_a2, 201)

        res_get = self.dispatch("tag.get_entity_tags", {"entity_id": artist_id, "entity_type": "artist"})
        self.assertResponseCode(res_get, 200)
        names = [item["name"] for item in res_get["data"]]
        self.assertEqual(names, ["1960s", "Modal Jazz"])

        # Remove one tag
        res_rem = self.dispatch("tag.remove", {"entity_id": artist_id, "tag_id": t1})
        self.assertResponseCode(res_rem, 200)

        # Removing again returns 404 RelationNotFound
        res_rem_missing = self.dispatch("tag.remove", {"entity_id": artist_id, "tag_id": t1})
        self.assertResponseCode(res_rem_missing, 404)
        self.assertEqual(res_rem_missing["error"]["type"], "RelationNotFound")

        # Assign validation & 404 errors
        res_missing_entity = self.dispatch("tag.assign", {"entity_id": str(uuid.uuid4()), "tag_id": t2})
        self.assertResponseCode(res_missing_entity, 404)
        self.assertEqual(res_missing_entity["error"]["type"], "NotFound")

        res_missing_tag = self.dispatch("tag.assign", {"entity_id": artist_id, "tag_id": str(uuid.uuid4())})
        self.assertResponseCode(res_missing_tag, 404)
        self.assertEqual(res_missing_tag["error"]["type"], "TagNotFound")

        res_invalid_type = self.dispatch("tag.assign", {"entity_id": artist_id, "tag_id": t2, "entity_type": "invalid"})
        self.assertValidationError(res_invalid_type, expected_type="InvalidValue")

        res_mismatched_type = self.dispatch("tag.assign", {"entity_id": artist_id, "tag_id": t2, "entity_type": "track"})
        self.assertResponseCode(res_mismatched_type, 404)
        self.assertEqual(res_mismatched_type["error"]["type"], "NotFound")

        res_assign_to_tag = self.dispatch("tag.assign", {"entity_id": t1, "tag_id": t2})
        self.assertResponseCode(res_assign_to_tag, 404)
        self.assertEqual(res_assign_to_tag["error"]["type"], "NotFound")

        res_rem_invalid_type = self.dispatch("tag.remove", {"entity_id": artist_id, "tag_id": t2, "entity_type": "invalid"})
        self.assertValidationError(res_rem_invalid_type, expected_type="InvalidValue")

        res_rem_mismatched_type = self.dispatch("tag.remove", {"entity_id": artist_id, "tag_id": t2, "entity_type": "track"})
        self.assertResponseCode(res_rem_mismatched_type, 404)
        self.assertEqual(res_rem_mismatched_type["error"]["type"], "NotFound")

        res_bad_get = self.dispatch("tag.get_entity_tags", {"entity_id": "bad"})
        self.assertValidationError(res_bad_get, expected_type="InvalidValue")

        res_get_invalid_type = self.dispatch("tag.get_entity_tags", {"entity_id": artist_id, "entity_type": "invalid"})
        self.assertValidationError(res_get_invalid_type, expected_type="InvalidValue")

        res_get_mismatched_type = self.dispatch("tag.get_entity_tags", {"entity_id": artist_id, "entity_type": "track"})
        self.assertResponseCode(res_get_mismatched_type, 404)
        self.assertEqual(res_get_mismatched_type["error"]["type"], "NotFound")

        res_get_missing_entity = self.dispatch("tag.get_entity_tags", {"entity_id": str(uuid.uuid4())})
        self.assertResponseCode(res_get_missing_entity, 404)
        self.assertEqual(res_get_missing_entity["error"]["type"], "NotFound")

        res_get_tag_as_entity = self.dispatch("tag.get_entity_tags", {"entity_id": t1})
        self.assertResponseCode(res_get_tag_as_entity, 404)
        self.assertEqual(res_get_tag_as_entity["error"]["type"], "NotFound")

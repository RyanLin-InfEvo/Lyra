# SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
#
# SPDX-License-Identifier: AGPL-3.0-or-later

import json
import ctypes

from base_test_case import BaseLyraTestCase

class TestArtistController(BaseLyraTestCase):

    def test_router_missing_command(self):
        """Test missing 'command' field: Should return 400 (Router level)"""
        request = {"params": {"some_param": 1}}
        req_str = json.dumps(request).encode('utf-8')
        res_ptr = self.lib.lyra_dispatch(req_str)
        res_str = ctypes.cast(res_ptr, ctypes.c_char_p).value.decode('utf-8')
        res = json.loads(res_str)
        self.lib.lyra_free_string(res_ptr)

        self.assertValidationError(res, expected_type=res["error"]["type"], expected_message_content="Missing or invalid 'command' field")

    def test_router_invalid_command_type(self):
        """Test invalid 'command' type (e.g., integer): Should return 400"""
        request = {"command": 123, "params": {}}
        req_str = json.dumps(request).encode('utf-8')
        res_ptr = self.lib.lyra_dispatch(req_str)
        res_str = ctypes.cast(res_ptr, ctypes.c_char_p).value.decode('utf-8')
        res = json.loads(res_str)
        self.lib.lyra_free_string(res_ptr)

        self.assertValidationError(res, expected_type=res["error"]["type"], expected_message_content="Missing or invalid 'command' field")

    def test_router_unknown_command(self):
        """Test calling an unknown command: Router should return 404 Not Found"""
        res = self.dispatch("InvalidCommand123", {"some_param": 1})
        self.assertResponseCode(res, 404)
        self.assertEqual(res["error"]["message"], "Unknown command: InvalidCommand123")
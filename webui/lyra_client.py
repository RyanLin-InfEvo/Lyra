# SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
#
# SPDX-License-Identifier: AGPL-3.0-or-later

"""
Lyra C++ Core FFI Client (ctypes encapsulation)
Zero-dependency Python wrapper for liblyra_core.so.
"""

import ctypes
import json
import os
from typing import Any, Callable, Dict, Optional

EVENT_CALLBACK_TYPE = ctypes.CFUNCTYPE(None, ctypes.c_char_p, ctypes.c_void_p)


class LyraClient:
    """Object-oriented wrapper around the Lyra C-API."""

    def __init__(
        self,
        storage_root: Optional[str] = None,
        so_path: Optional[str] = None,
    ) -> None:
        self.initialized = False
        self.storage_root: Optional[str] = None
        self._c_callback = None
        self._event_handler: Optional[Callable[[Dict[str, Any]], None]] = None

        self.lib = self._load_shared_library(so_path)
        self._setup_ffi_signatures()

        if storage_root is not None:
            self.init(storage_root)

    @staticmethod
    def _find_default_so_path() -> str:
        """Locate liblyra_core.so across standard relative paths."""
        candidates = [
            os.environ.get("LYRA_CORE_SO"),
            os.path.abspath(
                os.path.join(os.path.dirname(__file__), "..", "core", "build", "liblyra_core.so")
            ),
            os.path.abspath(
                os.path.join(os.getcwd(), "core", "build", "liblyra_core.so")
            ),
            os.path.abspath(
                os.path.join(os.getcwd(), "liblyra_core.so")
            ),
            "/usr/local/lib/liblyra_core.so",
        ]
        for candidate in candidates:
            if candidate and os.path.exists(candidate):
                return candidate

        raise FileNotFoundError(
            "liblyra_core.so could not be located. "
            "Please build the project with `./build.sh` or specify the `so_path` argument."
        )

    def _load_shared_library(self, so_path: Optional[str] = None) -> ctypes.CDLL:
        resolved_path = so_path or self._find_default_so_path()
        if not os.path.exists(resolved_path):
            raise FileNotFoundError(f"Shared library not found at: {resolved_path}")
        return ctypes.CDLL(resolved_path)

    def _setup_ffi_signatures(self) -> None:
        """Declare argument and return types for FFI functions."""
        # int lyra_init(const char *storage_root)
        self.lib.lyra_init.argtypes = [ctypes.c_char_p]
        self.lib.lyra_init.restype = ctypes.c_int

        # char *lyra_dispatch(const char *json_request)
        self.lib.lyra_dispatch.argtypes = [ctypes.c_char_p]
        self.lib.lyra_dispatch.restype = ctypes.c_void_p

        # void lyra_free_string(char *str)
        self.lib.lyra_free_string.argtypes = [ctypes.c_void_p]
        self.lib.lyra_free_string.restype = None

        # void lyra_register_event_callback(LyraEventCallback callback, void *user_data)
        self.lib.lyra_register_event_callback.argtypes = [
            EVENT_CALLBACK_TYPE,
            ctypes.c_void_p,
        ]
        self.lib.lyra_register_event_callback.restype = None

    def init(self, storage_root: str) -> None:
        """Initialize the Lyra core database and storage subsystem."""
        abs_storage_root = os.path.abspath(storage_root)
        os.makedirs(abs_storage_root, exist_ok=True)

        result_code = self.lib.lyra_init(abs_storage_root.encode("utf-8"))
        if result_code != 0:
            raise RuntimeError(
                f"Failed to initialize Lyra core database in: {abs_storage_root} (code={result_code})"
            )

        self.storage_root = abs_storage_root
        self.initialized = True

    def dispatch(self, command: str, params: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        """Dispatch a command with a params dictionary."""
        return self.raw_dispatch({
            "command": command,
            "params": params if params is not None else {},
        })

    def raw_dispatch(self, raw_request_dict: Dict[str, Any]) -> Dict[str, Any]:
        """Send a raw request dictionary to lyra_dispatch and parse the JSON response."""
        res_ptr = None
        try:
            req_str = json.dumps(raw_request_dict).encode("utf-8")
            res_ptr = self.lib.lyra_dispatch(req_str)

            if not res_ptr:
                raise RuntimeError("Lyra core returned a null response pointer.")

            res_str = ctypes.cast(res_ptr, ctypes.c_char_p).value.decode("utf-8")
            return json.loads(res_str)
        except json.JSONDecodeError as err:
            raise RuntimeError(f"Failed to parse JSON response from Lyra core: {err}") from err
        finally:
            if res_ptr:
                self.lib.lyra_free_string(res_ptr)

    def register_event_callback(self, handler: Callable[[Dict[str, Any]], None]) -> None:
        """Register a Python callback function to receive push events from the audio engine."""
        self._event_handler = handler

        def _native_callback(json_event_ptr, _user_data):
            if json_event_ptr and self._event_handler:
                try:
                    event_str = json_event_ptr.decode("utf-8")
                    event_data = json.loads(event_str)
                    self._event_handler(event_data)
                except Exception:
                    pass

        self._c_callback = EVENT_CALLBACK_TYPE(_native_callback)
        self.lib.lyra_register_event_callback(self._c_callback, None)

    def unregister_event_callback(self) -> None:
        """Unregister the event callback."""
        self.lib.lyra_register_event_callback(EVENT_CALLBACK_TYPE(), None)
        self._c_callback = None
        self._event_handler = None

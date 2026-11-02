/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#pragma once

#include "lyra_plugin_api.h"
#include "services/audio_device_info.h"
#include <string>
#include <vector>

namespace lyra {

LyraAudioSink *create_local_audio_sink();
void destroy_local_audio_sink(LyraAudioSink *sink);

LyraAudioSink *create_null_audio_sink();
void destroy_null_audio_sink(LyraAudioSink *sink);

std::vector<AudioDeviceInfo> list_local_audio_devices();
bool is_valid_audio_device_id(const std::string &device_id);
bool is_audio_device_available(const std::string &device_id);

bool shutdown_local_audio_context();

} // namespace lyra

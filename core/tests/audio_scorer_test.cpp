/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#include "services/audio_scorer.h"
#include <cassert>
#include <iostream>
#include <vector>

using namespace lyra;

void test_4tier_comparator_tiers() {
    std::cout << "[Test] 4-Tier Comparator Tiers..." << std::endl;

    // Tier 1: quality_score (DESC)
    {
        ScoredCandidateAsset a;
        a.quality_score = 90;
        a.file_hash = "z_hash";

        ScoredCandidateAsset b;
        b.quality_score = 80;
        b.file_hash = "a_hash";

        assert(AudioScorer::compare_candidate_assets(a, b) == true);
        assert(AudioScorer::compare_candidate_assets(b, a) == false);
    }

    // Tier 2: is_lossless (DESC) when quality_score tied
    {
        ScoredCandidateAsset a;
        a.quality_score = 70;
        a.is_lossless = true;
        a.file_hash = "z_hash";

        ScoredCandidateAsset b;
        b.quality_score = 70;
        b.is_lossless = false;
        b.file_hash = "a_hash";

        assert(AudioScorer::compare_candidate_assets(a, b) == true);
        assert(AudioScorer::compare_candidate_assets(b, a) == false);
    }

    // Tier 3: file_size (DESC) when quality_score and is_lossless tied
    {
        ScoredCandidateAsset a;
        a.quality_score = 70;
        a.is_lossless = true;
        a.file_size = 5000000;
        a.file_hash = "z_hash";

        ScoredCandidateAsset b;
        b.quality_score = 70;
        b.is_lossless = true;
        b.file_size = 3000000;
        b.file_hash = "a_hash";

        assert(AudioScorer::compare_candidate_assets(a, b) == true);
        assert(AudioScorer::compare_candidate_assets(b, a) == false);
    }

    // Tier 4: identifier / hash (ASC) when all else tied
    {
        ScoredCandidateAsset a;
        a.quality_score = 70;
        a.is_lossless = true;
        a.file_size = 5000000;
        a.file_hash = "aaa";

        ScoredCandidateAsset b;
        b.quality_score = 70;
        b.is_lossless = true;
        b.file_size = 5000000;
        b.file_hash = "bbb";

        assert(AudioScorer::compare_candidate_assets(a, b) == true);
        assert(AudioScorer::compare_candidate_assets(b, a) == false);
    }

    // AudioVersion comparator tiers
    {
        ScoredAudioVersion v1;
        v1.pcm_hash = "pcm_1";
        v1.quality_score = 95;

        ScoredAudioVersion v2;
        v2.pcm_hash = "pcm_2";
        v2.quality_score = 80;

        assert(AudioScorer::compare_audio_versions(v1, v2) == true);
        assert(AudioScorer::compare_audio_versions(v2, v1) == false);

        // Tie-break with lossless
        ScoredAudioVersion v_lossless;
        v_lossless.pcm_hash = "pcm_lossless";
        v_lossless.quality_score = 71;
        v_lossless.is_lossless = true;

        ScoredAudioVersion v_lossy;
        v_lossy.pcm_hash = "pcm_lossy";
        v_lossy.quality_score = 71;
        v_lossy.is_lossless = false;

        assert(AudioScorer::compare_audio_versions(v_lossless, v_lossy) == true);
        assert(AudioScorer::compare_audio_versions(v_lossy, v_lossless) == false);
    }

    std::cout << "  ✓ 4-Tier Comparator Tiers passed." << std::endl;
}

void test_candidate_asset_scoring_and_bonuses() {
    std::cout << "[Test] Candidate Asset Scoring and Bonuses..." << std::endl;

    Audio audio;
    audio.pcm_hash = "pcm_test";
    audio.bit_depth = 24;
    audio.sample_rate = 96000;
    audio.channels = 2;
    audio.duration = 60.0;

    Asset flac_asset;
    flac_asset.file_hash = "hash_flac";
    flac_asset.mime_type = "audio/flac";
    flac_asset.file_size = 30000000;

    Asset mp3_asset;
    mp3_asset.file_hash = "hash_mp3";
    mp3_asset.mime_type = "audio/mpeg";
    mp3_asset.file_size = 2000000;

    // Score without preferred format
    auto scored_flac = AudioScorer::score_candidate_asset(audio, flac_asset);
    auto scored_mp3 = AudioScorer::score_candidate_asset(audio, mp3_asset);

    assert(scored_flac.is_lossless == true);
    assert(scored_mp3.is_lossless == false);

    // FLAC should have base_score + 500
    assert(scored_flac.quality_score == scored_flac.base_quality_score + AudioScorer::LOSSLESS_BONUS);
    // MP3 should have only base_score
    assert(scored_mp3.quality_score == scored_mp3.base_quality_score);

    // Score with preferred_format = "mp3"
    auto pref_mp3 = AudioScorer::score_candidate_asset(audio, mp3_asset, "mp3");
    assert(pref_mp3.quality_score == scored_mp3.base_quality_score + AudioScorer::PREFERRED_FORMAT_BONUS);

    // Preferred format (+1000) should beat lossless bonus (+500)
    assert(pref_mp3.quality_score > scored_flac.quality_score);

    // Test score_and_sort_candidate_assets
    std::vector<Asset> assets = {mp3_asset, flac_asset};
    auto sorted_default = AudioScorer::score_and_sort_candidate_assets(audio, assets);
    assert(sorted_default.size() == 2);
    assert(sorted_default[0].file_hash == "hash_flac");
    assert(sorted_default[1].file_hash == "hash_mp3");

    // With preferred format "mp3", MP3 should be sorted first
    auto sorted_pref = AudioScorer::score_and_sort_candidate_assets(audio, assets, "mp3");
    assert(sorted_pref.size() == 2);
    assert(sorted_pref[0].file_hash == "hash_mp3");
    assert(sorted_pref[1].file_hash == "hash_flac");

    std::cout << "  ✓ Candidate Asset Scoring and Bonuses passed." << std::endl;
}

void test_candidate_audio_version_scoring() {
    std::cout << "[Test] Candidate Audio Version Scoring across Version Family..." << std::endl;

    Audio root_audio;
    root_audio.pcm_hash = "pcm_root";
    root_audio.bit_depth = 24;
    root_audio.sample_rate = 96000;
    root_audio.channels = 2;
    root_audio.duration = 180.0;

    Asset root_asset;
    root_asset.file_hash = "flac_root";
    root_asset.mime_type = "audio/flac";
    root_asset.file_size = 50000000;
    root_audio.assets.push_back(root_asset);

    Audio child_audio;
    child_audio.pcm_hash = "pcm_child";
    child_audio.parent_hash = "pcm_root";
    child_audio.bit_depth = 16;
    child_audio.sample_rate = 44100;
    child_audio.channels = 2;
    child_audio.duration = 180.0;

    Asset child_asset;
    child_asset.file_hash = "mp3_child";
    child_asset.mime_type = "audio/mpeg";
    child_asset.file_size = 7200000;
    child_audio.assets.push_back(child_asset);

    std::vector<Audio> versions = {child_audio, root_audio};
    auto sorted_versions = AudioScorer::score_and_sort_candidate_versions(versions);

    assert(sorted_versions.size() == 2);
    assert(sorted_versions[0].pcm_hash == "pcm_root");
    assert(sorted_versions[0].is_master == true);
    assert(sorted_versions[0].is_lossless == true);
    assert(sorted_versions[0].quality_score == 97);

    assert(sorted_versions[1].pcm_hash == "pcm_child");
    assert(sorted_versions[1].is_master == false);
    assert(sorted_versions[1].is_lossless == false);
    assert(sorted_versions[1].quality_score == 68);

    std::cout << "  ✓ Candidate Audio Version Scoring passed." << std::endl;
}

int main() {
    test_4tier_comparator_tiers();
    test_candidate_asset_scoring_and_bonuses();
    test_candidate_audio_version_scoring();

    std::cout << "ALL_AUDIO_SCORER_TESTS_PASSED\n";
    return 0;
}

#pragma once
#include <string>

struct Audio {
    std::string pcm_hash;
    std::string parent_hash;
    int quality_score = 0;
    int bit_depth = 0;
    int sample_rate = 0;
    int channels = 0;
    double duration = 0.0;
    double integrated_loudness = 0.0;
    double true_peak = 0.0;
};

#pragma once

#include <nlohmann/json.hpp>

using json = nlohmann::json;

class ArtistController {
  public:
    // CreateArtist
    static json create(const json &params);

    // Get Artist
    static json get(const json &params);
};

#pragma once
#include <string>

struct Track {
  std::string id;
  std::string work_id;
  std::string pcm_hash;
  std::string title;

  int recording_year = 0;
  int recording_month = 0;
  int recording_day = 0;
  std::string recording_location;

  int duration = 0; // A cached value from Audio, in milliseconds

  std::string isrc = "";
  std::string musicbrainz_id = "";
  std::string ytm_id = "";
  std::string spotify_id;
};
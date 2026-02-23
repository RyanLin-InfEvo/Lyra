#pragma once
#include <string>

struct Work {
  std::string id;
  std::string title;
  int composition_start_year = 0;
  int composition_end_year = 0;
  std::string composition_date_text;
  std::string iswc;
  std::string musicbrainz_id;
};

#pragma once
#include <string>

struct Image {
  std::string image_hash;
  std::string file_hash;
  int width = 0;
  int height = 0;
  std::string dominant_color = "";
};

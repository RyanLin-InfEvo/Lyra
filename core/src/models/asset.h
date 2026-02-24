#pragma once
#include <string>

struct Asset {
    std::string file_hash;
    std::string mime_type = "";
    std::string asset_type = "";
    int file_size = 0;
    std::string created_at = "";
};

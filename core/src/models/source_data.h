#pragma once
#include <string>

struct SourceData {
    std::string id;
    std::string file_hash;
    std::string source_type = "";
    std::string original_path = "";
    std::string created_at = "";
    std::string note = "";
};

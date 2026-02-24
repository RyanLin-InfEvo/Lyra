#pragma once
#include <string>

struct Text {
    std::string text_hash;
    std::string file_hash;
    std::string language = "";
    std::string encoding = "utf-8";
    std::string format = "";
};

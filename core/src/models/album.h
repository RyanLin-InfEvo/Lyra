#pragma once
#include <string>

struct Album {
    std::string id;
    std::string title;
    int release_year = 0;
    int release_month = 0;
    int release_day = 0;
};

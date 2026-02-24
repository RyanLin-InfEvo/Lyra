#pragma once

#include <nlohmann/json.hpp>

using json = nlohmann::json;

class Router {
  public:
    static json route(const json &request);
};

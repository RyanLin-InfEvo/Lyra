#include "lyra_c_api.h"
#include "database.h"
#include <cstring>           // 為了使用 strdup (複製字串用)
#include <fmt/core.h>        // 引入 字串格式化工具
#include <nlohmann/json.hpp> // 引入 JSON 工具
#include <string>

using json = nlohmann::json;

// Lyra core initialization
int lyra_init(const char *storage_root) {
  try {
    std::string db_path = std::string(storage_root) + "/lyra.db";
    init_database(db_path);
    return 0;

  } catch (const std::exception &e) {
    return -1;
  }
}

char *lyra_dispatch(const char *json_request) {
  try {

    // Parsing JSON strings into JSON objects
    json request = json::parse(json_request);

    // Extract command
    std::string command = request.value("command", "Unknown");

    // Prepare response
    json response;
    response["protocol"] = "lyra-core";
    response["code"] = 200;

    // Handle different commands
    if (command == "CreateArtist") {
      // Extract name and uuid from request
      std::string artist_name = request["params"]["name"];
      std::string artist_uuid = request["params"]["uuid"];

      // Insert artist into database
      insert_artist(artist_uuid, artist_name);

      response["data"]["message"] = fmt::format(
          "Lyra: Successfully inserted {} into lyra.db!", artist_name);
      response["data"]["uuid"] = artist_uuid;
    } else {
      response["data"]["message"] = "Command not found";
    }

    // Convert JSON object to string
    std::string response_str = response.dump();

    // Return response string
    return strdup(response_str.c_str());

  } catch (const std::exception &e) {

    json error_res;
    error_res["code"] = 400;
    error_res["error"]["message"] = e.what();
    return strdup(error_res.dump().c_str());
  }
}

// Free memory
void lyra_free_string(char *str) {
  if (str != nullptr) {
    free(str);
  }
}
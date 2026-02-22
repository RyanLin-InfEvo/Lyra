#include <string>

#include "../database.h"
#include "../models/artist.h"
#include "../utils/uuid_generator.h"
#include "artist_controller.h"

using json = nlohmann::json;

json ArtistController::create(const json &params) {

  // Format Check: If 'name' avilable in params
  if (!params.contains("name") || params["name"].get<std::string>().empty()) {
    json error_res;
    error_res["code"] = 400; // 400 Bad Request
    error_res["error"]["message"] = "Create Fail: Must provide artist name";
    return error_res;
  }

  Artist new_artist;

  new_artist.id = UuidGenerator::generate_v4();
  new_artist.name = params.value("name", "");

  // Call: Database
  bool success = Database::insert_artist(new_artist);

  // Return
  if (success) {
    // Success
    json response;
    response["code"] = 200;
    response["data"]["id"] = new_artist.id;
    response["data"]["name"] = new_artist.name;
    response["message"] = "Create Artist success.";
    return response;
  } else {
    // Error
    json error_res;
    error_res["code"] = 500; // 500 Internal Server Error
    error_res["error"]["message"] = " Database error";
    return error_res;
  }
}

json ArtistController::get(const json &params) {

  if (!params.contains("uuid") || params["uuid"].get<std::string>().empty()) {
    json error_res;
    error_res["code"] = 400; // 400 Bad Request
    error_res["error"]["message"] = "Create Fail: Must provide uuid";
    return error_res;
  }

  std::optional<Artist> artist =
      Database::get_artist(params["uuid"].get<std::string>());

  if (artist.has_value()) {
    // Success
    json response;
    response["code"] = 200;
    response["data"]["id"] = artist->id;
    response["data"]["name"] = artist->name;
    response["data"]["description"] = artist->description;
    return response;
  } else {
    // Error
    json error_res;
    error_res["code"] = 404; // 404 Not Found
    error_res["error"]["message"] = "Artist not found";
    return error_res;
  }
}
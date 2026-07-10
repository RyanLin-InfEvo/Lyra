// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#include <iostream>
#include <string>
#include <vector>
#include <optional>
#include <sstream>
#include <cstdlib>
#include <cctype>
#include <unistd.h>
#include <nlohmann/json.hpp>

#include "lyra_c_api.h"

using json = nlohmann::json;

// Function declarations
void print_help();
std::vector<std::string> tokenize(const std::string& line);
std::vector<std::string> get_flag_aliases(const std::string& flag);
std::string get_opt(const std::vector<std::string>& args, const std::vector<std::string>& flags);
void add_param(json& params, const std::vector<std::string>& args, const std::string& name, const std::vector<std::string>& flags, bool is_int = false);
bool check_positional_id(const std::vector<std::string>& cmd_args, const std::string& cmd_name);
std::optional<std::string> parse_args_to_json(const std::vector<std::string>& cmd_args);
int run_dispatch(const std::string& req_str, bool pretty);
std::string build_request(const std::string& command, const json& params);

int main(int argc, char* argv[]) {
    std::vector<std::string> args(argv + 1, argv + argc);
    
    // Parse global options
    std::string db_dir = ".";
    if (const char* env_db = std::getenv("LYRA_DB_DIR")) {
        db_dir = env_db;
    }
    
    bool pretty = false;
    bool force_interactive = false;
    
    std::vector<std::string> cmd_args;
    for (size_t i = 0; i < args.size(); ++i) {
        if (args[i] == "-d" || args[i] == "--db-dir") {
            if (i + 1 < args.size()) {
                db_dir = args[i+1];
                i++;
            } else {
                std::cerr << "Error: Missing value for " << args[i] << "\n";
                return 1;
            }
        } else if (args[i] == "-p" || args[i] == "--pretty") {
            pretty = true;
        } else if (args[i] == "-i" || args[i] == "--interactive") {
            force_interactive = true;
        } else if (args[i] == "-h" || args[i] == "--help") {
            print_help();
            return 0;
        } else {
            cmd_args.assign(args.begin() + i, args.end());
            break;
        }
    }
    
    // Default to interactive mode if no command is specified and stdin/stdout are terminals
    if (cmd_args.empty()) {
        if (force_interactive || (isatty(STDIN_FILENO) && isatty(STDOUT_FILENO))) {
            cmd_args.push_back("interactive");
        } else {
            print_help();
            return 1;
        }
    }
    
    // Initialize Database
    int init_res = lyra_init(db_dir.c_str());
    if (init_res != 0) {
        std::cerr << "Error: Failed to initialize database in directory: " << db_dir << "\n";
        return 1;
    }
    
    // Handle Interactive Mode
    if (cmd_args[0] == "interactive") {
        std::cout << "❄️ Lyra CLI Interactive REPL\n";
        std::cout << "Type a command (e.g., 'artist create --name \"Artist Name\"') or a raw JSON request.\n";
        std::cout << "Type 'exit' or 'quit' to exit.\n\n";
        
        std::string line;
        while (true) {
            std::cout << "lyra> ";
            std::cout.flush();
            if (!std::getline(std::cin, line)) {
                break;
            }
            
            size_t first = line.find_first_not_of(" \t\r\n");
            if (first == std::string::npos) {
                continue;
            }
            line = line.substr(first);
            if (line == "exit" || line == "quit") {
                break;
            }
            
            if (line[0] == '{') {
                run_dispatch(line, pretty);
            } else {
                std::vector<std::string> tokens = tokenize(line);
                if (tokens.empty()) continue;
                
                auto req_opt = parse_args_to_json(tokens);
                if (req_opt) {
                    run_dispatch(*req_opt, pretty);
                }
            }
        }
        return 0;
    }
    
    // Handle One-shot Command Execution
    if (cmd_args[0] == "dispatch") {
        std::string json_payload = "";
        if (cmd_args.size() > 1 && cmd_args[1] != "-") {
            json_payload = cmd_args[1];
        } else {
            std::string line;
            while (std::getline(std::cin, line)) {
                json_payload += line + "\n";
            }
        }
        return run_dispatch(json_payload, pretty);
    }
    
    // Parse native subcommands
    auto req_opt = parse_args_to_json(cmd_args);
    if (!req_opt) {
        return 1;
    }
    
    return run_dispatch(*req_opt, pretty);
}

void print_help() {
    std::cout << "Usage: lyra-cli [global-options] <command> [subcommand] [options/arguments]\n\n"
              << "Global Options:\n"
              << "  -d, --db-dir <dir>      Database directory path (default: '.' or LYRA_DB_DIR)\n"
              << "  -p, --pretty            Pretty print JSON response\n"
              << "  -h, --help              Show this help message\n\n"
              << "Commands:\n"
              << "  artist create --name <name> [options]\n"
              << "  artist update <id> [options]\n"
              << "  artist get <id>\n"
              << "  artist list [--offset <offset>] [--limit <limit>] [--search <query>]\n"
              << "  track create --pcm-hash <hash> [options]\n"
              << "  track update <id> [options]\n"
              << "  track get <id>\n"
              << "  track get-path <id>     Get physical file path of a track\n"
              << "  track list [--offset <offset>] [--limit <limit>] [--search <query>]\n"
              << "  album create --title <title> [options]\n"
              << "  album update <id> [options]\n"
              << "  album get <id>\n"
              << "  album list [--offset <offset>] [--limit <limit>] [--search <query>]\n"
              << "  work create --title <title> [options]\n"
              << "  work update <id> [options]\n"
              << "  work get <id>\n"
              << "  work list [--offset <offset>] [--limit <limit>] [--search <query>]\n"
              << "  playlist create --title <title> [options]\n"
              << "  playlist update <id> [options]\n"
              << "  playlist get <id>\n"
              << "  playlist list [--offset <offset>] [--limit <limit>] [--search <query>]\n"
              << "  playlist add-track --playlist-id <pid> --track-id <tid> [--position <pos>]\n"
              << "  playlist remove-track --playlist-id <pid> --track-id <tid>\n"
              << "  playlist get-tracks <id>\n"
              << "  track-artist add --track-id <tid> --artist-id <aid> --role <role> [--position <pos>]\n"
              << "  track-artist remove --track-id <tid> --artist-id <aid>\n"
              << "  track-artist update --track-id <tid> --artist-id <aid> [options]\n"
              << "  asset\n"
              << "    asset ingest <source_path>   Ingest a file into storage\n"
              << "  dispatch [json_payload]   Send a raw JSON request (reads stdin if payload is '-' or omitted)\n"
              << "  interactive               Start interactive REPL session\n";
}

std::vector<std::string> tokenize(const std::string& line) {
    std::vector<std::string> tokens;
    std::string current;
    bool in_quotes = false;
    char quote_char = 0;
    
    for (size_t i = 0; i < line.size(); ++i) {
        char c = line[i];
        if (in_quotes) {
            if (c == quote_char) {
                in_quotes = false;
            } else {
                current += c;
            }
        } else {
            if (c == '"' || c == '\'') {
                in_quotes = true;
                quote_char = c;
            } else if (std::isspace(static_cast<unsigned char>(c))) {
                if (!current.empty()) {
                    tokens.push_back(current);
                    current.clear();
                }
            } else {
                current += c;
            }
        }
    }
    if (!current.empty()) {
        tokens.push_back(current);
    }
    return tokens;
}

std::vector<std::string> get_flag_aliases(const std::string& flag) {
    std::vector<std::string> aliases;
    if (flag.empty()) return aliases;
    aliases.push_back(flag);
    if (flag.starts_with("--")) {
        std::string alt_body = flag.substr(2);
        bool changed = false;
        for (char& c : alt_body) {
            if (c == '-') {
                c = '_';
                changed = true;
            } else if (c == '_') {
                c = '-';
                changed = true;
            }
        }
        if (changed) {
            aliases.push_back("--" + alt_body);
        }
    }
    return aliases;
}

std::string get_opt(const std::vector<std::string>& args, const std::vector<std::string>& flags) {
    std::vector<std::string> all_aliases;
    for (const auto& f : flags) {
        auto aliases = get_flag_aliases(f);
        all_aliases.insert(all_aliases.end(), aliases.begin(), aliases.end());
    }
    
    for (size_t i = 0; i < args.size(); ++i) {
        bool match = false;
        for (const auto& f : all_aliases) {
            if (args[i] == f) {
                match = true;
                break;
            }
        }
        if (match) {
            if (i + 1 < args.size()) {
                std::string next_val = args[i+1];
                if (next_val.starts_with("-")) {
                    bool is_negative_int = true;
                    if (next_val.size() > 1) {
                        for (size_t j = 1; j < next_val.size(); ++j) {
                            if (!std::isdigit(static_cast<unsigned char>(next_val[j]))) {
                                is_negative_int = false;
                                break;
                            }
                        }
                    } else {
                        is_negative_int = false;
                    }
                    if (!is_negative_int) {
                        return "";
                    }
                }
                return next_val;
            }
        }
    }
    return "";
}

void add_param(json& params, const std::vector<std::string>& args, const std::string& name, const std::vector<std::string>& flags, bool is_int) {
    std::string val = get_opt(args, flags);
    if (!val.empty()) {
        if (is_int) {
            try {
                params[name] = std::stoi(val);
            } catch (...) {
                // If it fails to parse, pass raw string to let Core validator fail it
                params[name] = val;
            }
        } else {
            params[name] = val;
        }
    }
}

bool check_positional_id(const std::vector<std::string>& cmd_args, const std::string& cmd_name) {
    if (cmd_args.size() < 3) {
        std::cerr << "Error: " << cmd_name << " requires an <id> positional argument\n";
        return false;
    }
    std::string id = cmd_args[2];
    if (id.starts_with("-")) {
        std::cerr << "Error: " << cmd_name << " requires an <id> positional argument, but found flag: " << id << "\n";
        return false;
    }
    return true;
}

std::string build_request(const std::string& command, const json& params) {
    json request;
    request["command"] = command;
    request["params"] = params;
    return request.dump();
}

std::optional<std::string> parse_args_to_json(const std::vector<std::string>& cmd_args) {
    if (cmd_args.empty()) return std::nullopt;
    
    std::string cmd = cmd_args[0];
    
    if (cmd == "artist") {
        if (cmd_args.size() < 2) {
            std::cerr << "Error: artist command requires a subcommand (create, update, get, list)\n";
            return std::nullopt;
        }
        std::string sub = cmd_args[1];
        json params = json::object();
        std::string action = "";
        
        if (sub == "create") {
            action = "CreateArtist";
            add_param(params, cmd_args, "name", {"--name", "-n"});
            add_param(params, cmd_args, "musicbrainz_id", {"--musicbrainz-id"});
            add_param(params, cmd_args, "ytm_id", {"--ytm-id"});
            add_param(params, cmd_args, "spotify_id", {"--spotify-id"});
        } else if (sub == "get") {
            action = "GetArtist";
            if (!check_positional_id(cmd_args, "artist get")) return std::nullopt;
            params["id"] = cmd_args[2];
        } else if (sub == "update") {
            action = "UpdateArtist";
            if (!check_positional_id(cmd_args, "artist update")) return std::nullopt;
            params["id"] = cmd_args[2];
            add_param(params, cmd_args, "name", {"--name", "-n"});
            add_param(params, cmd_args, "musicbrainz_id", {"--musicbrainz-id"});
            add_param(params, cmd_args, "ytm_id", {"--ytm-id"});
            add_param(params, cmd_args, "spotify_id", {"--spotify-id"});
        } else if (sub == "list") {
            action = "ListArtists";
            add_param(params, cmd_args, "offset", {"--offset"}, true);
            add_param(params, cmd_args, "limit", {"--limit"}, true);
            add_param(params, cmd_args, "search", {"--search", "-s"});
        } else {
            std::cerr << "Error: Unknown artist subcommand: " << sub << "\n";
            return std::nullopt;
        }
        return build_request(action, params);
    }
    
    if (cmd == "track") {
        if (cmd_args.size() < 2) {
            std::cerr << "Error: track command requires a subcommand (create, update, get, list)\n";
            return std::nullopt;
        }
        std::string sub = cmd_args[1];
        json params = json::object();
        std::string action = "";
        
        if (sub == "create") {
            action = "CreateTrack";
            // TODO: Once audio file upload or decoding is implemented, pcm_hash should be computed
            // on the server side; the client will upload the file instead of providing --pcm-hash directly.
            add_param(params, cmd_args, "pcm_hash", {"--pcm-hash"});
            add_param(params, cmd_args, "title", {"--title", "--name", "-t", "-n"});
            add_param(params, cmd_args, "work_id", {"--work-id"});
            add_param(params, cmd_args, "recording_year", {"--recording-year"}, true);
            add_param(params, cmd_args, "recording_month", {"--recording-month"}, true);
            add_param(params, cmd_args, "recording_day", {"--recording-day"}, true);
            add_param(params, cmd_args, "recording_location", {"--recording-location"});
            add_param(params, cmd_args, "duration", {"--duration"}, true);
            add_param(params, cmd_args, "isrc", {"--isrc"});
            add_param(params, cmd_args, "musicbrainz_id", {"--musicbrainz-id"});
            add_param(params, cmd_args, "ytm_id", {"--ytm-id"});
            add_param(params, cmd_args, "spotify_id", {"--spotify-id"});
        } else if (sub == "get") {
            action = "GetTrack";
            if (!check_positional_id(cmd_args, "track get")) return std::nullopt;
            params["id"] = cmd_args[2];
        } else if (sub == "get-path") {
            action = "GetResourcePath";
            if (!check_positional_id(cmd_args, "track get-path")) return std::nullopt;
            params["track_id"] = cmd_args[2];
        } else if (sub == "update") {
            action = "UpdateTrack";
            if (!check_positional_id(cmd_args, "track update")) return std::nullopt;
            params["id"] = cmd_args[2];
            add_param(params, cmd_args, "title", {"--title", "--name", "-t", "-n"});
            add_param(params, cmd_args, "work_id", {"--work-id"});
            add_param(params, cmd_args, "recording_year", {"--recording-year"}, true);
            add_param(params, cmd_args, "recording_month", {"--recording-month"}, true);
            add_param(params, cmd_args, "recording_day", {"--recording-day"}, true);
            add_param(params, cmd_args, "recording_location", {"--recording-location"});
            add_param(params, cmd_args, "duration", {"--duration"}, true);
            add_param(params, cmd_args, "isrc", {"--isrc"});
            add_param(params, cmd_args, "musicbrainz_id", {"--musicbrainz-id"});
            add_param(params, cmd_args, "ytm_id", {"--ytm-id"});
            add_param(params, cmd_args, "spotify_id", {"--spotify-id"});
        } else if (sub == "list") {
            action = "ListTracks";
            add_param(params, cmd_args, "offset", {"--offset"}, true);
            add_param(params, cmd_args, "limit", {"--limit"}, true);
            add_param(params, cmd_args, "search", {"--search", "-s"});
        } else {
            std::cerr << "Error: Unknown track subcommand: " << sub << "\n";
            return std::nullopt;
        }
        return build_request(action, params);
    }
    
    if (cmd == "album") {
        if (cmd_args.size() < 2) {
            std::cerr << "Error: album command requires a subcommand (create, update, get, list)\n";
            return std::nullopt;
        }
        std::string sub = cmd_args[1];
        json params = json::object();
        std::string action = "";
        
        if (sub == "create") {
            action = "CreateAlbum";
            add_param(params, cmd_args, "title", {"--title", "--name", "-t", "-n"});
            add_param(params, cmd_args, "release_year", {"--release-year"}, true);
            add_param(params, cmd_args, "release_month", {"--release-month"}, true);
            add_param(params, cmd_args, "release_day", {"--release-day"}, true);
        } else if (sub == "get") {
            action = "GetAlbum";
            if (!check_positional_id(cmd_args, "album get")) return std::nullopt;
            params["id"] = cmd_args[2];
        } else if (sub == "update") {
            action = "UpdateAlbum";
            if (!check_positional_id(cmd_args, "album update")) return std::nullopt;
            params["id"] = cmd_args[2];
            add_param(params, cmd_args, "title", {"--title", "--name", "-t", "-n"});
            add_param(params, cmd_args, "release_year", {"--release-year"}, true);
            add_param(params, cmd_args, "release_month", {"--release-month"}, true);
            add_param(params, cmd_args, "release_day", {"--release-day"}, true);
        } else if (sub == "list") {
            action = "ListAlbums";
            add_param(params, cmd_args, "offset", {"--offset"}, true);
            add_param(params, cmd_args, "limit", {"--limit"}, true);
            add_param(params, cmd_args, "search", {"--search", "-s"});
        } else {
            std::cerr << "Error: Unknown album subcommand: " << sub << "\n";
            return std::nullopt;
        }
        return build_request(action, params);
    }
    
    if (cmd == "work") {
        if (cmd_args.size() < 2) {
            std::cerr << "Error: work command requires a subcommand (create, update, get, list)\n";
            return std::nullopt;
        }
        std::string sub = cmd_args[1];
        json params = json::object();
        std::string action = "";
        
        if (sub == "create") {
            action = "CreateWork";
            add_param(params, cmd_args, "title", {"--title", "--name", "-t", "-n"});
            add_param(params, cmd_args, "composition_start_year", {"--composition-start-year"}, true);
            add_param(params, cmd_args, "composition_end_year", {"--composition-end-year"}, true);
            add_param(params, cmd_args, "composition_date_text", {"--composition-date-text"});
            add_param(params, cmd_args, "iswc", {"--iswc"});
            add_param(params, cmd_args, "musicbrainz_id", {"--musicbrainz-id"});
        } else if (sub == "get") {
            action = "GetWork";
            if (!check_positional_id(cmd_args, "work get")) return std::nullopt;
            params["id"] = cmd_args[2];
        } else if (sub == "update") {
            action = "UpdateWork";
            if (!check_positional_id(cmd_args, "work update")) return std::nullopt;
            params["id"] = cmd_args[2];
            add_param(params, cmd_args, "title", {"--title", "--name", "-t", "-n"});
            add_param(params, cmd_args, "composition_start_year", {"--composition-start-year"}, true);
            add_param(params, cmd_args, "composition_end_year", {"--composition-end-year"}, true);
            add_param(params, cmd_args, "composition_date_text", {"--composition-date-text"});
            add_param(params, cmd_args, "iswc", {"--iswc"});
            add_param(params, cmd_args, "musicbrainz_id", {"--musicbrainz-id"});
        } else if (sub == "list") {
            action = "ListWorks";
            add_param(params, cmd_args, "offset", {"--offset"}, true);
            add_param(params, cmd_args, "limit", {"--limit"}, true);
            add_param(params, cmd_args, "search", {"--search", "-s"});
        } else {
            std::cerr << "Error: Unknown work subcommand: " << sub << "\n";
            return std::nullopt;
        }
        return build_request(action, params);
    }
    
    if (cmd == "playlist") {
        if (cmd_args.size() < 2) {
            std::cerr << "Error: playlist command requires a subcommand (create, update, get, list, add-track, remove-track, get-tracks)\n";
            return std::nullopt;
        }
        std::string sub = cmd_args[1];
        json params = json::object();
        std::string action = "";
        
        if (sub == "create") {
            action = "CreatePlaylist";
            add_param(params, cmd_args, "title", {"--title", "--name", "-t", "-n"});
            add_param(params, cmd_args, "description", {"--description", "-d"});
        } else if (sub == "get") {
            action = "GetPlaylist";
            if (!check_positional_id(cmd_args, "playlist get")) return std::nullopt;
            params["id"] = cmd_args[2];
        } else if (sub == "update") {
            action = "UpdatePlaylist";
            if (!check_positional_id(cmd_args, "playlist update")) return std::nullopt;
            params["id"] = cmd_args[2];
            add_param(params, cmd_args, "title", {"--title", "--name", "-t", "-n"});
            add_param(params, cmd_args, "description", {"--description", "-d"});
        } else if (sub == "list") {
            action = "ListPlaylists";
            add_param(params, cmd_args, "offset", {"--offset"}, true);
            add_param(params, cmd_args, "limit", {"--limit"}, true);
            add_param(params, cmd_args, "search", {"--search", "-s"});
        } else if (sub == "add-track") {
            action = "AddPlaylistTrack";
            add_param(params, cmd_args, "playlist_id", {"--playlist-id"});
            add_param(params, cmd_args, "track_id", {"--track-id"});
            add_param(params, cmd_args, "position", {"--position"}, true);
        } else if (sub == "remove-track") {
            action = "RemovePlaylistTrack";
            add_param(params, cmd_args, "playlist_id", {"--playlist-id"});
            add_param(params, cmd_args, "track_id", {"--track-id"});
        } else if (sub == "get-tracks") {
            action = "GetPlaylistTracks";
            if (!check_positional_id(cmd_args, "playlist get-tracks")) return std::nullopt;
            params["id"] = cmd_args[2];
        } else {
            std::cerr << "Error: Unknown playlist subcommand: " << sub << "\n";
            return std::nullopt;
        }
        return build_request(action, params);
    }
    
    if (cmd == "track-artist") {
        if (cmd_args.size() < 2) {
            std::cerr << "Error: track-artist command requires a subcommand (add, remove, update)\n";
            return std::nullopt;
        }
        std::string sub = cmd_args[1];
        json params = json::object();
        std::string action = "";
        
        if (sub == "add") {
            action = "AddTrackArtist";
            add_param(params, cmd_args, "track_id", {"--track-id"});
            add_param(params, cmd_args, "artist_id", {"--artist-id"});
            add_param(params, cmd_args, "role", {"--role"});
            add_param(params, cmd_args, "position", {"--position"}, true);
        } else if (sub == "remove") {
            action = "RemoveTrackArtist";
            add_param(params, cmd_args, "track_id", {"--track-id"});
            add_param(params, cmd_args, "artist_id", {"--artist-id"});
        } else if (sub == "update") {
            action = "UpdateTrackArtist";
            add_param(params, cmd_args, "track_id", {"--track-id"});
            add_param(params, cmd_args, "artist_id", {"--artist-id"});
            add_param(params, cmd_args, "role", {"--role"});
            add_param(params, cmd_args, "position", {"--position"}, true);
        } else {
            std::cerr << "Error: Unknown track-artist subcommand: " << sub << "\n";
            return std::nullopt;
        }
        return build_request(action, params);
    }
    
    if (cmd == "asset") {
        if (cmd_args.size() < 2) {
            std::cerr << "Error: asset command requires a subcommand (ingest)\n";
            return std::nullopt;
        }
        std::string sub = cmd_args[1];
        json params = json::object();
        std::string action = "";
        
        if (sub == "ingest") {
            action = "IngestAsset";
            if (cmd_args.size() < 3) {
                std::cerr << "Error: asset ingest requires a source file path\n";
                return std::nullopt;
            }
            params["source_path"] = cmd_args[2];
        } else {
            std::cerr << "Error: Unknown asset subcommand: " << sub << "\n";
            return std::nullopt;
        }
        return build_request(action, params);
    }
    
    std::cerr << "Error: Unknown command: " << cmd << "\n";
    return std::nullopt;
}

int run_dispatch(const std::string& req_str, bool pretty) {
    char* res_ptr = lyra_dispatch(req_str.c_str());
    if (!res_ptr) {
        std::cerr << "Error: C++ core returned a null pointer.\n";
        return 1;
    }
    
    std::string res_str(res_ptr);
    lyra_free_string(res_ptr);
    
    int exit_code = 0;
    try {
        auto j = json::parse(res_str);
        if (pretty) {
            std::cout << j.dump(4) << "\n";
        } else {
            std::cout << res_str << "\n";
        }
        if (j.contains("code") && j["code"].is_number_integer()) {
            int code = j["code"].get<int>();
            if (code >= 400) {
                exit_code = 1;
            }
        }
    } catch (...) {
        std::cout << res_str << "\n";
    }
    return exit_code;
}

/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#include "audio_helper.h"
#include "../models/audio.h"
#include "process_runner.h"
#include "sha256.h"
#include <algorithm>
#include <array>
#include <cctype>
#include <filesystem>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <nlohmann/json.hpp>
#include <sstream>
#include <string_view>

namespace lyra {
namespace utils {

namespace {

std::optional<double> get_json_double(const nlohmann::json &j, const std::string &key) {
    if (!j.is_object() || !j.contains(key) || j[key].is_null()) {
        return std::nullopt;
    }
    if (j[key].is_number()) {
        return j[key].get<double>();
    }
    if (j[key].is_string()) {
        try {
            return std::stod(j[key].get<std::string>());
        } catch (...) {
            return std::nullopt;
        }
    }
    return std::nullopt;
}

std::optional<int> get_json_int(const nlohmann::json &j, const std::string &key) {
    if (!j.is_object() || !j.contains(key) || j[key].is_null()) {
        return std::nullopt;
    }
    if (j[key].is_number()) {
        return j[key].get<int>();
    }
    if (j[key].is_string()) {
        try {
            return std::stoi(j[key].get<std::string>());
        } catch (...) {
            return std::nullopt;
        }
    }
    return std::nullopt;
}

std::optional<std::string> get_json_string(const nlohmann::json &j, const std::string &key) {
    if (!j.is_object() || !j.contains(key) || j[key].is_null()) {
        return std::nullopt;
    }
    if (j[key].is_string()) {
        return j[key].get<std::string>();
    }
    return std::nullopt;
}

std::optional<std::string> get_tag_case_insensitive(const nlohmann::json &tags_obj, const std::string &target_key) {
    if (!tags_obj.is_object()) {
        return std::nullopt;
    }
    for (auto it = tags_obj.begin(); it != tags_obj.end(); ++it) {
        std::string key = it.key();
        std::transform(key.begin(), key.end(), key.begin(), [](unsigned char c) {
            return std::tolower(c);
        });
        if (key == target_key) {
            if (it.value().is_string()) {
                return it.value().get<std::string>();
            } else if (it.value().is_number()) {
                return it.value().dump();
            }
        }
    }
    return std::nullopt;
}

std::optional<std::string> get_tag(const nlohmann::json &json_data, const std::string &tag_name) {
    // 1. Search Format tags
    if (json_data.contains("format") && json_data["format"].is_object()) {
        const auto &fmt = json_data["format"];
        if (fmt.contains("tags") && fmt["tags"].is_object()) {
            if (auto val = get_tag_case_insensitive(fmt["tags"], tag_name);
                val) return val;
        }
    }
    // 2. Search Stream tags (only audio streams)
    if (json_data.contains("streams") && json_data["streams"].is_array()) {
        for (const auto &stream : json_data["streams"]) {
            if (auto codec_type = get_json_string(stream, "codec_type");
                codec_type && *codec_type == "audio") {
                if (stream.contains("tags") && stream["tags"].is_object()) {
                    if (auto val = get_tag_case_insensitive(stream["tags"], tag_name);
                        val) return val;
                }
            }
        }
    }
    return std::nullopt;
}

bool is_ascii_alpha(char c) {
    return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z');
}

std::string to_ascii_lower(std::string_view s) {
    std::string out(s);
    for (char &c : out) {
        if (c >= 'A' && c <= 'Z') {
            c = static_cast<char>(c - 'A' + 'a');
        }
    }
    return out;
}

std::string to_ascii_upper(std::string_view s) {
    std::string out(s);
    for (char &c : out) {
        if (c >= 'a' && c <= 'z') {
            c = static_cast<char>(c - 'a' + 'A');
        }
    }
    return out;
}

std::string trim_ascii(std::string_view s) {
    size_t start = s.find_first_not_of(" \t\r\n");
    if (start == std::string_view::npos) {
        return "";
    }
    size_t end = s.find_last_not_of(" \t\r\n");
    return std::string(s.substr(start, end - start + 1));
}

bool is_all_ascii_alpha(std::string_view s) {
    if (s.empty()) return false;
    for (char c : s) {
        if (!is_ascii_alpha(c)) return false;
    }
    return true;
}

// Sorted ISO 639-1 (183), ISO 639-2/3 + Sinitic (512; excludes und/xxx/zxx), and ISO 15924 (226)
// allowlists derived from iso-codes 4.20.1 so metadata hyphens (e.g., "web-link", "eng-live") are not
// misparsed as language tags.
constexpr std::array<std::string_view, 183> ISO_639_1_CODES = {
    "aa", "ab", "ae", "af", "ak", "am", "an", "ar", "as", "av", "ay", "az", "ba", "be", "bg", "bi",
    "bm", "bn", "bo", "br", "bs", "ca", "ce", "ch", "co", "cr", "cs", "cu", "cv", "cy", "da", "de",
    "dv", "dz", "ee", "el", "en", "eo", "es", "et", "eu", "fa", "ff", "fi", "fj", "fo", "fr", "fy",
    "ga", "gd", "gl", "gn", "gu", "gv", "ha", "he", "hi", "ho", "hr", "ht", "hu", "hy", "hz", "ia",
    "id", "ie", "ig", "ii", "ik", "io", "is", "it", "iu", "ja", "jv", "ka", "kg", "ki", "kj", "kk",
    "kl", "km", "kn", "ko", "kr", "ks", "ku", "kv", "kw", "ky", "la", "lb", "lg", "li", "ln", "lo",
    "lt", "lu", "lv", "mg", "mh", "mi", "mk", "ml", "mn", "mr", "ms", "mt", "my", "na", "nb", "nd",
    "ne", "ng", "nl", "nn", "no", "nr", "nv", "ny", "oc", "oj", "om", "or", "os", "pa", "pi", "pl",
    "ps", "pt", "qu", "rm", "rn", "ro", "ru", "rw", "sa", "sc", "sd", "se", "sg", "si", "sk", "sl",
    "sm", "sn", "so", "sq", "sr", "ss", "st", "su", "sv", "sw", "ta", "te", "tg", "th", "ti", "tk",
    "tl", "tn", "to", "tr", "ts", "tt", "tw", "ty", "ug", "uk", "ur", "uz", "ve", "vi", "vo", "wa",
    "wo", "xh", "yi", "yo", "za", "zh", "zu"};

constexpr std::array<std::string_view, 512> ISO_639_2_3_CODES = {
    "aar", "abk", "ace", "ach", "ada", "ady", "afa", "afh", "afr", "ain", "aka", "akk", "alb", "ale",
    "alg", "alt", "amh", "ang", "anp", "apa", "ara", "arc", "arg", "arm", "arn", "arp", "art", "arw",
    "asm", "ast", "ath", "aus", "ava", "ave", "awa", "aym", "aze", "bad", "bai", "bak", "bal", "bam",
    "ban", "baq", "bas", "bat", "bej", "bel", "bem", "ben", "ber", "bho", "bih", "bik", "bin", "bis",
    "bla", "bnt", "bod", "bos", "bra", "bre", "btk", "bua", "bug", "bul", "bur", "byn", "cad", "cai",
    "car", "cat", "cau", "ceb", "cel", "ces", "cha", "chb", "che", "chg", "chi", "chk", "chm", "chn",
    "cho", "chp", "chr", "chu", "chv", "chy", "cmc", "cmn", "cnr", "cop", "cor", "cos", "cpe", "cpf",
    "cpp", "cre", "crh", "crp", "csb", "cus", "cym", "cze", "dak", "dan", "dar", "day", "del", "den",
    "deu", "dgr", "din", "div", "doi", "dra", "dsb", "dua", "dum", "dut", "dyu", "dzo", "efi", "egy",
    "eka", "ell", "elx", "eng", "enm", "epo", "est", "eus", "ewe", "ewo", "fan", "fao", "fas", "fat",
    "fij", "fil", "fin", "fiu", "fon", "fra", "fre", "frm", "fro", "frr", "frs", "fry", "ful", "fur",
    "gaa", "gan", "gay", "gba", "gem", "geo", "ger", "gez", "gil", "gla", "gle", "glg", "glv", "gmh",
    "goh", "gon", "gor", "got", "grb", "grc", "gre", "grn", "gsw", "guj", "gwi", "hai", "hak", "hat",
    "hau", "haw", "heb", "her", "hil", "him", "hin", "hit", "hmn", "hmo", "hrv", "hsb", "hsn", "hun",
    "hup", "hye", "iba", "ibo", "ice", "ido", "iii", "ijo", "iku", "ile", "ilo", "ina", "inc", "ind",
    "ine", "inh", "ipk", "ira", "iro", "isl", "ita", "jav", "jbo", "jpn", "jpr", "jrb", "kaa", "kab",
    "kac", "kal", "kam", "kan", "kar", "kas", "kat", "kau", "kaw", "kaz", "kbd", "kha", "khi", "khm",
    "kho", "kik", "kin", "kir", "kmb", "kok", "kom", "kon", "kor", "kos", "kpe", "krc", "krl", "kro",
    "kru", "kua", "kum", "kur", "kut", "lad", "lah", "lam", "lao", "lat", "lav", "lez", "lim", "lin",
    "lit", "lol", "loz", "ltz", "lua", "lub", "lug", "lui", "lun", "luo", "lus", "lzh", "mac", "mad",
    "mag", "mah", "mai", "mak", "mal", "man", "mao", "map", "mar", "mas", "may", "mdf", "mdr", "men",
    "mga", "mic", "min", "mis", "mkd", "mkh", "mlg", "mlt", "mnc", "mni", "mno", "moh", "mon", "mos",
    "mri", "msa", "mul", "mun", "mus", "mwl", "mwr", "mya", "myn", "myv", "nah", "nai", "nan", "nap",
    "nau", "nav", "nbl", "nde", "ndo", "nds", "nep", "new", "nia", "nic", "niu", "nld", "nno", "nob",
    "nog", "non", "nor", "nqo", "nso", "nub", "nwc", "nya", "nym", "nyn", "nyo", "nzi", "oci", "oji",
    "ori", "orm", "osa", "oss", "ota", "oto", "paa", "pag", "pal", "pam", "pan", "pap", "pau", "peo",
    "per", "phi", "phn", "pli", "pol", "pon", "por", "pra", "pro", "pus", "que", "raj", "rap", "rar",
    "roa", "roh", "rom", "ron", "rum", "run", "rup", "rus", "sad", "sag", "sah", "sai", "sal", "sam",
    "san", "sas", "sat", "scn", "sco", "sel", "sem", "sga", "sgn", "shn", "sid", "sin", "sio", "sit",
    "sla", "slk", "slo", "slv", "sma", "sme", "smi", "smj", "smn", "smo", "sms", "sna", "snd", "snk",
    "sog", "som", "son", "sot", "spa", "sqi", "srd", "srn", "srp", "srr", "ssa", "ssw", "suk", "sun",
    "sus", "sux", "swa", "swe", "syc", "syr", "tah", "tai", "tam", "tat", "tel", "tem", "ter", "tet",
    "tgk", "tgl", "tha", "tib", "tig", "tir", "tiv", "tkl", "tlh", "tli", "tmh", "tog", "ton", "tpi",
    "tsi", "tsn", "tso", "tuk", "tum", "tup", "tur", "tut", "tvl", "twi", "tyv", "udm", "uga", "uig",
    "ukr", "umb", "urd", "uzb", "vai", "ven", "vie", "vol", "vot", "wak", "wal", "war", "was", "wel",
    "wen", "wln", "wol", "wuu", "xal", "xho", "yao", "yap", "yid", "yor", "ypk", "yue", "zap", "zbl",
    "zen", "zgh", "zha", "zho", "znd", "zul", "zun", "zza"};

constexpr std::array<std::string_view, 226> ISO_15924_SCRIPTS = {
    "adlm", "afak", "aghb", "ahom", "arab", "aran", "armi", "armn", "avst", "bali", "bamu", "bass",
    "batk", "beng", "berf", "bhks", "blis", "bopo", "brah", "brai", "bugi", "buhd", "cakm", "cans",
    "cari", "cham", "cher", "chis", "chrs", "cirt", "copt", "cpmn", "cprt", "cyrl", "cyrs", "deva",
    "diak", "dogr", "dsrt", "dupl", "egyd", "egyh", "egyp", "elba", "elym", "ethi", "gara", "geok",
    "geor", "glag", "gong", "gonm", "goth", "gran", "grek", "gujr", "gukh", "guru", "hanb", "hang",
    "hani", "hano", "hans", "hant", "hatr", "hebr", "hira", "hluw", "hmng", "hmnp", "hntl", "hrkt",
    "hung", "inds", "ital", "jamo", "java", "jpan", "jurc", "kali", "kana", "kawi", "khar", "khmr",
    "khoj", "kitl", "kits", "knda", "kore", "kpel", "krai", "kthi", "lana", "laoo", "latf", "latg",
    "latn", "leke", "lepc", "limb", "lina", "linb", "lisu", "loma", "lyci", "lydi", "mahj", "maka",
    "mand", "mani", "marc", "maya", "medf", "mend", "merc", "mero", "mlym", "modi", "mong", "moon",
    "mroo", "mtei", "mult", "mymr", "nagm", "nand", "narb", "nbat", "newa", "nkdb", "nkgb", "nkoo",
    "nshu", "ogam", "olck", "onao", "orkh", "orya", "osge", "osma", "ougr", "palm", "pauc", "pcun",
    "pelm", "perm", "phag", "phli", "phlp", "phlv", "phnx", "piqd", "plrd", "prti", "psin", "qaaa",
    "qabx", "ranj", "rjng", "rohg", "roro", "runr", "samr", "sara", "sarb", "saur", "seal", "sgnw",
    "shaw", "shrd", "shui", "sidd", "sidt", "sind", "sinh", "sogd", "sogo", "sora", "soyo", "sund",
    "sunu", "sylo", "syrc", "syre", "syrj", "syrn", "tagb", "takr", "tale", "talu", "taml", "tang",
    "tavt", "tayo", "telu", "teng", "tfng", "tglg", "thaa", "thai", "tibt", "tirh", "tnsa", "todr",
    "tols", "toto", "tutg", "ugar", "vaii", "visp", "vith", "wara", "wcho", "wole", "xpeo", "xsux",
    "yezi", "yiii", "zanb", "zinh", "zmth", "zsye", "zsym", "zxxx", "zyyy", "zzzz"};

constexpr std::array<std::string_view, 249> ISO_3166_1_REGIONS = {
    "ad", "ae", "af", "ag", "ai", "al", "am", "ao", "aq", "ar", "as", "at", "au", "aw", "ax", "az",
    "ba", "bb", "bd", "be", "bf", "bg", "bh", "bi", "bj", "bl", "bm", "bn", "bo", "bq", "br", "bs",
    "bt", "bv", "bw", "by", "bz", "ca", "cc", "cd", "cf", "cg", "ch", "ci", "ck", "cl", "cm", "cn",
    "co", "cr", "cu", "cv", "cw", "cx", "cy", "cz", "de", "dj", "dk", "dm", "do", "dz", "ec", "ee",
    "eg", "eh", "er", "es", "et", "fi", "fj", "fk", "fm", "fo", "fr", "ga", "gb", "gd", "ge", "gf",
    "gg", "gh", "gi", "gl", "gm", "gn", "gp", "gq", "gr", "gs", "gt", "gu", "gw", "gy", "hk", "hm",
    "hn", "hr", "ht", "hu", "id", "ie", "il", "im", "in", "io", "iq", "ir", "is", "it", "je", "jm",
    "jo", "jp", "ke", "kg", "kh", "ki", "km", "kn", "kp", "kr", "kw", "ky", "kz", "la", "lb", "lc",
    "li", "lk", "lr", "ls", "lt", "lu", "lv", "ly", "ma", "mc", "md", "me", "mf", "mg", "mh", "mk",
    "ml", "mm", "mn", "mo", "mp", "mq", "mr", "ms", "mt", "mu", "mv", "mw", "mx", "my", "mz", "na",
    "nc", "ne", "nf", "ng", "ni", "nl", "no", "np", "nr", "nu", "nz", "om", "pa", "pe", "pf", "pg",
    "ph", "pk", "pl", "pm", "pn", "pr", "ps", "pt", "pw", "py", "qa", "re", "ro", "rs", "ru", "rw",
    "sa", "sb", "sc", "sd", "se", "sg", "sh", "si", "sj", "sk", "sl", "sm", "sn", "so", "sr", "ss",
    "st", "sv", "sx", "sy", "sz", "tc", "td", "tf", "tg", "th", "tj", "tk", "tl", "tm", "tn", "to",
    "tr", "tt", "tv", "tw", "tz", "ua", "ug", "um", "us", "uy", "uz", "va", "vc", "ve", "vg", "vi",
    "vn", "vu", "wf", "ws", "ye", "yt", "za", "zm", "zw"};

constexpr std::array<std::string_view, 31> UN_M49_REGIONS = {
    "001", "002", "003", "005", "009", "011", "013", "014", "015", "017", "018", "019", "021", "029", "030", "034",
    "035", "039", "053", "054", "057", "061", "142", "143", "145", "150", "151", "154", "155", "202", "419"};

constexpr std::array<std::string_view, 8> ZH_EXTLANG_CODES = {
    "cmn", "gan", "hak", "hsn", "lzh", "nan", "wuu", "yue"};

constexpr std::array<std::string_view, 7> BCP47_LYRICS_VARIANTS = {
    "alalc97", "hepburn", "jyutping", "pehoeji", "pinyin", "tailo", "wadegile"};

template <size_t N>
constexpr bool is_strictly_sorted(const std::array<std::string_view, N> &arr) {
    for (size_t i = 1; i < N; ++i) {
        if (!(arr[i - 1] < arr[i])) return false;
    }
    return true;
}

static_assert(is_strictly_sorted(ISO_639_1_CODES), "ISO_639_1_CODES must be strictly sorted");
static_assert(is_strictly_sorted(ISO_639_2_3_CODES), "ISO_639_2_3_CODES must be strictly sorted");
static_assert(is_strictly_sorted(ISO_15924_SCRIPTS), "ISO_15924_SCRIPTS must be strictly sorted");
static_assert(is_strictly_sorted(ISO_3166_1_REGIONS), "ISO_3166_1_REGIONS must be strictly sorted");
static_assert(is_strictly_sorted(UN_M49_REGIONS), "UN_M49_REGIONS must be strictly sorted");
static_assert(is_strictly_sorted(ZH_EXTLANG_CODES), "ZH_EXTLANG_CODES must be strictly sorted");
static_assert(is_strictly_sorted(BCP47_LYRICS_VARIANTS), "BCP47_LYRICS_VARIANTS must be strictly sorted");

bool is_iso639_1(std::string_view code) {
    return std::binary_search(ISO_639_1_CODES.begin(), ISO_639_1_CODES.end(), code);
}

bool is_iso639_2_or_3(std::string_view code) {
    return std::binary_search(ISO_639_2_3_CODES.begin(), ISO_639_2_3_CODES.end(), code);
}

bool is_iso15924_script(std::string_view code) {
    return std::binary_search(ISO_15924_SCRIPTS.begin(), ISO_15924_SCRIPTS.end(), code);
}

bool is_iso3166_1_region(std::string_view code) {
    return std::binary_search(ISO_3166_1_REGIONS.begin(), ISO_3166_1_REGIONS.end(), code);
}

bool is_un_m49_region(std::string_view code) {
    return std::binary_search(UN_M49_REGIONS.begin(), UN_M49_REGIONS.end(), code);
}

bool is_zh_extlang(std::string_view code) {
    return std::binary_search(ZH_EXTLANG_CODES.begin(), ZH_EXTLANG_CODES.end(), code);
}

bool is_bcp47_lyrics_variant(std::string_view code) {
    return std::binary_search(BCP47_LYRICS_VARIANTS.begin(), BCP47_LYRICS_VARIANTS.end(), code);
}

std::optional<std::string> parse_strict_bcp47(std::string_view tag_part) {
    if (tag_part.empty()) {
        return std::nullopt;
    }

    std::vector<std::string_view> tokens;
    size_t start = 0;
    while (start <= tag_part.size()) {
        size_t sep = tag_part.find('-', start);
        if (sep == std::string_view::npos) {
            tokens.push_back(tag_part.substr(start));
            break;
        }
        tokens.push_back(tag_part.substr(start, sep - start));
        start = sep + 1;
    }

    if (tokens.empty()) {
        return std::nullopt;
    }
    for (std::string_view tok : tokens) {
        if (tok.empty()) {
            return std::nullopt;
        }
    }

    const std::string_view primary = tokens[0];
    if (tokens.size() == 1 && (primary == "und" || primary == "xxx")) {
        return std::string("");
    }

    const bool valid_primary = (primary.size() == 2 && is_iso639_1(primary)) ||
                               (primary.size() == 3 && is_iso639_2_or_3(primary));
    if (!valid_primary) {
        return std::nullopt;
    }
    if (tokens.size() == 1) {
        return std::string(primary);
    }

    bool saw_extlang = false;
    bool saw_script = false;
    bool saw_region = false;
    bool saw_variant = false;
    std::string canonical(primary);
    for (size_t i = 1; i < tokens.size(); ++i) {
        const std::string_view tok = tokens[i];
        if (!saw_extlang && !saw_script && !saw_region && !saw_variant &&
            primary == "zh" && tok.size() == 3 && is_zh_extlang(tok)) {
            saw_extlang = true;
            canonical += "-";
            canonical += tok;
        } else if (!saw_script && !saw_region && !saw_variant &&
                   tok.size() == 4 && is_all_ascii_alpha(tok) && is_iso15924_script(tok)) {
            saw_script = true;
            std::string script(tok);
            script[0] = static_cast<char>(script[0] - 'a' + 'A');
            canonical += "-" + script;
        } else if (!saw_region && !saw_variant &&
                   ((tok.size() == 2 && is_iso3166_1_region(tok)) ||
                    (tok.size() == 3 && is_un_m49_region(tok)))) {
            saw_region = true;
            canonical += "-";
            canonical += is_all_ascii_alpha(tok) ? to_ascii_upper(tok) : std::string(tok);
        } else if (!saw_variant && is_bcp47_lyrics_variant(tok)) {
            saw_variant = true;
            canonical += "-";
            canonical += tok;
        } else {
            return std::nullopt;
        }
    }

    return canonical;
}

std::optional<std::string> parse_lyrics_tag_language(std::string_view raw_suffix, bool allow_uslt_fallback) {
    // 1. FFmpeg USLT with NUL/space-only language and empty description -> "lyrics-" / "lyrics-   "
    if (trim_ascii(raw_suffix).empty()) {
        return allow_uslt_fallback ? std::optional<std::string>("") : std::nullopt;
    }

    const std::string lower_raw = to_ascii_lower(raw_suffix);
    const std::string trimmed = trim_ascii(lower_raw);

    // 2. Strict BCP-47 across whole tag suffix (Vorbis/MP4, e.g., "zh-tw", "cmn-hant-tw", "eng", "und", "xxx")
    if (auto bcp47 = parse_strict_bcp47(trimmed); bcp47.has_value()) {
        return bcp47;
    }

    // 3. Real FFmpeg ID3v2 USLT format: "lyrics-<desc>-<lang>" (or "lyrics-<desc>-" / "lyrics-<desc>-   ")
    if (allow_uslt_fallback) {
        if (const size_t last_dash = lower_raw.rfind('-'); last_dash != std::string::npos && last_dash > 0) {
            const std::string_view tail_raw(lower_raw.data() + last_dash + 1, lower_raw.size() - last_dash - 1);
            const std::string tail = trim_ascii(tail_raw);
            if (tail.empty() || tail == "xxx" || tail == "und") {
                return std::string("");
            }
            if (tail == "zxx") {
                return std::nullopt;
            }
            if ((tail.size() == 3 && is_all_ascii_alpha(tail) && is_iso639_2_or_3(tail)) ||
                (tail.size() == 2 && is_all_ascii_alpha(tail) && is_iso639_1(tail))) {
                return tail;
            }
        }
    }

    // 4. Colon description fallback (e.g., "lyrics-en:us")
    if (const size_t colon = trimmed.find(':'); colon != std::string::npos) {
        const std::string prefix = trim_ascii(std::string_view(trimmed).substr(0, colon));
        if (auto bcp47 = parse_strict_bcp47(prefix); bcp47.has_value()) {
            return bcp47;
        }
    }

    return std::nullopt;
}

bool is_id3_container_format(std::string_view format_name) {
    static constexpr const char *ID3_FORMATS[] = {
        "aac", "aiff", "dsf", "mp3", "mpc", "mpc8", "tta", "wav"};
    size_t start = 0;
    while (start <= format_name.size()) {
        size_t sep = format_name.find(',', start);
        const std::string_view raw_tok = (sep == std::string_view::npos)
                                             ? format_name.substr(start)
                                             : format_name.substr(start, sep - start);
        const std::string tok = to_ascii_lower(trim_ascii(raw_tok));
        for (const char *id3_fmt : ID3_FORMATS) {
            if (tok == id3_fmt) {
                return true;
            }
        }
        if (sep == std::string_view::npos) {
            break;
        }
        start = sep + 1;
    }
    return false;
}

void collect_lyrics_from_tags_obj(
    const nlohmann::json &tags_obj,
    std::vector<EmbeddedLyricsTag> &out,
    bool container_supports_id3_uslt) {
    if (!tags_obj.is_object()) {
        return;
    }

    static constexpr const char *PREFIXES[] = {
        "lyrics-",
        "lyrics:",
        "unsyncedlyrics-",
        "unsyncedlyrics:",
        "syncedlyrics-",
        "syncedlyrics:",
    };

    for (auto it = tags_obj.begin(); it != tags_obj.end(); ++it) {
        if (!it.value().is_string()) {
            continue;
        }
        const std::string &val = it.value().get_ref<const std::string &>();
        if (val.find_first_not_of(" \t\r\n") == std::string::npos) {
            continue;
        }

        const std::string key = to_ascii_lower(it.key());
        std::optional<std::string> language;

        if (key == "lyrics" || key == "unsyncedlyrics" || key == "syncedlyrics") {
            language = "";
        } else {
            for (const char *prefix : PREFIXES) {
                const std::string_view pfx(prefix);
                const bool allow_uslt_fallback = container_supports_id3_uslt && (pfx == "lyrics-");
                const bool matches_prefix =
                    (allow_uslt_fallback ? key.size() >= pfx.size() : key.size() > pfx.size()) &&
                    key.compare(0, pfx.size(), pfx) == 0;
                if (matches_prefix) {
                    language = parse_lyrics_tag_language(std::string_view(key).substr(pfx.size()), allow_uslt_fallback);
                    break;
                }
            }
        }

        if (!language.has_value()) {
            continue;
        }

        bool duplicate = false;
        for (const auto &existing : out) {
            if (existing.language == *language && existing.content == val) {
                duplicate = true;
                break;
            }
        }
        if (!duplicate) {
            out.push_back(EmbeddedLyricsTag{val, *language});
        }
    }
}

std::vector<EmbeddedLyricsTag> extract_embedded_lyrics(const nlohmann::json &json_data) {
    std::vector<EmbeddedLyricsTag> lyrics;
    if (json_data.contains("format") && json_data["format"].is_object()) {
        const auto &fmt = json_data["format"];
        auto format_name = get_json_string(fmt, "format_name");
        const bool container_supports_id3_uslt = format_name.has_value() && is_id3_container_format(*format_name);
        if (fmt.contains("tags") && fmt["tags"].is_object()) {
            collect_lyrics_from_tags_obj(fmt["tags"], lyrics, container_supports_id3_uslt);
        }
    }
    if (json_data.contains("streams") && json_data["streams"].is_array()) {
        for (const auto &stream : json_data["streams"]) {
            auto codec_type = get_json_string(stream, "codec_type");
            if (codec_type && *codec_type == "audio") {
                if (stream.contains("tags") && stream["tags"].is_object()) {
                    collect_lyrics_from_tags_obj(stream["tags"], lyrics, false);
                }
            }
        }
    }
    return lyrics;
}

} // namespace

tl::expected<std::string, std::string> AudioHelper::calculate_pcm_hash(const std::string &filepath) {
    Sha256 sha;
    auto callback = [&sha](const uint8_t *data, size_t size) {
        sha.update(data, size);
    };

    std::vector<std::string> args = {
        "ffmpeg", "-v", "error", "-i", filepath, "-f", "s32le", "-acodec", "pcm_s32le", "-"};

    auto result = ProcessRunner::run(args, callback, 0);
    if (!result) {
        return tl::unexpected("Process execution failed: " + result.error());
    }

    if (result.value() != 0) {
        return tl::unexpected("ffmpeg exited with code: " + std::to_string(result.value()));
    }

    return sha.finalize();
}

// extract metadata from media file using ffprobe
tl::expected<MediaMetadata, std::string> AudioHelper::extract_metadata(const std::string &filepath) {
    std::string json_str;
    auto callback = [&json_str](const uint8_t *data, size_t size) {
        json_str.append(reinterpret_cast<const char *>(data), size);
    };

    std::vector<std::string> args = {
        "ffprobe", "-v", "error",
        "-show_entries", "format=format_name,duration,tags",
        "-show_entries", "format_tags",
        "-show_entries", "stream=sample_rate,channels,duration,disposition,width,height,codec_name,codec_type,tags:disposition=attached_pic",
        "-show_entries", "stream_tags",
        "-of", "json", filepath};

    // Limit output size to 2MB
    auto result = ProcessRunner::run(args, callback, 2 * 1024 * 1024);
    if (!result)
        return tl::unexpected("Process execution failed: " + result.error());

    if (result.value() != 0)
        return tl::unexpected("ffprobe exited with code: " + std::to_string(result.value()));

    nlohmann::json json_data;
    try {
        json_data = nlohmann::json::parse(json_str);
    } catch (const std::exception &e) {
        return tl::unexpected("Failed to parse JSON: " + std::string(e.what()));
    }

    MediaMetadata metadata;
    double audio_duration = 0.0;
    bool has_audio_duration = false;

    if (json_data.contains("streams") && json_data["streams"].is_array()) {
        for (const auto &stream : json_data["streams"]) {
            auto codec_type = get_json_string(stream, "codec_type");
            if (!codec_type)
                continue;

            if (*codec_type == "audio") {
                if (auto sr = get_json_int(stream, "sample_rate"); sr)
                    metadata.sample_rate = *sr;
                if (auto ch = get_json_int(stream, "channels"); ch)
                    metadata.channels = *ch;
                if (auto dur = get_json_double(stream, "duration"); dur) {
                    audio_duration = *dur;
                    has_audio_duration = true;
                }
            } else if (*codec_type == "video") {
                bool is_attached_pic = false;
                if (stream.contains("disposition") && stream["disposition"].is_object()) {
                    auto disp = stream["disposition"];
                    if (auto attached = get_json_int(disp, "attached_pic");
                        attached && *attached == 1) {
                        is_attached_pic = true;
                        metadata.has_cover_art = true;
                    }
                }
                if (!is_attached_pic) {
                    if (auto w = get_json_int(stream, "width"); w)
                        metadata.video_width = *w;
                    if (auto h = get_json_int(stream, "height"); h)
                        metadata.video_height = *h;
                    if (auto codec = get_json_string(stream, "codec_name");
                        codec)
                        metadata.video_codec = *codec;
                }
            }
        }
    }

    if (has_audio_duration) {
        metadata.duration = audio_duration;
    } else if (json_data.contains("format") && json_data["format"].is_object()) {
        if (auto fmt_dur = get_json_double(json_data["format"], "duration");
            fmt_dur) {
            metadata.duration = *fmt_dur;
        }
    }

    metadata.title = get_tag(json_data, "title");
    metadata.artist = get_tag(json_data, "artist");
    metadata.album = get_tag(json_data, "album");
    metadata.date = get_tag(json_data, "date");
    metadata.track = get_tag(json_data, "track");
    metadata.embedded_lyrics = extract_embedded_lyrics(json_data);

    return metadata;
}

tl::expected<std::vector<uint8_t>, std::string> AudioHelper::extract_cover_art(const std::string &filepath) {
    auto meta_res = extract_metadata(filepath);
    if (!meta_res) {
        return tl::unexpected("Metadata extraction failed: " + meta_res.error());
    }

    const auto &meta = meta_res.value();
    std::vector<std::string> args;

    if (meta.video_width.has_value() && meta.video_height.has_value()) {
        double seek_time = (meta.duration > 2.0) ? 2.0 : 0.0;
        std::stringstream ss;
        ss << std::fixed << std::setprecision(6) << seek_time;
        args = {"ffmpeg", "-v", "error", "-ss", ss.str(), "-i", filepath, "-an", "-vframes", "1", "-f", "image2pipe", "-"};
    } else if (meta.has_cover_art) {
        args = {"ffmpeg", "-v", "error", "-i", filepath, "-an", "-c:v", "copy", "-f", "image2pipe", "-"};
    } else {
        return tl::unexpected("No cover art or video stream found");
    }

    std::vector<uint8_t> buffer;
    auto callback = [&buffer](const uint8_t *data, size_t size) {
        buffer.insert(buffer.end(), data, data + size);
    };

    // Limit output to 10MB
    auto result = ProcessRunner::run(args, callback, 10 * 1024 * 1024);
    if (!result) {
        return tl::unexpected("Process execution failed: " + result.error());
    }

    if (result.value() != 0) {
        return tl::unexpected("ffmpeg exited with code: " + std::to_string(result.value()));
    }

    return buffer;
}

tl::expected<void, std::string> AudioHelper::extract_cover_art_to_file(const std::string &filepath, const std::string &output_image_path) {
    auto meta_res = extract_metadata(filepath);
    if (!meta_res) {
        return tl::unexpected("Metadata extraction failed: " + meta_res.error());
    }

    const auto &meta = meta_res.value();
    std::vector<std::string> args;

    if (meta.video_width.has_value() && meta.video_height.has_value()) {
        double seek_time = (meta.duration > 2.0) ? 2.0 : 0.0;
        std::stringstream ss;
        ss << std::fixed << std::setprecision(6) << seek_time;
        args = {"ffmpeg", "-v", "error", "-ss", ss.str(), "-i", filepath, "-an", "-vframes", "1", "-f", "image2pipe", "-"};
    } else if (meta.has_cover_art) {
        args = {"ffmpeg", "-v", "error", "-i", filepath, "-an", "-c:v", "copy", "-f", "image2pipe", "-"};
    } else {
        return tl::unexpected("No cover art or video stream found");
    }

    std::ofstream out(output_image_path, std::ios::binary);
    if (!out) {
        return tl::unexpected("Failed to open output image file for writing");
    }

    auto callback = [&out](const uint8_t *data, size_t size) {
        out.write(reinterpret_cast<const char *>(data), size);
    };

    // Limit to 10MB to prevent disk exhaustion DoS
    auto result = ProcessRunner::run(args, callback, 10 * 1024 * 1024);
    out.close();

    if (!result) {
        std::filesystem::remove(output_image_path);
        return tl::unexpected("Process execution failed or output limit exceeded: " + result.error());
    }

    if (result.value() != 0) {
        std::filesystem::remove(output_image_path);
        return tl::unexpected("ffmpeg exited with code: " + std::to_string(result.value()));
    }

    return {};
}

namespace {

bool ends_with_case_insensitive(std::string_view str, std::string_view suffix) {
    if (str.length() < suffix.length()) return false;
    auto str_suffix = str.substr(str.length() - suffix.length());
    return std::equal(str_suffix.begin(), str_suffix.end(), suffix.begin(), suffix.end(),
                      [](char a, char b) {
                          return std::tolower(static_cast<unsigned char>(a)) ==
                                 std::tolower(static_cast<unsigned char>(b));
                      });
}

bool contains_case_insensitive(std::string_view str, std::string_view sub) {
    if (sub.empty()) return true;
    if (str.length() < sub.length()) return false;
    auto it = std::search(
        str.begin(), str.end(),
        sub.begin(), sub.end(),
        [](char a, char b) {
            return std::tolower(static_cast<unsigned char>(a)) ==
                   std::tolower(static_cast<unsigned char>(b));
        });
    return it != str.end();
}

std::string extract_base_mime(std::string_view raw_mime) {
    std::string lower = to_ascii_lower(trim_ascii(raw_mime));
    if (const size_t semi = lower.find(';'); semi != std::string::npos) {
        lower = trim_ascii(std::string_view(lower).substr(0, semi));
    }
    return lower;
}

std::string normalize_audio_subtype(std::string_view raw_subtype) {
    if (raw_subtype.rfind("x-", 0) == 0) {
        return std::string(raw_subtype.substr(2));
    }
    return std::string(raw_subtype);
}

std::optional<std::string> detect_format_from_extension(std::string_view value) {
    const std::string trimmed = trim_ascii(value);
    if (trimmed.empty()) {
        return std::nullopt;
    }
    if (ends_with_case_insensitive(trimmed, ".flac")) return "FLAC";
    if (ends_with_case_insensitive(trimmed, ".mp3")) return "MP3";
    if (ends_with_case_insensitive(trimmed, ".wav")) return "WAV";
    if (ends_with_case_insensitive(trimmed, ".alac")) return "ALAC";
    if (ends_with_case_insensitive(trimmed, ".aiff") || ends_with_case_insensitive(trimmed, ".aif")) return "AIFF";
    if (ends_with_case_insensitive(trimmed, ".aac") || ends_with_case_insensitive(trimmed, ".m4a")) return "AAC";
    if (ends_with_case_insensitive(trimmed, ".ogg")) return "OGG";
    if (ends_with_case_insensitive(trimmed, ".opus")) return "OPUS";
    if (ends_with_case_insensitive(trimmed, ".webm")) return "WEBM";
    return std::nullopt;
}

std::optional<std::string> detect_format_from_audio_subtype(std::string_view subtype) {
    if (subtype == "flac") return "FLAC";
    if (subtype == "mp3" || subtype == "mpeg") return "MP3";
    if (subtype == "wav" || subtype == "wave") return "WAV";
    if (subtype == "alac") return "ALAC";
    if (subtype == "aiff" || subtype == "aif") return "AIFF";
    if (subtype == "aac" || subtype == "mp4" || subtype == "m4a") return "AAC";
    if (subtype == "ogg" || subtype == "vorbis") return "OGG";
    if (subtype == "opus") return "OPUS";
    if (subtype == "webm") return "WEBM";
    return std::nullopt;
}

bool is_lossless_format_name(std::string_view fmt) {
    return fmt == "FLAC" || fmt == "WAV" || fmt == "ALAC" || fmt == "AIFF";
}

bool is_asset_lossless(const Asset &asset) {
    const std::string base_mime = extract_base_mime(asset.mime_type);
    if (base_mime.rfind("audio/", 0) == 0) {
        const std::string sub = normalize_audio_subtype(std::string_view(base_mime).substr(6));
        if (!sub.empty() && sub != "octet-stream") {
            if (auto fmt = detect_format_from_audio_subtype(sub)) {
                return is_lossless_format_name(*fmt);
            }
            return false;
        }
        if (auto ext_fmt = detect_format_from_extension(asset.file_hash)) {
            return is_lossless_format_name(*ext_fmt);
        }
        return false;
    }

    if (base_mime == "application/ogg") {
        return false;
    }
    if (base_mime.empty() || base_mime == "application/octet-stream") {
        if (auto ext_fmt = detect_format_from_extension(asset.file_hash)) {
            return is_lossless_format_name(*ext_fmt);
        }
        return false;
    }
    if (base_mime.find('/') != std::string::npos) {
        return false;
    }

    for (std::string_view candidate : {std::string_view(base_mime), std::string_view(asset.file_hash)}) {
        if (auto ext_fmt = detect_format_from_extension(candidate)) {
            return is_lossless_format_name(*ext_fmt);
        }
    }
    return false;
}

std::string detect_asset_codec(const Asset *asset, bool is_lossless) {
    if (asset) {
        const std::string base_mime = extract_base_mime(asset->mime_type);
        if (base_mime.rfind("audio/", 0) == 0) {
            const std::string sub = normalize_audio_subtype(std::string_view(base_mime).substr(6));
            if (!sub.empty() && sub != "octet-stream") {
                if (auto fmt = detect_format_from_audio_subtype(sub); fmt && *fmt != "WEBM") {
                    return *fmt;
                }
                return is_lossless ? "FLAC" : "MP3";
            }
            if (auto ext_fmt = detect_format_from_extension(asset->file_hash);
                ext_fmt && *ext_fmt != "WEBM") {
                return *ext_fmt;
            }
            return is_lossless ? "FLAC" : "MP3";
        }

        if (base_mime == "application/ogg") {
            return "OGG";
        }
        if (base_mime.empty() || base_mime == "application/octet-stream") {
            if (auto ext_fmt = detect_format_from_extension(asset->file_hash);
                ext_fmt && *ext_fmt != "WEBM") {
                return *ext_fmt;
            }
            return is_lossless ? "FLAC" : "MP3";
        }
        if (base_mime.find('/') != std::string::npos) {
            return is_lossless ? "FLAC" : "MP3";
        }

        for (std::string_view candidate : {std::string_view(base_mime), std::string_view(asset->file_hash)}) {
            if (auto ext_fmt = detect_format_from_extension(candidate)) {
                return (*ext_fmt != "WEBM") ? *ext_fmt : (is_lossless ? "FLAC" : "MP3");
            }
        }
    }
    return is_lossless ? "FLAC" : "MP3";
}

} // namespace

AudioQualityInfo AudioHelper::evaluate_quality(const Audio &audio, const Asset &asset) {
    // 1. Bit Depth Score (0~25)
    int bit_depth_score = 0;
    if (audio.bit_depth >= 24) {
        bit_depth_score = 25;
    } else if (audio.bit_depth >= 16) {
        bit_depth_score = 18;
    } else {
        bit_depth_score = 8;
    }

    // 2. Sample Rate Score (0~25)
    int sample_rate_score = 0;
    if (audio.sample_rate >= 192000) {
        sample_rate_score = 25;
    } else if (audio.sample_rate >= 96000) {
        sample_rate_score = 22;
    } else if (audio.sample_rate >= 88200) {
        sample_rate_score = 20;
    } else if (audio.sample_rate >= 48000) {
        sample_rate_score = 16;
    } else if (audio.sample_rate >= 44100) {
        sample_rate_score = 15;
    } else {
        sample_rate_score = 10;
    }

    int resolution_score = bit_depth_score + sample_rate_score;

    // 3. Lossless / Bitrate Score (0~45)
    bool is_lossless = is_asset_lossless(asset);
    int lossless_bitrate_score = 0;
    if (is_lossless) {
        lossless_bitrate_score = 45;
    } else {
        double bitrate = 0.0;
        if (audio.duration > 0.0 && asset.file_size > 0) {
            bitrate = (static_cast<double>(asset.file_size) * 8.0) / audio.duration;
        }
        if (bitrate >= 320000.0) {
            lossless_bitrate_score = 30;
        } else if (bitrate >= 256000.0) {
            lossless_bitrate_score = 25;
        } else if (bitrate >= 192000.0) {
            lossless_bitrate_score = 18;
        } else if (bitrate >= 128000.0) {
            lossless_bitrate_score = 10;
        } else {
            lossless_bitrate_score = 5;
        }
    }

    // 4. Channels Score (0~5)
    int channels_score = 0;
    if (audio.channels >= 2) {
        channels_score = 5;
    } else if (audio.channels == 1) {
        channels_score = 2;
    } else {
        channels_score = 0;
    }

    int total_quality_score = resolution_score + lossless_bitrate_score + channels_score;

    // 5. Format string formatting
    std::string codec = detect_asset_codec(&asset, is_lossless);

    int bit_depth = audio.bit_depth > 0 ? audio.bit_depth : 16;
    std::string bit_depth_str = std::to_string(bit_depth) + "-bit";

    int sample_rate = audio.sample_rate > 0 ? audio.sample_rate : 44100;
    std::string sample_rate_str;
    if (sample_rate % 1000 == 0) {
        sample_rate_str = std::to_string(sample_rate / 1000) + "kHz";
    } else {
        std::ostringstream ss;
        ss << (sample_rate / 1000.0) << "kHz";
        sample_rate_str = ss.str();
    }

    std::string format_str = codec + " " + bit_depth_str + " / " + sample_rate_str;

    AudioQualityInfo result;
    result.quality_score = total_quality_score;
    result.is_lossless = is_lossless;
    result.format = format_str;
    result.file_size = asset.file_size;

    return result;
}

AudioQualityInfo AudioHelper::evaluate_quality(const Audio &audio) {
    if (audio.assets.empty()) {
        Asset default_asset;
        return evaluate_quality(audio, default_asset);
    }

    const Asset *primary_asset = nullptr;
    bool any_lossless = false;

    for (const auto &asset : audio.assets) {
        bool current_lossless = is_asset_lossless(asset);
        if (current_lossless) {
            any_lossless = true;
        }

        if (!primary_asset) {
            primary_asset = &asset;
            continue;
        }

        if (bool primary_is_lossless = is_asset_lossless(*primary_asset);
            current_lossless && !primary_is_lossless) {
            primary_asset = &asset;
        } else if (current_lossless == primary_is_lossless) {
            if (asset.file_size > primary_asset->file_size) {
                primary_asset = &asset;
            }
        }
    }

    auto qinfo = evaluate_quality(audio, *primary_asset);
    if (any_lossless) {
        qinfo.is_lossless = true;
    }
    return qinfo;
}

bool AudioHelper::matches_format(const Asset &asset, const std::string &preferred_format) {
    if (preferred_format.empty()) {
        return false;
    }
    std::string fmt = preferred_format;
    std::transform(fmt.begin(), fmt.end(), fmt.begin(), [](unsigned char c) {
        return std::tolower(c);
    });
    if (!fmt.empty() && fmt.front() == '.') {
        fmt.erase(0, 1);
    }
    if (fmt.rfind("audio/", 0) == 0) {
        fmt.erase(0, 6);
    }
    if (fmt.rfind("x-", 0) == 0) {
        fmt.erase(0, 2);
    }

    const std::string &mime = asset.mime_type;
    const std::string &hash = asset.file_hash;

    if (fmt == "flac") {
        return contains_case_insensitive(mime, "audio/flac") ||
               ends_with_case_insensitive(mime, ".flac") ||
               ends_with_case_insensitive(hash, ".flac");
    }
    if (fmt == "wav") {
        return contains_case_insensitive(mime, "audio/wav") ||
               contains_case_insensitive(mime, "audio/x-wav") ||
               ends_with_case_insensitive(mime, ".wav") ||
               ends_with_case_insensitive(hash, ".wav");
    }
    if (fmt == "mp3" || fmt == "mpeg") {
        return contains_case_insensitive(mime, "audio/mp3") ||
               contains_case_insensitive(mime, "audio/mpeg") ||
               ends_with_case_insensitive(mime, ".mp3") ||
               ends_with_case_insensitive(hash, ".mp3");
    }
    if (fmt == "alac") {
        return contains_case_insensitive(mime, "audio/alac") ||
               ends_with_case_insensitive(mime, ".alac") ||
               ends_with_case_insensitive(hash, ".alac");
    }
    if (fmt == "aiff" || fmt == "aif") {
        return contains_case_insensitive(mime, "audio/aiff") ||
               contains_case_insensitive(mime, "audio/x-aiff") ||
               ends_with_case_insensitive(mime, ".aiff") ||
               ends_with_case_insensitive(hash, ".aiff") ||
               ends_with_case_insensitive(mime, ".aif") ||
               ends_with_case_insensitive(hash, ".aif");
    }
    if (fmt == "ogg" || fmt == "vorbis") {
        return contains_case_insensitive(mime, "audio/ogg") ||
               contains_case_insensitive(mime, "audio/vorbis") ||
               ends_with_case_insensitive(mime, ".ogg") ||
               ends_with_case_insensitive(hash, ".ogg");
    }
    if (fmt == "m4a") {
        return contains_case_insensitive(mime, "audio/m4a") ||
               contains_case_insensitive(mime, "audio/mp4") ||
               ends_with_case_insensitive(mime, ".m4a") ||
               ends_with_case_insensitive(hash, ".m4a");
    }
    if (fmt == "aac") {
        return contains_case_insensitive(mime, "audio/aac") ||
               contains_case_insensitive(mime, "audio/m4a") ||
               contains_case_insensitive(mime, "audio/mp4") ||
               ends_with_case_insensitive(mime, ".aac") ||
               ends_with_case_insensitive(hash, ".aac") ||
               ends_with_case_insensitive(mime, ".m4a") ||
               ends_with_case_insensitive(hash, ".m4a");
    }

    return contains_case_insensitive(mime, fmt) ||
           ends_with_case_insensitive(mime, "." + fmt) ||
           ends_with_case_insensitive(hash, "." + fmt);
}

std::optional<std::string> AudioHelper::format_from_mime_type(
    std::string_view mime_type,
    std::string_view file_hash) {
    const std::string base_mime = extract_base_mime(mime_type);
    if (base_mime.rfind("audio/", 0) == 0) {
        const std::string sub = normalize_audio_subtype(std::string_view(base_mime).substr(6));
        if (sub.empty() || sub == "octet-stream") {
            return detect_format_from_extension(file_hash);
        }
        if (auto known = detect_format_from_audio_subtype(sub)) {
            return known;
        }
        return to_ascii_upper(sub);
    }

    if (base_mime == "application/ogg") {
        return "OGG";
    }
    if (base_mime.empty() || base_mime == "application/octet-stream") {
        return detect_format_from_extension(file_hash);
    }
    if (base_mime.find('/') != std::string::npos) {
        // Ignore non-audio MIME types such as image/*, text/*, or video/*.
        return std::nullopt;
    }

    if (auto ext_fmt = detect_format_from_extension(base_mime)) {
        return ext_fmt;
    }
    return detect_format_from_extension(file_hash);
}

} // namespace utils
} // namespace lyra

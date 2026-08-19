/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#include "../src/models/album.h"
#include "../src/models/artist.h"
#include "../src/models/asset.h"
#include "../src/models/image.h"
#include "../src/models/playlist.h"
#include "../src/models/relation_types.h"
#include "../src/models/track.h"
#include "../src/services/cover_art_service.h"
#include "../src/services/database_context.h"
#include "../src/services/repositories/sqlite/sqlite_album_repository.h"
#include "../src/services/repositories/sqlite/sqlite_artist_repository.h"
#include "../src/services/repositories/sqlite/sqlite_asset_repository.h"
#include "../src/services/repositories/sqlite/sqlite_image_repository.h"
#include "../src/services/repositories/sqlite/sqlite_playlist_repository.h"
#include "../src/services/repositories/sqlite/sqlite_track_repository.h"
#include "../src/utils/storage_helper.h"
#include <cassert>
#include <filesystem>
#include <fstream>
#include <iostream>

using namespace lyra;

namespace {

void create_dummy_file(const std::string &filepath) {
    std::ofstream out(filepath, std::ios::binary);
    out << "dummy image data";
    out.close();
}

} // namespace

bool test_album_cover(const std::string &temp_dir) {
    std::cout << "Running test_album_cover..." << std::endl;
    std::string db_path = (std::filesystem::path(temp_dir) / "test_album.db").string();
    SqliteDatabaseContext ctx(db_path);

    SqliteAlbumRepository album_repo(ctx);
    SqliteArtistRepository artist_repo(ctx);
    SqliteAssetRepository asset_repo(ctx);
    SqliteImageRepository image_repo(ctx);
    SqlitePlaylistRepository playlist_repo(ctx);
    SqliteTrackRepository track_repo(ctx);

    CoverArtService service(image_repo, track_repo, album_repo, artist_repo, playlist_repo, asset_repo, temp_dir);

    // 1. Non-existent album
    auto res_err = service.get_album_cover("non-existent-album-id");
    assert(!res_err.has_value());
    assert(res_err.error().type == ErrorType::NotFound);

    // 2. Create album
    Album album;
    album.id = "album-1";
    album.title = "Test Album 1";
    assert(album_repo.insert(album).has_value());

    // Album without cover -> 404
    auto res_empty = service.get_album_cover("album-1");
    assert(!res_empty.has_value());
    assert(res_empty.error().type == ErrorType::NotFound);

    // 3. Create Asset & Image & link to album
    std::string file_hash = "1111111111111111111111111111111111111111111111111111111111111111";
    std::string img_hash = "img-album-1";

    Asset asset;
    asset.file_hash = file_hash;
    asset.mime_type = "image/jpeg";
    asset.asset_type = "image";
    asset.file_size = 12345;
    assert(asset_repo.insert(asset).has_value());

    auto cas_path = utils::StorageHelper::resolve_cas_path(temp_dir, file_hash, ".jpg");
    create_dummy_file(cas_path.string());

    Image img;
    img.image_hash = img_hash;
    img.file_hash = file_hash;
    img.width = 500;
    img.height = 500;
    img.dominant_color = "#FFFFFF";
    assert(image_repo.insert(img).has_value());
    assert(image_repo.link_entity(album.id, img.image_hash, "front").has_value());

    // 4. Call get_album_cover
    auto res_ok = service.get_album_cover("album-1");
    assert(res_ok.has_value());
    assert(res_ok.value().image_hash == img_hash);
    assert(res_ok.value().file_hash == file_hash);
    assert(res_ok.value().mime_type == "image/jpeg");
    assert(res_ok.value().source_entity_type == "album");
    assert(res_ok.value().source_entity_id == "album-1");
    assert(res_ok.value().width == 500);
    assert(res_ok.value().height == 500);

    std::cout << "test_album_cover: SUCCESS" << std::endl;
    return true;
}

bool test_track_cover_and_fallback(const std::string &temp_dir) {
    std::cout << "Running test_track_cover_and_fallback..." << std::endl;
    std::string db_path = (std::filesystem::path(temp_dir) / "test_track.db").string();
    SqliteDatabaseContext ctx(db_path);

    SqliteAlbumRepository album_repo(ctx);
    SqliteArtistRepository artist_repo(ctx);
    SqliteAssetRepository asset_repo(ctx);
    SqliteImageRepository image_repo(ctx);
    SqlitePlaylistRepository playlist_repo(ctx);
    SqliteTrackRepository track_repo(ctx);

    CoverArtService service(image_repo, track_repo, album_repo, artist_repo, playlist_repo, asset_repo, temp_dir);

    // 1. Non-existent track
    auto res_err = service.get_track_cover("non-existent-track-id");
    assert(!res_err.has_value());
    assert(res_err.error().type == ErrorType::NotFound);

    // 2. Create Album & Album cover
    Album album;
    album.id = "album-track-test";
    album.title = "Album For Track Test";
    assert(album_repo.insert(album).has_value());

    std::string album_file_hash = "2222222222222222222222222222222222222222222222222222222222222222";
    std::string album_img_hash = "img-album-cover";

    Asset album_asset;
    album_asset.file_hash = album_file_hash;
    album_asset.mime_type = "image/png";
    album_asset.asset_type = "image";
    assert(asset_repo.insert(album_asset).has_value());

    auto album_cas_path = utils::StorageHelper::resolve_cas_path(temp_dir, album_file_hash, ".png");
    create_dummy_file(album_cas_path.string());

    Image album_img;
    album_img.image_hash = album_img_hash;
    album_img.file_hash = album_file_hash;
    album_img.width = 600;
    album_img.height = 600;
    assert(image_repo.insert(album_img).has_value());
    assert(image_repo.link_entity(album.id, album_img.image_hash, "front").has_value());

    // 3. Create Track 1 (with direct cover)
    Track track1;
    track1.id = "track-1-direct";
    track1.title = "Track 1 Direct";
    track1.pcm_hash = "pcm-1";
    assert(track_repo.insert(track1).has_value());

    std::string track_file_hash = "3333333333333333333333333333333333333333333333333333333333333333";
    std::string track_img_hash = "img-track-1";

    Asset track_asset;
    track_asset.file_hash = track_file_hash;
    track_asset.mime_type = "image/jpeg";
    track_asset.asset_type = "image";
    assert(asset_repo.insert(track_asset).has_value());

    auto track_cas_path = utils::StorageHelper::resolve_cas_path(temp_dir, track_file_hash, ".jpg");
    create_dummy_file(track_cas_path.string());

    Image track_img;
    track_img.image_hash = track_img_hash;
    track_img.file_hash = track_file_hash;
    track_img.width = 300;
    track_img.height = 300;
    assert(image_repo.insert(track_img).has_value());
    assert(image_repo.link_entity(track1.id, track_img.image_hash, "front").has_value());

    auto res_track1 = service.get_track_cover(track1.id);
    assert(res_track1.has_value());
    assert(res_track1.value().image_hash == track_img_hash);
    assert(res_track1.value().source_entity_type == "track");
    assert(res_track1.value().source_entity_id == track1.id);

    // 4. Create Track 2 (no direct cover, linked to album)
    Track track2;
    track2.id = "track-2-fallback";
    track2.title = "Track 2 Fallback";
    track2.pcm_hash = "pcm-2";
    assert(track_repo.insert(track2).has_value());

    TrackAlbumParams ta_params;
    ta_params.track_id = track2.id;
    ta_params.album_id = album.id;
    ta_params.position = 1;
    assert(track_repo.add_album(ta_params).has_value());

    auto res_track2 = service.get_track_cover(track2.id);
    assert(res_track2.has_value());
    assert(res_track2.value().image_hash == album_img_hash);
    assert(res_track2.value().source_entity_type == "album");
    assert(res_track2.value().source_entity_id == album.id);

    std::cout << "test_track_cover_and_fallback: SUCCESS" << std::endl;
    return true;
}

bool test_artist_cover(const std::string &temp_dir) {
    std::cout << "Running test_artist_cover..." << std::endl;
    std::string db_path = (std::filesystem::path(temp_dir) / "test_artist.db").string();
    SqliteDatabaseContext ctx(db_path);

    SqliteAlbumRepository album_repo(ctx);
    SqliteArtistRepository artist_repo(ctx);
    SqliteAssetRepository asset_repo(ctx);
    SqliteImageRepository image_repo(ctx);
    SqlitePlaylistRepository playlist_repo(ctx);
    SqliteTrackRepository track_repo(ctx);

    CoverArtService service(image_repo, track_repo, album_repo, artist_repo, playlist_repo, asset_repo, temp_dir);

    // 1. Non-existent artist -> ArtistNotFound
    auto res_err = service.get_artist_cover("non-existent-artist");
    assert(!res_err.has_value());
    assert(res_err.error().type == ErrorType::ArtistNotFound);

    // 2. Create Artist
    Artist artist;
    artist.id = "artist-1";
    artist.name = "Test Artist";
    assert(artist_repo.insert(artist).has_value());

    // Artist with no cover -> NotFound
    auto res_empty = service.get_artist_cover("artist-1");
    assert(!res_empty.has_value());
    assert(res_empty.error().type == ErrorType::NotFound);

    // 3. Fallback to latest album cover
    Album album;
    album.id = "album-artist-test";
    album.title = "Artist Album";
    album.release_year = 2024;
    album.release_month = 1;
    album.release_day = 1;
    assert(album_repo.insert(album).has_value());

    std::string album_file_hash = "4444444444444444444444444444444444444444444444444444444444444444";
    std::string album_img_hash = "img-artist-album";

    Asset album_asset;
    album_asset.file_hash = album_file_hash;
    album_asset.mime_type = "image/jpeg";
    album_asset.asset_type = "image";
    assert(asset_repo.insert(album_asset).has_value());

    auto album_cas_path = utils::StorageHelper::resolve_cas_path(temp_dir, album_file_hash, ".jpg");
    create_dummy_file(album_cas_path.string());

    Image album_img;
    album_img.image_hash = album_img_hash;
    album_img.file_hash = album_file_hash;
    album_img.width = 400;
    album_img.height = 400;
    assert(image_repo.insert(album_img).has_value());
    assert(image_repo.link_entity(album.id, album_img.image_hash, "front").has_value());

    Track track;
    track.id = "track-artist-test";
    track.title = "Artist Track";
    track.pcm_hash = "pcm-artist-track";
    assert(track_repo.insert(track).has_value());

    TrackAlbumParams ta;
    ta.track_id = track.id;
    ta.album_id = album.id;
    assert(track_repo.add_album(ta).has_value());

    TrackArtistParams tar;
    tar.track_id = track.id;
    tar.artist_id = artist.id;
    tar.role = ArtistRole::Main;
    assert(track_repo.add_artist(tar).has_value());

    auto res_fallback = service.get_artist_cover("artist-1");
    assert(res_fallback.has_value());
    assert(res_fallback.value().image_hash == album_img_hash);

    // 4. Direct artist avatar
    std::string avatar_file_hash = "5555555555555555555555555555555555555555555555555555555555555555";
    std::string avatar_img_hash = "img-artist-avatar";

    Asset avatar_asset;
    avatar_asset.file_hash = avatar_file_hash;
    avatar_asset.mime_type = "image/png";
    avatar_asset.asset_type = "image";
    assert(asset_repo.insert(avatar_asset).has_value());

    auto avatar_cas_path = utils::StorageHelper::resolve_cas_path(temp_dir, avatar_file_hash, ".png");
    create_dummy_file(avatar_cas_path.string());

    Image avatar_img;
    avatar_img.image_hash = avatar_img_hash;
    avatar_img.file_hash = avatar_file_hash;
    avatar_img.width = 250;
    avatar_img.height = 250;
    assert(image_repo.insert(avatar_img).has_value());
    assert(image_repo.link_entity(artist.id, avatar_img.image_hash, "artist_avatar").has_value());

    auto res_avatar = service.get_artist_cover("artist-1");
    assert(res_avatar.has_value());
    assert(res_avatar.value().image_hash == avatar_img_hash);
    assert(res_avatar.value().source_entity_type == "artist");

    std::cout << "test_artist_cover: SUCCESS" << std::endl;
    return true;
}

bool test_playlist_cover(const std::string &temp_dir) {
    std::cout << "Running test_playlist_cover..." << std::endl;
    std::string db_path = (std::filesystem::path(temp_dir) / "test_playlist.db").string();
    SqliteDatabaseContext ctx(db_path);

    SqliteAlbumRepository album_repo(ctx);
    SqliteArtistRepository artist_repo(ctx);
    SqliteAssetRepository asset_repo(ctx);
    SqliteImageRepository image_repo(ctx);
    SqlitePlaylistRepository playlist_repo(ctx);
    SqliteTrackRepository track_repo(ctx);

    CoverArtService service(image_repo, track_repo, album_repo, artist_repo, playlist_repo, asset_repo, temp_dir);

    // 1. Non-existent playlist -> PlaylistNotFound
    auto res_err = service.get_playlist_cover("non-existent-playlist");
    assert(!res_err.has_value());
    assert(res_err.error().type == ErrorType::PlaylistNotFound);

    // 2. Empty playlist -> NotFound
    Playlist playlist;
    playlist.id = "pl-1";
    playlist.title = "Test Playlist";
    assert(playlist_repo.insert(playlist).has_value());

    auto res_empty = service.get_playlist_cover("pl-1");
    assert(!res_empty.has_value());
    assert(res_empty.error().type == ErrorType::NotFound);

    // 3. Add track with cover to playlist
    Track track;
    track.id = "track-pl";
    track.title = "Track Playlist";
    track.pcm_hash = "pcm-pl";
    assert(track_repo.insert(track).has_value());

    std::string track_file_hash = "6666666666666666666666666666666666666666666666666666666666666666";
    std::string track_img_hash = "img-track-pl";

    Asset track_asset;
    track_asset.file_hash = track_file_hash;
    track_asset.mime_type = "image/jpeg";
    track_asset.asset_type = "image";
    assert(asset_repo.insert(track_asset).has_value());

    auto track_cas_path = utils::StorageHelper::resolve_cas_path(temp_dir, track_file_hash, ".jpg");
    create_dummy_file(track_cas_path.string());

    Image track_img;
    track_img.image_hash = track_img_hash;
    track_img.file_hash = track_file_hash;
    track_img.width = 400;
    track_img.height = 400;
    assert(image_repo.insert(track_img).has_value());
    assert(image_repo.link_entity(track.id, track_img.image_hash, "front").has_value());

    assert(playlist_repo.add_track(playlist.id, track.id, 1).has_value());

    auto res_pl_track = service.get_playlist_cover("pl-1");
    assert(res_pl_track.has_value());
    assert(res_pl_track.value().image_hash == track_img_hash);

    // 4. Direct playlist image
    std::string pl_file_hash = "7777777777777777777777777777777777777777777777777777777777777777";
    std::string pl_img_hash = "img-playlist-direct";

    Asset pl_asset;
    pl_asset.file_hash = pl_file_hash;
    pl_asset.mime_type = "image/webp";
    pl_asset.asset_type = "image";
    assert(asset_repo.insert(pl_asset).has_value());

    auto pl_cas_path = utils::StorageHelper::resolve_cas_path(temp_dir, pl_file_hash, ".webp");
    create_dummy_file(pl_cas_path.string());

    Image pl_img;
    pl_img.image_hash = pl_img_hash;
    pl_img.file_hash = pl_file_hash;
    pl_img.width = 800;
    pl_img.height = 800;
    assert(image_repo.insert(pl_img).has_value());
    assert(image_repo.link_entity(playlist.id, pl_img.image_hash, "front").has_value());

    auto res_pl_direct = service.get_playlist_cover("pl-1");
    assert(res_pl_direct.has_value());
    assert(res_pl_direct.value().image_hash == pl_img_hash);
    assert(res_pl_direct.value().source_entity_type == "playlist");

    std::cout << "test_playlist_cover: SUCCESS" << std::endl;
    return true;
}

bool test_entity_images(const std::string &temp_dir) {
    std::cout << "Running test_entity_images..." << std::endl;
    std::string db_path = (std::filesystem::path(temp_dir) / "test_entity.db").string();
    SqliteDatabaseContext ctx(db_path);

    SqliteAlbumRepository album_repo(ctx);
    SqliteArtistRepository artist_repo(ctx);
    SqliteAssetRepository asset_repo(ctx);
    SqliteImageRepository image_repo(ctx);
    SqlitePlaylistRepository playlist_repo(ctx);
    SqliteTrackRepository track_repo(ctx);

    CoverArtService service(image_repo, track_repo, album_repo, artist_repo, playlist_repo, asset_repo, temp_dir);

    // 1. Non-existent entity -> NotFound
    auto res_err = service.get_entity_images("non-existent-entity");
    assert(!res_err.has_value());
    assert(res_err.error().type == ErrorType::NotFound);

    // 2. Create Track and link two images
    Track track;
    track.id = "track-entity-test";
    track.title = "Entity Test Track";
    track.pcm_hash = "pcm-entity-track";
    assert(track_repo.insert(track).has_value());

    // Front image
    std::string front_file_hash = "8888888888888888888888888888888888888888888888888888888888888888";
    std::string front_img_hash = "img-front";
    Asset front_asset;
    front_asset.file_hash = front_file_hash;
    front_asset.mime_type = "image/jpeg";
    front_asset.asset_type = "image";
    assert(asset_repo.insert(front_asset).has_value());
    auto front_path = utils::StorageHelper::resolve_cas_path(temp_dir, front_file_hash, ".jpg");
    create_dummy_file(front_path.string());

    Image front_img;
    front_img.image_hash = front_img_hash;
    front_img.file_hash = front_file_hash;
    front_img.width = 500;
    front_img.height = 500;
    assert(image_repo.insert(front_img).has_value());
    assert(image_repo.link_entity(track.id, front_img.image_hash, "front").has_value());

    // Back image
    std::string back_file_hash = "9999999999999999999999999999999999999999999999999999999999999999";
    std::string back_img_hash = "img-back";
    Asset back_asset;
    back_asset.file_hash = back_file_hash;
    back_asset.mime_type = "image/png";
    back_asset.asset_type = "image";
    assert(asset_repo.insert(back_asset).has_value());
    auto back_path = utils::StorageHelper::resolve_cas_path(temp_dir, back_file_hash, ".png");
    create_dummy_file(back_path.string());

    Image back_img;
    back_img.image_hash = back_img_hash;
    back_img.file_hash = back_file_hash;
    back_img.width = 600;
    back_img.height = 600;
    assert(image_repo.insert(back_img).has_value());
    assert(image_repo.link_entity(track.id, back_img.image_hash, "back").has_value());

    // Query all
    auto res_all = service.get_entity_images(track.id);
    assert(res_all.has_value());
    assert(res_all.value().size() == 2);

    // Query role "front"
    auto res_front = service.get_entity_images(track.id, "front");
    assert(res_front.has_value());
    assert(res_front.value().size() == 1);
    assert(res_front.value()[0].image_hash == front_img_hash);

    // Query non-matching role
    auto res_avatar = service.get_entity_images(track.id, "artist_avatar");
    assert(res_avatar.has_value());
    assert(res_avatar.value().empty());

    std::cout << "test_entity_images: SUCCESS" << std::endl;
    return true;
}

int main(int argc, char *argv[]) {
    std::string temp_dir = "./temp_cover_art_test_dir";
    if (argc > 1) {
        temp_dir = argv[1];
    }
    std::filesystem::create_directories(temp_dir);

    std::cout << "=== Running CoverArtService C++ Unit Tests ===" << std::endl;

    assert(test_album_cover(temp_dir));
    assert(test_track_cover_and_fallback(temp_dir));
    assert(test_artist_cover(temp_dir));
    assert(test_playlist_cover(temp_dir));
    assert(test_entity_images(temp_dir));

    std::cout << "ALL_COVER_ART_SERVICE_TESTS_PASSED" << std::endl;
    return 0;
}

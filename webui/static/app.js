/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

/**
 * Lyra Web UI - Frontend Application
 * Single Page Application managing music playback, asset browsing, and C++ Core dispatching.
 */

class LyraApp {
  constructor() {
    this.apiBase = '/api/dispatch';
    this.currentView = 'tracks';
    this.searchQuery = '';
    this.playbackMode = localStorage.getItem('lyra_playback_mode') || 'browser'; // 'browser' | 'core'

    // Pagination
    this.tracksPage = 1;
    this.tracksLimit = 25;
    this.tracksTotal = 0;

    // Data Cache
    this.tracks = [];
    this.albums = [];
    this.artists = [];
    this.playlists = [];
    this.currentDetail = null; // { type, id, data, tracks }

    // Playback State
    this.currentTrack = null;
    this.queue = [];
    this.queueIndex = -1;
    this.isPlaying = false;
    this.isMuted = false;
    this.volume = parseFloat(localStorage.getItem('lyra_volume') || '0.8');
    this.isShuffled = false;
    this.repeatMode = 'off'; // 'off' | 'all' | 'one'

    // Audio Elements
    this.audioElement = new Audio();
    this.corePollTimer = null;
    this.searchDebounceTimer = null;

    this.init();
  }

  init() {
    this.setupAudioListeners();
    this.setupUIEventListeners();
    this.setupKeyboardShortcuts();
    this.setPlaybackMode(this.playbackMode);
    this.setVolume(this.volume);

    // Initial Data Fetch
    this.checkHealth();
    this.loadTracks();
    this.loadAlbums();
    this.loadArtists();
    this.loadPlaylists();
  }

  // =========================================================================
  // API Communication
  // =========================================================================

  async dispatch(command, params = {}) {
    try {
      const response = await fetch(this.apiBase, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ command, params }),
      });

      if (!response.ok) {
        throw new Error(`HTTP Error ${response.status}: ${response.statusText}`);
      }

      const result = await response.json();
      return result;
    } catch (err) {
      console.error(`API Error on [${command}]:`, err);
      this.showToast(`API Error: ${err.message}`, 'error');
      throw err;
    }
  }

  async checkHealth() {
    try {
      const res = await fetch('/api/health');
      if (res.ok) {
        document.getElementById('systemStatusPill').className = 'status-pill online';
        document.querySelector('#systemStatusPill .status-text').textContent = 'Online';
      } else {
        document.getElementById('systemStatusPill').className = 'status-pill';
        document.querySelector('#systemStatusPill .status-text').textContent = 'Offline';
      }
    } catch {
      document.getElementById('systemStatusPill').className = 'status-pill';
      document.querySelector('#systemStatusPill .status-text').textContent = 'Offline';
    }
  }

  // =========================================================================
  // Data Loading & View Rendering
  // =========================================================================

  async loadTracks(page = 1) {
    this.tracksPage = page;
    const offset = (page - 1) * this.tracksLimit;
    const params = {
      offset: offset,
      limit: this.tracksLimit,
    };
    if (this.searchQuery && this.searchQuery.trim() !== '') {
      params.search = this.searchQuery.trim();
    }

    try {
      const res = await this.dispatch('ListTracks', params);
      if (res.code === 200 && res.data) {
        this.tracks = res.data.items || [];
        this.tracksTotal = res.data.total || 0;
        this.renderTracksTable();
        this.renderPagination();
        document.getElementById('badgeTracksCount').textContent = this.tracksTotal;
        document.getElementById('tracksSubtext').textContent = `${this.tracksTotal} tracks in library`;
      }
    } catch (err) {
      console.error('Failed to load tracks:', err);
    }
  }

  async loadAlbums() {
    try {
      const res = await this.dispatch('ListAlbums', { limit: 100 });
      if (res.code === 200 && res.data) {
        this.albums = res.data.items || [];
        document.getElementById('badgeAlbumsCount').textContent = res.data.total || this.albums.length;
        document.getElementById('albumsSubtext').textContent = `${this.albums.length} albums in library`;
        this.renderAlbumsGrid();
      }
    } catch (err) {
      console.error('Failed to load albums:', err);
    }
  }

  async loadArtists() {
    try {
      const res = await this.dispatch('ListArtists', { limit: 100 });
      if (res.code === 200 && res.data) {
        this.artists = res.data.items || [];
        document.getElementById('badgeArtistsCount').textContent = res.data.total || this.artists.length;
        document.getElementById('artistsSubtext').textContent = `${this.artists.length} artists in library`;
        this.renderArtistsGrid();
      }
    } catch (err) {
      console.error('Failed to load artists:', err);
    }
  }

  async loadPlaylists() {
    try {
      const res = await this.dispatch('ListPlaylists', { limit: 100 });
      if (res.code === 200 && res.data) {
        this.playlists = res.data.items || [];
        document.getElementById('badgePlaylistsCount').textContent = res.data.total || this.playlists.length;
        document.getElementById('playlistsSubtext').textContent = `${this.playlists.length} playlists created`;
        this.renderPlaylistsGrid();
      }
    } catch (err) {
      console.error('Failed to load playlists:', err);
    }
  }

  renderTracksTable() {
    const tbody = document.getElementById('tracksTableBody');
    const empty = document.getElementById('tracksEmptyState');

    if (!this.tracks || this.tracks.length === 0) {
      tbody.innerHTML = '';
      empty.style.display = 'block';
      return;
    }
    empty.style.display = 'none';

    const offset = (this.tracksPage - 1) * this.tracksLimit;
    tbody.innerHTML = this.tracks
      .map((track, idx) => {
        const isCurrent = this.currentTrack && this.currentTrack.id === track.id;
        const durationStr = this.formatDuration(track.duration);
        const title = this.escapeHtml(track.title || 'Untitled Track');
        const artist = this.escapeHtml(track.artist_name || track.artist || 'Unknown Artist');
        const album = this.escapeHtml(track.album_title || track.album || '—');

        return `
          <tr class="${isCurrent ? 'active-track' : ''}" data-track-id="${track.id}">
            <td class="col-num">${offset + idx + 1}</td>
            <td class="col-cover">
              <img class="table-cover-thumb" src="/api/cover/${track.id}" loading="lazy" alt="" />
            </td>
            <td class="col-title">
              <div class="track-title-cell">
                <span class="track-main-title">${title}</span>
                <span class="track-sub-artist">${artist}</span>
              </div>
            </td>
            <td class="col-artist">${artist}</td>
            <td class="col-album">${album}</td>
            <td class="col-duration">${durationStr}</td>
            <td class="col-actions">
              <div class="action-btn-group">
                <button class="table-btn" title="Play Track" onclick="app.playTrackById('${track.id}')">
                  <svg viewBox="0 0 20 20" width="14" height="14" fill="currentColor"><path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM9.555 7.168A1 1 0 008 8v4a1 1 0 001.555.832l3-2a1 1 0 000-1.664l-3-2z" clip-rule="evenodd"/></svg>
                </button>
                <button class="table-btn" title="Add to Queue" onclick="app.addToQueueById('${track.id}')">
                  <svg viewBox="0 0 20 20" width="14" height="14" fill="currentColor"><path fill-rule="evenodd" d="M10 3a1 1 0 011 1v5h5a1 1 0 110 2h-5v5a1 1 0 11-2 0v-5H4a1 1 0 110-2h5V4a1 1 0 011-1z" clip-rule="evenodd"/></svg>
                </button>
                <button class="table-btn" title="Add to Playlist" onclick="app.openAddToPlaylistModal('${track.id}', '${title}')">
                  <svg viewBox="0 0 20 20" width="14" height="14" fill="currentColor"><path d="M7 3a1 1 0 000 2h6a1 1 0 100-2H7zM4 7a1 1 0 011-1h10a1 1 0 110 2H5a1 1 0 01-1-1zM2 11a2 2 0 012-2h12a2 2 0 012 2v4a2 2 0 01-2 2H4a2 2 0 01-2-2v-4z"/></svg>
                </button>
              </div>
            </td>
          </tr>
        `;
      })
      .join('');
  }

  renderPagination() {
    const totalPages = Math.ceil(this.tracksTotal / this.tracksLimit) || 1;
    const startIdx = this.tracksTotal === 0 ? 0 : (this.tracksPage - 1) * this.tracksLimit + 1;
    const endIdx = Math.min(this.tracksPage * this.tracksLimit, this.tracksTotal);

    document.getElementById('pageStartIdx').textContent = startIdx;
    document.getElementById('pageEndIdx').textContent = endIdx;
    document.getElementById('pageTotalCount').textContent = this.tracksTotal;
    document.getElementById('pageIndicator').textContent = `Page ${this.tracksPage} of ${totalPages}`;

    document.getElementById('prevPageBtn').disabled = this.tracksPage <= 1;
    document.getElementById('nextPageBtn').disabled = this.tracksPage >= totalPages;
  }

  renderAlbumsGrid() {
    const grid = document.getElementById('albumsGrid');
    const empty = document.getElementById('albumsEmptyState');

    if (!this.albums || this.albums.length === 0) {
      grid.innerHTML = '';
      empty.style.display = 'block';
      return;
    }
    empty.style.display = 'none';

    grid.innerHTML = this.albums
      .map((album) => {
        const title = this.escapeHtml(album.title || 'Untitled Album');
        const year = album.release_year ? album.release_year : '';

        return `
          <div class="card-item" onclick="app.openAlbumDetail('${album.id}')">
            <div class="card-cover-wrapper">
              <img class="card-cover-img" src="/api/cover/${album.id}" loading="lazy" alt="" />
              <div class="card-play-overlay">
                <button class="card-play-btn" title="View Album">
                  <svg viewBox="0 0 24 24" width="20" height="20" fill="currentColor"><path d="M8 5v14l11-7z"/></svg>
                </button>
              </div>
            </div>
            <div class="card-title">${title}</div>
            <div class="card-subtext">${year ? `Released: ${year}` : 'Album'}</div>
          </div>
        `;
      })
      .join('');
  }

  renderArtistsGrid() {
    const grid = document.getElementById('artistsGrid');
    const empty = document.getElementById('artistsEmptyState');

    if (!this.artists || this.artists.length === 0) {
      grid.innerHTML = '';
      empty.style.display = 'block';
      return;
    }
    empty.style.display = 'none';

    grid.innerHTML = this.artists
      .map((artist) => {
        const name = this.escapeHtml(artist.name || 'Unknown Artist');
        return `
          <div class="card-item" onclick="app.openArtistDetail('${artist.id}')">
            <div class="card-cover-wrapper">
              <img class="card-cover-img" src="/api/cover/${artist.id}" loading="lazy" alt="" />
              <div class="card-play-overlay">
                <button class="card-play-btn" title="View Artist">
                  <svg viewBox="0 0 24 24" width="20" height="20" fill="currentColor"><path d="M8 5v14l11-7z"/></svg>
                </button>
              </div>
            </div>
            <div class="card-title">${name}</div>
            <div class="card-subtext">Artist</div>
          </div>
        `;
      })
      .join('');
  }

  renderPlaylistsGrid() {
    const grid = document.getElementById('playlistsGrid');
    const empty = document.getElementById('playlistsEmptyState');

    if (!this.playlists || this.playlists.length === 0) {
      grid.innerHTML = '';
      empty.style.display = 'block';
      return;
    }
    empty.style.display = 'none';

    grid.innerHTML = this.playlists
      .map((pl) => {
        const title = this.escapeHtml(pl.title || 'Untitled Playlist');
        const desc = this.escapeHtml(pl.description || 'Playlist');

        return `
          <div class="card-item" onclick="app.openPlaylistDetail('${pl.id}')">
            <div class="card-cover-wrapper">
              <img class="card-cover-img" src="/api/cover/${pl.id}" loading="lazy" alt="" />
              <div class="card-play-overlay">
                <button class="card-play-btn" title="View Playlist">
                  <svg viewBox="0 0 24 24" width="20" height="20" fill="currentColor"><path d="M8 5v14l11-7z"/></svg>
                </button>
              </div>
            </div>
            <div class="card-title">${title}</div>
            <div class="card-subtext">${desc}</div>
          </div>
        `;
      })
      .join('');
  }

  // =========================================================================
  // Detail Views (Album, Artist, Playlist)
  // =========================================================================

  async openAlbumDetail(albumId) {
    try {
      const albumRes = await this.dispatch('GetAlbum', { id: albumId });
      if (albumRes.code !== 200 || !albumRes.data) return;

      const album = albumRes.data;
      // Fetch tracks in library
      const tracksRes = await this.dispatch('ListTracks', { limit: 100 });
      const albumTracks = (tracksRes.data.items || []).filter((t) => t.album_id === albumId || t.album === album.title);

      this.currentDetail = {
        type: 'ALBUM',
        id: albumId,
        data: album,
        tracks: albumTracks,
      };

      document.getElementById('detailTypeBadge').textContent = 'ALBUM';
      document.getElementById('detailTitle').textContent = album.title || 'Untitled Album';
      document.getElementById('detailMeta').textContent = `${album.release_year ? `Year: ${album.release_year} • ` : ''}${albumTracks.length} tracks`;
      document.getElementById('detailCoverImg').src = `/api/cover/${albumId}`;

      this.renderDetailTracks(albumTracks);
      this.switchView('detail');
    } catch (err) {
      this.showToast('Failed to open album detail', 'error');
    }
  }

  async openArtistDetail(artistId) {
    try {
      const artistRes = await this.dispatch('GetArtist', { id: artistId });
      if (artistRes.code !== 200 || !artistRes.data) return;

      const artist = artistRes.data;
      const tracksRes = await this.dispatch('ListTracks', { limit: 100 });
      const artistTracks = (tracksRes.data.items || []).filter((t) => t.artist_id === artistId || t.artist === artist.name);

      this.currentDetail = {
        type: 'ARTIST',
        id: artistId,
        data: artist,
        tracks: artistTracks,
      };

      document.getElementById('detailTypeBadge').textContent = 'ARTIST';
      document.getElementById('detailTitle').textContent = artist.name || 'Unknown Artist';
      document.getElementById('detailMeta').textContent = `${artistTracks.length} tracks recorded`;
      document.getElementById('detailCoverImg').src = `/api/cover/${artistId}`;

      this.renderDetailTracks(artistTracks);
      this.switchView('detail');
    } catch (err) {
      this.showToast('Failed to open artist detail', 'error');
    }
  }

  async openPlaylistDetail(playlistId) {
    try {
      const plRes = await this.dispatch('GetPlaylist', { id: playlistId });
      if (plRes.code !== 200 || !plRes.data) return;

      const playlist = plRes.data;
      const plTracksRes = await this.dispatch('GetPlaylistTracks', { playlist_id: playlistId });
      const tracks = plTracksRes.code === 200 && plTracksRes.data ? plTracksRes.data : [];

      this.currentDetail = {
        type: 'PLAYLIST',
        id: playlistId,
        data: playlist,
        tracks: tracks,
      };

      document.getElementById('detailTypeBadge').textContent = 'PLAYLIST';
      document.getElementById('detailTitle').textContent = playlist.title || 'Untitled Playlist';
      document.getElementById('detailMeta').textContent = `${playlist.description || 'Custom Playlist'} • ${tracks.length} tracks`;
      document.getElementById('detailCoverImg').src = `/api/cover/${playlistId}`;

      this.renderDetailTracks(tracks);
      this.switchView('detail');
    } catch (err) {
      this.showToast('Failed to open playlist detail', 'error');
    }
  }

  renderDetailTracks(tracks) {
    const tbody = document.getElementById('detailTracksTableBody');
    if (!tracks || tracks.length === 0) {
      tbody.innerHTML = `<tr><td colspan="7" style="text-align: center; padding: 32px; color: var(--text-dim);">No tracks found in this collection.</td></tr>`;
      return;
    }

    tbody.innerHTML = tracks
      .map((track, idx) => {
        const durationStr = this.formatDuration(track.duration);
        const title = this.escapeHtml(track.title || 'Untitled Track');
        const artist = this.escapeHtml(track.artist_name || track.artist || 'Unknown Artist');
        const album = this.escapeHtml(track.album_title || track.album || '—');

        return `
          <tr data-track-id="${track.id}">
            <td class="col-num">${idx + 1}</td>
            <td class="col-cover">
              <img class="table-cover-thumb" src="/api/cover/${track.id}" loading="lazy" alt="" />
            </td>
            <td class="col-title">
              <div class="track-title-cell">
                <span class="track-main-title">${title}</span>
                <span class="track-sub-artist">${artist}</span>
              </div>
            </td>
            <td class="col-artist">${artist}</td>
            <td class="col-album">${album}</td>
            <td class="col-duration">${durationStr}</td>
            <td class="col-actions">
              <div class="action-btn-group">
                <button class="table-btn" title="Play Track" onclick="app.playTrackById('${track.id}')">
                  <svg viewBox="0 0 20 20" width="14" height="14" fill="currentColor"><path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM9.555 7.168A1 1 0 008 8v4a1 1 0 001.555.832l3-2a1 1 0 000-1.664l-3-2z" clip-rule="evenodd"/></svg>
                </button>
                <button class="table-btn" title="Add to Queue" onclick="app.addToQueueById('${track.id}')">
                  <svg viewBox="0 0 20 20" width="14" height="14" fill="currentColor"><path fill-rule="evenodd" d="M10 3a1 1 0 011 1v5h5a1 1 0 110 2h-5v5a1 1 0 11-2 0v-5H4a1 1 0 110-2h5V4a1 1 0 011-1z" clip-rule="evenodd"/></svg>
                </button>
              </div>
            </td>
          </tr>
        `;
      })
      .join('');
  }

  // =========================================================================
  // Navigation & View Switching
  // =========================================================================

  switchView(viewName) {
    this.currentView = viewName;

    // Update Nav Sidebar items
    document.querySelectorAll('.nav-item').forEach((btn) => {
      btn.classList.toggle('active', btn.dataset.view === viewName);
    });

    // Update View Panels
    document.querySelectorAll('.view-panel').forEach((panel) => {
      panel.classList.remove('active');
    });

    const target = document.getElementById(
      viewName === 'detail' ? 'viewDetail' : `view${viewName.charAt(0).toUpperCase() + viewName.slice(1)}`
    );
    if (target) target.classList.add('active');
  }

  // =========================================================================
  // Audio Playback Engine (Dual Mode: Browser HTML5 & Local C++ Core)
  // =========================================================================

  setPlaybackMode(mode) {
    this.playbackMode = mode;
    localStorage.setItem('lyra_playback_mode', mode);

    document.getElementById('modeBrowserBtn').classList.toggle('active', mode === 'browser');
    document.getElementById('modeCoreBtn').classList.toggle('active', mode === 'core');

    const badge = document.getElementById('playerModeBadge');
    if (mode === 'browser') {
      badge.textContent = 'Browser Stream';
      badge.title = 'Streaming via HTML5 Audio API';
      // If was playing in core, stop core
      if (this.corePollTimer) {
        clearInterval(this.corePollTimer);
        this.corePollTimer = null;
      }
    } else {
      badge.textContent = 'Local C++ Core';
      badge.title = 'Direct hardware output via liblyra_core';
      // Pause browser audio if active
      this.audioElement.pause();
      this.startCoreStatePolling();
    }
  }

  setupAudioListeners() {
    this.audioElement.addEventListener('timeupdate', () => {
      if (this.playbackMode === 'browser' && this.audioElement.duration) {
        const cur = this.audioElement.currentTime;
        const dur = this.audioElement.duration;
        this.updateProgressUI(cur, dur);
      }
    });

    this.audioElement.addEventListener('play', () => {
      this.isPlaying = true;
      this.updatePlayPauseUI();
    });

    this.audioElement.addEventListener('pause', () => {
      this.isPlaying = false;
      this.updatePlayPauseUI();
    });

    this.audioElement.addEventListener('ended', () => {
      this.handleTrackEnded();
    });

    this.audioElement.addEventListener('error', (err) => {
      console.error('Browser audio error:', err);
      this.showToast('Audio playback error', 'error');
    });
  }

  async playTrack(track, replaceQueue = false) {
    if (!track) return;
    this.currentTrack = track;

    if (replaceQueue) {
      this.queue = [track];
      this.queueIndex = 0;
    } else {
      const idx = this.queue.findIndex((t) => t.id === track.id);
      if (idx !== -1) {
        this.queueIndex = idx;
      } else {
        this.queue.push(track);
        this.queueIndex = this.queue.length - 1;
      }
    }

    this.updatePlayerTrackUI(track);
    this.updateQueueUI();

    if (this.playbackMode === 'browser') {
      this.audioElement.src = `/api/audio/${track.id}`;
      try {
        await this.audioElement.play();
        this.isPlaying = true;
      } catch (err) {
        console.warn('Autoplay prevented or streaming error:', err);
      }
    } else {
      // Local C++ Core Mode
      try {
        const resPath = await this.dispatch('GetResourcePath', { track_id: track.id });
        if (resPath.code === 200 && resPath.data && resPath.data.path) {
          await this.dispatch('audio.play', { file_path: resPath.data.path });
          await this.dispatch('audio.set_volume', { volume: this.volume });
          this.isPlaying = true;
        } else {
          this.showToast('Could not resolve audio path for Core playback', 'error');
        }
      } catch (err) {
        this.showToast('Core play failed', 'error');
      }
    }

    this.updatePlayPauseUI();
    this.highlightActiveRow();
  }

  async togglePlayPause() {
    if (!this.currentTrack) {
      if (this.queue.length > 0) {
        this.playTrack(this.queue[0]);
      } else if (this.tracks.length > 0) {
        this.playTrack(this.tracks[0]);
      }
      return;
    }

    if (this.playbackMode === 'browser') {
      if (this.audioElement.paused) {
        await this.audioElement.play();
        this.isPlaying = true;
      } else {
        this.audioElement.pause();
        this.isPlaying = false;
      }
    } else {
      // Core Mode
      if (this.isPlaying) {
        await this.dispatch('audio.pause', {});
        this.isPlaying = false;
      } else {
        await this.dispatch('audio.resume', {});
        this.isPlaying = true;
      }
    }

    this.updatePlayPauseUI();
  }

  async playPrevious() {
    if (this.queue.length === 0) return;
    if (this.playbackMode === 'browser' && this.audioElement.currentTime > 3) {
      this.audioElement.currentTime = 0;
      return;
    }

    let prevIdx = this.queueIndex - 1;
    if (prevIdx < 0) {
      prevIdx = this.repeatMode === 'all' ? this.queue.length - 1 : 0;
    }
    this.queueIndex = prevIdx;
    this.playTrack(this.queue[this.queueIndex]);
  }

  async playNext() {
    if (this.queue.length === 0) return;

    let nextIdx = this.queueIndex + 1;
    if (nextIdx >= this.queue.length) {
      if (this.repeatMode === 'all') {
        nextIdx = 0;
      } else {
        this.isPlaying = false;
        this.updatePlayPauseUI();
        return;
      }
    }
    this.queueIndex = nextIdx;
    this.playTrack(this.queue[this.queueIndex]);
  }

  handleTrackEnded() {
    if (this.repeatMode === 'one') {
      if (this.playbackMode === 'browser') {
        this.audioElement.currentTime = 0;
        this.audioElement.play();
      } else {
        this.playTrack(this.currentTrack);
      }
    } else {
      this.playNext();
    }
  }

  seek(positionPercent) {
    if (this.playbackMode === 'browser') {
      if (this.audioElement.duration) {
        this.audioElement.currentTime = (positionPercent / 100) * this.audioElement.duration;
      }
    } else {
      // Core seek
      if (this.currentTrack && this.currentTrack.duration) {
        const totalSec = this.currentTrack.duration / 1000.0;
        const targetSec = (positionPercent / 100) * totalSec;
        this.dispatch('audio.seek', { position: targetSec });
      }
    }
  }

  setVolume(vol) {
    this.volume = Math.max(0, Math.min(1, vol));
    localStorage.setItem('lyra_volume', this.volume.toString());

    this.audioElement.volume = this.volume;
    document.getElementById('playerVolumeSlider').value = this.volume;

    if (this.playbackMode === 'core') {
      this.dispatch('audio.set_volume', { volume: this.volume });
    }

    const volHigh = document.getElementById('volIconHigh');
    const volMuted = document.getElementById('volIconMuted');
    if (this.volume === 0 || this.isMuted) {
      volHigh.style.display = 'none';
      volMuted.style.display = 'block';
    } else {
      volHigh.style.display = 'block';
      volMuted.style.display = 'none';
    }
  }

  toggleMute() {
    if (this.isMuted) {
      this.isMuted = false;
      this.setVolume(this.prevVolume || 0.8);
    } else {
      this.prevVolume = this.volume;
      this.isMuted = true;
      this.setVolume(0);
    }
  }

  startCoreStatePolling() {
    if (this.corePollTimer) clearInterval(this.corePollTimer);

    this.corePollTimer = setInterval(async () => {
      if (this.playbackMode !== 'core') return;
      try {
        const res = await this.dispatch('audio.get_state', {});
        if (res.code === 200 && res.data) {
          const state = res.data.state; // 'PLAYING', 'PAUSED', 'STOPPED'
          const pos = res.data.position || 0;
          const dur = (this.currentTrack && this.currentTrack.duration) ? this.currentTrack.duration / 1000.0 : (res.data.duration || 0);

          this.isPlaying = state === 'PLAYING';
          this.updatePlayPauseUI();
          this.updateProgressUI(pos, dur);

          if (state === 'STOPPED' && this.isPlaying) {
            this.handleTrackEnded();
          }
        }
      } catch {
        // ignore poll errors
      }
    }, 500);
  }

  // =========================================================================
  // Queue Management
  // =========================================================================

  playTrackById(trackId) {
    const track = this.findTrack(trackId);
    if (track) this.playTrack(track);
  }

  addToQueueById(trackId) {
    const track = this.findTrack(trackId);
    if (track) {
      this.queue.push(track);
      this.updateQueueUI();
      this.showToast(`Added "${track.title || 'Track'}" to queue`, 'info');
    }
  }

  playAll(tracks) {
    if (!tracks || tracks.length === 0) return;
    this.queue = [...tracks];
    this.queueIndex = 0;
    this.playTrack(this.queue[0]);
    this.showToast(`Playing all ${tracks.length} tracks`, 'info');
  }

  shuffleAll(tracks) {
    if (!tracks || tracks.length === 0) return;
    const shuffled = [...tracks].sort(() => Math.random() - 0.5);
    this.queue = shuffled;
    this.queueIndex = 0;
    this.playTrack(this.queue[0]);
    this.showToast(`Shuffled and playing ${tracks.length} tracks`, 'info');
  }

  findTrack(trackId) {
    return (
      this.tracks.find((t) => t.id === trackId) ||
      (this.currentDetail && this.currentDetail.tracks && this.currentDetail.tracks.find((t) => t.id === trackId)) ||
      this.queue.find((t) => t.id === trackId)
    );
  }

  updateQueueUI() {
    const badge = document.getElementById('queueBadge');
    badge.textContent = this.queue.length;

    const countLabel = document.getElementById('queueCountLabel');
    countLabel.textContent = `${this.queue.length} items`;

    const list = document.getElementById('queueList');
    if (this.queue.length === 0) {
      list.innerHTML = `<div style="text-align:center; padding: 24px; color: var(--text-dim); font-size: 0.85rem;">Queue is empty</div>`;
      return;
    }

    list.innerHTML = this.queue
      .map((item, idx) => {
        const isCurrent = idx === this.queueIndex;
        const title = this.escapeHtml(item.title || 'Untitled');
        const artist = this.escapeHtml(item.artist_name || item.artist || 'Unknown');

        return `
          <div class="queue-item ${isCurrent ? 'current' : ''}" onclick="app.jumpToQueueIndex(${idx})">
            <img class="queue-item-thumb" src="/api/cover/${item.id}" alt="" />
            <div class="queue-item-info">
              <div class="queue-item-title">${title}</div>
              <div class="queue-item-artist">${artist}</div>
            </div>
            <button class="queue-item-remove" title="Remove" onclick="event.stopPropagation(); app.removeFromQueue(${idx})">&times;</button>
          </div>
        `;
      })
      .join('');
  }

  jumpToQueueIndex(idx) {
    if (idx >= 0 && idx < this.queue.length) {
      this.queueIndex = idx;
      this.playTrack(this.queue[idx]);
    }
  }

  removeFromQueue(idx) {
    this.queue.splice(idx, 1);
    if (this.queueIndex >= idx && this.queueIndex > 0) {
      this.queueIndex--;
    }
    this.updateQueueUI();
  }

  clearQueue() {
    this.queue = [];
    this.queueIndex = -1;
    this.updateQueueUI();
    this.showToast('Queue cleared', 'info');
  }

  toggleQueueDrawer() {
    const drawer = document.getElementById('queueDrawer');
    const overlay = document.getElementById('queueOverlay');
    const isOpen = drawer.classList.contains('open');

    if (isOpen) {
      drawer.classList.remove('open');
      overlay.classList.remove('open');
    } else {
      this.updateQueueUI();
      drawer.classList.add('open');
      overlay.classList.add('open');
    }
  }

  // =========================================================================
  // UI Updates & Feedback
  // =========================================================================

  updatePlayerTrackUI(track) {
    document.getElementById('playerTrackTitle').textContent = track.title || 'Untitled Track';
    document.getElementById('playerTrackArtist').textContent = track.artist_name || track.artist || 'Unknown Artist';
    document.getElementById('playerCoverImg').src = `/api/cover/${track.id}`;
  }

  updatePlayPauseUI() {
    const playIcon = document.getElementById('playIcon');
    const pauseIcon = document.getElementById('pauseIcon');
    if (this.isPlaying) {
      playIcon.style.display = 'none';
      pauseIcon.style.display = 'block';
    } else {
      playIcon.style.display = 'block';
      pauseIcon.style.display = 'none';
    }
  }

  updateProgressUI(currentSeconds, totalSeconds) {
    const curLabel = document.getElementById('playerCurrentTime');
    const totalLabel = document.getElementById('playerTotalDuration');
    const slider = document.getElementById('playerSeekSlider');

    curLabel.textContent = this.formatSeconds(currentSeconds);
    totalLabel.textContent = this.formatSeconds(totalSeconds);

    if (totalSeconds > 0) {
      const pct = (currentSeconds / totalSeconds) * 100;
      slider.value = pct;
    }
  }

  highlightActiveRow() {
    document.querySelectorAll('.tracks-table tr').forEach((row) => {
      const rowId = row.dataset.trackId;
      row.classList.toggle('active-track', rowId && this.currentTrack && rowId === this.currentTrack.id);
    });
  }

  showToast(message, type = 'info') {
    const container = document.getElementById('toastContainer');
    const toast = document.createElement('div');
    toast.className = `toast-item ${type}`;
    toast.textContent = message;
    container.appendChild(toast);

    setTimeout(() => {
      toast.style.opacity = '0';
      toast.style.transition = 'opacity 0.3s ease';
      setTimeout(() => toast.remove(), 300);
    }, 3500);
  }

  // =========================================================================
  // Modals & Operations
  // =========================================================================

  openImportModal() {
    document.getElementById('importSourcePath').value = '';
    document.getElementById('importResultBox').style.display = 'none';
    document.getElementById('importModal').classList.add('open');
  }

  async executeImport() {
    const pathInput = document.getElementById('importSourcePath');
    const path = pathInput.value.trim();
    const resultBox = document.getElementById('importResultBox');

    if (!path) {
      this.showToast('Please enter an audio file path', 'error');
      return;
    }

    resultBox.style.display = 'block';
    resultBox.textContent = 'Importing audio into Lyra CAS...';

    try {
      const res = await this.dispatch('ImportTrack', { source_path: path });
      if (res.code === 200) {
        resultBox.textContent = `✅ Successfully imported!\nTrack ID: ${res.data.track_id}\nTitle: ${res.data.title}\nPCM Hash: ${res.data.pcm_hash}`;
        this.showToast('Track imported successfully!', 'success');
        this.loadTracks();
        this.loadAlbums();
        this.loadArtists();
      } else {
        resultBox.textContent = `❌ Import Failed: ${res.error ? res.error.message : 'Unknown error'}`;
      }
    } catch (err) {
      resultBox.textContent = `❌ Import Exception: ${err.message}`;
    }
  }

  openCreatePlaylistModal() {
    document.getElementById('newPlaylistTitle').value = '';
    document.getElementById('newPlaylistDesc').value = '';
    document.getElementById('createPlaylistModal').classList.add('open');
  }

  async submitCreatePlaylist() {
    const title = document.getElementById('newPlaylistTitle').value.trim();
    const description = document.getElementById('newPlaylistDesc').value.trim();

    if (!title) {
      this.showToast('Playlist title is required', 'error');
      return;
    }

    try {
      const res = await this.dispatch('CreatePlaylist', { title, description });
      if (res.code === 201 || res.code === 200) {
        this.showToast(`Playlist "${title}" created!`, 'success');
        this.closeModal('createPlaylistModal');
        this.loadPlaylists();
      }
    } catch (err) {
      this.showToast('Failed to create playlist', 'error');
    }
  }

  openAddToPlaylistModal(trackId, trackTitle) {
    const label = document.getElementById('addToPlaylistTrackLabel');
    label.textContent = `Add "${trackTitle}" to playlist:`;

    const container = document.getElementById('playlistSelectOptions');
    if (this.playlists.length === 0) {
      container.innerHTML = `<div style="color: var(--text-dim); padding: 12px;">No playlists available. Create one first!</div>`;
    } else {
      container.innerHTML = this.playlists
        .map(
          (pl) => `
          <div class="playlist-choice-item" onclick="app.addTrackToPlaylist('${pl.id}', '${trackId}')">
            📁 ${this.escapeHtml(pl.title)}
          </div>
        `
        )
        .join('');
    }

    document.getElementById('addToPlaylistModal').classList.add('open');
  }

  async addTrackToPlaylist(playlistId, trackId) {
    try {
      const res = await this.dispatch('AddPlaylistTrack', {
        playlist_id: playlistId,
        track_id: trackId,
      });
      if (res.code === 200 || res.code === 201) {
        this.showToast('Added track to playlist', 'success');
        this.closeModal('addToPlaylistModal');
      }
    } catch (err) {
      this.showToast('Failed to add track to playlist', 'error');
    }
  }

  closeModal(modalId) {
    document.getElementById(modalId).classList.remove('open');
  }

  // =========================================================================
  // UI Event Listeners & Shortcuts
  // =========================================================================

  setupUIEventListeners() {
    // Mode Buttons
    document.getElementById('modeBrowserBtn').addEventListener('click', () => this.setPlaybackMode('browser'));
    document.getElementById('modeCoreBtn').addEventListener('click', () => this.setPlaybackMode('core'));

    // Navigation Items
    document.querySelectorAll('.nav-item').forEach((btn) => {
      btn.addEventListener('click', () => this.switchView(btn.dataset.view));
    });

    // Import Button
    document.getElementById('openImportModalBtn').addEventListener('click', () => this.openImportModal());
    document.getElementById('btnExecuteImport').addEventListener('click', () => this.executeImport());

    // Playlist Buttons
    document.getElementById('sidebarNewPlaylistBtn').addEventListener('click', () => this.openCreatePlaylistModal());
    document.getElementById('createPlaylistBtn').addEventListener('click', () => this.openCreatePlaylistModal());
    document.getElementById('btnSubmitCreatePlaylist').addEventListener('click', () => this.submitCreatePlaylist());

    // Sidebar Refresh
    document.getElementById('sidebarRefreshBtn').addEventListener('click', () => {
      this.loadTracks();
      this.loadAlbums();
      this.loadArtists();
      this.loadPlaylists();
      this.showToast('Library refreshed', 'info');
    });

    // Tracks View Actions
    document.getElementById('tracksPlayAllBtn').addEventListener('click', () => this.playAll(this.tracks));
    document.getElementById('tracksShuffleAllBtn').addEventListener('click', () => this.shuffleAll(this.tracks));

    // Detail View Actions
    document.getElementById('detailBackBtn').addEventListener('click', () => {
      const prev = this.currentDetail ? this.currentDetail.type.toLowerCase() + 's' : 'tracks';
      this.switchView(prev);
    });
    document.getElementById('detailPlayAllBtn').addEventListener('click', () => {
      if (this.currentDetail && this.currentDetail.tracks) this.playAll(this.currentDetail.tracks);
    });
    document.getElementById('detailAddQueueBtn').addEventListener('click', () => {
      if (this.currentDetail && this.currentDetail.tracks) {
        this.queue.push(...this.currentDetail.tracks);
        this.updateQueueUI();
        this.showToast(`Added ${this.currentDetail.tracks.length} tracks to queue`, 'info');
      }
    });

    // Pagination
    document.getElementById('prevPageBtn').addEventListener('click', () => {
      if (this.tracksPage > 1) this.loadTracks(this.tracksPage - 1);
    });
    document.getElementById('nextPageBtn').addEventListener('click', () => {
      this.loadTracks(this.tracksPage + 1);
    });

    // Search Input
    const searchInput = document.getElementById('globalSearchInput');
    const searchClear = document.getElementById('searchClearBtn');

    searchInput.addEventListener('input', (e) => {
      this.searchQuery = e.target.value;
      searchClear.style.display = this.searchQuery ? 'block' : 'none';

      clearTimeout(this.searchDebounceTimer);
      this.searchDebounceTimer = setTimeout(() => {
        this.loadTracks(1);
      }, 250);
    });

    searchClear.addEventListener('click', () => {
      searchInput.value = '';
      this.searchQuery = '';
      searchClear.style.display = 'none';
      this.loadTracks(1);
    });

    // Player Controls
    document.getElementById('btnPlayPause').addEventListener('click', () => this.togglePlayPause());
    document.getElementById('btnPrev').addEventListener('click', () => this.playPrevious());
    document.getElementById('btnNext').addEventListener('click', () => this.playNext());
    document.getElementById('btnMute').addEventListener('click', () => this.toggleMute());

    // Scrub Slider
    const seekSlider = document.getElementById('playerSeekSlider');
    seekSlider.addEventListener('input', (e) => {
      this.seek(parseFloat(e.target.value));
    });

    // Volume Slider
    const volSlider = document.getElementById('playerVolumeSlider');
    volSlider.addEventListener('input', (e) => {
      this.setVolume(parseFloat(e.target.value));
    });

    // Queue Drawer Toggle
    document.getElementById('btnToggleQueue').addEventListener('click', () => this.toggleQueueDrawer());
    document.getElementById('btnCloseQueue').addEventListener('click', () => this.toggleQueueDrawer());
    document.getElementById('queueOverlay').addEventListener('click', () => this.toggleQueueDrawer());
    document.getElementById('btnClearQueue').addEventListener('click', () => this.clearQueue());

    // Shuffle & Repeat Toggle
    document.getElementById('btnShuffle').addEventListener('click', (e) => {
      this.isShuffled = !this.isShuffled;
      e.currentTarget.classList.toggle('active', this.isShuffled);
      this.showToast(this.isShuffled ? 'Shuffle enabled' : 'Shuffle disabled', 'info');
    });

    document.getElementById('btnRepeat').addEventListener('click', (e) => {
      if (this.repeatMode === 'off') {
        this.repeatMode = 'all';
        e.currentTarget.classList.add('active');
        this.showToast('Repeat All enabled', 'info');
      } else if (this.repeatMode === 'all') {
        this.repeatMode = 'one';
        e.currentTarget.classList.add('active');
        this.showToast('Repeat One enabled', 'info');
      } else {
        this.repeatMode = 'off';
        e.currentTarget.classList.remove('active');
        this.showToast('Repeat disabled', 'info');
      }
    });
  }

  setupKeyboardShortcuts() {
    window.addEventListener('keydown', (e) => {
      // Avoid triggering when focused in an input or textarea
      if (['INPUT', 'TEXTAREA'].includes(document.activeElement.tagName)) {
        if (e.key === 'Escape') {
          document.activeElement.blur();
        }
        return;
      }

      switch (e.code) {
        case 'Space':
          e.preventDefault();
          this.togglePlayPause();
          break;
        case 'ArrowRight':
          e.preventDefault();
          if (this.playbackMode === 'browser') {
            this.audioElement.currentTime = Math.min(this.audioElement.duration || 0, this.audioElement.currentTime + 5);
          }
          break;
        case 'ArrowLeft':
          e.preventDefault();
          if (this.playbackMode === 'browser') {
            this.audioElement.currentTime = Math.max(0, this.audioElement.currentTime - 5);
          }
          break;
        case 'ArrowUp':
          e.preventDefault();
          this.setVolume(this.volume + 0.05);
          break;
        case 'ArrowDown':
          e.preventDefault();
          this.setVolume(this.volume - 0.05);
          break;
        case 'KeyN':
          this.playNext();
          break;
        case 'KeyP':
          this.playPrevious();
          break;
        case 'KeyM':
          this.toggleMute();
          break;
        case 'KeyQ':
          this.toggleQueueDrawer();
          break;
        case 'Slash':
          e.preventDefault();
          document.getElementById('globalSearchInput').focus();
          break;
        case 'Escape':
          this.closeModal('importModal');
          this.closeModal('createPlaylistModal');
          this.closeModal('addToPlaylistModal');
          const drawer = document.getElementById('queueDrawer');
          if (drawer.classList.contains('open')) this.toggleQueueDrawer();
          break;
      }
    });
  }

  // =========================================================================
  // Utility Helpers
  // =========================================================================

  formatDuration(ms) {
    if (!ms || isNaN(ms)) return '0:00';
    return this.formatSeconds(ms / 1000);
  }

  formatSeconds(sec) {
    if (!sec || isNaN(sec)) return '0:00';
    const mins = Math.floor(sec / 60);
    const secs = Math.floor(sec % 60);
    return `${mins}:${secs < 10 ? '0' : ''}${secs}`;
  }

  escapeHtml(str) {
    if (!str) return '';
    return str
      .toString()
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#039;');
  }
}

// Instantiate App when DOM is loaded
let app;
window.addEventListener('DOMContentLoaded', () => {
  app = new LyraApp();
});

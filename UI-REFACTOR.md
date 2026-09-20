# Veyra presentation refactor

## Inventory / boundaries

Active source: /Users/stinus/Developer/Veyra. NavigationStack with existing item-based main destinations and child NavigationLinks. Home currently contains Trakt continue watching, Trakt upcoming, sports and IPTV recently added. These rails must remain.

Movies/Series: TMDB, thirteen real logo filters, Dutch metadata, adaptive poster grids, existing detail/source selection. Sports: SportsStore/ESPN with team logos, favorites, filters/date selection and match details. Live TV: VeyraEPGStore, VeyraEPGService, timeline grid and provider choice; retain its two-dimensional focus handling. Settings: IPTV sources, addon CRUD/migration, account/OpenSubtitles, Trakt/privacy. Player: AetherEngine render surface and unchanged loading/resume/scrobbling; embedded/external subtitles, subtitle appearance persistence and OpenSubtitles service.

No replacement of services, storage, routing, source resolvers, parsers or playback engine. No fake stream quality, matches, recommendations or account integrations. No new providers beyond current selection. Functional screen backgrounds abstract; content backgrounds use real current artwork. Older Swift UI files are preserved in Backups/UI-refactor, outside the application target.

## Phases

1. Inventory and baseline build.
2. Shared design tokens, artwork/hero/cards, focus and glass components.
3. One shared top navigation over existing NavigationStack routes.
4. Home hero plus existing rails.
5. Movies/Series shared hero, circular provider row, existing grids.
6. Sports real event hero and existing dashboard.
7. EPG presentation while preserving guide geometry and actions.
8. Settings/IPTV/Addons/Account abstract backgrounds and rounded glass.
9. Player presentation over the existing engine/subtitle renderer.
10. Build, static preservation checks, available runtime/focus checks.

Device installation is paused until the end. Visual/Siri Remote and playback checks are recorded separately from compiler checks; successful compilation alone is not acceptance of focus, performance or end-to-end playback.

## Result — 18 September 2026, build 7

Implemented a shared floating navigation, full-bleed single-backdrop Home/Movies/Series heroes, shared poster cards and circular provider filters, Sports event hero and horizontal league filters, abstract EPG/IPTV/settings backgrounds, two-column settings cards (including Trakt), and glass playback controls with a red timeline, play/pause, ±10 seconds and actual audio-track selection. Existing subtitle overlay, external/OpenSubtitles and appearance settings remain mounted with the player. No invented quality badges or sports/content fixtures.

The current featured movie/series is the first real loaded result. No auto-rotating carousel or synthetic recommendations were added. Sports uses real team logos because the existing feed has no event backdrop. Artwork uses bounded TMDB sizes (w1280/w500), lazy catalog grids and no full-screen animated shader. No new caching architecture; actual memory, frame rate and cache behavior still need device measurement.

Verification:
- Navigation, Home, catalog, Sports and player phase builds passed.
- Consolidated signed tvOS build including EPG and settings passed (23:22). An intermediate incremental-link failure resolved on subsequent compilation.
- Trakt integration checks passed (mocked network; no live account changes). Test compiler list updated for the existing VeyraAPIKeyStore dependency.
- Sports checks passed: states, team identity, favorites, failure recovery and date isolation.
- Five automatic deployment checks passed.
- No `.green` / `Color.green` usages remain in app Swift presentation code.
- Device Hub UI access timed out. Siri Remote navigation/focus, overscan, live playback, seeking/audio switching, subtitle rendering, EPG interaction and performance are NOT visually or end-to-end validated by these build/tests. They remain device acceptance checks.

Additional minimal build repairs: removed a redundant optional unwrap in existing Xtream decoding. A newly saved root-level TorrentProvider.swift was found after AddonRegistry referenced it; fixed its nonexistent `.addon` source kind to `.direct` and the missing settings switch case. It accepts HTTP(S) playback links, not magnet/torrent playback; no player engine changes or torrent transport were introduced.

Deployment: build 7 successfully installed and launched on Woonkamer at 23:24:57 after one connection-reset retry. Source fingerprint verified against the deployed snapshot. Automatic updates remain enabled.

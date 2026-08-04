# Graph Report - .  (2026-08-04)

## Corpus Check
- 132 files · ~288,660 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 1907 nodes · 2774 edges · 104 communities (93 shown, 11 thin omitted)
- Extraction: 97% EXTRACTED · 3% INFERRED · 0% AMBIGUOUS · INFERRED: 91 edges (avg confidence: 0.85)
- Token cost: 157,329 input · 0 output

## Community Hubs (Navigation)
- Session State Hub
- Windows Flutter Runner
- Wire Protocol Payloads
- Board View Rendering
- Game Engine Core
- Game Screen Layout
- Host Lobby Screen
- Board Logic & Flood Fill
- Host Session Authority
- Relay Transport Client
- Achievements System
- Result Screen & Stats
- Board Skin Definitions
- Router & LAN Browse
- App Theme Palette
- Particle & Confetti Painters
- LAN WebSocket Server
- Achievements Screen UI
- Store Screen UI
- Connection Overlay
- Audio SFX Engine
- Difficulty Picker Widget
- Firebase Analytics Facade
- Home Screen
- Achievement Toast Overlay
- Riverpod Consumer Widgets
- LAN Guest Client
- Transport Interfaces
- Hearts Bar Widget
- In-App Purchase State
- Session Providers
- mDNS Discovery (io)
- How To Play Sheet
- Relay Room Durable Object
- AdMob Ads Facade
- Ad Gate Pacing
- Chat State
- Store & Skin Providers
- Cell Tile Widget
- Ambient Background
- Server Message Types
- Stats Charts Widget
- Difficulty & GameConfig
- Screen Shake Effect
- App Entry Point
- Relay TypeScript Config
- App Icon Brand Identity
- Skin Picker Widget
- Relay Package Manifest
- Avatar Widget
- Client Message Types
- Chat Panel Widget
- Coin Store Ledger
- Pressable Interaction
- Host Transport Stubs
- Discovery Web Stubs
- About Screen
- Android Icon Density Ladder
- Stateful Widget States
- Join Screen
- Menu Banner Ad
- IAP Setup Contract
- Windows Win32 Entry
- Ad Unit IDs
- Explosion Overlay
- SharedPreferences Persistence
- Engine Unit Tests
- Web PWA Manifest
- Privacy & Data Safety
- Authoritative Host Protocol
- Game Modes & Determinism
- Coin Pack Catalogue
- Transport Seam Rationale
- Short ID Generation
- Tip Jar Products
- Reconnect & Presence
- Interstitial & Rewarded Flow
- Session Notifiers
- Route Builders
- Emoji Bar Widget
- AdMob Setup Guide
- Firebase Options Config
- Explosion Timing Curve
- Windows CMake Build
- Skin Selection State
- Skin Pricing Table
- Release Build Checklist
- Relay URL Config
- Local IP Lookup (io)
- Android MainActivity
- Immutable Skin Model
- Test Ad Units
- Discovery Stub Export
- Local IP Conditional Export
- Local IP Web Stub
- Server Conditional Export
- App Lifecycle Observer
- BoardView Widget Pair
- Board Grid Layout
- Widget Smoke Test
- Untyped String Node

## God Nodes (most connected - your core abstractions)
1. `sessionProvider` - 28 edges
2. `Win32Window` - 22 edges
3. `GamePalette` - 19 edges
4. `ServerMessage` - 19 edges
5. `sharedPreferencesProvider` - 18 edges
6. `ClientMessage` - 16 edges
7. `Room` - 15 edges
8. `storeProvider` - 14 edges
9. `MessageHandler` - 12 edges
10. `chatProvider` - 11 edges

## Surprising Connections (you probably didn't know these)
- `Rewarded Ad (free coins, +250, 60s cooldown)` --semantically_similar_to--> `Coin pack catalogue (coins_handful/stack/chest/vault)`  [INFERRED] [semantically similar]
  ADS_SETUP.md → IAP_SETUP.md
- `Windows has no Firebase SDK — analytics is a no-op there` --semantically_similar_to--> `stub/io conditional export split for the web build`  [INFERRED] [semantically similar]
  FIREBASE_SETUP.md → CLAUDE.md
- `Flutter web host page (flutter_bootstrap.js, manifest, icons)` --semantically_similar_to--> `Windows runner executable target`  [INFERRED] [semantically similar]
  web/index.html → windows/runner/CMakeLists.txt
- `Store listing copy (Minesweeper Co-op)` --conceptually_related_to--> `AdMob Ads Integration (Android)`  [AMBIGUOUS]
  RELEASE.md → ADS_SETUP.md
- `Ads are Android-only (no web/Windows support)` --semantically_similar_to--> `Billing is Android-only; coin UI hidden on web/Windows`  [INFERRED] [semantically similar]
  ADS_SETUP.md → IAP_SETUP.md

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Monetization stack and its required disclosures** — ads_setup_admob_integration, iap_setup_in_app_purchases, firebase_setup_firebase_analytics, privacy_index_advertising_and_analytics_disclosure, release_data_safety_answers [INFERRED 0.85]
- **Reconnect and presence flow** — claude_reconnect_presence, claude_logical_vs_transport_ids, claude_rejoin_token, claude_grace_window, claude_online_host_reclaim, claude_liveness_ping [EXTRACTED 1.00]
- **Windows CMake build chain** — windows_cmakelists_project_build, windows_cmakelists_apply_standard_settings, windows_flutter_cmakelists_flutter_assemble, windows_flutter_cmakelists_flutter_wrapper_app, windows_runner_cmakelists_runner_target [EXTRACTED 1.00]
- **Cross-Platform App Icon Set Derived From One Master Artwork** — assets_icon_icon_source_app_icon, m_icon_master_app_icon, web_favicon_browser_favicon, web_icons_icon_192_pwa_icon, web_icons_icon_512_pwa_icon, web_icons_icon_maskable_192_pwa_maskable_icon, web_icons_icon_maskable_512_pwa_maskable_icon, android_app_src_main_res_mipmap_xxxhdpi_ic_launcher_android_launcher_icon, android_app_src_main_res_drawable_xxxhdpi_ic_launcher_foreground_adaptive_foreground [INFERRED 0.95]
- **Maskable / Adaptive Icon Variants Honoring a Central Safe Zone** — web_icons_icon_maskable_192_pwa_maskable_icon, web_icons_icon_maskable_512_pwa_maskable_icon, android_app_src_main_res_drawable_xxxhdpi_ic_launcher_foreground_adaptive_foreground, web_icons_icon_maskable_512_maskable_safe_zone [INFERRED 0.85]
- **Brand Visual Language: Bomb, Grid Tiles, Flag, Neon Burst** — m_icon_bomb_on_grid_motif, m_icon_red_flag_marker, m_icon_neon_blue_magenta_palette, m_icon_game_brand_identity [EXTRACTED 1.00]
- **Adaptive Icon Foreground Density Set** — android_app_src_main_res_drawable_mdpi_ic_launcher_foreground_asset, android_app_src_main_res_drawable_hdpi_ic_launcher_foreground_asset, android_app_src_main_res_drawable_xhdpi_ic_launcher_foreground_asset, android_app_src_main_res_drawable_xxhdpi_ic_launcher_foreground_asset, android_app_src_main_res_mipmap_mdpi_ic_launcher_density_ladder [INFERRED 0.95]
- **Legacy Launcher Icon Density Set** — android_app_src_main_res_mipmap_mdpi_ic_launcher_asset, android_app_src_main_res_mipmap_hdpi_ic_launcher_asset, android_app_src_main_res_mipmap_xhdpi_ic_launcher_asset, android_app_src_main_res_mipmap_xxhdpi_ic_launcher_asset, android_app_src_main_res_mipmap_mdpi_ic_launcher_density_ladder [INFERRED 0.95]
- **Minesweeper Visual Brand System (bomb, tiles, flag, neon burst)** — android_app_src_main_res_mipmap_xxhdpi_ic_launcher_brand_identity, android_app_src_main_res_mipmap_xxhdpi_ic_launcher_red_flag_motif, android_app_src_main_res_drawable_xxhdpi_ic_launcher_foreground_asset, android_app_src_main_res_mipmap_xxhdpi_ic_launcher_asset, android_app_src_main_res_drawable_hdpi_ic_launcher_foreground_generated_from_icon_source [INFERRED 0.85]

## Communities (104 total, 11 thin omitted)

### Community 0 - "Session State Hub"
Cohesion: 0.02
Nodes (105): ad_gate.dart, chat.dart, DiscoveryAdvertiser?, DiscoveryBrowser?, host_session.dart, _advertiser, _attemptConnect, avatarData (+97 more)

### Community 1 - "Windows Flutter Runner"
Cohesion: 0.06
Nodes (54): FlutterViewController, PluginRegistry, Point, RECT, Size, unique_ptr, RegisterPlugins(), DartProject (+46 more)

### Community 2 - "Wire Protocol Payloads"
Cohesion: 0.03
Nodes (57): bool?, avatarData, avatarSeed, by, byPlayerId, cells, code, color (+49 more)

### Community 3 - "Board View Rendering"
Cohesion: 0.03
Nodes (57): explosion_overlay.dart, _AnimatedCell, build, _buildCursors, cell, CellCb, cellSize, _chainTicker (+49 more)

### Community 4 - "Game Engine Core"
Cohesion: 0.04
Nodes (54): board.dart, Board get, DateTime? get, GameStatus get, autoFlagged, _board, byPlayerId, cells (+46 more)

### Community 5 - "Game Screen Layout"
Cohesion: 0.04
Nodes (54): big, boardH, boardLabel, boardW, _centeredH, _centeredW, _centerIfBoardChanged, _centerScheduled (+46 more)

### Community 6 - "Host Lobby Screen"
Cohesion: 0.05
Nodes (50): HostMode, accent, _AutoFlagToggle, child, _ChoiceTile, columns, _Connecting, createState (+42 more)

### Community 7 - "Board Logic & Flood Fill"
Cohesion: 0.04
Nodes (47): difficulty.dart, adjacentMines, allMinesRevealed, autoFlag, Board, Cell, cellAt, cellCount (+39 more)

### Community 8 - "Host Session Authority"
Cohesion: 0.04
Nodes (46): ../game/board.dart, GameEngine? get, HostJoinInfo? get, Iterable, GameEngine, _applyClientMessage, _bindTransport, _broadcast (+38 more)

### Community 9 - "Relay Transport Client"
Cohesion: 0.05
Nodes (43): Completer, Exception, _attemptReclaim, baseUrl, broadcast, _channel, close, code (+35 more)

### Community 10 - "Achievements System"
Cohesion: 0.05
Nodes (38): GameMode get, PlayerStats, AchievementContext, achievementId, AchievementsNotifier, AchievementState, copyWith, description (+30 more)

### Community 11 - "Result Screen & Stats"
Cohesion: 0.06
Nodes (34): accent, _AwardsRow, _Badge, _ChartCard, child, createState, durationMs, _Fact (+26 more)

### Community 12 - "Board Skin Definitions"
Cohesion: 0.06
Nodes (31): bevelWidthFrac, boardBackground, cellBorderColor, cellBorderWidth, cellGapFrac, cellRadiusFrac, CellStructure, checkerboard (+23 more)

### Community 13 - "Router & LAN Browse"
Cohesion: 0.07
Nodes (28): appRouter, discoveryProvider, BrowseScreen, _BrowseScreenState, build, _codeCtrl, _connectLan, _connectOnline (+20 more)

### Community 14 - "App Theme Palette"
Cohesion: 0.07
Nodes (27): amber, amberBright, AppPalette, AppTheme, bg, build, copyWith, cream (+19 more)

### Community 15 - "Particle & Confetti Painters"
Cohesion: 0.07
Nodes (26): CustomPainter, _BoardEdgesPainter, build, burst, _c, color, colors, _ConfettiPainter (+18 more)

### Community 16 - "LAN WebSocket Server"
Cohesion: 0.08
Nodes (25): ../core/ids.dart, HttpServer?, broadcast, channel, _connFor, _conns, _eventCtrl, events (+17 more)

### Community 17 - "Achievements Screen UI"
Cohesion: 0.09
Nodes (22): ../../app/tips.dart, Achievement, AchievementStats, achievement, _AchievementCard, _ProgressHeader, stats, total (+14 more)

### Community 18 - "Store Screen UI"
Cohesion: 0.08
Nodes (24): affordable, _CoinPackCard, enabled, equipped, _Footer, iap, label, onBuy (+16 more)

### Community 19 - "Connection Overlay"
Cohesion: 0.08
Nodes (23): ColorScheme, dart:ui, SessionConnState, accent, build, _Card, ConnectionOverlay, cs (+15 more)

### Community 20 - "Audio SFX Engine"
Cohesion: 0.08
Nodes (23): dart:typed_data, Future, build, _bytes, dataBytes, dispose, _doInit, init (+15 more)

### Community 21 - "Difficulty Picker Widget"
Cohesion: 0.08
Nodes (23): easy,
  medium,
  hard,, BoardPreset, build, config, custom, CustomConfigEditor, fromConfig, label (+15 more)

### Community 22 - "Firebase Analytics Facade"
Cohesion: 0.08
Nodes (23): ../firebase_options.dart, FirebaseAnalytics?, achievementUnlocked, adInterstitialShown, adRewardEarned, Analytics, coinPackPurchased, _fa (+15 more)

### Community 23 - "Home Screen"
Cohesion: 0.08
Nodes (23): _AchievementsPill, createState, _DifficultyRow, dispose, _HeroButton, icon, initState, label (+15 more)

### Community 24 - "Achievement Toast Overlay"
Cohesion: 0.09
Nodes (20): ../../audio/sfx.dart, avatar.dart, chat_panel.dart, emoji_bar.dart, ../../game/engine.dart, AchievementToast, onTap, toast (+12 more)

### Community 25 - "Riverpod Consumer Widgets"
Cohesion: 0.11
Nodes (22): ConsumerWidget, MutedNotifier, soundProvider, toggle, achievementsProvider, chatProvider, leave, AchievementsScreen (+14 more)

### Community 26 - "LAN Guest Client"
Cohesion: 0.09
Nodes (22): DateTime?, _channel, close, connect, _ctrl, _deadTimeout, events, _heartbeat (+14 more)

### Community 27 - "Transport Interfaces"
Cohesion: 0.10
Nodes (22): int?, broadcast, close, code, connect, events, GuestConnected, GuestDisconnected (+14 more)

### Community 28 - "Hearts Bar Widget"
Cohesion: 0.09
Nodes (21): PlayerInfo, _AttributionBadge, build, current, filled, _Heart, HeartsBar, heartsLostBy (+13 more)

### Community 29 - "In-App Purchase State"
Cohesion: 0.10
Nodes (21): ../../app/coin_packs.dart, available, build, _buy, buyCoins, buyTip, copyWith, error (+13 more)

### Community 30 - "Session Providers"
Cohesion: 0.15
Nodes (22): ConsumerState, ConsumerStatefulWidget, mutedProvider, localProfileProvider, sessionProvider, GameScreen, _GameScreenState, initState (+14 more)

### Community 31 - "mDNS Discovery (io)"
Cohesion: 0.09
Nodes (21): dart:async, Discovery?, _ctrl, DiscoveredHost, _discovery, DiscoveryAdvertiser, DiscoveryBrowser, firstOrNull (+13 more)

### Community 32 - "How To Play Sheet"
Cohesion: 0.09
Nodes (20): difficulty_picker.dart, ../../game/difficulty.dart, game_panel.dart, IconData, body, build, _HowToPlaySheet, icon (+12 more)

### Community 33 - "Relay Room Durable Object"
Cohesion: 0.20
Nodes (7): GuestRecord, Room, shortId(), Env, fetch(), normalizeCode(), randomCode()

### Community 34 - "AdMob Ads Facade"
Cohesion: 0.10
Nodes (20): ad_ids.dart, InterstitialAd?, Ads, available, createMenuBanner, _gatherConsent, init, instance (+12 more)

### Community 35 - "Ad Gate Pacing"
Cohesion: 0.10
Nodes (20): AdGateNotifier, AdGateState, copyWith, interstitialDue, _kInterstitialEveryNMatches, _kInterstitialMinGap, _kLastInterstitialMs, _kLastRewardedMs (+12 more)

### Community 36 - "Chat State"
Cohesion: 0.10
Nodes (20): build, ChatMessage, ChatNotifier, ChatState, clear, close, copyWith, _keep (+12 more)

### Community 37 - "Store & Skin Providers"
Cohesion: 0.14
Nodes (21): _grant, iapProvider, boardSkinProvider, storeProvider, build, _confirmReset, _buildBody, build (+13 more)

### Community 38 - "Cell Tile Widget"
Cohesion: 0.10
Nodes (20): _bg, build, CellTile, _content, _decoration, _flag, flagColor, _glyphShadows (+12 more)

### Community 39 - "Ambient Background"
Cohesion: 0.12
Nodes (17): ../../app/theme.dart, Clip, Color, EdgeInsetsGeometry?, GamePalette, AmbientBackground, build, child (+9 more)

### Community 40 - "Server Message Types"
Cohesion: 0.11
Nodes (19): SChat, SCursor, SCursorLeave, SEmoji, SError, ServerMessage, SFlagged, SGameOver (+11 more)

### Community 41 - "Stats Charts Widget"
Cohesion: 0.11
Nodes (18): GameSnapshot, build, _ChartEmpty, color, CumulativeRevealsLine, formatMmSs, isRing, label (+10 more)

### Community 42 - "Difficulty & GameConfig"
Cohesion: 0.11
Nodes (17): autoFlagChord, cellCount, copyWith, Difficulty, fromDifficulty, fromJson, fromName, GameConfig (+9 more)

### Community 43 - "Screen Shake Effect"
Cohesion: 0.12
Nodes (16): AnimationController, _activeMagnitude, _angleSeed, build, child, createState, _ctrl, didUpdateWidget (+8 more)

### Community 44 - "App Entry Point"
Cohesion: 0.13
Nodes (14): ../../analytics/analytics.dart, app/router.dart, _AppScrollBehavior, build, buildScrollbar, main, MinesweeperApp, prefs (+6 more)

### Community 45 - "Relay TypeScript Config"
Cohesion: 0.12
Nodes (15): @cloudflare/workers-types, ES2022, src/**/*.ts, compilerOptions, esModuleInterop, isolatedModules, lib, module (+7 more)

### Community 46 - "App Icon Brand Identity"
Cohesion: 0.23
Nodes (15): Android Adaptive Icon Foreground Layer (xxxhdpi drawable), Android Legacy Launcher Icon (xxxhdpi mipmap), flutter_launcher_icons Generation Pipeline, Canonical Icon Source (assets/icon/icon.png, 1024px), Spiked Bomb Bursting Through Minesweeper Grid (visual motif), Minesweeper Co-op Brand Identity (visual), Master App Icon Artwork (M icon.png), Neon Blue-to-Magenta Radial Burst Palette (+7 more)

### Community 47 - "Skin Picker Widget"
Cohesion: 0.13
Nodes (14): cell_tile.dart, locked, _LockOverlay, onTap, price, _sample, _sampleFlag, selected (+6 more)

### Community 48 - "Relay Package Manifest"
Cohesion: 0.13
Nodes (14): @cloudflare/workers-types, devDependencies, @cloudflare/workers-types, typescript, wrangler, name, private, scripts (+6 more)

### Community 49 - "Avatar Widget"
Cohesion: 0.14
Nodes (14): dart:convert, Avatar, avatarData, build, _bytes, color, createState, data (+6 more)

### Community 50 - "Client Message Types"
Cohesion: 0.13
Nodes (15): CChat, CChord, CCursor, CCursorLeave, CEmoji, CFlag, CJoin, CLeave (+7 more)

### Community 51 - "Chat Panel Widget"
Cohesion: 0.13
Nodes (14): color, _controller, createState, dispose, _EmptyState, _focus, initState, _jumpToBottom (+6 more)

### Community 52 - "Coin Store Ledger"
Cohesion: 0.15
Nodes (13): ../../app/skin_pricing.dart, addCoins, buy, coins, copyWith, _kCoinsKey, _kOwnedKey, kStartingCoins (+5 more)

### Community 53 - "Pressable Interaction"
Cohesion: 0.15
Nodes (13): Duration, build, child, createState, duration, _hovered, hoverScale, onTap (+5 more)

### Community 54 - "Host Transport Stubs"
Cohesion: 0.14
Nodes (13): int get, RelayHostTransport, LanHostTransport, broadcast, events, LanHostTransport, port, sendToGuest (+5 more)

### Community 55 - "Discovery Web Stubs"
Cohesion: 0.14
Nodes (13): DiscoveredHost, DiscoveryAdvertiser, DiscoveryBrowser, host, hosts, name, port, serviceName (+5 more)

### Community 56 - "About Screen"
Cohesion: 0.14
Nodes (13): AboutScreen, build, icon, kPrivacyPolicyUrl, kSupportEmail, label, _LinkRow, onTap (+5 more)

### Community 57 - "Android Icon Density Ladder"
Cohesion: 0.26
Nodes (13): Adaptive Icon Foreground (hdpi), Icons Generated from assets/icon/icon.png via flutter_launcher_icons, Adaptive Icon Foreground (mdpi), Adaptive Icon Foreground (xhdpi), Adaptive Icon Foreground (xxhdpi), Opaque Full-Bleed Foreground Layer, Legacy Launcher Icon (hdpi), Legacy Launcher Icon (mdpi) (+5 more)

### Community 58 - "Stateful Widget States"
Cohesion: 0.23
Nodes (13): _BoardCamera, _BoardCameraState, _ElapsedStatBubble, _ElapsedStatBubbleState, _StatsSection, _StatsSectionState, Confetti, _ConfettiState (+5 more)

### Community 59 - "Join Screen"
Cohesion: 0.15
Nodes (12): createState, dispose, initState, lanUrl, roomCode, package:wakelock_plus/wakelock_plus.dart, ../widgets/chat_button.dart, ../widgets/chat_overlay.dart (+4 more)

### Community 60 - "Menu Banner Ad"
Cohesion: 0.18
Nodes (11): ../../ads/ads.dart, BannerAd?, _ad, build, createState, dispose, initState, _loaded (+3 more)

### Community 61 - "IAP Setup Contract"
Cohesion: 0.17
Nodes (12): Ads are Android-only (no web/Windows support), Immutable state objects with copyWith reducers, Billing is Android-only; coin UI hidden on web/Windows, Coin pack catalogue (coins_handful/stack/chest/vault), Always acknowledge via completePurchase() to avoid auto-refund, In-App Purchases (Play Billing), Product ID = code↔Play Console contract, Coin grants read from a trusted table, never client input (+4 more)

### Community 62 - "Windows Win32 Entry"
Cohesion: 0.24
Nodes (9): _In_, _In_opt_, vector, wWinMain(), string, wchar_t, CreateAndAttachConsole(), GetCommandLineArguments() (+1 more)

### Community 63 - "Ad Unit IDs"
Cohesion: 0.17
Nodes (11): bannerAdUnitId, interstitialAdUnitId, _pick, _realBanner, _realInterstitial, _realRewarded, rewardedAdUnitId, _testBanner (+3 more)

### Community 64 - "Explosion Overlay"
Cohesion: 0.18
Nodes (10): explosion_timing.dart, build, cellSize, centers, delayMs, eventId, ExplosionOverlay, _Ring (+2 more)

### Community 65 - "SharedPreferences Persistence"
Cohesion: 0.18
Nodes (11): sharedPreferencesProvider, build, _persist, build, _persist, build, setAvatarData, setDifficulty (+3 more)

### Community 66 - "Engine Unit Tests"
Cohesion: 0.25
Nodes (8): package:flutter_test/flutter_test.dart, package:minesweeper/game/board.dart, package:minesweeper/game/difficulty.dart, package:minesweeper/game/engine.dart, package:minesweeper/net/messages.dart, main, main, main

### Community 67 - "Web PWA Manifest"
Cohesion: 0.18
Nodes (10): background_color, description, display, icons, name, orientation, prefer_related_applications, short_name (+2 more)

### Community 68 - "Privacy & Data Safety"
Cohesion: 0.27
Nodes (10): Play Data Safety: advertising ID declaration, UMP consent prompt for EEA/UK, Advertising and analytics disclosure (AdMob + Firebase), Multiplayer data flow (LAN direct vs relayed room code), No accounts / no sign-up policy, Minesweeper Co-op Privacy Policy, Play Data safety form answers, Google Play Console one-time setup (+2 more)

### Community 69 - "Authoritative Host Protocol"
Cohesion: 0.29
Nodes (10): Authoritative host model (host GameEngine is sole source of truth), Backward compatibility: decoders accept legacy message shapes, Forward compatibility: unknown types decode to CUnknown/SUnknown, Host renders through the guest code path (localEvents stream), protocolVersion (currently 5) bump-on-break, Relay internals (worker.ts router + room.ts Durable Object), Wire protocol ({"t":type,"d":payload} ClientMessage/ServerMessage), Relay outer envelope (to-host/to-guest/to-all/control frames) (+2 more)

### Community 70 - "Game Modes & Determinism"
Cohesion: 0.22
Nodes (10): Deterministic seeded mine placement with 3x3 safe zone, Flag accuracy computed once at game-end to avoid desync, Game modes (classic / hearts), Hearts mode chain explosion, Analytics event catalogue (host_started, match_started, match_ended, skin_purchased), Swappable Analytics facade, Firebase config keys are non-secret and committed, Firebase Analytics (project minesweeper-co-op) (+2 more)

### Community 71 - "Coin Pack Catalogue"
Cohesion: 0.20
Nodes (9): badge, CoinPack, coinPackForId, coins, kCoinPacks, kCoinProductIds, label, null (+1 more)

### Community 72 - "Transport Seam Rationale"
Cohesion: 0.33
Nodes (9): Single shared AmbientBackground behind transparent scaffolds, stub/io conditional export split for the web build, Transport seam (HostTransport/GuestTransport as pure pipes), Dart & Flutter DevTools extension settings, minesweeper pubspec (version 1.0.0+1, Dart ^3.9.2), flutter_launcher_icons config (android/web/windows), Networking deps (shelf, shelf_web_socket, web_socket_channel, nsd), Multiplayer LAN Minesweeper (project overview) (+1 more)

### Community 73 - "Short ID Generation"
Cohesion: 0.22
Nodes (8): dart:math, _alphabet, buf, joinCode, n, rng, shortId, toString

### Community 74 - "Tip Jar Products"
Cohesion: 0.22
Nodes (8): emoji, isTipProduct, kTipProductIds, kTips, label, productId, TipTier, Set

### Community 75 - "Reconnect & Presence"
Cohesion: 0.36
Nodes (8): 30s offline grace window before eviction, Liveness ping/pong and dead-timeout close, Logical vs transport player ids, Online host reclaim (/reclaim/<code>, SHostAway/SHostBack), Reconnect / presence subsystem, Rejoin token (stable identity across reconnects), 5-char Crockford base32 room code, Room limits (1 host + 7 guests, 30s host grace, no persistence)

### Community 76 - "Interstitial & Rewarded Flow"
Cohesion: 0.25
Nodes (8): adGateProvider, emojiBurstProvider, _handleServerMessage, _Cta, _maybeShowInterstitial, _watchRewarded, build, EmojiOverlay

### Community 77 - "Session Notifiers"
Cohesion: 0.29
Nodes (8): DiscoveryNotifier, EmojiBurstNotifier, LocalProfile, LocalProfileNotifier, SessionNotifier, SessionState, List, Notifier

### Community 78 - "Route Builders"
Cohesion: 0.36
Nodes (8): build, build, build, build, Route /, Route /game, Route /join, Route /result

### Community 79 - "Emoji Bar Widget"
Cohesion: 0.25
Nodes (7): build, EmojiBar, emojiFontFallback, _emojis, onSend, static const, ValueChanged

### Community 80 - "AdMob Setup Guide"
Cohesion: 0.33
Nodes (7): Ad Gate pacing tunables (kRewardedCoins, cooldown, cadence), AdMob Ads Integration (Android), Banner Ad (Home and Store only), Interstitial Ad (every 3rd finished match), Rewarded Ad (free coins, +250, 60s cooldown), Link AdMob to the Firebase project for ad revenue, Deferred work (ads/monetization, iOS, transport integration tests)

### Community 81 - "Firebase Options Config"
Cohesion: 0.29
Nodes (6): android, DefaultFirebaseOptions, web, package:firebase_core/firebase_core.dart, package:flutter/foundation.dart, static const FirebaseOptions

### Community 82 - "Explosion Timing Curve"
Cohesion: 0.29
Nodes (6): ExplosionTiming, maxDistance, msPerCenter, msPerDistance, ringDurationMs, static const int

### Community 83 - "Windows CMake Build"
Cohesion: 0.48
Nodes (7): Windows distribution via Microsoft Store / MSIX, APPLY_STANDARD_SETTINGS (C++17, /W4 /WX, no exceptions), Windows top-level CMake project (BINARY_NAME minesweeper, install rules), flutter_assemble custom target (tool_backend.bat), flutter_wrapper_app static library, flutter_wrapper_plugin static library, Windows runner executable target

### Community 84 - "Skin Selection State"
Cohesion: 0.33
Nodes (5): ../../app/board_skin.dart, ../core/prefs.dart, build, _kSelectedSkinKey, select

### Community 85 - "Skin Pricing Table"
Cohesion: 0.33
Nodes (5): board_skin.dart, kFreeSkinId, skinPrice, _structurePrice, Map

### Community 86 - "Release Build Checklist"
Cohesion: 0.40
Nodes (5): flutter_lints analyzer configuration, RELAY_URL dart-define build flag, Release build commands (appbundle/apk/windows/web), Pre-submit checklist, Upload keystore + key.properties (irrecoverable if lost)

### Community 87 - "Relay URL Config"
Cohesion: 0.40
Nodes (4): bool get, _placeholderRelayUrl, relayBaseUrl, relayIsConfigured

### Community 88 - "Local IP Lookup (io)"
Cohesion: 0.40
Nodes (4): dart:io, getLocalIPv4Addresses, out, return

### Community 90 - "Immutable Skin Model"
Cohesion: 0.67
Nodes (3): @immutable, BoardSkin, BoardSkinNotifier

## Ambiguous Edges - Review These
- `AdMob Ads Integration (Android)` → `Store listing copy (Minesweeper Co-op)`  [AMBIGUOUS]
  RELEASE.md · relation: conceptually_related_to
- `Adaptive Icon Foreground (mdpi)` → `Opaque Full-Bleed Foreground Layer`  [AMBIGUOUS]
  android/app/src/main/res/drawable-mdpi/ic_launcher_foreground.png · relation: conceptually_related_to

## Knowledge Gaps
- **1120 isolated node(s):** `_testBanner`, `_testInterstitial`, `_testRewarded`, `_realBanner`, `_realInterstitial` (+1115 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **11 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What is the exact relationship between `AdMob Ads Integration (Android)` and `Store listing copy (Minesweeper Co-op)`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._
- **What is the exact relationship between `Adaptive Icon Foreground (mdpi)` and `Opaque Full-Bleed Foreground Layer`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._
- **Why does `GameConfig` connect `Difficulty & GameConfig` to `Session State Hub`, `How To Play Sheet`, `Wire Protocol Payloads`, `Game Engine Core`, `Board Logic & Flood Fill`, `Host Session Authority`, `Difficulty Picker Widget`?**
  _High betweenness centrality (0.024) - this node is a cross-community bridge._
- **Why does `GamePalette` connect `Ambient Background` to `How To Play Sheet`, `Game Screen Layout`, `Host Lobby Screen`, `Result Screen & Stats`, `App Theme Palette`, `Achievements Screen UI`, `Store Screen UI`, `Chat Panel Widget`, `Home Screen`, `About Screen`, `Achievement Toast Overlay`, `Immutable Skin Model`?**
  _High betweenness centrality (0.011) - this node is a cross-community bridge._
- **Why does `sessionProvider` connect `Session Providers` to `Session State Hub`, `Store & Skin Providers`, `Interstitial & Rewarded Flow`, `Route Builders`, `Chat Panel Widget`, `Riverpod Consumer Widgets`?**
  _High betweenness centrality (0.006) - this node is a cross-community bridge._
- **What connects `_testBanner`, `_testInterstitial`, `_testRewarded` to the rest of the system?**
  _1120 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Session State Hub` be split into smaller, more focused modules?**
  _Cohesion score 0.018867924528301886 - nodes in this community are weakly interconnected._
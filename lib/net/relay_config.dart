/// Placeholder value that signals "no relay configured". Online play is
/// disabled until the build overrides [relayBaseUrl] with a real URL.
const _placeholderRelayUrl = 'wss://minesweeper-relay.example.workers.dev';

/// Base URL of the relay deployment. Override at build time with
/// `--dart-define=RELAY_URL=wss://your-relay.workers.dev`.
const relayBaseUrl = String.fromEnvironment(
  'RELAY_URL',
  defaultValue: _placeholderRelayUrl,
);

bool get relayIsConfigured => relayBaseUrl != _placeholderRelayUrl;

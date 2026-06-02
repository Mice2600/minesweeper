/// Placeholder value that signals "no relay configured". Online play is
/// disabled if [relayBaseUrl] is ever overridden back to this.
const _placeholderRelayUrl = 'wss://minesweeper-relay.example.workers.dev';

/// Base URL of the relay deployment. Defaults to the production relay so
/// shipped builds have working online play without any build flag. Override
/// at build time with `--dart-define=RELAY_URL=wss://your-relay.workers.dev`
/// (e.g. to point at a local relay during development).
const relayBaseUrl = String.fromEnvironment(
  'RELAY_URL',
  defaultValue: 'wss://minesweeper-relay.lacon.workers.dev',
);

bool get relayIsConfigured => relayBaseUrl != _placeholderRelayUrl;

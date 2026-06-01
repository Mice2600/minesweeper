import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One chat line as held in the local transcript.
class ChatMessage {
  const ChatMessage({
    required this.playerId,
    required this.name,
    required this.text,
    required this.ts,
    required this.mine,
  });

  /// Logical author id — resolve the live avatar/color via
  /// `GameSnapshot.playerById`. Falls back to [name] if the author has left.
  final String playerId;

  /// Author name snapshot at send time.
  final String name;
  final String text;

  /// Host epoch-ms timestamp (source of truth for ordering).
  final int ts;

  /// True if this is the local player's own message — rendered differently and
  /// never counted as unread.
  final bool mine;
}

/// Chat transcript + the two bits of view state the UI needs: how many lines
/// have arrived unseen, and whether the panel is currently open.
class ChatState {
  const ChatState({
    this.messages = const [],
    this.unread = 0,
    this.open = false,
  });

  final List<ChatMessage> messages;
  final int unread;
  final bool open;

  ChatState copyWith({
    List<ChatMessage>? messages,
    int? unread,
    bool? open,
  }) =>
      ChatState(
        messages: messages ?? this.messages,
        unread: unread ?? this.unread,
        open: open ?? this.open,
      );
}

/// Holds the chat transcript independently of [GameSnapshot] (which is rebuilt
/// on lobby/game/snapshot messages), so chat survives the lobby → game
/// transition. Cleared on leave / new session.
final chatProvider =
    NotifierProvider<ChatNotifier, ChatState>(ChatNotifier.new);

class ChatNotifier extends Notifier<ChatState> {
  /// Cap the in-memory transcript so a long session can't grow without bound.
  static const _maxMessages = 200;

  @override
  ChatState build() => const ChatState();

  /// Appends a received line. Bumps the unread badge only for *other* players'
  /// messages that arrive while the panel is closed.
  void receive({
    required String playerId,
    required String name,
    required String text,
    required int ts,
    required bool mine,
  }) {
    final next = [...state.messages, ChatMessage(
      playerId: playerId,
      name: name,
      text: text,
      ts: ts,
      mine: mine,
    )];
    if (next.length > _maxMessages) {
      next.removeRange(0, next.length - _maxMessages);
    }
    final bumpUnread = !mine && !state.open;
    state = state.copyWith(
      messages: next,
      unread: bumpUnread ? state.unread + 1 : state.unread,
    );
  }

  /// Open the panel and mark everything read.
  void open() => state = state.copyWith(open: true, unread: 0);

  void close() => state = state.copyWith(open: false);

  void toggle() => state.open ? close() : open();

  /// Reset on leave / new session.
  void clear() => state = const ChatState();
}

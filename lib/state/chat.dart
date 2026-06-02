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

/// Chat transcript + the view state the UI needs: unread count, panel open
/// flag, and the last message from another player (for the toast preview).
class ChatState {
  const ChatState({
    this.messages = const [],
    this.unread = 0,
    this.open = false,
    this.lastMessage,
  });

  final List<ChatMessage> messages;
  final int unread;
  final bool open;

  /// Last message received from another player. Drives the toast preview.
  final ChatMessage? lastMessage;

  static const _keep = Object();

  ChatState copyWith({
    List<ChatMessage>? messages,
    int? unread,
    bool? open,
    Object? lastMessage = _keep,
  }) =>
      ChatState(
        messages: messages ?? this.messages,
        unread: unread ?? this.unread,
        open: open ?? this.open,
        lastMessage: identical(lastMessage, _keep)
            ? this.lastMessage
            : lastMessage as ChatMessage?,
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
    final msg = ChatMessage(
      playerId: playerId,
      name: name,
      text: text,
      ts: ts,
      mine: mine,
    );
    final next = [...state.messages, msg];
    if (next.length > _maxMessages) {
      next.removeRange(0, next.length - _maxMessages);
    }
    final bumpUnread = !mine && !state.open;
    state = state.copyWith(
      messages: next,
      unread: bumpUnread ? state.unread + 1 : state.unread,
      lastMessage: !mine ? msg : ChatState._keep,
    );
  }

  /// Open the panel and mark everything read.
  void open() => state = state.copyWith(open: true, unread: 0);

  void close() => state = state.copyWith(open: false);

  void toggle() => state.open ? close() : open();

  /// Reset on leave / new session.
  void clear() => state = const ChatState(lastMessage: null);
}

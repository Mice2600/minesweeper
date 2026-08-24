/// Text moderation for user-generated content.
///
/// Two surfaces feed through here:
///
///  * **display names** — [sanitizeName], applied when a player joins,
///  * **chat lines** — [maskProfanity], applied before the host re-broadcasts.
///
/// Both run on the **host**, which is authoritative for names and chat, so a
/// patched client can't push raw text to the rest of the room. The guest-side
/// composer doesn't pre-filter: showing the sender their own unmasked text and
/// then masking it for everyone else is the same tradeoff every chat product
/// makes, and it keeps the authoritative path single.
///
/// The matcher folds leetspeak, accents, and zero-width padding before it
/// compares, so `f.u.c.k`, `fu¢k`, `ƒúck`, and `f​uck` all land on the
/// same entry. Two lists with different strictness keep the false-positive
/// rate sane:
///
///  * [_blockedAnywhere] — terms with no innocent substring host, matched
///    anywhere in the folded text (this is what catches separator evasion).
///  * [_blockedWords] — terms that *are* substrings of ordinary English
///    ("ass" in "grass", "anal" in "analysis", "pedo" in "torpedo"), matched
///    only as a whole token.
///
/// This is a floor, not a guarantee. It exists so the app has a real content
/// filter behind the in-app report/block/kick tools, which is what Google
/// Play's user-generated-content policy requires.
library;

import 'dart:convert';

class Moderation {
  Moderation._();

  /// Longest display name the host will store. Longer names are truncated.
  static const int maxNameLength = 16;

  /// Longest chat line the host will re-broadcast.
  static const int maxChatLength = 280;

  /// Largest avatar payload the host will accept, in base64 characters. The
  /// picker produces a 72×72 q70 JPEG (~2–4 KB), so this is a generous ceiling
  /// that still bounds what a single join can cost every *other* device in the
  /// room — each one decodes the blob and holds it in memory.
  static const int maxAvatarBase64Length = 32 * 1024;

  /// Fallback when a name sanitizes down to nothing.
  static const String fallbackName = 'Player';

  /// The reaction set the emoji bar offers, in display order. The host drops
  /// any `CEmoji` whose code isn't in here, so the reaction channel can't be
  /// used to push arbitrary text past the chat filter.
  static const List<String> emojiReactions = [
    '👍',
    '❤️',
    '😂',
    '😮',
    '🎉',
    '🤔',
    '🚩',
    '💣',
  ];

  /// True when [code] is one of the reactions the UI actually offers.
  static bool isAllowedEmoji(String code) => emojiReactions.contains(code);

  // ─── Public API ───────────────────────────────────────────────────────────

  /// Returns [text] with any blocked term replaced by `*`, one per source
  /// character, so the shape of the message survives but the term doesn't.
  /// Separators *inside* a match are masked too — `f.u.c.k` becomes `*******`.
  static String maskProfanity(String text) {
    final src = stripInvisible(text);
    final marked = _markProfanity(src);
    if (marked.isEmpty) return src;
    final out = StringBuffer();
    for (var i = 0; i < src.length; i++) {
      out.write(marked.contains(i) ? '*' : src[i]);
    }
    return out.toString();
  }

  /// True when [text] contains a blocked term. Used for the "pick another
  /// name" hint on the profile editor; the host masks regardless.
  static bool containsProfanity(String text) =>
      _markProfanity(stripInvisible(text)).isNotEmpty;

  /// Normalizes a display name: strips invisible characters, collapses runs of
  /// whitespace, caps the length, masks profanity, and falls back to
  /// [fallbackName] if nothing usable is left.
  static String sanitizeName(String raw) {
    var t = stripInvisible(raw).replaceAll(RegExp(r'\s+'), ' ').trim();
    if (t.length > maxNameLength) t = t.substring(0, maxNameLength).trim();
    t = maskProfanity(t);
    // A name that is nothing but mask characters is worse than no name.
    if (t.isEmpty || RegExp(r'^\*+$').hasMatch(t)) return fallbackName;
    return t;
  }

  /// Normalizes a chat line: strips invisible characters, trims, caps the
  /// length, masks profanity. Returns `''` for anything the caller should drop.
  static String sanitizeChat(String raw) {
    var t = stripInvisible(raw).trim();
    if (t.isEmpty) return '';
    if (t.length > maxChatLength) t = t.substring(0, maxChatLength);
    return maskProfanity(t);
  }

  /// Validates a client-supplied avatar. Returns the payload unchanged when it
  /// is an in-budget JPEG, or `null` for anything the caller should drop —
  /// oversized, not valid base64, or not a JPEG.
  ///
  /// This **rejects rather than truncates**, unlike the text sanitizers above.
  /// A clipped JPEG is its own decoder hazard, and unlike a name or a chat
  /// line, this payload is handed to an image decoder on every device in the
  /// room — so the safe failure mode is "no photo", not "partial photo".
  static String? sanitizeAvatar(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    if (raw.length > maxAvatarBase64Length) return null;
    try {
      final bytes = base64Decode(raw);
      // JPEG start-of-image marker. The picker always encodes JPEG (see
      // SessionNotifier.pickAndCompressAvatar), so anything else is a client
      // that went off-script.
      if (bytes.length < 3 ||
          bytes[0] != 0xFF ||
          bytes[1] != 0xD8 ||
          bytes[2] != 0xFF) {
        return null;
      }
    } catch (_) {
      return null;
    }
    return raw;
  }

  /// Removes control characters, zero-width joiners/spaces, and bidi overrides.
  /// These render as nothing (or as garbage) and exist in user input almost
  /// exclusively to break naive filters.
  static String stripInvisible(String s) => s.replaceAll(_invisible, '');

  // ─── Matcher ──────────────────────────────────────────────────────────────

  static final RegExp _invisible = RegExp(
    '[\u0000-\u001F\u007F\u00AD\u200B-\u200F\u202A-\u202E\u2060-\u2064\uFEFF]',
  );

  /// A token is a maximal run of letters, digits, and the symbols people
  /// substitute for letters. Everything else separates tokens.
  static final RegExp _token = RegExp(r'[\p{L}\p{N}@$!|+]+', unicode: true);

  /// Original-string indices that fall inside a blocked term.
  static Set<int> _markProfanity(String src) {
    final marked = <int>{};
    if (src.isEmpty) return marked;

    // Pass 1 — whole-token matches, for terms that are substrings of ordinary
    // words. `grass` must survive; `ass` must not.
    for (final m in _token.allMatches(src)) {
      final folded = _foldLetters(src.substring(m.start, m.end)).letters;
      if (_isBlockedWord(folded)) {
        _mark(marked, m.start, m.end - 1);
      }
    }

    // Pass 2 — substring matches over the whole string with every non-letter
    // dropped. This is what defeats `f.u.c.k`, `f u c k`, and `f-u-c-k`.
    final folded = _foldLetters(src);
    _markSubstrings(marked, folded);

    // Pass 3 — same, with runs of 3+ identical letters collapsed, so
    // `fuuuuck` folds back onto `fuck`. Runs of two are left alone; collapsing
    // those would mangle ordinary words.
    final collapsed = _collapseRuns(folded);
    if (collapsed.letters != folded.letters) {
      _markSubstrings(marked, collapsed);
    }

    return marked;
  }

  static void _markSubstrings(Set<int> marked, _Folded f) {
    if (f.letters.isEmpty) return;
    for (final term in _blockedAnywhere) {
      var from = 0;
      while (true) {
        final at = f.letters.indexOf(term, from);
        if (at < 0) break;
        _mark(marked, f.start[at], f.end[at + term.length - 1]);
        from = at + 1;
      }
    }
  }

  static void _mark(Set<int> out, int from, int to) {
    for (var i = from; i <= to; i++) {
      out.add(i);
    }
  }

  static bool _isBlockedWord(String folded) {
    if (folded.isEmpty) return false;
    if (_blockedWords.contains(folded)) return true;
    // Cheap plural/possessive tolerance so `dicks` and `pedos` don't need
    // their own entries.
    if (folded.length > 3 && folded.endsWith('s')) {
      if (_blockedWords.contains(folded.substring(0, folded.length - 1))) {
        return true;
      }
    }
    return false;
  }

  /// Folds [s] down to bare lowercase ASCII letters, remembering which source
  /// characters each folded letter came from so a match can be mapped back.
  static _Folded _foldLetters(String s) {
    final buf = StringBuffer();
    final start = <int>[];
    final end = <int>[];
    for (var i = 0; i < s.length; i++) {
      final folded = _foldMap[s[i].toLowerCase()] ?? s[i].toLowerCase();
      if (folded.length != 1) continue;
      final code = folded.codeUnitAt(0);
      if (code < 0x61 || code > 0x7A) continue; // a-z only
      buf.write(folded);
      start.add(i);
      end.add(i);
    }
    return _Folded(buf.toString(), start, end);
  }

  /// Collapses runs of 3 or more identical letters to a single letter, keeping
  /// the source range of the whole run so masking still covers all of it.
  static _Folded _collapseRuns(_Folded f) {
    final letters = f.letters;
    if (letters.length < 3) return f;
    final buf = StringBuffer();
    final start = <int>[];
    final end = <int>[];
    var i = 0;
    while (i < letters.length) {
      var j = i;
      while (j + 1 < letters.length && letters[j + 1] == letters[i]) {
        j++;
      }
      final runLength = j - i + 1;
      if (runLength >= 3) {
        buf.write(letters[i]);
        start.add(f.start[i]);
        end.add(f.end[j]);
      } else {
        for (var k = i; k <= j; k++) {
          buf.write(letters[k]);
          start.add(f.start[k]);
          end.add(f.end[k]);
        }
      }
      i = j + 1;
    }
    return _Folded(buf.toString(), start, end);
  }

  /// Leetspeak, currency-symbol, and accent folding.
  static const Map<String, String> _foldMap = {
    '0': 'o', '1': 'i', '3': 'e', '4': 'a', '5': 's', '6': 'g', '7': 't',
    '8': 'b', '9': 'g', '@': 'a', r'$': 's', '!': 'i', '|': 'l', '+': 't',
    '¢': 'c', '£': 'l', '€': 'e', '¥': 'y', '§': 's', 'µ': 'u',
    'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a', 'ā': 'a',
    'ă': 'a', 'ą': 'a', 'æ': 'a',
    'ç': 'c', 'ć': 'c', 'č': 'c',
    'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e', 'ē': 'e', 'ė': 'e', 'ę': 'e',
    'ě': 'e',
    'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i', 'ī': 'i', 'į': 'i', 'ı': 'i',
    'ñ': 'n', 'ń': 'n', 'ň': 'n',
    'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o', 'ø': 'o', 'ō': 'o',
    'ő': 'o', 'œ': 'o',
    'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u', 'ū': 'u', 'ů': 'u', 'ű': 'u',
    'ý': 'y', 'ÿ': 'y',
    'ß': 's', 'ś': 's', 'š': 's', 'ş': 's',
    'ź': 'z', 'ż': 'z', 'ž': 'z',
    'ť': 't', 'ţ': 't', 'ð': 'd', 'đ': 'd', 'ď': 'd',
    'ł': 'l', 'ĺ': 'l', 'ľ': 'l',
    'ř': 'r', 'ŕ': 'r',
    'ğ': 'g', 'ĝ': 'g',
    'ƒ': 'f', 'þ': 'p',
  };

  /// Terms with no innocent substring host — safe to match anywhere, which is
  /// what makes separator evasion (`f.u.c.k`) detectable.
  static const Set<String> _blockedAnywhere = {
    'fuck', 'fuk', 'fck', 'fuq', 'phuck',
    'shit', 'bullshi',
    'cunt', 'whore', 'slut', 'bastard', 'bitch',
    'asshole', 'arsehole', 'dickhead', 'jackass', 'dumbass', 'wanker',
    'bollocks', 'twat', 'motherfuck',
    'nigger', 'nigga', 'faggot', 'kike', 'wetback', 'tranny', 'towelhead',
    'raghead', 'beaner', 'chink',
    'retard', 'spastic',
    'rapist', 'molest', 'pedophile', 'paedophile', 'childporn',
    'incest', 'bestiality', 'necrophil',
    'dildo', 'blowjob', 'handjob', 'rimjob', 'jizz', 'cumshot', 'creampie',
    'porn', 'hentai', 'penis', 'vagina', 'clitoris', 'masturbat',
    'goatse', 'lolicon', 'shota',
    // Non-letters are dropped before matching, so this also catches
    // "kill yourself", "k-i-l-l y0urself", and friends.
    'killyourself', 'killurself',
  };

  /// Terms that are also substrings of ordinary words — matched only when they
  /// stand alone as a token.
  static const Set<String> _blockedWords = {
    'ass', 'arse', 'anal', 'anus', 'butthole',
    'cock', 'dick', 'cum', 'tit', 'tits', 'boob', 'boobs', 'pussy', 'pussies',
    'prick', 'ballsack', 'nutsack', 'semen', 'sperm', 'orgy', 'orgasm',
    'fag', 'fags', 'homo', 'dyke', 'queer', 'tranny',
    'spic', 'coon', 'gook', 'gypsy', 'jap', 'kraut', 'paki',
    'pedo', 'paedo', 'rape', 'raped', 'rapes', 'raping',
    'nazi', 'hitler', 'kkk', 'heil',
    'hoe', 'hoes', 'skank', 'douche', 'bimbo', 'milf',
    'kys', 'stfu', 'gtfo', 'wanker', 'tosser', 'minger',
    'crap', 'piss', 'pissed', 'turd', 'wtf',
  };
}

/// A folded view of a source string: bare lowercase letters plus, for each of
/// them, the source-index range it came from.
class _Folded {
  const _Folded(this.letters, this.start, this.end);

  /// Lowercase a–z only. Everything else in the source was dropped.
  final String letters;

  /// `start[i]` / `end[i]` bracket the source characters that produced
  /// `letters[i]`. They differ only for collapsed repeat-runs.
  final List<int> start;
  final List<int> end;
}

import 'package:flutter_test/flutter_test.dart';
import 'package:minesweeper/core/moderation.dart';
import 'package:minesweeper/state/moderation.dart';

void main() {
  group('maskProfanity — catches', () {
    const evasions = <String, String>{
      'plain': 'you fuck',
      'dots': 'you f.u.c.k',
      'spaces': 'you f u c k',
      'dashes': 'you f-u-c-k',
      'leetspeak': 'you fu(k off',
      'digits': 'you sh1t',
      'symbols': r'you $hit',
      'accents': 'you fúck',
      'stretched': 'you fuuuuck',
      'mixed case': 'you FuCk',
    };

    evasions.forEach((label, input) {
      test(label, () {
        final masked = Moderation.maskProfanity(input);
        expect(masked, contains('*'), reason: '"$input" was not filtered');
        expect(masked.toLowerCase(), isNot(contains('fuck')));
        expect(masked.toLowerCase(), isNot(contains('shit')));
      });
    });

    test('slurs are masked anywhere, even glued to other words', () {
      expect(Moderation.maskProfanity('xxfaggotxx'), contains('*'));
    });

    test('masking preserves the length of the source string', () {
      const input = 'what the f.u.c.k';
      expect(Moderation.maskProfanity(input).length, input.length);
    });
  });

  group('maskProfanity — leaves alone', () {
    // The Scunthorpe problem: these all *contain* a blocked term but are
    // ordinary words, so they must survive untouched.
    const innocent = [
      'nice grass tile',
      'that pass was clean',
      'run the analysis again',
      'fire the torpedo',
      'a raccoon in the cocoon',
      'suspicious clicking',
      'the cockpit is on fire',
      'documentation',
      'class is in session',
      'assassin',
      'Titanic',
      'hello there',
      'good luck sweeping!',
    ];

    for (final line in innocent) {
      test('"$line"', () {
        expect(Moderation.maskProfanity(line), line);
      });
    }

    test('empty input is returned unchanged', () {
      expect(Moderation.maskProfanity(''), '');
    });
  });

  group('containsProfanity', () {
    test('true for a blocked term', () {
      expect(Moderation.containsProfanity('sh!t'), isTrue);
    });
    test('false for ordinary text', () {
      expect(Moderation.containsProfanity('grass class pass'), isFalse);
    });
  });

  group('sanitizeName', () {
    test('trims and collapses whitespace', () {
      expect(Moderation.sanitizeName('  Al   ice  '), 'Al ice');
    });

    test('caps at the max length', () {
      final long = 'A' * 40;
      expect(
        Moderation.sanitizeName(long).length,
        lessThanOrEqualTo(Moderation.maxNameLength),
      );
    });

    test('strips zero-width padding used to evade the filter', () {
      // U+200B between every letter — renders as "fuck", folds to it too.
      const padded = 'f​u​c​k';
      final out = Moderation.sanitizeName(padded);
      expect(out.toLowerCase(), isNot(contains('fuck')));
    });

    test('a name that is entirely profanity falls back rather than starring out',
        () {
      expect(Moderation.sanitizeName('fuck'), Moderation.fallbackName);
    });

    test('an empty name falls back', () {
      expect(Moderation.sanitizeName('   '), Moderation.fallbackName);
    });

    test('ordinary names are untouched', () {
      expect(Moderation.sanitizeName('Sweeper42'), 'Sweeper42');
    });
  });

  group('sanitizeChat', () {
    test('drops whitespace-only input so the caller can skip it', () {
      expect(Moderation.sanitizeChat('   \n '), '');
    });

    test('truncates past the max length', () {
      final long = 'a' * 500;
      expect(Moderation.sanitizeChat(long).length, Moderation.maxChatLength);
    });

    test('masks while leaving the rest of the line readable', () {
      final out = Moderation.sanitizeChat('mine at 3,4 you idiot fuck');
      expect(out, startsWith('mine at 3,4 you idiot'));
      expect(out, endsWith('****'));
    });
  });

  group('BlockedPlayers', () {
    test('id match blocks', () {
      const b = BlockedPlayers(ids: {'p1'});
      expect(b.isBlocked(id: 'p1', name: 'Whoever'), isTrue);
      expect(b.isBlocked(id: 'p2', name: 'Whoever'), isFalse);
    });

    test('name match survives cosmetic respelling', () {
      final b = BlockedPlayers(names: {BlockedPlayers.foldName('Xx_Griefer_xX')});
      expect(b.isBlocked(id: 'newId', name: 'xX GRIEFER Xx'), isTrue);
    });

    test('unrelated players are not blocked', () {
      final b = BlockedPlayers(names: {BlockedPlayers.foldName('Griefer')});
      expect(b.isBlocked(id: 'x', name: 'Friend'), isFalse);
    });

    test('an empty block list matches nothing', () {
      const b = BlockedPlayers();
      expect(b.isBlocked(id: 'p1', name: 'Anyone'), isFalse);
    });
  });

  group('ReportReason', () {
    test('slug round-trips', () {
      for (final r in ReportReason.values) {
        expect(ReportReason.fromSlug(r.slug), r);
      }
    });

    test('an unrecognized slug degrades to `other` instead of throwing', () {
      expect(ReportReason.fromSlug('from-a-newer-build'), ReportReason.other);
    });
  });

  group('FiledReport', () {
    final report = FiledReport(
      targetName: 'Griefer',
      reason: ReportReason.abusiveChat,
      details: 'would not stop',
      evidence: const ['line one', 'line two'],
      ts: DateTime.utc(2026, 8, 4, 12, 30),
    );

    test('JSON round-trips', () {
      final back = FiledReport.fromJson(report.toJson());
      expect(back.targetName, report.targetName);
      expect(back.reason, report.reason);
      expect(back.details, report.details);
      expect(back.evidence, report.evidence);
      expect(back.ts, report.ts);
    });

    test('email body carries the evidence', () {
      final text = report.asText();
      expect(text, contains('Griefer'));
      expect(text, contains(ReportReason.abusiveChat.label));
      expect(text, contains('line one'));
      expect(text, contains('line two'));
    });
  });
}

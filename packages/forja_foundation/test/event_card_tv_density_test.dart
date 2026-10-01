import 'package:flutter_test/flutter_test.dart';
import 'package:forja_foundation/tokens/event_card_tokens.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';

void main() {
  test('event card type densifies on TV ladder', () {
    expect(
      EventCardTokens.titleFontSizeTv,
      ShellTokens.tvBodyFontSize,
    );
    expect(
      EventCardTokens.titleFontSizeTv,
      lessThan(EventCardTokens.titleFontSize),
    );
    expect(
      EventCardTokens.metaFontSizeTv,
      ShellTokens.tvMetaFontSize,
    );
    expect(
      EventCardTokens.radiusTv,
      lessThan(EventCardTokens.radius),
    );
  });
}

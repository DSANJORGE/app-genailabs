import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'testu_client.dart';
import 'testu_i18n.dart';
import 'testu_shell.dart';
import 'testu_theme.dart';
import 'testu_widgets.dart';

/// Desktop frame for the browser build (spec: testu-learn-web). Below
/// [kTestuWide] the child is the phone app untouched; from there on a left
/// rail carries the four tabs and every route lives in a centred 720px
/// column. Sits in MaterialApp.builder, outside the Navigator, so pushed
/// routes keep the rail beside them.
class TestuFrame extends StatelessWidget {
  const TestuFrame({
    super.key,
    required this.rail,
    required this.onTab,
    required this.child,
  });

  /// Rail only once signed in and unlocked — sign-in, the lock screen and
  /// the launch intro are client-neutral full-window surfaces.
  final bool rail;
  final ValueChanged<int> onTab;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!testuWide(context)) return child;
    final t = TestuTokens.of(context);
    return ColoredBox(
      color: t.bg,
      child: Row(children: [
        if (rail) TestuRail(onTab: onTab),
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: child,
            ),
          ),
        ),
      ]),
    );
  }
}

/// The bottom nav stood on its side: client logo or wordmark, then the four
/// mono labels with the 2px orange tick on their left edge (same colours
/// and tracking as [TestuNav]).
class TestuRail extends StatelessWidget {
  const TestuRail({super.key, required this.onTab});

  final ValueChanged<int> onTab;

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    return Container(
      width: 200,
      padding: const EdgeInsets.fromLTRB(18, 26, 18, 18),
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: t.line)),
      ),
      // Language switch re-reads L(); the shell tells us which tab is up.
      child: ValueListenableBuilder<String>(
        valueListenable: testuLang,
        builder: (_, _, _) => ValueListenableBuilder<int>(
          valueListenable: TestuShell.currentTab,
          builder: (_, current, _) {
            final labels = testuTabLabels();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (client.logo != null)
                  Image.asset(client.logo!, height: 22)
                else
                  Text(
                    client.wordmark.toUpperCase(),
                    style: TextStyle(
                      fontFamily: 'Sora',
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      letterSpacing: 0.8,
                      color: client.brand,
                    ),
                  ),
                const SizedBox(height: 34),
                for (var i = 0; i < labels.length; i++)
                  TestuPressable(
                    onTap: () => onTab(i),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          curve: TestuTokens.curve,
                          width: 2,
                          height: 12,
                          color: i == current ? t.orange : Colors.transparent,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          labels[i],
                          style: TextStyle(
                            fontFamily: 'GeistMono',
                            fontWeight: FontWeight.w500,
                            fontSize: 10,
                            letterSpacing: 1.2,
                            color: i == current ? t.ink : t.faint,
                          ),
                        ),
                      ]),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

const _kNudged = 'testu_web_nudged';

/// Phone-sized browser, once per browser: the web build is for desks, the
/// app is for phones (Diego, 2026-09-07). Checked at first frame only, so
/// resizing a desktop window never triggers it. [web] is the test seam.
/// ponytail: no store buttons until the App Store / Play listings exist.
Future<void> maybeShowTestuWebNudge(BuildContext context,
    {bool web = kIsWeb}) async {
  if (!web || MediaQuery.sizeOf(context).width >= 600) return;
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(_kNudged) ?? false) return;
  await prefs.setBool(_kNudged, true);
  if (!context.mounted) return;
  final t = TestuTokens.of(context);
  await showTestuDialog<void>(
    context,
    dismissible: false,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TestuEyebrow(L('MADE FOR DESKTOP', 'PENSADO PARA ESCRITORIO')),
        const SizedBox(height: 10),
        Text(
          L('TestU Learn on the web is designed for a desktop screen. On your phone, the TestU Learn app is the way to learn.',
              'TestU Learn en la web está pensado para pantallas de escritorio. En tu teléfono, la app de TestU Learn es la forma de aprender.'),
          style: TextStyle(
            fontFamily: 'Geist',
            fontSize: 13.5,
            height: 1.5,
            color: t.mut,
          ),
        ),
        const SizedBox(height: 16),
        TestuButton(
          L('CONTINUE ON THE WEB', 'SEGUIR EN LA WEB'),
          variant: TestuButtonVariant.primary,
          onTap: () => Navigator.of(context).pop(),
        ),
      ],
    ),
  );
}

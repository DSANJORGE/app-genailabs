import 'package:flutter/material.dart';

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
        builder: (_, __, ___) => ValueListenableBuilder<int>(
          valueListenable: TestuShell.currentTab,
          builder: (_, current, __) {
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

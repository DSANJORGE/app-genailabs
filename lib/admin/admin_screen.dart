import 'dart:async';

import 'package:eme_app_package/eme_http.dart' show EmeHttpException;
import 'package:flutter/material.dart';

import '../testu/testu_i18n.dart';
import 'admin_api.dart';
import 'admin_nav.dart';
import 'admin_ui.dart';

/// A failed read, in words. The console never shows a reader a thrown
/// object: a transport failure is a connection, a status is a status, and
/// only [AdminApi]'s own `Exception('msg')` mutations carry a sentence worth
/// printing as-is.
String loadError(Object e) {
  if (e is! EmeHttpException) return errText(e);
  final code = e.statusCode;
  return code == null
      ? L('No connection.', 'Sin conexión.')
      : L('Could not load ($code).', 'No se pudo cargar ($code).');
}

/// The honesty line every `tutordaily`-derived chart needs while a topic
/// filter is on. `tutordaily` has no topic dimension, so its bars stay
/// org-wide even when the pill above them says otherwise; the reader is told
/// rather than left to assume the chart followed the filter.
String get allTopicsNote => L('Daily activity includes every topic.',
    'La actividad diaria incluye todos los temas.');

/// Wraps the element an Iris citation may be pointing at, so it rings when
/// cited.
///
/// Fact ids are opaque (`f1`..`fN`), so a citation cannot name an element by
/// id. `ask.groovy` gives every fact a `focus` key from one small vocabulary
/// instead -- `stat`, `topic`, `weakest`, `grid`, `gap`, `inactive`, `iris`
/// -- and each screen wraps exactly those elements here. A few elements
/// answer to more than one key, which is why this takes a set.
///
/// Carrying [ConsoleRoute.stamp] through is the whole reason this exists
/// rather than a bare `Pulse`: the vocabulary is small enough that two
/// citations in a row usually share a key, and a [Pulse] that only watched
/// `active` would ring once and then sit still.
///
/// A top-level function rather than a mixin method: Dominio runs its own
/// fetch machine and needs the same wiring.
Widget pulse(ConsoleRoute route, Set<String> keys, {required Widget child}) =>
    Pulse(
      active: keys.contains(route.highlight),
      stamp: route.stamp,
      child: child,
    );

/// The fetch half of an analytics screen (spec analytics-v1 §6), shared by
/// Resumen, Actividad, Persona and Equipo.
///
/// All four do the same four things and got them wrong in the same four ways
/// when they were copies: listen to the filters, debounce the gesture, stamp
/// the reply so a slow answer to an abandoned filter never overwrites a fast
/// answer to the current one, and swap between skeleton, error and content.
/// Written once here, a screen only has to say what it fetches ([fetch]),
/// what it says when that throws ([errorText]) and what it draws ([fetched]).
///
/// Dominio keeps its own copy: its recompute poll re-enters the fetch on a
/// timer, which is a different machine.
mixin FilteredFetch<T, W extends StatefulWidget> on State<W> {
  /// The last successful reply, or null before the first one lands.
  T? data;
  Object? error;
  bool loading = true;

  Timer? _debounce;
  int _request = 0;

  /// The filters this screen re-reads on, and the router whose highlight
  /// decides what pulses. Both are `widget.*` on every screen; the mixin
  /// cannot reach through [W] to say so.
  AnalyticsFilters get filters;
  ConsoleNav get nav;

  /// One fetch of everything the screen draws.
  Future<T> fetch();

  /// What the panel says when [fetch] throws. Screens with a sentence of
  /// their own override it; the rest get [loadError].
  String errorText(Object e) => loadError(e);

  /// Whether the panel offers a Retry. False for a failure that will fail
  /// the same way every time — a permission, not a hiccup.
  bool canRetry(Object e) => true;

  @override
  void initState() {
    super.initState();
    filters.addListener(_schedule);
    _fetch();
  }

  @override
  void dispose() {
    filters.removeListener(_schedule);
    _debounce?.cancel();
    super.dispose();
  }

  /// Every filter gesture is debounced: three taps in a row cost one fetch.
  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 150), load);
  }

  /// Refetch from the top — the filter listener and the error panel's Retry.
  void load() {
    setState(() {
      loading = true;
      error = null;
    });
    _fetch();
  }

  Future<void> _fetch() async {
    final mine = ++_request;
    try {
      final next = await fetch();
      if (!mounted || mine != _request) return;
      setState(() {
        data = next;
        error = null;
        loading = false;
      });
    } catch (e) {
      if (!mounted || mine != _request) return;
      setState(() {
        error = e;
        loading = false;
      });
    }
  }

  /// Skeleton, error panel or [page] — the one state machine every analytics
  /// screen renders. The route is a per-citation thing, so only the page body
  /// rebuilds on it: not the fetch, not the filters.
  Widget fetched(Widget Function(BuildContext, T data, ConsoleRoute route) page) =>
      crossfade(_state(page));

  Widget _state(Widget Function(BuildContext, T, ConsoleRoute) page) {
    final e = error;
    if (e != null) {
      return ConsolePanelError(
          text: errorText(e), onRetry: canRetry(e) ? load : null);
    }
    final d = data;
    if (loading || d == null) return const Skeleton(lines: 6, height: 22);
    return ValueListenableBuilder<ConsoleRoute>(
      valueListenable: nav,
      builder: (context, route, _) => page(context, d, route),
    );
  }
}

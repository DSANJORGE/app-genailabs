import 'dart:async';

import 'package:flutter/material.dart';

import 'admin_nav.dart';
import 'admin_ui.dart';

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

  /// What the panel says when [fetch] throws.
  String errorText(Object e);

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

  /// True when an Iris citation is pointing at [what]. Citation ids name the
  /// element they quote ("stats.active7d", "teams.pisco", "gap.phishing"), so
  /// a substring match is what connects one to a panel.
  // TODO(task-16): swap the substring match for the citation id vocabulary
  // the Iris panel actually emits, once Task 16 fixes it.
  bool points(String? highlight, String what) =>
      highlight != null && highlight.toLowerCase().contains(what);

  /// Skeleton, error panel or [page] — the one state machine every analytics
  /// screen renders. The highlight is a per-citation thing, so only the page
  /// body rebuilds on it: not the fetch, not the filters.
  Widget fetched(Widget Function(BuildContext, T data, String? highlight) page) =>
      crossfade(_state(page));

  Widget _state(Widget Function(BuildContext, T, String?) page) {
    final e = error;
    if (e != null) {
      return ConsolePanelError(text: errorText(e), onRetry: load);
    }
    final d = data;
    if (loading || d == null) return const Skeleton(lines: 6, height: 22);
    return ValueListenableBuilder<ConsoleRoute>(
      valueListenable: nav,
      builder: (context, route, _) => page(context, d, route.highlight),
    );
  }
}

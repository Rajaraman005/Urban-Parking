import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'urban_bottom_nav.dart';

final tabNavigationHistoryProvider =
    NotifierProvider<TabNavigationHistoryController, List<int>>(
      TabNavigationHistoryController.new,
    );

class TabNavigationHistoryController extends Notifier<List<int>> {
  @override
  List<int> build() => const [0];

  void syncRoute(int currentIndex) {
    final normalized = _normalize(currentIndex);
    if (state.isNotEmpty && state.last == normalized) return;
    if (normalized == 0) {
      state = const [0];
      return;
    }
    state = [...state.where((index) => index != normalized), normalized];
  }

  void selectTab({required int currentIndex, required int nextIndex}) {
    final current = _normalize(currentIndex);
    final next = _normalize(nextIndex);
    if (current == next) return;
    if (next == 0) {
      state = const [0];
      return;
    }

    final history = [...state.where((index) => index != next)];
    if (history.isEmpty || history.last != current) {
      history.add(current);
    }
    history.add(next);
    state = history;
  }

  int? popToPreviousTab(int currentIndex) {
    final current = _normalize(currentIndex);
    final history = [...state.where((index) => index != current)];
    if (history.isEmpty) return null;

    final previous = history.last;
    state = previous == 0 ? const [0] : history;
    return previous;
  }

  bool hasPreviousTab(int currentIndex) {
    final current = _normalize(currentIndex);
    return state.any((index) => index != current);
  }

  int _normalize(int index) {
    return index.clamp(0, UrbanBottomNav.destinationCount - 1);
  }
}

class TabShell extends ConsumerStatefulWidget {
  const TabShell({
    required this.currentIndex,
    required this.child,
    super.key,
    this.resizeToAvoidBottomInset,
  });

  final int currentIndex;
  final Widget child;
  final bool? resizeToAvoidBottomInset;

  @override
  ConsumerState<TabShell> createState() => _TabShellState();
}

class _TabShellState extends ConsumerState<TabShell> {
  @override
  void initState() {
    super.initState();
    _syncRouteAfterBuild();
  }

  @override
  void didUpdateWidget(TabShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _syncRouteAfterBuild();
    }
  }

  void _syncRouteAfterBuild() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(tabNavigationHistoryProvider.notifier)
          .syncRoute(widget.currentIndex);
    });
  }

  @override
  Widget build(BuildContext context) {
    final routerCanPop = GoRouter.of(context).canPop();
    final canReturnToPreviousTab = ref.watch(
      tabNavigationHistoryProvider.select(
        (history) => history.any((index) => index != widget.currentIndex),
      ),
    );
    final shouldHandleSystemBack = !routerCanPop && canReturnToPreviousTab;

    return PopScope(
      canPop: !shouldHandleSystemBack,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || !shouldHandleSystemBack) return;
        final previous = ref
            .read(tabNavigationHistoryProvider.notifier)
            .popToPreviousTab(widget.currentIndex);
        if (previous == null) return;
        context.go(UrbanBottomNav.routeForIndex(previous));
      },
      child: Scaffold(
        resizeToAvoidBottomInset: widget.resizeToAvoidBottomInset,
        body: widget.child,
        bottomNavigationBar: UrbanBottomNav(
          currentIndex: widget.currentIndex,
          onDestinationSelected: (index) {
            ref
                .read(tabNavigationHistoryProvider.notifier)
                .selectTab(currentIndex: widget.currentIndex, nextIndex: index);
            context.go(UrbanBottomNav.routeForIndex(index));
          },
        ),
      ),
    );
  }
}

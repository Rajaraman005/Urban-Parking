import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urban_parking/shared/widgets/tab_shell.dart';

void main() {
  test('tab history returns from profile to the previous home tab', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final controller = container.read(tabNavigationHistoryProvider.notifier);

    controller.syncRoute(0);
    controller.selectTab(currentIndex: 0, nextIndex: 4);

    expect(container.read(tabNavigationHistoryProvider), [0, 4]);
    expect(controller.hasPreviousTab(4), isTrue);
    expect(controller.popToPreviousTab(4), 0);
    expect(container.read(tabNavigationHistoryProvider), [0]);
  });

  test('selecting home clears tab history so back can close from home', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final controller = container.read(tabNavigationHistoryProvider.notifier);

    controller.selectTab(currentIndex: 0, nextIndex: 2);
    controller.selectTab(currentIndex: 2, nextIndex: 4);
    controller.selectTab(currentIndex: 4, nextIndex: 0);

    expect(container.read(tabNavigationHistoryProvider), [0]);
    expect(controller.hasPreviousTab(0), isFalse);
  });
}

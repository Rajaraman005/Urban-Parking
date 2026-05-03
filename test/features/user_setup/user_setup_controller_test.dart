import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urban_parking/features/user_setup/presentation/user_setup_controller.dart';

void main() {
  test('host setup advances through feature steps', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(userSetupControllerProvider.future);
    final controller = container.read(userSetupControllerProvider.notifier);

    var state = await controller.saveIntent('host');
    expect(state.step, 'profile');

    state = await controller.saveProfile(
      fullName: 'Test Host',
      phone: '9876543210',
      gender: 'prefer_not_to_say',
      dob: '01/01/1990',
    );
    expect(state.step, 'host_basics');

    state = await controller.advanceHostStep('host_basics');
    expect(state.step, 'host_pricing');
  });
}

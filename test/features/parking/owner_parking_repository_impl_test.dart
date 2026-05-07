import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:urban_parking/features/parking/data/owner_parking_repository_impl.dart';

void main() {
  test('detects deployed pricing RPC without skip-weekends argument', () {
    const error = sb.PostgrestException(
      message:
          'Could not find the function public.update_owned_parking_space_pricing(p_available_from_date, p_available_to_date, p_daily_end_minute, p_daily_start_minute, p_expected_version, p_hourly_price, p_skip_weekends, p_slots_count, p_space_id) in the schema cache',
      code: 'PGRST202',
    );

    expect(isPricingSkipWeekendsRpcUnavailable(error), isTrue);
  });

  test('detects pricing RPC overload/schema-cache drift', () {
    const error = sb.PostgrestException(
      message:
          'Could not choose the best candidate function between overloaded public.update_owned_parking_space_pricing functions',
      code: 'PGRST203',
    );

    expect(isPricingSkipWeekendsRpcUnavailable(error), isTrue);
  });

  test('does not treat pricing validation failures as RPC drift', () {
    const error = sb.PostgrestException(
      message: 'Listing pricing is invalid',
      code: '23514',
    );

    expect(isPricingSkipWeekendsRpcUnavailable(error), isFalse);
  });
}

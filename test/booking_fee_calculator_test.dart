import 'package:flutter_test/flutter_test.dart';
import 'package:irent/core/utils/booking_fee_calculator.dart';

void main() {
  group('BookingFeeCalculator', () {
    test('calculates the online reservation fee from rent and gateway fee', () {
      final fee = BookingFeeCalculator.calculateReservationFee(
        rentAmount: 100000,
        gatewayFee: 1000,
      );

      expect(fee, 6000);
    });

    test('uses the 5% platform fee when no gateway fee is provided', () {
      final fee = BookingFeeCalculator.calculateReservationFee(
        rentAmount: 200000,
      );

      expect(fee, 10000);
    });
  });
}

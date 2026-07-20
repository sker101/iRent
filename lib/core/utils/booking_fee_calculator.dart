class BookingFeeCalculator {
  BookingFeeCalculator._();

  static double calculateReservationFee({
    required double rentAmount,
    double gatewayFee = 0,
  }) {
    return ((rentAmount * 0.05) + gatewayFee);
  }
}

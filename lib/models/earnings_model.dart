class EarningsResponse {
  final String totalPayment;
  final String paidAmount;
  final String pendingPayment;
  final String totalTrips;
  final List<PaymentTransaction> payments;

  EarningsResponse({
    required this.totalPayment,
    required this.paidAmount,
    required this.pendingPayment,
    required this.totalTrips,
    required this.payments,
  });

  factory EarningsResponse.fromJson(Map<String, dynamic> json) {
    return EarningsResponse(
      totalPayment: json['totalPayment'] ?? '0.00',
      paidAmount: json['paidAmount'] ?? '0.00',
      pendingPayment: json['pendingPayment'] ?? '0.00',
      totalTrips: json['totalTrips'] ?? '0',
      payments: json['payment'] != null
          ? List<PaymentTransaction>.from(
        (json['payment'] as List).map(
              (x) => PaymentTransaction.fromJson(x),
        ),
      )
          : [],
    );
  }

  Map<String, dynamic> toJson() => {
    'totalPayment': totalPayment,
    'paidAmount': paidAmount,
    'pendingPayment': pendingPayment,
    'totalTrips': totalTrips,
    'payment': payments.map((x) => x.toJson()).toList(),
  };
}

class PaymentTransaction {
  final String paymentId;
  final String rideId;
  final String paymentMethod;
  final double paidAmount;
  final double tipAmount;
  final double adminShare;
  final double driverShare;
  final String paymentStatus;
  final String createdAt;

  PaymentTransaction({
    required this.paymentId,
    required this.rideId,
    required this.paymentMethod,
    required this.paidAmount,
    required this.tipAmount,
    required this.adminShare,
    required this.driverShare,
    required this.paymentStatus,
    required this.createdAt,
  });

  factory PaymentTransaction.fromJson(Map<String, dynamic> json) {
    return PaymentTransaction(
      paymentId: json['paymentId'] ?? '',
      rideId: json['rideId'] ?? '',
      paymentMethod: json['paymentMethod'] ?? 'N/A',
      paidAmount: (json['paidAmount'] ?? 0).toDouble(),
      tipAmount: (json['tipAmount'] ?? 0).toDouble(),
      adminShare: (json['adminShare'] ?? 0).toDouble(),
      driverShare: (json['driverShare'] ?? 0).toDouble(),
      paymentStatus: json['paymentStatus'] ?? 'Pending',
      createdAt: json['createdAt'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'paymentId': paymentId,
    'rideId': rideId,
    'paymentMethod': paymentMethod,
    'paidAmount': paidAmount,
    'tipAmount': tipAmount,
    'adminShare': adminShare,
    'driverShare': driverShare,
    'paymentStatus': paymentStatus,
    'createdAt': createdAt,
  };
}
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pick_u_driver/models/earnings_model.dart';
import 'package:pick_u_driver/utils/theme/mcolors.dart';

import '../controllers/earnings_controller.dart';

class EarningsPage extends GetView<EarningsController> {
  const EarningsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Earnings', style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: MColor.primaryNavy,
        elevation: 0,
        centerTitle: true,
      ),
      body: Obx(() {
        if (controller.isLoading.value && controller.earningsData.value == null) {
          return Center(
            child: CircularProgressIndicator(color: MColor.primaryNavy),
          );
        }

        if (controller.hasError.value) return _buildErrorWidget();
        if (controller.earningsData.value == null ||
            controller.earningsData.value!.payments.isEmpty) {
          return _buildEmptyWidget();
        }

        return RefreshIndicator(
          onRefresh: controller.refreshEarnings,
          color: MColor.primaryNavy,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              children: [
                _buildSummaryCards(),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: _buildTransactionsList(),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildSummaryCards() {
    final data = controller.earningsData.value;
    if (data == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: MColor.primaryNavy.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  title: 'Total Earned',
                  highlight: true,
                  amount: controller.formatCurrency(data.totalPayment),
                  icon: Icons.account_balance_wallet_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  title: 'Trips',
                  amount: data.totalTrips.toString(),
                  icon: Icons.directions_car_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String amount,
    IconData? icon,
    bool highlight = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: highlight
            ? MColor.primaryNavy
            : MColor.primaryNavy.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: highlight
              ? Colors.transparent
              : MColor.primaryNavy.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: MColor.primaryNavy.withValues(alpha: highlight ? 0.2 : 0.05),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null)
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: highlight
                        ? Colors.white.withValues(alpha: 0.1)
                        : MColor.primaryNavy.withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 16,
                    color: highlight ? Colors.white : MColor.primaryNavy,
                  ),
                ),
              if (icon != null) const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: highlight
                      ? Colors.white.withValues(alpha: 0.9)
                      : MColor.primaryNavy.withValues(alpha: 0.8),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            amount,
            style: TextStyle(
              color: highlight ? Colors.white : MColor.primaryNavy,
              fontSize: highlight ? 22 : 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsList() {
    final data = controller.earningsData.value!;
    final sortedPayments = List<PaymentTransaction>.from(data.payments)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'Transaction History',
            style: TextStyle(
              color: MColor.primaryNavy,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 16),
        ListView.builder(
          itemCount: sortedPayments.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemBuilder: (context, index) =>
              _buildTransactionCard(sortedPayments[index]),
        ),
      ],
    );
  }

  Widget _buildTransactionCard(PaymentTransaction payment) {
    return GestureDetector(
      onTap: () => _showTransactionDetails(payment),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: MColor.primaryNavy.withValues(alpha: 0.1),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: MColor.primaryNavy.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: MColor.primaryNavy.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.account_balance_wallet_rounded,
                color: MColor.primaryNavy,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    controller.formatCurrency(payment.driverShare + payment.tipAmount),
                    style: TextStyle(
                      color: MColor.primaryNavy,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${controller.formatDate(payment.createdAt)} • ${controller.formatTime(payment.createdAt)}',
                    style: TextStyle(
                      color: MColor.primaryNavy.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                  ),
                  if (payment.tipAmount > 0) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Tip: ${controller.formatCurrency(payment.tipAmount)}',
                        style: const TextStyle(
                          color: Colors.green,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: MColor.primaryNavy,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                payment.paymentStatus,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTransactionDetails(PaymentTransaction payment) {
    showModalBottomSheet(
      context: Get.context!,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 20),
              decoration: BoxDecoration(
                color: MColor.primaryNavy.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Transaction Details',
                    style: TextStyle(
                      color: MColor.primaryNavy,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Divider(
              height: 32,
              color: MColor.primaryNavy.withValues(alpha: 0.1),
              thickness: 1,
            ),
            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Column(
                  children: [
                    // Amount Display
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: MColor.primaryNavy,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Total Amount',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            controller.formatCurrency(payment.driverShare + payment.tipAmount),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Payment Details
                    _buildDetailItem(
                      'Payment ID',
                      payment.paymentId,
                      Icons.receipt_long_rounded,
                    ),
                    _buildDetailItem(
                      'Ride ID',
                      payment.rideId,
                      Icons.route_rounded,
                    ),
                    _buildDetailItem(
                      'Payment Status',
                      payment.paymentStatus,
                      Icons.check_circle_rounded,
                    ),
                    _buildDetailItem(
                      'Payment Method',
                      payment.paymentMethod,
                      Icons.payment_rounded,
                    ),
                    _buildDetailItem(
                      'Date & Time',
                      '${controller.formatDate(payment.createdAt)} at ${controller.formatTime(payment.createdAt)}',
                      Icons.calendar_today_rounded,
                    ),

                    const SizedBox(height: 12),
                    Divider(color: MColor.primaryNavy.withValues(alpha: 0.1)),
                    const SizedBox(height: 12),

                    // Amount Breakdown
                    Text(
                      'Amount Breakdown',
                      style: TextStyle(
                        color: MColor.primaryNavy,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    _buildAmountRow('Driver Share', controller.formatCurrency(payment.driverShare)),
                    if (payment.tipAmount > 0)
                      _buildAmountRow('Tip Amount', controller.formatCurrency(payment.tipAmount)),

                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: MColor.primaryNavy.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total Amount',
                            style: TextStyle(
                              color: MColor.primaryNavy,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            controller.formatCurrency(payment.driverShare + payment.tipAmount),
                            style: TextStyle(
                              color: MColor.primaryNavy,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(String label, String value, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MColor.primaryNavy.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: MColor.primaryNavy.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: MColor.primaryNavy.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: MColor.primaryNavy,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: MColor.primaryNavy.withValues(alpha: 0.6),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: MColor.primaryNavy,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountRow(String label, String amount) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: MColor.primaryNavy.withValues(alpha: 0.7),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              color: MColor.primaryNavy,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyWidget() => Center(
    child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: MColor.primaryNavy.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.receipt_long_rounded,
              color: MColor.primaryNavy.withValues(alpha: 0.4),
              size: 64,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No Transactions Yet',
            style: TextStyle(
              color: MColor.primaryNavy,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your earnings will appear here\nonce available.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: MColor.primaryNavy.withValues(alpha: 0.6),
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildErrorWidget() => Center(
    child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: MColor.primaryNavy.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.error_outline_rounded,
              color: MColor.primaryNavy.withValues(alpha: 0.4),
              size: 64,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Error Loading Earnings',
            style: TextStyle(
              color: MColor.primaryNavy,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            controller.errorMessage.value,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: MColor.primaryNavy.withValues(alpha: 0.6),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: controller.refreshEarnings,
            style: ElevatedButton.styleFrom(
              backgroundColor: MColor.primaryNavy,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Retry',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

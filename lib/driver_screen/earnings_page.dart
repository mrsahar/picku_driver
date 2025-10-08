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
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Earnings'),
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
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildSummaryCards(),
                const SizedBox(height: 24),
                _buildTransactionsList(),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- Top Row (Paid & Pending) ---
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                title: 'Paid',
                amount: controller.formatCurrency(data.paidAmount),
                highlight: true,
                icon: Icons.check_circle_rounded,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                title: 'Pending',
                amount: controller.formatCurrency(data.pendingPayment),
                highlight: true,
                icon: Icons.pending_actions_rounded,
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // --- Bottom Row (Total Earnings & Trips) ---
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                title: 'Total Earned',
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
            : MColor.primaryNavy.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: highlight
              ? Colors.transparent
              : MColor.primaryNavy.withOpacity(0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: MColor.primaryNavy.withOpacity(highlight ? 0.2 : 0.05),
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
                        ? Colors.white.withOpacity(0.1)
                        : MColor.primaryNavy.withOpacity(0.05),
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
                      ? Colors.white.withOpacity(0.9)
                      : MColor.primaryNavy.withOpacity(0.8),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Earning History',
          style: TextStyle(
            color: MColor.primaryNavy,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ListView.builder(
          itemCount: data.payments.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemBuilder: (context, index) =>
              _buildTransactionCard(data.payments[index]),
        ),
      ],
    );
  }

  Widget _buildTransactionCard(PaymentTransaction payment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: MColor.primaryNavy.withOpacity(0.2),
          width: 1.2,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: MColor.primaryNavy.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Status + Method
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.account_balance_wallet_outlined, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    controller.formatCurrency(payment.driverShare),
                    style: TextStyle(
                      color: MColor.primaryNavy,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: MColor.primaryNavy.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  payment.paymentStatus,
                  style: TextStyle(
                    color: MColor.primaryNavy,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Date + Time Row
          Row(
            children: [
              Icon(Icons.calendar_today_outlined,
                  size: 14, color: MColor.primaryNavy.withOpacity(0.7)),
              const SizedBox(width: 6),
              Text(
                controller.formatDate(payment.createdAt),
                style: TextStyle(
                  color: MColor.primaryNavy.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 16),
              Icon(Icons.access_time,
                  size: 14, color: MColor.primaryNavy.withOpacity(0.7)),
              const SizedBox(width: 6),
              Text(
                controller.formatTime(payment.createdAt),
                style: TextStyle(
                  color: MColor.primaryNavy.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const Divider(height: 24, color: Color(0xFFEFEFEF)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildDetailItem('Paid', controller.formatCurrency(payment.paidAmount)),
              _buildDetailItem('Paid Via',payment.paymentMethod ),
              _buildDetailItem('Tip', controller.formatCurrency(payment.tipAmount)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: MColor.primaryNavy.withOpacity(0.6),
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: MColor.primaryNavy,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyWidget() => Center(
    child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_rounded,
              color: MColor.primaryNavy.withOpacity(0.2), size: 80),
          const SizedBox(height: 16),
          Text(
            'No Transactions Yet',
            style: TextStyle(
              color: MColor.primaryNavy,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your earnings will appear here once available.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: MColor.primaryNavy.withOpacity(0.6),
              fontSize: 14,
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
          Icon(Icons.error_outline_rounded,
              color: MColor.primaryNavy.withOpacity(0.4), size: 80),
          const SizedBox(height: 16),
          Text(
            'Error Loading Earnings',
            style: TextStyle(
              color: MColor.primaryNavy,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            controller.errorMessage.value,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: MColor.primaryNavy.withOpacity(0.6),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: controller.refreshEarnings,
            style: ElevatedButton.styleFrom(
              backgroundColor: MColor.primaryNavy,
              padding:
              const EdgeInsets.symmetric(horizontal: 36, vertical: 12),
            ),
            child: const Text(
              'Retry',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    ),
  );
}


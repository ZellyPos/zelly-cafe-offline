import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/price_formatter.dart';
import '../../../providers/report_provider.dart';

class OrderDetailsDialog extends StatelessWidget {
  final String orderId;

  const OrderDetailsDialog({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
          maxWidth: MediaQuery.of(context).size.width <= 1100 ? 500 : 600,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bool isCompact = constraints.maxWidth < 550;

            return FutureBuilder<Map<String, dynamic>?>(
              future: context.read<ReportProvider>().getOrderDetails(orderId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 200,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final order = snapshot.data;
                if (order == null) {
                  return const SizedBox(
                    height: 200,
                    child: Center(child: Text("Buyurtma topilmadi")),
                  );
                }

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(context, order),
                    const Divider(height: 32),
                    const Text(
                      "Buyurtma tarkibi:",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(child: _buildItemsList(context, isCompact)),
                    const Divider(height: 32),
                    _buildFooter(order, isCompact),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Map<String, dynamic> order) {
    final String id = order['id'].toString().substring(0, 8).toUpperCase();
    final DateTime date = DateTime.parse(order['created_at']);
    final String type = order['order_type'] == 0 ? "Stol" : "Saboy";
    final String location = order['location_name'] ?? "-";
    final String table = order['table_name'] ?? "-";

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  "Buyurtma #$id",
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    type,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.blue.shade800,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              "${DateFormat('dd.MM.yyyy HH:mm').format(date)} • $location / $table",
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
        ),
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close),
        ),
      ],
    );
  }

  Widget _buildItemsList(BuildContext context, bool isCompact) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: context.read<ReportProvider>().getOrderItems(orderId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final items = snapshot.data!;
        return ListView.separated(
          itemCount: items.length,
          separatorBuilder: (_, __) => const Divider(),
          itemBuilder: (context, index) {
            final item = items[index];
            final double price = (item['price'] as num).toDouble();
            final int qty = (item['qty'] as num).toInt();
            final double total = price * qty;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['product_name'] ?? "",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: isCompact ? 13 : 14,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          "${PriceFormatter.format(price)} x $qty",
                          style: TextStyle(
                            fontSize: isCompact ? 11 : 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 1,
                    child: Text(
                      "${PriceFormatter.format(total)} so'm",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: isCompact ? 13 : 14,
                      ),
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFooter(Map<String, dynamic> order, bool isCompact) {
    final double grandTotal = (order['total'] as num).toDouble();
    final double foodTotal = (order['food_total'] as num?)?.toDouble() ?? 0.0;
    final double roomTotal =
        (order['room_total'] as num?)?.toDouble() ??
        (order['room_charge'] as num?)?.toDouble() ??
        0.0;
    final double serviceTotal =
        (order['service_total'] as num?)?.toDouble() ?? 0.0;
    final String paymentType = order['payment_type'] ?? "Kassa";

    return Column(
      children: [
        _buildSummaryRow(
          "Taomlar:",
          PriceFormatter.format(
            foodTotal > 0 ? foodTotal : grandTotal - roomTotal - serviceTotal,
          ),
        ),
        if (roomTotal > 0) ...[
          const SizedBox(height: 4),
          _buildSummaryRow("Xona/Stol:", PriceFormatter.format(roomTotal)),
        ],
        if (serviceTotal > 0) ...[
          const SizedBox(height: 4),
          _buildSummaryRow(
            "Ofitsiant xizmati:",
            PriceFormatter.format(serviceTotal),
          ),
        ],
        const Divider(height: 24),
        _buildSummaryRow(
          "Jami:",
          PriceFormatter.format(grandTotal),
          isTotal: true,
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("To'lov turi:", style: TextStyle(color: Colors.grey)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                paymentType,
                style: TextStyle(
                  color: Colors.blue.shade700,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 18 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          "$value so'm",
          style: TextStyle(
            fontSize: isTotal ? 22 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
            color: isTotal ? Colors.blue.shade700 : Colors.black,
          ),
        ),
      ],
    );
  }
}

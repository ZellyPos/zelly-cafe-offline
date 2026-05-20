import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../models/courier.dart';
import '../../providers/delivery_provider.dart';

class CouriersMgmtScreen extends StatefulWidget {
  const CouriersMgmtScreen({super.key});

  @override
  State<CouriersMgmtScreen> createState() => _CouriersMgmtScreenState();
}

class _CouriersMgmtScreenState extends State<CouriersMgmtScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<DeliveryProvider>().loadCouriers(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Kuryerlar',
          style: TextStyle(
              color: Color(0xFF1E293B),
              fontWeight: FontWeight.bold,
              fontSize: 20),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              onPressed: () => _showCourierDialog(context),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text("Qo'shish"),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ),
        ],
      ),
      body: Consumer<DeliveryProvider>(
        builder: (_, dp, _) {
          if (dp.couriers.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.delivery_dining_outlined,
                      size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text(
                    "Kuryer qo'shilmagan",
                    style: TextStyle(
                        color: Colors.grey.shade400, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => _showCourierDialog(context),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text("Birinchi kuryerni qo'shish"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: dp.couriers.length,
            itemBuilder: (_, i) => _CourierCard(
              courier: dp.couriers[i],
              onEdit: () => _showCourierDialog(context, courier: dp.couriers[i]),
              onToggle: () {
                final c = dp.couriers[i];
                dp.updateCourier(c.copyWith(isActive: !c.isActive));
              },
              onDelete: () => _confirmDelete(context, dp.couriers[i], dp),
            ),
          );
        },
      ),
    );
  }

  void _showCourierDialog(BuildContext context, {Courier? courier}) {
    final isEdit = courier != null;
    final nameCtrl = TextEditingController(text: courier?.name ?? '');
    final phoneCtrl = TextEditingController(text: courier?.phone ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(isEdit ? 'Kuryerni tahrirlash' : "Yangi kuryer"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Ism *',
                prefixIcon: const Icon(Icons.person_rounded),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Telefon',
                prefixIcon: const Icon(Icons.phone_rounded),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child:
                  const Text('Bekor', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx);
              final dp = context.read<DeliveryProvider>();
              if (isEdit) {
                await dp.updateCourier(
                  courier.copyWith(
                      name: name,
                      phone: phoneCtrl.text.trim().isEmpty
                          ? null
                          : phoneCtrl.text.trim()),
                );
              } else {
                await dp.addCourier(
                  name,
                  phoneCtrl.text.trim().isEmpty
                      ? null
                      : phoneCtrl.text.trim(),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(isEdit ? 'Saqlash' : "Qo'shish"),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(
      BuildContext context, Courier courier, DeliveryProvider dp) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("O'chirish"),
        content: Text("${courier.name} ni o'chirishni tasdiqlaysizmi?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Bekor")),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await dp.deleteCourier(courier.id!);
            },
            child: const Text("O'chirish",
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _CourierCard extends StatelessWidget {
  final Courier courier;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _CourierCard({
    required this.courier,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: courier.isActive
              ? AppTheme.primaryColor.withValues(alpha: 0.12)
              : Colors.grey.shade100,
          child: Icon(
            Icons.delivery_dining_rounded,
            color: courier.isActive
                ? AppTheme.primaryColor
                : Colors.grey.shade400,
          ),
        ),
        title: Text(
          courier.name,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: courier.isActive
                ? const Color(0xFF1E293B)
                : Colors.grey.shade400,
          ),
        ),
        subtitle: courier.phone?.isNotEmpty == true
            ? Text(courier.phone!,
                style: const TextStyle(color: Color(0xFF64748B)))
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: courier.isActive,
              onChanged: (_) => onToggle(),
              activeThumbColor: AppTheme.primaryColor,
            ),
            IconButton(
              icon: const Icon(Icons.edit_rounded,
                  color: Color(0xFF64748B), size: 20),
              onPressed: onEdit,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded,
                  color: Colors.red, size: 20),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

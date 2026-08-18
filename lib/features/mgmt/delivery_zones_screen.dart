import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../core/utils/price_formatter.dart';
import '../../models/delivery_zone.dart';
import '../../providers/delivery_provider.dart';

class DeliveryZonesScreen extends StatefulWidget {
  const DeliveryZonesScreen({super.key});

  @override
  State<DeliveryZonesScreen> createState() => _DeliveryZonesScreenState();
}

class _DeliveryZonesScreenState extends State<DeliveryZonesScreen> {
  static const _palette = [
    '#6366F1', '#3B82F6', '#22C55E', '#F59E0B',
    '#EF4444', '#8B5CF6', '#EC4899', '#14B8A6',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<DeliveryProvider>().loadZones(),
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
          'Yetkazish zonalari',
          style: TextStyle(
              color: Color(0xFF1E293B),
              fontWeight: FontWeight.bold,
              fontSize: 20),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              onPressed: () => _showZoneDialog(context),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text("Zona qo'shish"),
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
          if (dp.zones.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.map_outlined,
                      size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text('Zona qo\'shilmagan',
                      style: TextStyle(
                          color: Colors.grey.shade400, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text(
                    'Zonalar orqali yetkazish narxini\nautomatik belgilash mumkin',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.grey.shade400, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _showZoneDialog(context),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text("Birinchi zonani qo'shish"),
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
            itemCount: dp.zones.length,
            itemBuilder: (_, i) {
              final zone = dp.zones[i];
              return _ZoneCard(
                zone: zone,
                onEdit: () => _showZoneDialog(context, zone: zone),
                onToggle: () =>
                    dp.updateZone(zone.copyWith(isActive: !zone.isActive)),
                onDelete: () => _confirmDelete(context, zone, dp),
              );
            },
          );
        },
      ),
    );
  }

  void _showZoneDialog(BuildContext context, {DeliveryZone? zone}) {
    final isEdit = zone != null;
    final nameCtrl = TextEditingController(text: zone?.name ?? '');
    final feeCtrl = TextEditingController(
        text: (zone == null || zone.fee == 0) ? '' : zone.fee.toStringAsFixed(0));
    String selectedColor = zone?.color ?? _palette.first;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(isEdit ? 'Zonani tahrirlash' : 'Yangi zona'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Zona nomi *',
                  hintText: 'Masalan: Shahar ichida',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: feeCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: "Yetkazish narxi (so'm)",
                  hintText: '0 = bepul',
                  prefixIcon:
                      const Icon(Icons.delivery_dining_rounded),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Rang:',
                  style: TextStyle(
                      fontSize: 13, color: Color(0xFF64748B))),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _palette.map((hex) {
                  final color = _hexToColor(hex);
                  final isSel = selectedColor == hex;
                  return GestureDetector(
                    onTap: () => setS(() => selectedColor = hex),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSel ? Colors.black54 : Colors.transparent,
                          width: isSel ? 2.5 : 0,
                        ),
                        boxShadow: isSel
                            ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 6)]
                            : [],
                      ),
                      child: isSel
                          ? const Icon(Icons.check, color: Colors.white, size: 16)
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Bekor',
                  style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                final fee = double.tryParse(feeCtrl.text) ?? 0;
                Navigator.pop(ctx);
                final dp = context.read<DeliveryProvider>();
                if (isEdit) {
                  await dp.updateZone(zone.copyWith(
                      name: name, fee: fee, color: selectedColor));
                } else {
                  await dp.addZone(name, fee, selectedColor);
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
      ),
    );
  }

  void _confirmDelete(
      BuildContext context, DeliveryZone zone, DeliveryProvider dp) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("O'chirish"),
        content: Text("«${zone.name}» zonasini o'chirishni tasdiqlaysizmi?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Bekor')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              if (zone.id != null) await dp.deleteZone(zone.id!);
            },
            child: const Text("O'chirish",
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _ZoneCard extends StatelessWidget {
  final DeliveryZone zone;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  const _ZoneCard(
      {required this.zone,
      required this.onEdit,
      required this.onToggle,
      required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final color = _hexToColor(zone.color);
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: zone.isActive ? 0.15 : 0.06),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.location_on_rounded,
              color: zone.isActive ? color : Colors.grey.shade400),
        ),
        title: Text(
          zone.name,
          style: TextStyle(
              fontWeight: FontWeight.w600,
              color: zone.isActive
                  ? const Color(0xFF1E293B)
                  : Colors.grey.shade400),
        ),
        subtitle: Text(
          zone.fee > 0
              ? 'Yetkazish: ${PriceFormatter.format(zone.fee)}'
              : 'Bepul yetkazish',
          style: TextStyle(
              color: zone.isActive
                  ? const Color(0xFF64748B)
                  : Colors.grey.shade300),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
                value: zone.isActive,
                onChanged: (_) => onToggle(),
                activeThumbColor: color),
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

Color _hexToColor(String hex) {
  final h = hex.replaceFirst('#', '');
  return Color(int.parse('FF$h', radix: 16));
}

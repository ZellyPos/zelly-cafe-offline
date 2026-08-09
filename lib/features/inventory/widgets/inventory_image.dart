import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/connectivity_provider.dart';

/// Ombor ekranlarida rasm ko'rsatish (mahsulot yoki xomashyo).
///
/// [ConnectivityProvider.getImageUrl] orqali lokal fayl yoki server URL'ini
/// aniqlaydi; rasm bo'lmasa yoki yuklanmasa ikonka ko'rsatadi.
class InventoryImage extends StatelessWidget {
  final String? imagePath;
  final IconData placeholderIcon;
  final double? size;
  final BorderRadius? borderRadius;

  const InventoryImage({
    super.key,
    required this.imagePath,
    this.placeholderIcon = Icons.inventory_2_outlined,
    this.size,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = borderRadius ?? BorderRadius.circular(12);

    Widget placeholder() => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.04),
        borderRadius: radius,
      ),
      child: Icon(
        placeholderIcon,
        color: theme.hintColor.withValues(alpha: 0.4),
        size: size != null ? size! * 0.45 : 24,
      ),
    );

    final url = context.read<ConnectivityProvider>().getImageUrl(imagePath);
    if (url == null) return placeholder();

    return ClipRRect(
      borderRadius: radius,
      child: url.startsWith('http')
          ? Image.network(
              url,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => placeholder(),
            )
          : Image.file(
              File(url),
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => placeholder(),
            ),
    );
  }
}

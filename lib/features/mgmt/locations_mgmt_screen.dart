import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/table_provider.dart';
import '../../models/location.dart';
import '../../core/app_strings.dart';
import '../../providers/connectivity_provider.dart';

class LocationsMgmtScreen extends StatefulWidget {
  const LocationsMgmtScreen({super.key});

  @override
  State<LocationsMgmtScreen> createState() => _LocationsMgmtScreenState();
}

class _LocationsMgmtScreenState extends State<LocationsMgmtScreen> {
  String searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final locationProvider = context.watch<LocationProvider>();
    final tableProvider = context.watch<TableProvider>();

    final filteredLocations = locationProvider.locations
        .where((l) => l.name.toLowerCase().contains(searchQuery.toLowerCase()))
        .toList();

    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          AppStrings.locationMgmt,
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: ElevatedButton.icon(
                onPressed: () => _showLocationDialog(context),
                icon: const Icon(Icons.add),
                label: Text(AppStrings.addLocation),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(24),
            color: theme.colorScheme.surface,
            child: TextField(
              onChanged: (val) => setState(() => searchQuery = val),
              style: TextStyle(color: theme.colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: "Joy nomi bo'yicha qidirish...",
                hintStyle: TextStyle(
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                ),
                filled: true,
                fillColor: theme.brightness == Brightness.light
                    ? const Color(0xFFF1F5F9)
                    : theme.colorScheme.onSurface.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
          // Grid
          Expanded(
            child: locationProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredLocations.isEmpty
                ? _buildEmptyState()
                : GridView.builder(
                    padding: const EdgeInsets.all(24),
                    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent:
                          MediaQuery.of(context).size.width <= 1100 ? 200 : 240,
                      childAspectRatio: 1.6,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: filteredLocations.length,
                    itemBuilder: (context, index) {
                      final location = filteredLocations[index];
                      final tableCount = tableProvider.tables
                          .where((t) => t.locationId == location.id)
                          .length;
                      return _buildLocationCard(context, location, tableCount);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.location_off_outlined,
            size: 64,
            color: theme.colorScheme.onSurface.withOpacity(0.1),
          ),
          const SizedBox(height: 16),
          Text(
            searchQuery.isEmpty ? "Joylar mavjud emas" : "Hech narsa topilmadi",
            style: TextStyle(
              color: theme.colorScheme.onSurface.withOpacity(0.5),
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard(
    BuildContext context,
    Location location,
    int tableCount,
  ) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: theme.brightness == Brightness.light
              ? const Color(0xFFE2E8F0)
              : theme.colorScheme.onSurface.withOpacity(0.1),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _showLocationDialog(context, location: location),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        location.name,
                        style: TextStyle(
                          fontSize: MediaQuery.of(context).size.width <= 1100
                              ? 15
                              : 16,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.edit_outlined,
                            color: Colors.blue,
                            size: 20,
                          ),
                          onPressed: () =>
                              _showLocationDialog(context, location: location),
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                            size: 20,
                          ),
                          onPressed: () => _confirmDelete(context, location),
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ],
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: theme.brightness == Brightness.light
                        ? Colors.blue.shade50
                        : theme.colorScheme.onSurface.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.table_bar_outlined,
                        size: 14,
                        color: theme.brightness == Brightness.light
                            ? Colors.blue.shade700
                            : theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "$tableCount ta stol",
                        style: TextStyle(
                          color: theme.brightness == Brightness.light
                              ? Colors.blue.shade700
                              : theme.colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, Location location) async {
    final locationProvider = context.read<LocationProvider>();
    final success = await locationProvider.deleteLocation(
      location.id!,
      connectivity: context.read<ConnectivityProvider>(),
    );

    if (!context.mounted) return;

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.warningDeleteLocation),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Joy muvaffaqiyatli o'chirildi"),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showLocationDialog(BuildContext context, {Location? location}) {
    final nameController = TextEditingController(text: location?.name ?? '');

    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            location == null ? AppStrings.addLocation : AppStrings.editLocation,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                style: TextStyle(color: theme.colorScheme.onSurface),
                decoration: InputDecoration(
                  labelText: AppStrings.locationName,
                  labelStyle: TextStyle(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                AppStrings.cancel,
                style: const TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.isEmpty) return;
                final newLocation = Location(
                  id: location?.id,
                  name: nameController.text,
                );
                if (location == null) {
                  context.read<LocationProvider>().addLocation(
                    newLocation,
                    connectivity: context.read<ConnectivityProvider>(),
                  );
                } else {
                  context.read<LocationProvider>().updateLocation(
                    newLocation,
                    connectivity: context.read<ConnectivityProvider>(),
                  );
                }
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(AppStrings.save),
            ),
          ],
        );
      },
    );
  }
}

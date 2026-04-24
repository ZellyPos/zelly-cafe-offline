import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../providers/app_settings_provider.dart';
import '../../core/tunnel_service.dart';

class ConnectionSettingsScreen extends StatefulWidget {
  const ConnectionSettingsScreen({super.key});

  @override
  State<ConnectionSettingsScreen> createState() =>
      _ConnectionSettingsScreenState();
}

class _ConnectionSettingsScreenState extends State<ConnectionSettingsScreen> {
  final _urlController = TextEditingController();
  final _portController = TextEditingController();
  final TunnelService _tunnel = TunnelService();
  final ScrollController _logScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    final connectivity = context.read<ConnectivityProvider>();
    _urlController.text = connectivity.clientBaseUrl ?? 'http://';
    _portController.text = connectivity.port.toString();
    _tunnel.addListener(_onTunnelChanged);
  }

  @override
  void dispose() {
    _tunnel.removeListener(_onTunnelChanged);
    _logScrollController.dispose();
    super.dispose();
  }

  void _onTunnelChanged() {
    // Tunnel URL olganda avtomatik saqlash
    if (_tunnel.tunnelUrl != null) {
      final settings = context.read<AppSettingsProvider>();
      settings.setGlobalTunnelUrl(_tunnel.tunnelUrl);
    }
    setState(() {});
    // Log oxiriga scroll
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_logScrollController.hasClients) {
        _logScrollController.animateTo(
          _logScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final connectivity = context.watch<ConnectivityProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Ulanish sozlamalari'),
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              children: [
                // ─── Tarmoq rejimi kartasi ───
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  elevation: 8,
                  shadowColor: Colors.black12,
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Tarmoq rejimi',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Container(
                          decoration: BoxDecoration(
                            color: theme.brightness == Brightness.light
                                ? const Color(0xFFF8FAFC)
                                : theme.colorScheme.onSurface.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              _buildModeOption(
                                context,
                                ConnectivityMode.server,
                                'Server (Kassa)',
                                'Ushbu kompyuter asosiy server sifatida ishlaydi',
                                Icons.computer,
                                connectivity,
                              ),
                              const Divider(height: 1),
                              _buildModeOption(
                                context,
                                ConnectivityMode.client,
                                'Client (Ofitsiant)',
                                'Boshqa qurilmadagi serverga ulanish',
                                Icons.smartphone,
                                connectivity,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                        if (connectivity.mode == ConnectivityMode.client) ...[
                          const Text(
                            'Server manzili',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _urlController,
                            decoration: InputDecoration(
                              hintText: 'http://192.168.1.XX:8080',
                              filled: true,
                              fillColor: theme.brightness == Brightness.light
                                  ? const Color(0xFFF8FAFC)
                                  : theme.colorScheme.onSurface.withValues(alpha: 0.08),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ],
                        if (connectivity.mode == ConnectivityMode.server) ...[
                          const Text(
                            'Port',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _portController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: theme.brightness == Brightness.light
                                  ? const Color(0xFFF8FAFC)
                                  : theme.colorScheme.onSurface.withValues(alpha: 0.08),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            onChanged: (val) {
                              final p = int.tryParse(val);
                              if (p != null) connectivity.setPort(p);
                            },
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: theme.colorScheme.primary.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'Ulanish uchun IP:',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                                Text(
                                  '${connectivity.serverIp ?? "Qidirilmoqda..."}:${connectivity.port}',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 32),
                        if (connectivity.connectionStatus.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 24.0),
                            child: Text(
                              connectivity.connectionStatus,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: connectivity.isSuccess
                                    ? Colors.green
                                    : Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => connectivity.testConnection(),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text('Tekshirish'),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  if (connectivity.mode == ConnectivityMode.client) {
                                    connectivity.setClientBaseUrl(_urlController.text);
                                  }
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Sozlamalar saqlandi'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                  Navigator.pop(context);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.colorScheme.primary,
                                  foregroundColor: theme.colorScheme.onPrimary,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text('Saqlash'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // ─── Cloudflare Tunnel bo'limi ───
                const SizedBox(height: 24),
                _buildTunnelCard(context, theme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModeOption(
    BuildContext context,
    ConnectivityMode mode,
    String title,
    String subtitle,
    IconData icon,
    ConnectivityProvider connectivity,
  ) {
    final theme = Theme.of(context);
    final isSelected = connectivity.mode == mode;

    return ListTile(
      onTap: () => connectivity.setMode(mode),
      leading: Icon(
        icon,
        color: isSelected ? theme.colorScheme.primary : Colors.grey,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: isSelected
          ? Icon(Icons.check_circle, color: theme.colorScheme.primary)
          : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Widget _buildTunnelCard(BuildContext context, ThemeData theme) {
    final connectivity = context.read<ConnectivityProvider>();
    final status = _tunnel.status;
    final tunnelUrl = _tunnel.tunnelUrl;
    final isRunning = status == TunnelStatus.running;
    final isStarting =
        status == TunnelStatus.starting || status == TunnelStatus.installing;

    Color statusColor = Colors.grey;
    String statusText = 'Ishlamayapti';
    IconData statusIcon = Icons.cloud_off;
    if (status == TunnelStatus.running) {
      statusColor = Colors.green;
      statusText = 'Faol';
      statusIcon = Icons.cloud_done;
    } else if (isStarting) {
      statusColor = Colors.orange;
      statusText = status == TunnelStatus.installing
          ? 'O\'rnatilmoqda...'
          : 'Ishga tushirilmoqda...';
      statusIcon = Icons.cloud_sync;
    } else if (status == TunnelStatus.error) {
      statusColor = Colors.red;
      statusText = 'Xatolik';
      statusIcon = Icons.cloud_off;
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 8,
      shadowColor: Colors.black12,
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(statusIcon, color: statusColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Cloudflare Tunnel',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Internetdan hisobotlarni ko\'rish',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.55),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isStarting)
                        const SizedBox(
                          width: 8,
                          height: 8,
                          child:
                              CircularProgressIndicator(strokeWidth: 1.5),
                        )
                      else
                        Icon(Icons.circle, color: statusColor, size: 8),
                      const SizedBox(width: 4),
                      Text(
                        statusText,
                        style: TextStyle(
                            color: statusColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Aktiv URL ko'rsatish
            if (tunnelUrl != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: Colors.green.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.link, color: Colors.green, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SelectableText(
                        tunnelUrl,
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(Icons.copy,
                          size: 16, color: Colors.green),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: tunnelUrl));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('URL nusxalandi!'),
                            duration: Duration(seconds: 2),
                            backgroundColor: Colors.green,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],

            // Xatolik
            if (status == TunnelStatus.error &&
                _tunnel.errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        color: Colors.red, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _tunnel.errorMessage!,
                        style:
                            const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            // Tugma
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isStarting
                    ? null
                    : isRunning
                        ? () => _tunnel.stop()
                        : () => _tunnel.start(connectivity.port),
                icon: isStarting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Icon(
                        isRunning
                            ? Icons.stop_circle_outlined
                            : Icons.rocket_launch_outlined,
                        size: 18),
                label: Text(
                  isStarting
                      ? (status == TunnelStatus.installing
                          ? 'cloudflared o\'rnatilmoqda...'
                          : 'Tunnel ishga tushirilmoqda...')
                      : isRunning
                          ? 'Tunnelni To\'xtatish'
                          : '🚀  Tunnelni Ishga Tushirish',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isRunning ? Colors.red.shade600 : const Color(0xFFF6821F),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),

            // Live loglar
            if (_tunnel.logs.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                height: 130,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SingleChildScrollView(
                  controller: _logScrollController,
                  child: Text(
                    _tunnel.logs,
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 20),

            // Info
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.brightness == Brightness.light
                    ? const Color(0xFFFFF7ED)
                    : const Color(0xFFF6821F).withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFFF6821F).withValues(alpha: 0.25)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline,
                          size: 15, color: Color(0xFFF6821F)),
                      SizedBox(width: 6),
                      Text(
                        'Bir tugma — hammasi avtomatik!',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Color(0xFFF6821F)),
                      ),
                    ],
                  ),
                  SizedBox(height: 6),
                  Text(
                    '• cloudflared avtomatik yuklanib o\'rnatiladi\n'
                    '• Tunnel URL si Telegram botga avtomatik qo\'shiladi\n'
                    '• Har restart da URL o\'zgaradi (bepul versiya)\n'
                    '• Ilova yopilsa tunnel ham to\'xtaydi',
                    style: TextStyle(fontSize: 11, height: 1.6),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

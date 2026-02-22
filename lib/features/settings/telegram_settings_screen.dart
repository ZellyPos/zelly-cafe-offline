import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_settings_provider.dart';

class TelegramSettingsScreen extends StatefulWidget {
  const TelegramSettingsScreen({super.key});

  @override
  State<TelegramSettingsScreen> createState() => _TelegramSettingsScreenState();
}

class _TelegramSettingsScreenState extends State<TelegramSettingsScreen> {
  late TextEditingController _tokenController;
  late TextEditingController _chatController;

  @override
  void initState() {
    super.initState();
    final settings = context.read<AppSettingsProvider>();
    _tokenController = TextEditingController(text: settings.telegramBotToken);
    _chatController = TextEditingController(text: settings.telegramChatId);
  }

  @override
  void dispose() {
    _tokenController.dispose();
    _chatController.dispose();
    super.dispose();
  }

  void _saveSettings() async {
    final settings = context.read<AppSettingsProvider>();
    await settings.setTelegramSettings(
      _tokenController.text.trim(),
      _chatController.text.trim(),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Telegram sozlamalari saqlandi!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Telegram Sozlamalari'),
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
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
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bot Sozlamalari',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Hisobotlarni Telegram botga yuborish uchun quyidagi ma\'lumotlarni kiriting.',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 32),

                  _buildLabel('Bot Token'),
                  TextField(
                    controller: _tokenController,
                    decoration: InputDecoration(
                      hintText: '12345678:ABCDE...',
                      prefixIcon: const Icon(Icons.token_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: theme.colorScheme.onSurface.withOpacity(0.15),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: theme.colorScheme.onSurface.withOpacity(0.15),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  _buildLabel('Chat ID'),
                  TextField(
                    controller: _chatController,
                    decoration: InputDecoration(
                      hintText: '-10012345678',
                      prefixIcon: const Icon(Icons.chat_bubble_outline),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: theme.colorScheme.onSurface.withOpacity(0.15),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: theme.colorScheme.onSurface.withOpacity(0.15),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),

                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _saveSettings,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Saqlash',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            _buildInstructions(),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface.withOpacity(0.6),
        ),
      ),
    );
  }

  Widget _buildInstructions() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark
        ? theme.colorScheme.primary.withOpacity(0.08)
        : const Color(0xFFEFF6FF);
    final borderColor = isDark
        ? theme.colorScheme.primary.withOpacity(0.2)
        : const Color(0xFFDBEAFE);
    final headingColor = isDark
        ? theme.colorScheme.primary
        : const Color(0xFF1E40AF);
    final textColor = isDark
        ? theme.colorScheme.primary.withOpacity(0.85)
        : const Color(0xFF1E40AF);
    final iconColor = isDark
        ? theme.colorScheme.primary
        : const Color(0xFF2563EB);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: iconColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'Qanday sozlanadi?',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: headingColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildStep(
            1,
            'Telegramda @BotFather orqasli yangi bot yarating va Token-ni oling.',
            textColor,
          ),
          _buildStep(
            2,
            'Botni o\'zingizning guruhingizga qo\'shing.',
            textColor,
          ),
          _buildStep(
            3,
            'Guruhning ID raqamini aniqlash uchun @GetMyChatID_Bot botidan foydalaning.',
            textColor,
          ),
          _buildStep(
            4,
            'Olingan ma\'lumotlarni yuqoridagi maydonlarga kiriting va "Saqlash" tugmasini bosing.',
            textColor,
          ),
        ],
      ),
    );
  }

  Widget _buildStep(int number, String text, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$number. ',
            style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
          ),
          Expanded(
            child: Text(text, style: TextStyle(color: textColor, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

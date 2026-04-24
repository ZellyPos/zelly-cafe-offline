import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_settings_provider.dart';
import '../../core/app_strings.dart';

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
    final token = _tokenController.text.trim();
    final chatId = _chatController.text.trim();

    if (token.isNotEmpty && !RegExp(r'^\d{8,11}:[-a-zA-Z0-9_]{35}$').hasMatch(token)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.invalidToken), backgroundColor: Colors.red),
      );
      return;
    }

    if (chatId.isNotEmpty && !RegExp(r'^-?\d+$').hasMatch(chatId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.invalidChatId), backgroundColor: Colors.red),
      );
      return;
    }

    final settings = context.read<AppSettingsProvider>();
    await settings.setTelegramSettings(token, chatId);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.botSaved),
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
        title: Text(AppStrings.telegramSettingsTitle),
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
                    AppStrings.botSettings,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppStrings.reportsDescription,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 32),

                  _buildLabel(AppStrings.botToken),
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

                  _buildLabel(AppStrings.chatId),
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
                      child: Text(
                        AppStrings.save,
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
                AppStrings.tgInstructionsTitle,
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
            AppStrings.tgStep1,
            textColor,
          ),
          _buildStep(
            2,
            AppStrings.tgStep2,
            textColor,
          ),
          _buildStep(
            3,
            AppStrings.tgStep3,
            textColor,
          ),
          _buildStep(
            4,
            AppStrings.tgStep4,
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

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/ai_provider.dart';
import 'ai_analysis_dialog.dart';

class AiActionButton extends StatelessWidget {
  final VoidCallback onAnalyze;
  final String label;
  final String dialogTitle;

  const AiActionButton({
    super.key,
    required this.onAnalyze,
    required this.label,
    required this.dialogTitle,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () {
        context.read<AiProvider>().clear();
        showDialog(
          context: context,
          builder: (context) => AiAnalysisDialog(
            onAnalyze: () async {
              await Future.microtask(onAnalyze);
            },
            title: dialogTitle,
          ),
        );
      },
      icon: const Icon(Icons.auto_awesome),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: Colors.purple,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

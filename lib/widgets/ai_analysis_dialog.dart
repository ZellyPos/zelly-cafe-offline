import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import '../../providers/ai_provider.dart';

class AiAnalysisDialog extends StatelessWidget {
  final Future<void> Function() onAnalyze;
  final String title;

  const AiAnalysisDialog({
    super.key,
    required this.onAnalyze,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    // Trigger analysis immediately when dialog opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<AiProvider>();
      if (provider.lastResult == null &&
          !provider.isLoading &&
          provider.error == null) {
        onAnalyze();
      }
    });

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 600,
        height: 500,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.auto_awesome,
                      color: Colors.purple,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    context.read<AiProvider>().clear();
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
            const Divider(height: 32),
            Expanded(
              child: Consumer<AiProvider>(
                builder: (context, provider, child) {
                  if (provider.isLoading) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: Colors.purple),
                          SizedBox(height: 16),
                          Text("AI tahlil qilmoqda..."),
                        ],
                      ),
                    );
                  }

                  if (provider.error != null) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 48,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            provider.error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.red),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: onAnalyze,
                            child: const Text("Qayta urinib ko'rish"),
                          ),
                        ],
                      ),
                    );
                  }

                  if (provider.lastResult != null) {
                    return Markdown(
                      data: provider.lastResult!,
                      styleSheet: MarkdownStyleSheet(
                        h1: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        h2: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        p: const TextStyle(fontSize: 16, height: 1.5),
                        listBullet: const TextStyle(fontSize: 16),
                      ),
                    );
                  }

                  return const Center(child: Text("Ma'lumot yo'q"));
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

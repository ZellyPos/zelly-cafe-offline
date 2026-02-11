import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../providers/ai_provider.dart';

class AiSummaryBanner extends StatefulWidget {
  const AiSummaryBanner({super.key});

  @override
  State<AiSummaryBanner> createState() => _AiSummaryBannerState();
}

class _AiSummaryBannerState extends State<AiSummaryBanner> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<AiProvider>(
      builder: (context, provider, child) {
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.auto_awesome,
                    color: Colors.white,
                    size: 28,
                  ),
                  title: const Text(
                    "Bugungi xulosa (AI)",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  trailing: IconButton(
                    icon: Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      setState(() => _expanded = !_expanded);
                      if (_expanded &&
                          provider.lastResult == null &&
                          !provider.isLoading) {
                        provider.getDashboardSummary();
                      }
                    },
                  ),
                ),
                if (_expanded)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (provider.isLoading)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(20.0),
                              child: CircularProgressIndicator(),
                            ),
                          )
                        else if (provider.error != null)
                          Text(
                            provider.error!,
                            style: const TextStyle(color: Colors.red),
                          )
                        else if (provider.lastResult != null)
                          MarkdownBody(
                            data: provider.lastResult!,
                            styleSheet: MarkdownStyleSheet(
                              p: const TextStyle(fontSize: 16, height: 1.5),
                              listBullet: const TextStyle(fontSize: 16),
                            ),
                          )
                        else
                          Center(
                            child: ElevatedButton(
                              onPressed: () => provider.getDashboardSummary(),
                              child: const Text("Tahlilni boshlash"),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

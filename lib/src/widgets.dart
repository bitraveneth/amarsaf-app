import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'theme.dart';

class LanguageButton extends StatelessWidget {
  const LanguageButton({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final next = state.language == 'bn' ? 'en' : 'bn';
    final label = state.language == 'bn' ? 'English' : 'বাংলা';
    return TextButton(
      onPressed: () => state.setLanguage(next),
      child: Text(label),
    );
  }
}

class FieldScaffold extends StatelessWidget {
  const FieldScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions = const [],
    this.floatingActionButton,
  });

  final String title;
  final Widget body;
  final List<Widget> actions;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [...actions, const LanguageButton()],
      ),
      floatingActionButton: floatingActionButton,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: body,
          ),
        ),
      ),
    );
  }
}

class QueueBanner extends StatelessWidget {
  const QueueBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final text = state.text;
    final pending = state.queue.pendingFor(state.userId);
    final failed = state.queue.failedFor(state.userId);
    if (pending == 0 && failed == 0 && (state.banner == null || state.banner!.isEmpty)) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: moss,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (state.banner != null && state.banner!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6, right: 8),
                  child: Text(state.banner!, style: const TextStyle(color: ink)),
                ),
              if (pending > 0 || failed > 0)
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$pending ${text.queued}'
                        '${failed > 0 ? ' · $failed ${text.syncFailed}' : ''}',
                        style: const TextStyle(color: tealDark, fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (pending > 0)
                      TextButton(
                        onPressed: state.flushing ? null : () => state.flushQueue(),
                        child: Text(state.flushing ? text.loading : text.sync),
                      ),
                    if (failed > 0)
                      TextButton(
                        onPressed: state.discardFailed,
                        child: Text(text.discard),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  const StatCard({super.key, required this.label, required this.value, this.onTap});

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: muted, fontSize: 13)),
              const SizedBox(height: 6),
              Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: ink)),
            ],
          ),
        ),
      ),
    );
  }
}

class EmptyNote extends StatelessWidget {
  const EmptyNote(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Center(child: Text(message, style: const TextStyle(color: muted), textAlign: TextAlign.center)),
    );
  }
}

class LoadError extends StatelessWidget {
  const LoadError({super.key, required this.message, required this.onRetry, required this.retryLabel});

  final String message;
  final VoidCallback onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: Text(retryLabel)),
        ],
      ),
    );
  }
}

Future<void> showNotice(BuildContext context, String message) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.read<AppState>().text.confirm),
        ),
      ],
    ),
  );
}

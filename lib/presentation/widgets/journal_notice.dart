import 'package:flutter/material.dart';
import '../../app/run_controller.dart';

class JournalNotice extends StatelessWidget {
  const JournalNotice({super.key, required this.runs});
  final RunController runs;
  @override
  Widget build(BuildContext context) => runs.profileError == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              Text(
                runs.profileError!,
                style: const TextStyle(color: Colors.orangeAccent),
              ),
              TextButton(
                onPressed: runs.busy ? null : runs.retryProfile,
                child: const Text('Retry journal update'),
              ),
            ],
          ),
        );
}

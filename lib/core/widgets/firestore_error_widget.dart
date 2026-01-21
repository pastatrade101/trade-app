import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

class FirestoreErrorWidget extends StatelessWidget {
  const FirestoreErrorWidget({
    super.key,
    required this.error,
    this.stackTrace,
    this.title,
  });

  final Object error;
  final StackTrace? stackTrace;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final firebaseError =
        error is FirebaseException ? error as FirebaseException : null;
    final message = _buildMessage(firebaseError);
    final detail = firebaseError?.message ?? error.toString();
    final isPermissionError = firebaseError?.code == 'permission-denied';
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title ??
                (isPermissionError
                    ? 'Not authorized'
                    : 'Unable to load data'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 4),
          Text(
            detail,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          if (stackTrace != null) ...[
            const SizedBox(height: 8),
            Text(
              stackTrace.toString(),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10),
            ),
          ],
        ],
      ),
    );
  }

  String _buildMessage(FirebaseException? firebaseError) {
    if (firebaseError == null) {
      return error.toString();
    }
    if (firebaseError.code == 'permission-denied') {
      return 'Not authorized. Please sign in again.';
    }
    if (firebaseError.message?.toLowerCase().contains('index') == true) {
      return 'Firestore index required. Visit the Firebase console to create it.';
    }
    return firebaseError.message ?? 'Firestore error occurred.';
  }
}

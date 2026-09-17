import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Ouvre un lien externe sans faire échouer le parcours si aucune application
/// n'est disponible sur l'appareil (navigateur embarqué, téléphone sans
/// WhatsApp, etc.).
Future<bool> openExternalUrl(
  BuildContext context,
  Uri uri, {
  required String failureMessage,
}) async {
  try {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failureMessage)),
      );
    }
    return opened;
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failureMessage)),
      );
    }
    return false;
  }
}

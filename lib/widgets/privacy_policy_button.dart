import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class PrivacyPolicyButton extends StatelessWidget {
  const PrivacyPolicyButton({super.key});

  static const String privacyUrl =
      'https://foodx.xo.je/privacy-policy.php';

  Future<void> _openPrivacyPolicy() async {
    final uri = Uri.parse(privacyUrl);

    if (!await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    )) {
      throw Exception('تعذر فتح سياسة الخصوصية');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.privacy_tip_outlined),
      title: const Text('سياسة الخصوصية'),
      subtitle: const Text('تعرف على طريقة استخدام وحماية بياناتك'),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: _openPrivacyPolicy,
    );
  }
}
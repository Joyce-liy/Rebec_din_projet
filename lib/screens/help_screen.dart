import 'package:flutter/material.dart';
import '../theme.dart';
import '../l10n/app_localizations.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(context.t('help_center')),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF2D3436),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tête
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [PharmaTheme.emeraldGreen, const Color(0xFF00695C)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.help_rounded,
                      color: Colors.white,
                      size: 40,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.t('help_header_title'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            context.t('help_header_subtitle'),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // FAQ
              Text(
                context.t('help_faq_title'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF2D3436),
                ),
              ),
              const SizedBox(height: 16),

              _buildFaqItem(
                context,
                question: context.t('help_faq_create_pharmacy_q'),
                answer: context.t('help_faq_create_pharmacy_a'),
              ),
              _buildFaqItem(
                context,
                question: context.t('help_faq_import_stock_q'),
                answer: context.t('help_faq_import_stock_a'),
              ),
              _buildFaqItem(
                context,
                question: context.t('help_faq_boost_visibility_q'),
                answer: context.t('help_faq_boost_visibility_a'),
              ),
              _buildFaqItem(
                context,
                question: context.t('help_faq_change_language_q'),
                answer: context.t('help_faq_change_language_a'),
              ),

              const SizedBox(height: 30),

              // Contact Support
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.support_agent_rounded,
                      size: 48,
                      color: PharmaTheme.emeraldGreen,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      context.t('help_support_title'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.t('help_support_description'),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () {
                        // TODO: Ouvrir WhatsApp ou email
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(context.t('help_support_snackbar')),
                          ),
                        );
                      },
                      icon: const Icon(Icons.chat_bubble_rounded),
                      label: Text(context.t('help_support_button')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: PharmaTheme.emeraldGreen,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFaqItem(
    BuildContext context, {
    required String question,
    required String answer,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        title: Text(
          question,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Text(
              answer,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

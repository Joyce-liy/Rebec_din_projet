import 'package:flutter/material.dart';
import 'package:pharm_admin/l10n/app_localizations.dart';
import '../services/firestore_service.dart';
import '../theme.dart';

/// Écran de migration pour les pharmacies créées avant le système owner_uid.
/// Le pharmacien voit la liste des pharmacies "orphelines" et réclame les siennes.
class ClaimPharmacyScreen extends StatefulWidget {
  const ClaimPharmacyScreen({Key? key}) : super(key: key);

  @override
  State<ClaimPharmacyScreen> createState() => _ClaimPharmacyScreenState();
}

class _ClaimPharmacyScreenState extends State<ClaimPharmacyScreen> {
  final FirestoreService _service = FirestoreService();
  List<Map<String, dynamic>> _orphans = [];
  bool _loading = true;
  final Set<String> _claiming = {};

  @override
  void initState() {
    super.initState();
    _loadOrphans();
  }

  Future<void> _loadOrphans() async {
    setState(() => _loading = true);
    try {
      final list = await _service.getOrphanPharmacies();
      setState(() => _orphans = list);
    } catch (e) {
      _showSnack('Erreur de chargement : $e', isError: true);
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _claim(String pharmacyId, String pharmacyName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
  context.t('confirm_claim'),   // ← C’est ça le changement principal
         
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Voulez-vous associer "$pharmacyName" à votre compte ?\n\n'
          'Elle ne sera plus visible par les autres pharmaciens.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
  context.t('annuler')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: PharmaTheme.emeraldGreen,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
  context.t('claim'),   // ← C’est ça le changement principal
            
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _claiming.add(pharmacyId));
    try {
      await _service.claimPharmacy(pharmacyId);
      setState(() => _orphans.removeWhere((p) => p['id'] == pharmacyId));
      _showSnack('"$pharmacyName" associée à votre compte ✓');
    } catch (e) {
      _showSnack('Erreur : $e', isError: true);
    } finally {
      setState(() => _claiming.remove(pharmacyId));
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.redAccent : PharmaTheme.emeraldGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
  context.t('recover_pharmacies'),   // ← C’est ça le changement principal
         
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: PharmaTheme.emeraldGreen),
            onPressed: _loadOrphans,
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: PharmaTheme.emeraldGreen),
            )
          : _orphans.isEmpty
              ? _buildEmpty()
              : _buildList(),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline_rounded,
              size: 72, color: PharmaTheme.emeraldGreen.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text(
  context.t('no_orphan_pharmacies'),   // ← C’est ça le changement principal
           
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 8),
         Text(
  context.t('all_pharmacies_have_owner'),   // ← C’est ça le changement principal
           
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    return Column(
      children: [
        // Bandeau explicatif
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF9C4),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFFDD835).withOpacity(0.5)),
          ),
          child: Row(
            children: const [
              Icon(Icons.info_outline_rounded, color: Color(0xFFF59E0B), size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Ces pharmacies ont été créées avant la mise à jour. '
                  'Reconnaissez les vôtres et cliquez "Réclamer" pour les associer à votre compte.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF78350F), height: 1.4),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _orphans.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final p = _orphans[i];
              final id = p['id'] as String;
              final nom = p['nom'] ?? 'Sans nom';
              final adresse = p['adresse'] ?? '';
              final isClaiming = _claiming.contains(id);

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: PharmaTheme.emeraldGreen.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.local_pharmacy_rounded,
                        color: PharmaTheme.emeraldGreen,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            nom,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          if (adresse.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 3),
                              child: Text(
                                adresse,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    isClaiming
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: PharmaTheme.emeraldGreen,
                            ),
                          )
                        : TextButton(
                            onPressed: () => _claim(id, nom),
                            style: TextButton.styleFrom(
                              backgroundColor:
                                  PharmaTheme.emeraldGreen.withOpacity(0.08),
                              foregroundColor: PharmaTheme.emeraldGreen,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                            ),
                            child: Text(
  context.t('claim'),   // ← C’est ça le changement principal
                              
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
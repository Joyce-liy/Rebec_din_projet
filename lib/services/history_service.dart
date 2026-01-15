import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HistoryService {
  HistoryService._privateConstructor();
  static final HistoryService _instance = HistoryService._privateConstructor();
  static HistoryService get instance => _instance;

  static const _kSearchHistoryKey = 'search_history_v2'; // Changé pour éviter les conflits avec l'ancien format
  final ValueNotifier<List<String>> history = ValueNotifier<List<String>>([]);

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_kSearchHistoryKey) ?? [];
      history.value = List<String>.from(list);
    } catch (e) {
      if (kDebugMode) debugPrint('HistoryService.load error: $e');
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_kSearchHistoryKey, history.value);
    } catch (e) {
      if (kDebugMode) debugPrint('HistoryService._save error: $e');
    }
  }

  // AJOUT DE L'ARGUMENT SOURCE
  Future<void> add(String term, {String source = "Recherche"}) async {
    final t = term.trim();
    if (t.isEmpty) return;
    
    // Formatage : "Scanner:Doliprane" ou "Recherche:Paracetamol"
    final entry = "$source:$t"; 
    
    final list = List<String>.from(history.value);
    
    // On retire l'entrée si elle existe déjà (peu importe la source ou même nom)
    list.removeWhere((item) => item.endsWith(":$t")); 
    
    list.insert(0, entry);
    if (list.length > 20) list.removeRange(20, list.length);
    
    history.value = list;
    await _save();
  }

  Future<void> remove(String entry) async {
    final list = List<String>.from(history.value);
    list.remove(entry);
    history.value = list;
    await _save();
  }

  Future<void> clear() async {
    history.value = [];
    await _save();
  }
}
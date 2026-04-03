# Tests et Cas d'Usage - REBEC-DIN

## 🧪 Cas de Test

### Test 1 : Recherche de Médicament Standard
**Entrée:** "Aspirin"
**Comportement attendu:**
1. ✓ Affiche les 5 pharmacies les plus proches
2. ✓ Recommande la pharmacie la plus rapide d'accès
3. ✓ Affiche distances et temps de trajet

### Test 2 : Hors-Sujet Détecté
**Entrée:** "Quelle est la meilleure équipe de football ?"
**Comportement attendu:**
1. ✓ Classification: NON (pas lié à la pharmacie)
2. ✓ Réponse courtoise de recadrage
3. ✓ Suggestion vers domaine pharmacie

### Test 3 : Sélection de Pharmacie
**Entrée (après liste):** "2" (deuxième pharmacie)
**Comportement attendu:**
1. ✓ Confirmation de la sélection
2. ✓ Propose 3 actions:
   - Lancer itinéraire
   - Conseils sur le médicament
   - Autre médicament

### Test 4 : Conseils Médicaux
**Entrée:** "2" (dans le menu d'action)
**Comportement attendu:**
1. ✓ Appelle Gemini avec contexte
2. ✓ Affiche conseils détaillés (max 200 mots)
3. ✓ Rappel de consulter un pharmacien

### Test 5 : Navigation
**Entrée:** "1" (lancer itinéraire)
**Comportement attendu:**
1. ✓ Ouvre Google Maps
2. ✓ Affiche l'itinéraire vers la pharmacie
3. ✓ Revient au mode recherche

### Test 6 : Texte avec Nombre
**Entrée:** "Je veux la pharmacie numéro 3" ou "trois"
**Comportement attendu:**
1. ✓ Parse correctement le nombre
2. ✓ Sélectionne la pharmacie correspondante

### Test 7 : API Indisponible
**Scénario:** Pas de clé API ou API down
**Comportement attendu:**
1. ✓ Fallback gracieux
2. ✓ Message d'erreur clair
3. ✓ App continue de fonctionner

### Test 8 : Contexte Persistant
**Scénario:**
1. Utilisateur: "Paracétamol"
2. [Pharmacies affichées]
3. Utilisateur: "1"
4. [Menu actions]
5. Utilisateur: "2"
**Comportement attendu:**
- Conseils incluent "paracétamol" du contexte
- L'IA se souvient du médicament initial

## 📊 Métriques de Succès

| Métrique | Cible |
|----------|-------|
| Temps de réponse API | < 3s |
| Précision détection intention | > 95% |
| Disponibilité API | > 99% |
| Taux d'erreur | < 1% |

## 🐛 Problèmes Connus et Solutions

### Problème 1: Clé API manquante
**Symptôme:** Aucun recadrage, juste fallback
**Solution:** Vérifier `.env` et relancer l'app

### Problème 2: Timeout sur API lente
**Symptôme:** Message "Je n'ai pas pu récupérer..."
**Solution:** Augmenter le timeout dans `GeminiService` (DEFAULT: 15s)

### Problème 3: GPS désactivé
**Symptôme:** "Je n'arrive pas à accéder à votre position"
**Solution:** Activer la localisation et réessayer

## 🔄 Flux Complet Illustré

```
START
│
├─ Salutation?
│  └─ OUI → Message accueil
│
└─ NON → Vérifier intention (Gemini)
   │
   ├─ HORS-SUJET
   │  └─ Réponse recadrage (Gemini) → Retour START
   │
   └─ PHARMACIE-RELATIF
      ├─ Récupérer position GPS
      ├─ Lister 5 pharmacies
      ├─ Calculer temps de trajet (Google Maps)
      ├─ Afficher recommandation
      │
      ├─ Utilisateur choisit pharmacie
      │  │
      │  ├─ OPTION 1: Navigation
      │  │  └─ Ouvrir Google Maps → Retour START
      │  │
      │  ├─ OPTION 2: Conseils
      │  │  └─ Appel Gemini avec contexte → Retour START
      │  │
      │  └─ OPTION 3: Autre médicament
      │     └─ Retour START
      │
      └─ Autre entrée invalide → Message d'erreur
```

## 🎯 Points Clés d'Amélioration

1. **Persistance** : Sauvegarder l'historique en SQLite
2. **Analytics** : Tracker les médicaments recherchés
3. **Prédictions** : Suggérer des pharmacies basées sur l'historique
4. **Intégration SMS** : Envoyer l'itinéraire par SMS
5. **Avis** : Afficher les notes des pharmacies

//composant qui met en avant les pharmacies prenium

import 'package:flutter/material.dart';
import '../theme.dart';

class PharmacyItem extends StatelessWidget {
  final String name;
  final String location;
  final bool isPremium; // Le paramètre clé

  const PharmacyItem({required this.name, required this.location, this.isPremium = false});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.only(bottom: 15),
      elevation: isPremium ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isPremium ? BorderSide(color: PharmaTheme.emeraldGreen, width: 2) : BorderSide.none,
      ),
      child: ListTile(
        contentPadding: EdgeInsets.all(10),
        leading: CircleAvatar(
          backgroundColor: isPremium ? PharmaTheme.emeraldGreen : Colors.grey.shade300,
          child: Icon(Icons.local_pharmacy, color: Colors.white),
        ),
        title: Row(
          children: [
            Text(name, style: TextStyle(fontWeight: FontWeight.bold)),
            if (isPremium) ...[
              SizedBox(width: 5),
              Icon(Icons.verified, color: PharmaTheme.emeraldGreen, size: 18),
            ]
          ],
        ),
        subtitle: Text(location),
        trailing: isPremium
            ? Text("PRIORITAIRE", style: TextStyle(color: PharmaTheme.emeraldGreen, fontWeight: FontWeight.bold, fontSize: 10))
            : Icon(Icons.arrow_forward_ios, size: 14),
      ),
    );
  }
}
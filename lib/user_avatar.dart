import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GlobalUserAvatar extends StatefulWidget {
  final double radius;
  final String userName;

  const GlobalUserAvatar({super.key, required this.radius, required this.userName});

  @override
  State<GlobalUserAvatar> createState() => _GlobalUserAvatarState();
}

class _GlobalUserAvatarState extends State<GlobalUserAvatar> {
  String? _imagePath;

  @override
  void initState() {
    super.initState();
    _loadProfilePic();
  }

  // Cette fonction charge l'image depuis la mémoire du téléphone
  Future<void> _loadProfilePic() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _imagePath = prefs.getString('user_profile_pic');
    });
  }

  @override
  Widget build(BuildContext context) {
    String initial = widget.userName.isNotEmpty ? widget.userName[0].toUpperCase() : "?";

    return CircleAvatar(
      radius: widget.radius,
      backgroundColor: Colors.green.shade600,
      backgroundImage: _imagePath != null ? FileImage(File(_imagePath!)) : null,
      child: _imagePath == null 
          ? Text(initial, style: TextStyle(color: Colors.white, fontSize: widget.radius * 0.8)) 
          : null,
    );
  }
}
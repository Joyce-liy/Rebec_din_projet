import 'package:flutter/material.dart';

class AppLanguage extends ValueNotifier<Locale> {
  AppLanguage(Locale value) : super(value);

  static final AppLanguage instance = AppLanguage(const Locale('fr'));

  void updateLocale(Locale locale) {
    if (locale == value) return;
    value = locale;
  }
}

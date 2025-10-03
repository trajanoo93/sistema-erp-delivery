import 'package:flutter/material.dart';

class AuthProvider extends ChangeNotifier {
  String? currentUser;
  int? userId;

  void setUser(int id, String name) {
    userId = id;
    currentUser = name;
    notifyListeners();
  }

  void logout() {
    userId = null;
    currentUser = null;
    notifyListeners();
  }
}
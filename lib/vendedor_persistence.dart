// lib/vendedor_persistence.dart
import 'package:shared_preferences/shared_preferences.dart';

class VendedorPersistence {
  static const String _vendedorKey = 'selectedVendedor';

  Future<void> saveVendedor(String vendedor) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_vendedorKey, vendedor);
  }

  Future<String?> getVendedor() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_vendedorKey);
  }
}
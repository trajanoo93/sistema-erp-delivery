import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'https://script.google.com/macros/s/AKfycbxe-i7zWz0VyUb5HY8a87Ln_NFm-MNGck4B5BO7EKuYuBLwex5qpmh0YfINg51kSXOQ/exec?action=Read'; 
  // Substitua pela URL exata

  static Future<List<dynamic>> fetchPedidos() async {
    final response = await http.get(Uri.parse(baseUrl));

    if (response.statusCode == 200) {
      // Converte a resposta JSON para lista
      return jsonDecode(response.body) as List<dynamic>;
    } else {
      throw Exception('Falha ao carregar pedidos');
    }
  }
}
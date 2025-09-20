import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlng;
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart'; // Para localização atual

class UnidadesPage extends StatefulWidget {
  const UnidadesPage({Key? key}) : super(key: key);

  @override
  _UnidadesPageState createState() => _UnidadesPageState();
}

class _UnidadesPageState extends State<UnidadesPage> {
  final TextEditingController _searchController = TextEditingController();
  final List<Map<String, dynamic>> _stores = [
    {
      'lat': -19.8874714,
      'lng': -43.9290403,
      'name': 'Cidade Nova',
      'address': 'Av. Cristiano Machado, 2312 - Cidade Nova, Belo Horizonte',
      'phone': '(31) 9 8256-4794',
      'image': 'https://lh3.googleusercontent.com/p/AF1QipNJQKVqT4qsHz9H0St6vzpMh1G4fesyoeSxWWYZ=w408-h717-k-no',
    },
    {
      'lat': -19.9763743,
      'lng': -44.0184645,
      'name': 'Barreiro',
      'address': 'Av. Sinfrônio Brochado, 612 - Barreiro, Belo Horizonte',
      'phone': '(31) 9 9534-8704',
      'image': 'https://lh3.googleusercontent.com/p/AF1QipOQ-E8AqFJ0DMIeDohcgjpvLxcHUaL2wgMMvM4P=w408-h408-k-no',
    },
    {
      'lat': -19.9072211,
      'lng': -43.9294909,
      'name': 'Central',
      'address': 'Central de Delivery - Belo Horizonte',
      'phone': '(31) 3461-3297',
      'image': 'https://lh3.googleusercontent.com/p/AF1QipPLmmeG0uqbJQpU2VVc7cdQ7xe9EsKcdriGZR8a=w408-h326-k-no',
    },
    {
      'lat': -19.930014,
      'lng': -43.972302,
      'name': 'Silva Lobo',
      'address': 'Av. Silva Lobo, 770 - Nova Suiça, Belo Horizonte',
      'phone': '(31) 9 7201-4492',
      'image': 'https://lh3.googleusercontent.com/p/AF1QipObZzd-UEN0yOzCHHhLiwVAJwyUbZx_k2aSbI-E=w408-h544-k-no',
    },
    {
      'lat': -19.9754216,
      'lng': -43.943332,
      'name': 'Belvedere',
      'address': 'Av. Luiz Paulo Franco, 961 - Belvedere, Belo Horizonte',
      'phone': '(31) 9 7304-9750',
      'image': 'https://lh3.googleusercontent.com/p/AF1QipPAVbGFffj-WajwOEE7nAk6DhKk9a9_RkPjkRr4=w408-h544-k-no',
    },
    {
      'lat': -19.9700819,
      'lng': -43.9653186,
      'name': 'Buritis',
      'address': 'Av. Professor Mário Werneck, 1542 - Buritis, Belo Horizonte',
      'phone': '(31) 9 9328-7517',
      'image': 'https://lh3.googleusercontent.com/p/AF1QipOSe3iefhzzvqnMyD2C8hhSWbAN7D_JS9OxsuU9=w408-h544-k-no',
    },
    {
      'lat': -19.9503454,
      'lng': -43.9218962,
      'name': 'Mangabeiras',
      'address': 'Av. dos Bandeirantes, 1600 - Mangabeiras, Belo Horizonte',
      'phone': '(31) 9 8258-7179',
      'image': 'https://lh3.googleusercontent.com/gps-cs-s/AC9h4npGm3lgKIRg2cz6KouFtNoGOSMXTnv05cvRd4w6_0aaDrLO2E4cCRZ7iWM6iqdAfweMFgPlcPPo2wEPClQdu516L6qIIXyw6ZUbFMuknMwXgVl6rXhfBKBv9PV8-vjf0p0VgD6n=w426-h240-k-no',
    },
    {
      'lat': -19.9458992,
      'lng': -43.949172,
      'name': 'Prudente',
      'address': 'Av. Prudente de Morais, 1159 - Santo Antônio, Belo Horizonte',
      'phone': '(31) 9 7304-8792',
      'image': 'https://lh3.googleusercontent.com/p/AF1QipOIVv-6WVUPxWKJbeyX4ZWqInabVbMVMQ89VyX3=w426-h240-k-no',
    },
    {
      'lat': -19.9080117,
      'lng': -43.9286144,
      'name': 'Silviano',
      'address': 'Av. Silviano Brandão, 825 - Floresta, Belo Horizonte',
      'phone': '(31) 9 8256-4824',
      'image': 'https://lh3.googleusercontent.com/p/AF1QipMNBzoJbnLiZtJyupgQKo6s8zZPVBeyWX6MoQ5W=w408-h725-k-no',
    },
    {
      'lat': -19.8467672,
      'lng': -43.9751728,
      'name': 'Pampulha',
      'address': 'Av. Otacílio Negrão de Lima, 6000 - Pampulha, Belo Horizonte',
      'phone': '(31) 9 7304-9877',
      'image': 'https://lh3.googleusercontent.com/p/AF1QipPhs29NVzV2vVvwAyXPtCUUnq1-XQb2cf4C__EP=w426-h240-k-no',
    },
    {
      'lat': -19.8865154,
      'lng': -44.0047992,
      'name': 'Castelo',
      'address': 'Av. Heráclito Mourão de Miranda, 800 - Castelo, Belo Horizonte',
      'phone': '(31) 9 9947-4595',
      'image': 'https://lh3.googleusercontent.com/gps-cs-s/AC9h4nqq237W2uMTuawYVhrCrIfY4vIZg-JzMSmLXBaBtU5FFlBvDg_8caCnWgqo77B-G7j_7lw3zD4JAEz4I-3eygnzvS81NcrllYzF231PWQ35D4_EyG6FL2nFNR1N9ZWHqdfAn3-l=w426-h240-k-no',
    },
    {
      'lat': -19.9565435,
      'lng': -43.9402123,
      'name': 'Sion',
      'address': 'R. Haití, 354, Sion, Belo Horizonte',
      'phone': '(31) 9 8311-2919',
      'image': 'https://lh3.googleusercontent.com/gps-cs-s/AC9h4nqq237W2uMTuawYVhrCrIfY4vIZg-JzMSmLXBaBtU5FFlBvDg_8caCnWgqo77B-G7j_7lw3zD4JAEz4I-3eygnzvS81NcrllYzF231PWQ35D4_EyG6FL2nFNR1N9ZWHqdfAn3-l=w426-h240-k-no',
    },
    {
      'lat': -19.9431775,
      'lng': -44.0381746,
      'name': 'Eldorado',
      'address': 'Av. João César de Oliveira, 1055 - Eldorado, Contagem',
      'phone': '(31) 9 8257-4157',
      'image': 'https://lh3.googleusercontent.com/p/AF1QipP7WKFae-vR7dMxrzYFQkdDvEfnXT17w02PI7cc=w408-h306-k-no',
    },
  ];
  bool _isLoading = false;
  latlng.LatLng? _userLocation;
  final MapController _mapController = MapController();

  Future<void> _geocodeAddress(String address) async {
    setState(() => _isLoading = true);
    try {
      final apiKey = 'AIzaSyBJswnlRTWAOLOZPokmVupMcFQHiFzGWzM';
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?address=${Uri.encodeComponent(address)}&key=$apiKey',
      );
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'OK') {
          final location = data['results'][0]['geometry']['location'];
          final lat = location['lat'];
          final lng = location['lng'];
          setState(() {
            _userLocation = latlng.LatLng(lat, lng);
          });
          _sortStoresByDistance(lat, lng);
          _zoomToNearestStores();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Endereço não encontrado')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao geocodificar o endereço')),
        );
      }
    } catch (e) {
      print('Erro ao geocodificar: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao geocodificar: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoading = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _userLocation = latlng.LatLng(position.latitude, position.longitude);
      });
      _sortStoresByDistance(position.latitude, position.longitude);
      _zoomToNearestStores();
    } catch (e) {
      print('Erro ao obter localização: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao obter localização: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _sortStoresByDistance(double userLat, double userLng) {
    setState(() {
      _stores.sort((a, b) {
        final distanceA = _calculateDistance(userLat.toString(), userLng.toString(), a['lat'].toString(), a['lng'].toString());
        final distanceB = _calculateDistance(userLat.toString(), userLng.toString(), b['lat'].toString(), b['lng'].toString());
        return distanceA.compareTo(distanceB);
      });
    });
  }

  void _zoomToNearestStores() {
    if (_stores.isNotEmpty && _userLocation != null) {
      final nearestStores = _stores.take(3).toList(); // Pega as 3 lojas mais próximas
      if (nearestStores.isNotEmpty) {
        final centerLat = (_userLocation!.latitude + nearestStores.map((s) => s['lat'] as double).reduce((a, b) => a + b) / nearestStores.length) / 2;
        final centerLng = (_userLocation!.longitude + nearestStores.map((s) => s['lng'] as double).reduce((a, b) => a + b) / nearestStores.length) / 2;
        _mapController.move(latlng.LatLng(centerLat, centerLng), 13.0); // Zoom ajustado para 13
      }
    }
  }

  void _moveMapToLocation(double lat, double lon) {
    _mapController.move(latlng.LatLng(lat, lon), 14.0); // Zoom ajustado para 14
  }

  double _calculateDistance(String lat1, String lng1, String lat2, String lng2) {
    const double earthRadius = 6371; // Raio da Terra em km
    final double lat1Rad = double.parse(lat1) * (math.pi / 180);
    final double lng1Rad = double.parse(lng1) * (math.pi / 180);
    final double lat2Rad = double.parse(lat2) * (math.pi / 180);
    final double lng2Rad = double.parse(lng2) * (math.pi / 180);
    final double dLat = lat2Rad - lat1Rad;
    final double dLng = lng2Rad - lng1Rad;
    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1Rad) * math.cos(lat2Rad) * math.sin(dLng / 2) * math.sin(dLng / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a)); // Ângulo em radianos
    final double distance = earthRadius * c; // Converte para quilômetros
    print('Distância calculada: $distance km entre ($lat1, $lng1) e ($lat2, $lng2)');
    return distance; // Retorna a distância em km
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Localizar Unidades',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'Digite o endereço do cliente',
                      labelStyle: GoogleFonts.poppins(color: Colors.black54, fontWeight: FontWeight.w500),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.orange.shade200),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.orange.shade200),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.orange.shade600, width: 2),
                      ),
                      prefixIcon: Icon(Icons.search, color: Colors.orange.shade600),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    onFieldSubmitted: _geocodeAddress,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _getCurrentLocation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade600,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.location_on, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        'Minha Localização',
                        style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 1,
                    child: Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white,
                              Colors.orange.shade50.withOpacity(0.5),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Lojas Próximas',
                                    style: GoogleFonts.poppins(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  Text(
                                    '${_stores.length}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.orange.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: ListView.builder(
                                itemCount: _stores.length,
                                itemBuilder: (context, index) {
                                  final store = _stores[index];
                                  final distance = _userLocation != null
                                      ? _calculateDistance(_userLocation!.latitude.toString(), _userLocation!.longitude.toString(), store['lat'].toString(), store['lng'].toString())
                                      : 0.0;
                                  return ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    leading: CircleAvatar(
                                      backgroundImage: NetworkImage(store['image'] as String),
                                      radius: 20,
                                    ),
                                    title: Text(
                                      store['name'] as String,
                                      style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                                    ),
                                    subtitle: Text(
                                      store['address'] as String,
                                      style: GoogleFonts.poppins(fontSize: 12, color: Colors.black54),
                                    ),
                                    trailing: Text(
                                      _userLocation != null
                                          ? '${distance.toStringAsFixed(2)} km'
                                          : 'N/A',
                                      style: TextStyle(color: Colors.orange),
                                    ),
                                    onTap: () {
                                      _moveMapToLocation(store['lat'], store['lng']);
                                    },
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white,
                              Colors.orange.shade50.withOpacity(0.5),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: FlutterMap(
                          mapController: _mapController,
                          options: MapOptions(
                            initialCenter: _userLocation ?? latlng.LatLng(-19.9208, -43.9378),
                            initialZoom: 12.0,
                          ),
                          children: [
                            TileLayer(
                              urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                              subdomains: ['a', 'b', 'c'],
                            ),
                            MarkerLayer(
                              markers: [
                                if (_userLocation != null)
                                  Marker(
                                    point: _userLocation!,
                                    child: Icon(
                                      Icons.location_on,
                                      color: Colors.green,
                                      size: 40,
                                    ),
                                  ),
                                ..._stores.map((store) => Marker(
                                      point: latlng.LatLng(store['lat'], store['lng']),
                                      child: Icon(
                                        Icons.location_on,
                                        color: Colors.red,
                                        size: 30,
                                      ),
                                    )).toList(),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
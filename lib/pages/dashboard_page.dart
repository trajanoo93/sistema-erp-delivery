
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../provider.dart';
import '../globals.dart' as globals;

class DashboardPage extends StatefulWidget {
  const DashboardPage({Key? key}) : super(key: key);

  @override
  _DashboardPageState createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> with TickerProviderStateMixin {
  final Color primaryColor = const Color(0xFFF28C38);
  final String _baseUrl = 'https://script.google.com/macros/s/AKfycbymsq-y46VtSRzpQcfKETBHhUukdVehvtN2_GzxhLL_d2ohpUGCyMxT_vyBN2OTUKjE/exec';
  final Map<String, String> _cdActions = {
    'Central': 'Read',
    'CD Barreiro': 'ReadCDBarreiro',
    'CD Sion': 'ReadCDSion',
    'Agendados': 'ReadAgendados',
  };
  final int _maxDisplayPedidos = 200; // Aumentado para 200
  late AnimationController _skeletonController;
  late Animation<double> _skeletonAnimation;

  @override
  void initState() {
    super.initState();
    _skeletonController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    _skeletonAnimation = Tween<double>(begin: 0.3, end: 0.6).animate(
      CurvedAnimation(parent: _skeletonController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _skeletonController.dispose();
    super.dispose();
  }

  Stream<Map<String, dynamic>> _fetchPedidosStream({bool forceRefresh = false}) async* {
    List<dynamic> combinedPedidos = [];
    final prefs = await SharedPreferences.getInstance();
    final todayKey = DateTime.now().toIso8601String().substring(0, 10);

    // Tenta carregar do cache, a menos que seja refresh
    if (!forceRefresh) {
      final cachedData = prefs.getString('dashboard_pedidos_$todayKey');
      if (cachedData != null) {
        combinedPedidos = jsonDecode(cachedData);
        yield {'status': 'success', 'data': combinedPedidos, 'progress': 1.0, 'message': 'Dados carregados do cache'};
      }
    }

    // Limpar cache antes de novo fetch
    await prefs.remove('dashboard_pedidos_$todayKey');

    // Fetch paralelo
    final futures = _cdActions.entries.map((entry) async {
      final cdName = entry.key;
      final action = entry.value;
      final url = '$_baseUrl?action=$action';
      try {
        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data is List) {
            return data.map((p) => {...p, 'cd_origem': cdName}).toList();
          } else if (data is Map<String, dynamic> && data['status'] == 'error') {
            return {'error': 'Erro na API $cdName: ${data['message']}'};
          }
          return {'error': 'Formato inesperado da resposta para $cdName'};
        }
        return {'error': 'Erro ao carregar $cdName: ${response.statusCode}'};
      } catch (e) {
        return {'error': 'Erro de conexão em $cdName: $e'};
      }
    }).toList();

    int completed = 0;
    for (var future in await Future.wait(futures)) {
      completed++;
      if (future is List<dynamic>) {
        combinedPedidos.addAll(future.take(_maxDisplayPedidos));
      } else if (future is Map<String, dynamic> && future.containsKey('error')) {
        yield {'status': 'error', 'message': future['error'], 'progress': completed / _cdActions.length};
      }
      yield {
        'status': 'loading',
        'data': combinedPedidos,
        'progress': completed / _cdActions.length,
        'message': 'Carregando ${_cdActions.keys.elementAt(completed - 1)}...'
      };
    }

    // Salvar no cache
    await prefs.setString('dashboard_pedidos_$todayKey', jsonEncode(combinedPedidos));
    yield {'status': 'success', 'data': combinedPedidos, 'progress': 1.0, 'message': 'Dados carregados'};
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final userId = authProvider.userId;
    final userName = globals.users[userId] ?? 'Vendedor';

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: StreamBuilder<Map<String, dynamic>>(
            stream: _fetchPedidosStream(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!['status'] == 'loading') {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(userName),
                    const SizedBox(height: 20),
                    _buildSkeletonCard(),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 20,
                      runSpacing: 20,
                      children: [
                        _buildSkeletonChartCard('Pedidos por Status'),
                        _buildSkeletonChartCard('Pedidos por Slot'),
                      ],
                    ),
                    if (snapshot.hasData && snapshot.data!['status'] == 'loading')
                      Padding(
                        padding: const EdgeInsets.only(top: 20),
                        child: Column(
                          children: [
                            LinearProgressIndicator(
                              value: snapshot.data!['progress'],
                              backgroundColor: primaryColor.withOpacity(0.2),
                              valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              snapshot.data!['message'],
                              style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              } else if (snapshot.hasError || snapshot.data!['status'] == 'error') {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, color: primaryColor, size: 48),
                      const SizedBox(height: 8),
                      Text(
                        snapshot.hasError ? 'Erro: ${snapshot.error}' : snapshot.data!['message'],
                        style: GoogleFonts.poppins(color: Colors.red, fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: () => setState(() {}),
                        icon: Icon(Icons.refresh, color: primaryColor),
                        label: Text(
                          'Tentar novamente',
                          style: GoogleFonts.poppins(fontSize: 14, color: primaryColor),
                        ),
                      ),
                    ],
                  ),
                );
              }

              final pedidos = snapshot.data!['data'] as List<dynamic>;
              final today = DateTime.now();
              final startOfDay = DateTime(today.year, today.month, today.day);
              final endOfDay = startOfDay.add(const Duration(days: 1));

              // Filtrar pedidos do vendedor logado e do dia atual
              final userPedidos = pedidos.where((p) {
                final vendedor = p['vendedor']?.toString() ?? '';
                final dataStr = p['data_agendamento']?.toString() ?? '';
                if (vendedor != userName || dataStr.isEmpty) return false;
                try {
                  final dt = DateTime.parse(dataStr);
                  final isSameDay = dt.year == today.year && dt.month == today.month && dt.day == today.day;
                  return isSameDay;
                } catch (e) {
                  debugPrint('Erro ao parsear data_agendamento: $dataStr, erro: $e');
                  return false;
                }
              }).toList();

              debugPrint('Pedidos filtrados para $userName: ${userPedidos.length}');

              // Calcula métricas
              double totalValue = userPedidos
                  .where((p) => p["status"] != "Cancelado")
                  .fold(0.0, (sum, p) {
                    final subTotal = p["subTotal"];
                    if (subTotal == null) return sum;
                    if (subTotal is num) return sum + subTotal.toDouble();
                    if (subTotal is String) {
                      try {
                        final cleanSubTotal = subTotal.replaceAll('R\$', '').replaceAll(',', '.').trim();
                        return sum + double.parse(cleanSubTotal);
                      } catch (e) {
                        debugPrint('Erro ao parsear subTotal: $subTotal, erro: $e');
                        return sum;
                      }
                    }
                    return sum;
                  });

              int totalOrders = userPedidos.where((p) => p["status"] != "Cancelado").length;

              Map<String, int> slots = {
                "09:00 - 12:00": 0,
                "12:00 - 15:00": 0,
                "15:00 - 18:00": 0,
                "18:00 - 21:00": 0,
              };
              for (var p in userPedidos) {
                final horarioAgendamento = p["horario_agendamento"];
                if (horarioAgendamento is String && slots.containsKey(horarioAgendamento)) {
                  slots[horarioAgendamento] = (slots[horarioAgendamento] ?? 0) + 1;
                }
              }

              Map<String, int> statusCount = {
                "Saiu pra Entrega": 0,
                "Registrado": 0,
                "Concluído": 0,
                "Cancelado": 0,
              };
              for (var p in userPedidos) {
                final status = p["status"];
                if (status is String && statusCount.containsKey(status)) {
                  statusCount[status] = (statusCount[status] ?? 0) + 1;
                }
              }

              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(userName),
                    const SizedBox(height: 20),
                    _buildMetricsCard(totalValue, totalOrders),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 20,
                      runSpacing: 20,
                      children: [
                        _buildStatusCard(statusCount, totalOrders),
                        _buildPedidosPorSlotCard(slots),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => setState(() => _fetchPedidosStream(forceRefresh: true)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        'Atualizar Dados',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(String userName) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: primaryColor,
            boxShadow: [
              BoxShadow(
                color: primaryColor.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            Icons.dashboard,
            color: Colors.white,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          'Vendas do Dia - $userName',
          style: GoogleFonts.poppins(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildSkeletonCard() {
    return AnimatedBuilder(
      animation: _skeletonAnimation,
      builder: (context, _) {
        return Opacity(
          opacity: _skeletonAnimation.value,
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 150,
                        height: 16,
                        color: Colors.grey[300],
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: 200,
                        height: 32,
                        color: Colors.grey[300],
                      ),
                    ],
                  ),
                  Container(
                    width: 100,
                    height: 40,
                    color: Colors.grey[300],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSkeletonChartCard(String title) {
    return AnimatedBuilder(
      animation: _skeletonAnimation,
      builder: (context, _) {
        return Opacity(
          opacity: _skeletonAnimation.value,
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            color: Colors.white,
            child: Container(
              width: 400,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 150,
                    height: 18,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: 360,
                    height: 180,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 30),
                  Column(
                    children: List.generate(4, (index) => Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        children: [
                          Container(
                            width: 14,
                            height: 14,
                            color: Colors.grey[300],
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 100,
                            height: 14,
                            color: Colors.grey[300],
                          ),
                        ],
                      ),
                    )),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMetricsCard(double totalValue, int totalOrders) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Valor Total do Dia",
                  style: GoogleFonts.poppins(fontSize: 16, color: Colors.black87),
                ),
                const SizedBox(height: 6),
                Text(
                  "R\$ ${totalValue.toStringAsFixed(2)}",
                  style: GoogleFonts.poppins(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ],
            ),
            Chip(
              label: Text(
                "$totalOrders Pedidos",
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 16),
              ),
              backgroundColor: primaryColor,
              elevation: 2,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPedidosPorSlotCard(Map<String, int> slots) {
    final maxY = slots.values.isNotEmpty
        ? (slots.values.reduce((a, b) => a > b ? a : b) + 2.0).toDouble()
        : 10.0;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Pedidos por Slot",
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxY,
                  barTouchData: BarTouchData(enabled: true),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < slots.length) {
                            return SideTitleWidget(
                              axisSide: meta.axisSide,
                              space: 8.0,
                              child: Text(
                                slots.keys.elementAt(index),
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.black87,
                                ),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: true),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  gridData: FlGridData(show: true, drawHorizontalLine: true),
                  borderData: FlBorderData(show: false),
                  barGroups: slots.entries.toList().asMap().entries.map(
                    (entry) {
                      final index = entry.key;
                      final slot = entry.value;
                      return BarChartGroupData(
                        x: index,
                        barRods: [
                          BarChartRodData(
                            toY: slot.value.toDouble(),
                            color: primaryColor,
                            width: 20,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ],
                      );
                    },
                  ).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(Map<String, int> statusCount, int totalOrders) {
    final Map<String, Color> statusColors = {
      "Saiu pra Entrega": Colors.yellow.shade700,
      "Registrado": Colors.blue.shade300,
      "Concluído": Colors.green,
      "Cancelado": Colors.grey.shade700,
    };

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Pedidos",
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 1,
                  centerSpaceRadius: 50,
                  pieTouchData: PieTouchData(enabled: true),
                  sections: statusCount.entries.map((entry) {
                    final status = entry.key;
                    final count = entry.value;
                    return PieChartSectionData(
                      value: count.toDouble(),
                      title: "$count",
                      radius: 65,
                      titlePositionPercentageOffset: 0.55,
                      titleStyle: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      color: statusColors[status] ?? Colors.grey,
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 30),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: statusCount.entries.map((entry) {
                final status = entry.key;
                final count = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: statusColors[status],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "$status ($count)",
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

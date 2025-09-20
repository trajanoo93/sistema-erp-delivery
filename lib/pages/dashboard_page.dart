import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/api_service.dart'; // Importando o ApiService

class DashboardPage extends StatefulWidget {
  const DashboardPage({Key? key}) : super(key: key);

  @override
  _DashboardPageState createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final Color primaryColor = const Color(0xFFF28C38);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: FutureBuilder<List<dynamic>>(
            future: ApiService.fetchPedidos(), // Carrega os pedidos da API
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF28C38)),
                    strokeWidth: 4.0,
                  ),
                );
              } else if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Erro ao carregar pedidos: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red, fontSize: 16),
                  ),
                );
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(
                  child: Text(
                    'Nenhum pedido encontrado.',
                    style: TextStyle(fontSize: 16),
                  ),
                );
              }

              final pedidos = snapshot.data!;

              // Calcula o valor total (desconsiderando cancelados)
              double totalValue = pedidos
                  .where((p) => p["status"] != "Cancelado")
                  .fold(0.0, (sum, p) {
                final subTotal = p["subTotal"];
                if (subTotal is num) {
                  return sum + subTotal.toDouble();
                }
                return sum;
              });

              // Total de pedidos não-cancelados
              int totalOrders =
                  pedidos.where((p) => p["status"] != "Cancelado").length;

              // Distribuição por Slot
              Map<String, int> slots = {
                "09:00 - 12:00": 0,
                "12:00 - 15:00": 0,
                "15:00 - 18:00": 0,
                "18:00 - 21:00": 0,
              };
              for (var p in pedidos) {
                final horarioAgendamento = p["horario_agendamento"];
                if (horarioAgendamento is String &&
                    slots.containsKey(horarioAgendamento)) {
                  slots[horarioAgendamento] =
                      (slots[horarioAgendamento] ?? 0) + 1;
                }
              }

              // Contagem de Status
              Map<String, int> statusCount = {
                "Saiu pra Entrega": 0,
                "Registrado": 0,
                "Concluído": 0,
                "Cancelado": 0,
              };
              for (var p in pedidos) {
                final status = p["status"];
                if (status is String && statusCount.containsKey(status)) {
                  statusCount[status] = (statusCount[status] ?? 0) + 1;
                }
              }

              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMetricsCard(totalValue, totalOrders),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 20,
                      runSpacing: 20,
                      children: [
                        _buildStatusCard(statusCount, totalOrders), // Pizza à esquerda
                        _buildPedidosPorSlotCard(slots), // Barras à direita
                      ],
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

  /// Card que mostra o Valor Total e o total de Pedidos
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
            // Texto Valor Total
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Valor Total do Dia",
                  style: TextStyle(fontSize: 16, color: Colors.black87),
                ),
                const SizedBox(height: 6),
                Text(
                  "R\$ ${totalValue.toStringAsFixed(2)}",
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ],
            ),
            // Chip com número de pedidos
            Chip(
              label: Text(
                "$totalOrders Pedidos",
                style: const TextStyle(color: Colors.white, fontSize: 16),
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

  /// Card que mostra o gráfico de Barras dos Pedidos por Slot
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
            const Text(
              "Pedidos por Slot",
              style: TextStyle(
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
                                style: const TextStyle(
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

  /// Card que mostra o gráfico de Pizza dos Status + legenda
  Widget _buildStatusCard(Map<String, int> statusCount, int totalOrders) {
    // Cores para cada status
    final Map<String, Color> statusColors = {
      "Saiu pra Entrega": primaryColor,
      "Registrado": Colors.blue[300]!,
      "Concluído": Colors.green,
      "Cancelado": Colors.grey[700]!,
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
            const Text(
              "Pedidos",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),

            // Donut Chart
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
                      titleStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      color: statusColors[status],
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 30), // Aumentado de 20 para 30 para mais espaçamento

            // Legenda em coluna
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
                        style: const TextStyle(
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
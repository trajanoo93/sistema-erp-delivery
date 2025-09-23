import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../utils/log_utils.dart';

class SchedulingSection extends StatefulWidget {
  final String shippingMethod;
  final String storeFinal;
  final Function(String, String) onDateTimeUpdated;
  final Function() onSchedulingChanged;
  final DateTime? initialDate;
  final String? initialTimeSlot;

  const SchedulingSection({
    Key? key,
    required this.shippingMethod,
    required this.storeFinal,
    required this.onDateTimeUpdated,
    required this.onSchedulingChanged,
    this.initialDate,
    this.initialTimeSlot,
  }) : super(key: key);

  @override
  State<SchedulingSection> createState() => _SchedulingSectionState();
}

class _SchedulingSectionState extends State<SchedulingSection> {
  DateTime? _selectedDate;
  String? _selectedTimeSlot;
  List<String> _availableTimeSlots = [];

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate ?? DateTime.now();
    _updateTimeSlots();
    _selectedTimeSlot = widget.initialTimeSlot != null && _availableTimeSlots.contains(widget.initialTimeSlot)
        ? widget.initialTimeSlot
        : _availableTimeSlots.isNotEmpty
            ? _availableTimeSlots.first
            : null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _updateParent();
      }
    });
  }

  @override
  void didUpdateWidget(SchedulingSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shippingMethod != oldWidget.shippingMethod ||
        widget.storeFinal != oldWidget.storeFinal ||
        widget.initialDate != oldWidget.initialDate ||
        widget.initialTimeSlot != oldWidget.initialTimeSlot) {
      setState(() {
        _selectedDate = widget.initialDate ?? DateTime.now();
        _updateTimeSlots();
        _selectedTimeSlot = widget.initialTimeSlot != null && _availableTimeSlots.contains(widget.initialTimeSlot)
            ? widget.initialTimeSlot
            : _availableTimeSlots.isNotEmpty
                ? _availableTimeSlots.first
                : null;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _updateParent();
        }
      });
    }
  }

  void _updateTimeSlots() {
    final now = DateTime.now();
    final isToday = _selectedDate != null && _selectedDate!.year == now.year && _selectedDate!.month == now.month && _selectedDate!.day == now.day;
    final isSunday = _selectedDate?.weekday == DateTime.sunday;
    final currentHour = now.hour + (now.minute / 60.0);
    final isPhysicalStore = widget.storeFinal == 'Unidade Sion' || widget.storeFinal == 'Unidade Barreiro';

    setState(() {
      if (isSunday) {
        if (widget.shippingMethod == 'pickup') {
          _availableTimeSlots = ['09:00 - 12:00'];
        } else if (isPhysicalStore) {
          // Lojas físicas em domingos: apenas até 15:00
          _availableTimeSlots = ['09:00 - 12:00', '12:00 - 15:00'];
        } else {
          // Central Distribuição em domingos
          _availableTimeSlots = ['09:00 - 12:00', '12:00 - 15:00', '15:00 - 18:00'];
        }
      } else {
        if (widget.shippingMethod == 'pickup') {
          _availableTimeSlots = ['09:00 - 12:00', '12:00 - 15:00', '15:00 - 18:00'];
        } else {
          _availableTimeSlots = [
            '09:00 - 12:00',
            '12:00 - 15:00',
            '15:00 - 18:00',
            '18:00 - 21:00',
          ];
        }
      }
      // Filtrar slots passados, incluindo o slot atual
      if (isToday) {
        _availableTimeSlots = _availableTimeSlots.where((slot) {
          final parts = slot.split('-').map((s) => s.trim()).toList();
          final startHour = double.parse(parts[0].split(':')[0]) + (double.parse(parts[0].split(':')[1]) / 60.0);
          final endHour = double.parse(parts[1].split(':')[0]) + (double.parse(parts[1].split(':')[1]) / 60.0);
          return currentHour <= endHour;
        }).toList();
      }
      // Garantir que haja pelo menos um slot
      if (_availableTimeSlots.isEmpty && isToday) {
        _availableTimeSlots = ['18:00 - 21:00']; // Slot padrão para o final do dia
      }
      if (_selectedTimeSlot == null || !_availableTimeSlots.contains(_selectedTimeSlot)) {
        _selectedTimeSlot = _availableTimeSlots.isNotEmpty ? _availableTimeSlots.first : null;
      }
    });
    logToFile('Available time slots: $_availableTimeSlots, isToday: $isToday, currentHour: $currentHour, isSunday: $isSunday, isPhysicalStore: $isPhysicalStore');
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      locale: const Locale('pt', 'BR'),
      builder: (context, child) {
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme(
              brightness: isDarkMode ? Brightness.dark : Brightness.light,
              primary: const Color(0xFFF28C38),
              onPrimary: Colors.white,
              secondary: const Color(0xFFFFCC80),
              onSecondary: Colors.black87,
              surface: isDarkMode ? Colors.grey[800]! : Colors.white,
              onSurface: isDarkMode ? Colors.white70 : Colors.black87,
              background: isDarkMode ? Colors.grey[900]! : Colors.white,
              onBackground: isDarkMode ? Colors.white70 : Colors.black87,
              error: Colors.red.shade700,
              onError: Colors.white,
            ),
            dialogBackgroundColor: isDarkMode ? Colors.grey[800] : Colors.white,
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFF28C38),
                textStyle: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              child!,
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancelar'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(_selectedDate),
                      child: const Text('Confirmar'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );

    if (picked != null && picked != _selectedDate && mounted) {
      setState(() {
        _selectedDate = picked;
        _updateTimeSlots();
      });
      _updateParent();
      await logToFile('Data selecionada: ${DateFormat('dd/MM/yyyy').format(picked)}');
    }
  }

  void _updateParent() {
    if (mounted && _selectedDate != null && _selectedTimeSlot != null) {
      String formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate!);
      widget.onDateTimeUpdated(formattedDate, _selectedTimeSlot!);
      widget.onSchedulingChanged();
      logToFile('Parent atualizado: date=$formattedDate, time=$_selectedTimeSlot');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFFF28C38);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => _selectDate(context),
                child: AbsorbPointer(
                  child: TextFormField(
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: widget.shippingMethod == 'delivery' ? 'Data de Entrega' : 'Data de Retirada',
                      labelStyle: GoogleFonts.poppins(
                        color: isDarkMode ? Colors.white70 : Colors.black54,
                        fontWeight: FontWeight.w500,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: primaryColor.withOpacity(0.3)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: primaryColor.withOpacity(0.3)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: primaryColor, width: 2),
                      ),
                      prefixIcon: Icon(Icons.calendar_today, color: primaryColor),
                      filled: true,
                      fillColor: isDarkMode ? Colors.grey[800] : Colors.white,
                    ),
                    controller: TextEditingController(
                      text: _selectedDate != null
                          ? DateFormat('dd/MM/yyyy').format(_selectedDate!)
                          : 'Selecione a data',
                    ),
                    validator: null,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        DropdownButtonFormField<String>(
          value: _selectedTimeSlot,
          decoration: InputDecoration(
            labelText: widget.shippingMethod == 'delivery' ? 'Horário de Entrega' : 'Horário de Retirada',
            labelStyle: GoogleFonts.poppins(
              color: isDarkMode ? Colors.white70 : Colors.black54,
              fontWeight: FontWeight.w500,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: primaryColor.withOpacity(0.3)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: primaryColor.withOpacity(0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: primaryColor, width: 2),
            ),
            prefixIcon: Icon(Icons.access_time, color: primaryColor),
            filled: true,
            fillColor: isDarkMode ? Colors.grey[800] : Colors.white,
          ),
          items: _availableTimeSlots.map((slot) {
            return DropdownMenuItem<String>(
              value: slot,
              child: Text(
                slot,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (mounted && value != null) {
              setState(() {
                _selectedTimeSlot = value;
              });
              _updateParent();
              logToFile('Horário selecionado: $value');
            }
          },
          validator: (value) => value == null ? 'Selecione um horário' : null,
        ),
      ],
    );
  }
}
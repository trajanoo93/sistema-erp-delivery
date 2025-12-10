// lib/widgets/scheduling_section.dart

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
    super.key,
    required this.shippingMethod,
    required this.storeFinal,
    required this.onDateTimeUpdated,
    required this.onSchedulingChanged,
    this.initialDate,
    this.initialTimeSlot,
  });

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
    // 🐛 FIX: Garantir que data inicial seja HOJE ou no futuro
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    if (widget.initialDate != null) {
      final initialDateNormalized = DateTime(
        widget.initialDate!.year,
        widget.initialDate!.month,
        widget.initialDate!.day,
      );
      // Se initialDate é no passado, usa hoje
      _selectedDate = initialDateNormalized.isBefore(today) ? today : initialDateNormalized;
    } else {
      _selectedDate = today;
    }
    
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
        // 🐛 FIX: Garantir que data seja HOJE ou no futuro
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        
        if (widget.initialDate != null) {
          final initialDateNormalized = DateTime(
            widget.initialDate!.year,
            widget.initialDate!.month,
            widget.initialDate!.day,
          );
          _selectedDate = initialDateNormalized.isBefore(today) ? today : initialDateNormalized;
        } else {
          _selectedDate = today;
        }
        
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
    final isToday = _selectedDate != null && 
                    _selectedDate!.year == now.year && 
                    _selectedDate!.month == now.month && 
                    _selectedDate!.day == now.day;
    final isSunday = _selectedDate?.weekday == DateTime.sunday;
    final currentHour = now.hour + (now.minute / 60.0);
    final isPhysicalStore = widget.storeFinal == 'Unidade Sion' || widget.storeFinal == 'Unidade Barreiro';

    setState(() {
      if (isSunday) {
        if (widget.shippingMethod == 'pickup') {
          _availableTimeSlots = ['09:00 - 12:00'];
        } else if (isPhysicalStore) {
          _availableTimeSlots = ['09:00 - 12:00', '12:00 - 15:00'];
        } else {
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
      
      // Filtrar slots passados apenas se for HOJE
      if (isToday) {
        _availableTimeSlots = _availableTimeSlots.where((slot) {
          final parts = slot.split('-').map((s) => s.trim()).toList();
          final endHour = double.parse(parts[1].split(':')[0]) + (double.parse(parts[1].split(':')[1]) / 60.0);
          return currentHour < endHour; // Mudado de <= para < para ser mais restritivo
        }).toList();
      }
      
      // Garantir pelo menos um slot
      if (_availableTimeSlots.isEmpty && isToday) {
        _availableTimeSlots = ['18:00 - 21:00'];
      }
      
      // Atualizar slot selecionado se necessário
      if (_selectedTimeSlot == null || !_availableTimeSlots.contains(_selectedTimeSlot)) {
        _selectedTimeSlot = _availableTimeSlots.isNotEmpty ? _availableTimeSlots.first : null;
      }
    });
    logToFile('Available time slots: $_availableTimeSlots, isToday: $isToday, currentHour: $currentHour, isSunday: $isSunday, isPhysicalStore: $isPhysicalStore');
  }

  Future<void> _selectDate(BuildContext context) async {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFFF28C38);
    
    // 🐛 FIX: Garantir que initialDate seja válido
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final safeInitialDate = (_selectedDate != null && !_selectedDate!.isBefore(today))
        ? _selectedDate!
        : today;
    
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: safeInitialDate, // 🐛 FIX: Usa data validada
      firstDate: today, // 🐛 FIX: Sempre a partir de hoje
      lastDate: today.add(const Duration(days: 30)),
      locale: const Locale('pt', 'BR'),
      cancelText: 'Cancelar',
      confirmText: 'Confirmar',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme(
              brightness: isDarkMode ? Brightness.dark : Brightness.light,
              primary: primaryColor,
              onPrimary: Colors.white,
              secondary: const Color(0xFFFFCC80),
              onSecondary: Colors.black87,
              surface: isDarkMode ? Colors.grey[800]! : Colors.white,
              onSurface: isDarkMode ? Colors.white70 : Colors.black87,
              error: Colors.red.shade700,
              onError: Colors.white,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: primaryColor,
                textStyle: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
            dialogTheme: DialogThemeData(
              backgroundColor: isDarkMode ? Colors.grey[800] : Colors.white,
            ),
          ),
          child: child!,
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
        // 🎨 Campo de data
        GestureDetector(
          onTap: () => _selectDate(context),
          child: AbsorbPointer(
            child: TextFormField(
              readOnly: true,
              decoration: InputDecoration(
                labelText: widget.shippingMethod == 'delivery' ? 'Data de Entrega' : 'Data de Retirada',
                labelStyle: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDarkMode ? Colors.white70 : Colors.black54,
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
                prefixIcon: Icon(Icons.calendar_today, color: primaryColor, size: 20),
                filled: true,
                fillColor: isDarkMode ? Colors.grey[800] : Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              controller: TextEditingController(
                text: _selectedDate != null
                    ? DateFormat('dd/MM/yyyy').format(_selectedDate!)
                    : 'Selecione a data',
              ),
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // 🎨 Campo de horário
        DropdownButtonFormField<String>(
          value: _selectedTimeSlot,
          decoration: InputDecoration(
            labelText: widget.shippingMethod == 'delivery' ? 'Horário de Entrega' : 'Horário de Retirada',
            labelStyle: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isDarkMode ? Colors.white70 : Colors.black54,
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
            prefixIcon: Icon(Icons.access_time, color: primaryColor, size: 20),
            filled: true,
            fillColor: isDarkMode ? Colors.grey[800] : Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
          dropdownColor: isDarkMode ? Colors.grey[800] : Colors.white,
        ),
      ],
    );
  }
}
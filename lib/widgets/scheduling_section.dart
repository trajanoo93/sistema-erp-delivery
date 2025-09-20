import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class SchedulingSection extends StatefulWidget {
  final String shippingMethod; // "delivery" ou "pickup"
  final Function(String, String) onDateTimeUpdated; // Callback para atualizar data e hora
  final DateTime? initialDate; // Data inicial a partir do PedidoState
  final String? initialTimeSlot; // Slot de horário inicial a partir do PedidoState

  const SchedulingSection({
    Key? key,
    required this.shippingMethod,
    required this.onDateTimeUpdated,
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
    _initializeFields();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _updateTimeSlots(_selectedDate);
        _updateParent();
      }
    });
  }

  void _initializeFields() {
    _selectedDate = widget.initialDate;
    _selectedTimeSlot = widget.initialTimeSlot;
  }

  @override
  void didUpdateWidget(SchedulingSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shippingMethod != oldWidget.shippingMethod ||
        widget.initialDate != oldWidget.initialDate ||
        widget.initialTimeSlot != oldWidget.initialTimeSlot) {
      _initializeFields();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _updateTimeSlots(_selectedDate);
          _updateParent();
        }
      });
    }
  }

  void _updateTimeSlots(DateTime? date) {
  if (date == null) {
    setState(() {
      _availableTimeSlots = [];
      _selectedTimeSlot = null;
    });
    _updateParent();
    return;
  }

  final now = DateTime.now();
  final isToday = date.day == now.day && date.month == now.month && date.year == now.year;
  final currentHour = now.hour;
  final currentMinute = now.minute;
  final currentTimeInMinutes = currentHour * 60 + currentMinute;

  List<String> slots = [];
  bool isSunday = date.weekday == DateTime.sunday;

  if (widget.shippingMethod == 'delivery') {
    if (isSunday) {
      slots = ['09:00 - 12:00', '12:00 - 15:00', '15:00 - 18:00'];
    } else {
      slots = ['09:00 - 12:00', '12:00 - 15:00', '15:00 - 18:00', '18:00 - 21:00'];
    }
  } else {
    // pickup
    if (isSunday) {
      slots = ['09:00 - 12:00'];
    } else {
      slots = ['09:00 - 12:00', '12:00 - 15:00', '15:00 - 18:00'];
    }
  }

  if (isToday) {
    slots = slots.where((slot) {
      final endTime = int.parse(slot.split(' - ')[1].split(':')[0]);
      final endTimeInMinutes = endTime * 60;
      return endTimeInMinutes > currentTimeInMinutes;
    }).toList();
  }

  setState(() {
    _availableTimeSlots = slots;
    // Garantir que _selectedTimeSlot seja definido se houver slots disponíveis
    if (_availableTimeSlots.isNotEmpty) {
      if (_selectedTimeSlot == null || !_availableTimeSlots.contains(_selectedTimeSlot)) {
        _selectedTimeSlot = _availableTimeSlots.first; // Selecionar o primeiro slot disponível
      }
    } else {
      _selectedTimeSlot = null; // Nenhum slot disponível
    }
  });
  _updateParent();
}

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) {
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: ThemeData(
            brightness: isDarkMode ? Brightness.dark : Brightness.light,
            colorScheme: ColorScheme(
              brightness: isDarkMode ? Brightness.dark : Brightness.light,
              primary: Colors.orange.shade600,
              onPrimary: Colors.white,
              secondary: Colors.orange.shade200,
              onSecondary: Colors.black87,
              surface: isDarkMode ? Colors.grey[800]! : Colors.white,
              onSurface: isDarkMode ? Colors.white70 : Colors.black87,
              background: isDarkMode ? Colors.grey[900]! : Colors.white,
              onBackground: isDarkMode ? Colors.white70 : Colors.black87,
              error: Colors.red.shade700,
              onError: Colors.white,
            ),
            dialogBackgroundColor: isDarkMode ? Colors.grey[800] : Colors.white,
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate && mounted) {
      setState(() {
        _selectedDate = picked;
      });
      _updateTimeSlots(picked);
      _updateParent();
    }
  }

  void _updateParent() {
  if (mounted && _selectedDate != null && _selectedTimeSlot != null) {
    String formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate!);
    widget.onDateTimeUpdated(formattedDate, _selectedTimeSlot!);
  }
}

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
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
                    borderSide: BorderSide(
                      color: Colors.orange.shade200,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.orange.shade200,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.orange.shade600,
                      width: 2,
                    ),
                  ),
                  prefixIcon: Icon(
                    Icons.calendar_today,
                    color: Colors.orange.shade600,
                  ),
                  filled: true,
                  fillColor: isDarkMode ? Colors.grey[800] : Colors.white,
                ),
                onTap: () => _selectDate(context),
                controller: TextEditingController(
                  text: _selectedDate != null
                      ? DateFormat('dd/MM/yyyy').format(_selectedDate!)
                      : 'Selecione a data',
                ),
                validator: null, // Validações movidas para _createOrder
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (_availableTimeSlots.isNotEmpty)
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
                borderSide: BorderSide(
                  color: Colors.orange.shade200,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Colors.orange.shade200,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Colors.orange.shade600,
                  width: 2,
                ),
              ),
              prefixIcon: Icon(
                Icons.access_time,
                color: Colors.orange.shade600,
              ),
              filled: true,
              fillColor: isDarkMode ? Colors.grey[800] : Colors.white,
            ),
            items: _availableTimeSlots.map((slot) {
              return DropdownMenuItem<String>(
                value: slot,
                child: Text(slot),
              );
            }).toList(),
            onChanged: (value) {
              if (mounted && value != null) {
                setState(() {
                  _selectedTimeSlot = value;
                });
                _updateParent();
              }
            },
            validator: null, // Validações movidas para _createOrder
          ),
      ],
    );
  }
}
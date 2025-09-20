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
    // Inicializar com a data fornecida ou a data atual apenas na primeira vez
    _selectedDate = widget.initialDate ?? DateTime.now();
    _selectedTimeSlot = widget.initialTimeSlot;
    print('SchedulingSection initState: initialDate=${widget.initialDate}, _selectedDate=$_selectedDate, initialTimeSlot=${widget.initialTimeSlot}');
    _updateTimeSlots(_selectedDate!);
  }

  @override
  void didUpdateWidget(SchedulingSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Atualizar apenas se o shippingMethod ou initialTimeSlot mudar
    if (widget.shippingMethod != oldWidget.shippingMethod || widget.initialTimeSlot != oldWidget.initialTimeSlot) {
      setState(() {
        _selectedTimeSlot = widget.initialTimeSlot ?? _selectedTimeSlot;
        _updateTimeSlots(_selectedDate!); // Manter _selectedDate estável
      });
      print('didUpdateWidget: shippingMethod=${widget.shippingMethod}, initialTimeSlot=${widget.initialTimeSlot}, keeping _selectedDate=$_selectedDate');
    }
    // Se initialDate mudar, apenas atualize se _selectedDate ainda não foi definida pelo usuário
    if (widget.initialDate != oldWidget.initialDate && _selectedDate == null) {
      setState(() {
        _selectedDate = widget.initialDate ?? DateTime.now();
        _updateTimeSlots(_selectedDate!);
      });
      print('didUpdateWidget: updated _selectedDate to ${widget.initialDate}');
    }
  }

  void _updateTimeSlots(DateTime date) {
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
    } else { // pickup
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
      // Garantir que _selectedTimeSlot seja válido para a nova lista
      if (_selectedTimeSlot != null && !_availableTimeSlots.contains(_selectedTimeSlot)) {
        _selectedTimeSlot = _availableTimeSlots.isNotEmpty ? _availableTimeSlots.first : null;
      } else if (_availableTimeSlots.isNotEmpty && _selectedTimeSlot == null) {
        _selectedTimeSlot = _availableTimeSlots.first;
      }
      print('updateTimeSlots: date=$date, availableTimeSlots=$_availableTimeSlots, selectedTimeSlot=$_selectedTimeSlot');
      _updateParent();
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.orange.shade600,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black87,
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate && mounted) {
      setState(() {
        _selectedDate = picked;
      });
      print('selectDate: new date=$picked');
      _updateTimeSlots(picked);
    }
  }

  void _updateParent() {
    if (_selectedDate != null && _selectedTimeSlot != null && mounted) {
      String formattedDate;
      if (widget.shippingMethod == 'delivery') {
        formattedDate = DateFormat('MMMM d, yyyy', 'en_US').format(_selectedDate!);
      } else {
        formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate!);
      }
      print('Updating parent with date: $formattedDate, time: $_selectedTimeSlot');
      widget.onDateTimeUpdated(formattedDate, _selectedTimeSlot!);
    } else if (mounted) {
      print('Clearing parent date and time');
      widget.onDateTimeUpdated('', '');
    }
  }

  @override
  Widget build(BuildContext context) {
    print('Building SchedulingSection: _selectedDate=$_selectedDate, _selectedTimeSlot=$_selectedTimeSlot');
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
                    color: Colors.black54,
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
                  fillColor: Colors.white,
                ),
                onTap: () => _selectDate(context),
                controller: TextEditingController(
                  text: _selectedDate != null
                      ? DateFormat('dd/MM/yyyy').format(_selectedDate!)
                      : 'Selecione a data',
                ),
                validator: (value) {
                  if (_selectedDate == null) {
                    return 'Por favor, selecione a data';
                  }
                  return null;
                },
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
                color: Colors.black54,
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
              fillColor: Colors.white,
            ),
            items: _availableTimeSlots.map((slot) {
              return DropdownMenuItem<String>(
                value: slot,
                child: Text(slot),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null && mounted) {
                setState(() {
                  _selectedTimeSlot = value;
                  print('Time slot changed to: $_selectedTimeSlot, keeping date: $_selectedDate');
                });
                _updateParent();
              }
            },
            validator: (value) {
              if (value == null && _availableTimeSlots.isNotEmpty) {
                return 'Por favor, selecione o horário';
              }
              return null;
            },
          ),
        if (_availableTimeSlots.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Text(
              'Nenhum horário disponível para a data selecionada.',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.red.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }
}
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;

class DateTimeStep extends StatefulWidget {
  final String title;
  final bool isDatePicker;
  final Function(DateTime)? onDateSelected;
  final Function(TimeOfDay)? onTimeSelected;

  const DateTimeStep({
    super.key,
    required this.title,
    required this.isDatePicker,
    this.onDateSelected,
    this.onTimeSelected,
  });

  @override
  State<DateTimeStep> createState() => _DateTimeStepState();
}

class _DateTimeStepState extends State<DateTimeStep> {
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();

  @override
  Widget build(BuildContext context) {
    if (widget.isDatePicker) {
      return _buildDatePicker();
    } else {
      return _buildTimePicker();
    }
  }

  Widget _buildDatePicker() {
    return Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            widget.title,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          SizedBox(height: 32),

          // Calendar
          Expanded(child: SingleChildScrollView(child: _buildCalendar())),
        ],
      ),
    );
  }

  Widget _buildCalendar() {
    final now = DateTime.now();
    final currentMonth = DateTime(_selectedDate.year, _selectedDate.month);
    final nextMonth = DateTime(_selectedDate.year, _selectedDate.month + 1);

    return Column(
      children: [
        _buildMonthCalendar(currentMonth, now),
        SizedBox(height: 32),
        _buildMonthCalendar(nextMonth, now),
      ],
    );
  }

  Widget _buildMonthCalendar(DateTime month, DateTime now) {
    final monthName = DateFormat('MMMM').format(month);
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);
    final startWeekday = firstDay.weekday;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          monthName,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF8B4513),
          ),
        ),
        SizedBox(height: 16),

        // Weekday headers
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
              .map(
                (day) => SizedBox(
                  width: 40,
                  child: Text(
                    day,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        SizedBox(height: 8),

        // Days
        ...List.generate(6, (weekIndex) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(7, (dayIndex) {
              final dayNumber =
                  weekIndex * 7 + dayIndex + 1 - (startWeekday - 1);

              if (dayNumber < 1 || dayNumber > lastDay.day) {
                return SizedBox(width: 40, height: 40);
              }

              final date = DateTime(month.year, month.month, dayNumber);
              final isSelected =
                  date.year == _selectedDate.year &&
                  date.month == _selectedDate.month &&
                  date.day == _selectedDate.day;
              final isPast = date.isBefore(
                DateTime(now.year, now.month, now.day),
              );

              return InkWell(
                onTap: isPast
                    ? null
                    : () {
                        setState(() => _selectedDate = date);
                        widget.onDateSelected?.call(date);
                      },
                child: Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected ? Color(0xFFFF4500) : Colors.transparent,
                    shape: BoxShape.circle,
                    border: isSelected
                        ? null
                        : Border.all(
                            color:
                                date.day == now.day &&
                                    date.month == now.month &&
                                    date.year == now.year
                                ? Color(0xFFFF4500)
                                : Colors.transparent,
                            width: 2,
                          ),
                  ),
                  child: Text(
                    '$dayNumber',
                    style: TextStyle(
                      fontSize: 14,
                      color: isSelected
                          ? Colors.white
                          : isPast
                          ? Colors.grey[300]
                          : Colors.black,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }),
          );
        }),
      ],
    );
  }

  Widget _buildTimePicker() {
    return Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            widget.title,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          SizedBox(height: 48),

          // Time Display
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Hour
                GestureDetector(
                  onTap: () => _selectHour(),
                  child: Container(
                    width: 80,
                    height: 80,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!, width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _selectedTime.hour.toString().padLeft(2, '0'),
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFF4500),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    ':',
                    style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
                  ),
                ),
                // Minute
                GestureDetector(
                  onTap: () => _selectMinute(),
                  child: Container(
                    width: 80,
                    height: 80,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!, width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _selectedTime.minute.toString().padLeft(2, '0'),
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.normal,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 16),
                // AM/PM Toggle
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (_selectedTime.period == DayPeriod.pm) {
                          setState(() {
                            _selectedTime = TimeOfDay(
                              hour: _selectedTime.hour - 12,
                              minute: _selectedTime.minute,
                            );
                          });
                        }
                      },
                      child: Container(
                        width: 50,
                        padding: EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _selectedTime.period == DayPeriod.am
                              ? Color(0xFFFF4500)
                              : Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'AM',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _selectedTime.period == DayPeriod.am
                                ? Colors.white
                                : Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 8),
                    GestureDetector(
                      onTap: () {
                        if (_selectedTime.period == DayPeriod.am) {
                          setState(() {
                            _selectedTime = TimeOfDay(
                              hour: _selectedTime.hour + 12,
                              minute: _selectedTime.minute,
                            );
                          });
                        }
                      },
                      child: Container(
                        width: 50,
                        padding: EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _selectedTime.period == DayPeriod.pm
                              ? Color(0xFFFF4500)
                              : Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'PM',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _selectedTime.period == DayPeriod.pm
                                ? Colors.white
                                : Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 48),

          // Clock Face
          Expanded(child: Center(child: _buildClockFace())),

          // Next Button
          SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FloatingActionButton(
              onPressed: () => widget.onTimeSelected?.call(_selectedTime),
              backgroundColor: Color(0xFFFF4500),
              child: Icon(Icons.arrow_forward, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClockFace() {
    return CustomPaint(
      size: Size(250, 250),
      painter: ClockPainter(
        hour: _selectedTime.hour % 12,
        minute: _selectedTime.minute,
      ),
    );
  }

  void _selectHour() async {
    final hour = await showDialog<int>(
      context: context,
      builder: (context) => _NumberPickerDialog(
        title: 'Select Hour',
        min: 1,
        max: 12,
        initial: _selectedTime.hourOfPeriod,
      ),
    );
    if (hour != null) {
      setState(() {
        _selectedTime = TimeOfDay(
          hour: _selectedTime.period == DayPeriod.am
              ? hour % 12
              : (hour % 12) + 12,
          minute: _selectedTime.minute,
        );
      });
    }
  }

  void _selectMinute() async {
    final minute = await showDialog<int>(
      context: context,
      builder: (context) => _NumberPickerDialog(
        title: 'Select Minute',
        min: 0,
        max: 59,
        initial: _selectedTime.minute,
      ),
    );
    if (minute != null) {
      setState(() {
        _selectedTime = TimeOfDay(hour: _selectedTime.hour, minute: minute);
      });
    }
  }
}

class ClockPainter extends CustomPainter {
  final int hour;
  final int minute;

  ClockPainter({required this.hour, required this.minute});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw clock circle
    final circlePaint = Paint()
      ..color = Colors.grey[200]!
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, circlePaint);

    // Draw hour numbers
    for (int i = 1; i <= 12; i++) {
      final angle = (i - 3) * 30 * math.pi / 180;
      final x = center.dx + radius * 0.7 * math.cos(angle);
      final y = center.dy + radius * 0.7 * math.sin(angle);

      final textPainter = TextPainter(
        text: TextSpan(
          text: '$i',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, y - textPainter.height / 2),
      );
    }

    // Draw hour hand
    final hourAngle = ((hour % 12) - 3) * 30 * math.pi / 180;
    final hourPaint = Paint()
      ..color = Color(0xFFFF4500)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      center,
      Offset(
        center.dx + radius * 0.4 * math.cos(hourAngle),
        center.dy + radius * 0.4 * math.sin(hourAngle),
      ),
      hourPaint,
    );

    // Draw minute hand dot
    final minuteAngle = (minute - 15) * 6 * math.pi / 180;
    final minutePaint = Paint()
      ..color = Color(0xFFFF4500)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(
        center.dx + radius * 0.8 * math.cos(minuteAngle),
        center.dy + radius * 0.8 * math.sin(minuteAngle),
      ),
      12,
      minutePaint,
    );

    // Draw center dot
    final centerPaint = Paint()
      ..color = Color(0xFFFF4500)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 8, centerPaint);
  }

  @override
  bool shouldRepaint(ClockPainter oldDelegate) =>
      hour != oldDelegate.hour || minute != oldDelegate.minute;
}

class _NumberPickerDialog extends StatefulWidget {
  final String title;
  final int min;
  final int max;
  final int initial;

  const _NumberPickerDialog({
    required this.title,
    required this.min,
    required this.max,
    required this.initial,
  });

  @override
  State<_NumberPickerDialog> createState() => _NumberPickerDialogState();
}

class _NumberPickerDialogState extends State<_NumberPickerDialog> {
  late int _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        height: 200,
        width: 200,
        child: ListView.builder(
          itemCount: widget.max - widget.min + 1,
          itemBuilder: (context, index) {
            final number = widget.min + index;
            final isSelected = number == _selected;
            return ListTile(
              title: Text(
                number.toString().padLeft(2, '0'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isSelected ? Color(0xFFFF4500) : Colors.black,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 18,
                ),
              ),
              onTap: () {
                setState(() => _selected = number);
                Navigator.pop(context, number);
              },
            );
          },
        ),
      ),
    );
  }
}

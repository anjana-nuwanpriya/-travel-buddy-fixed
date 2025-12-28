import 'package:flutter/material.dart';
import '../utils/colors.dart';

class SeatSelector extends StatelessWidget {
  final int availableSeats;
  final int selectedSeats;
  final Function(int) onSeatsChanged;

  const SeatSelector({
    super.key,
    required this.availableSeats,
    required this.selectedSeats,
    required this.onSeatsChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(4, (index) {
        final seatNumber = index + 1;
        final isAvailable = seatNumber <= availableSeats;
        final isSelected = seatNumber <= selectedSeats;

        return Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: GestureDetector(
              onTap: isAvailable ? () => onSeatsChanged(seatNumber) : null,
              child: Container(
                height: 60,
                decoration: BoxDecoration(
                  color: !isAvailable
                      ? AppColors.divider
                      : isSelected
                      ? AppColors.primary
                      : Colors.white,
                  border: Border.all(
                    color: !isAvailable
                        ? AppColors.divider
                        : isSelected
                        ? AppColors.primary
                        : AppColors.divider,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.event_seat,
                      color: !isAvailable
                          ? AppColors.textSecondary
                          : isSelected
                          ? Colors.white
                          : AppColors.textSecondary,
                    ),
                    SizedBox(height: 4),
                    Text(
                      '$seatNumber',
                      style: TextStyle(
                        color: !isAvailable
                            ? AppColors.textSecondary
                            : isSelected
                            ? Colors.white
                            : AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

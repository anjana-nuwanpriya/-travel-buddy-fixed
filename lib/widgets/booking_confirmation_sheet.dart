import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../services/payment_service.dart';
import '../services/booking_service.dart';
import '../utils/colors.dart';
import '../models/ride.dart';

class BookingConfirmationSheet extends StatefulWidget {
  final Ride ride;
  final int selectedSeats;
  final double totalAmount;
  final String? pickupAddress;
  final String? dropoffAddress;
  final double? pickupLat;
  final double? pickupLng;
  final double? dropoffLat;
  final double? dropoffLng;

  const BookingConfirmationSheet({
    super.key,
    required this.ride,
    required this.selectedSeats,
    required this.totalAmount,
    this.pickupAddress,
    this.dropoffAddress,
    this.pickupLat,
    this.pickupLng,
    this.dropoffLat,
    this.dropoffLng,
  });

  @override
  _BookingConfirmationSheetState createState() =>
      _BookingConfirmationSheetState();
}

class _BookingConfirmationSheetState extends State<BookingConfirmationSheet> {
  late PaymentService _paymentService;
  late BookingService _bookingService;
  String selectedPaymentMethod = 'razorpay';
  bool isProcessingPayment = false;

  @override
  void initState() {
    super.initState();
    _paymentService = PaymentService();
    _bookingService = BookingService();
  }

  @override
  void dispose() {
    _paymentService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: EdgeInsets.all(20),
            child: Row(
              children: [
                Text(
                  'Confirm Booking',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Payment method selection
                  _buildPaymentMethodSection(),
                  SizedBox(height: 24),

                  // Price breakdown
                  _buildPriceBreakdown(),
                ],
              ),
            ),
          ),

          // Confirm button
          Container(
            padding: EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: isProcessingPayment ? null : _processPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: isProcessingPayment
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text(
                        'Pay LKR${widget.totalAmount.toInt()}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Payment Method',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 12),

        // Payment options
        _buildPaymentOption(
          'razorpay',
          'Credit & Debit Cards',
          'Visa, Mastercard',
          Icons.payment,
        ),
        _buildPaymentOption(
          'cash',
          'Cash Payment',
          'Pay driver directly after ride',
          Icons.money,
        ),
      ],
    );
  }

  Widget _buildPaymentOption(
    String value,
    String title,
    String subtitle,
    IconData icon,
  ) {
    return RadioListTile<String>(
      value: value,
      groupValue: selectedPaymentMethod,
      onChanged: (String? value) =>
          setState(() => selectedPaymentMethod = value!),
      title: Row(
        children: [
          Icon(icon, color: AppColors.primary),
          SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontWeight: FontWeight.w500)),
              Text(
                subtitle,
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
        ],
      ),
      contentPadding: EdgeInsets.zero,
      activeColor: AppColors.primary,
    );
  }

  Widget _buildPriceBreakdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Price Breakdown',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 12),

        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.divider),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Seat price (${widget.selectedSeats}x)'),
                  Text('LKR${widget.totalAmount.toInt()}'),
                ],
              ),
              SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [Text('Platform fee'), Text('LKR0')],
              ),
              Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total Amount',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'LKR${widget.totalAmount.toInt()}',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _processPayment() {
    if (selectedPaymentMethod == 'cash') {
      _confirmBookingWithCash();
    } else {
      _initiateOnlinePayment();
    }
  }

  void _confirmBookingWithCash() {
    setState(() => isProcessingPayment = true);

    // Create the booking
    _createBooking().then((success) {
      if (mounted) {
        setState(() => isProcessingPayment = false);
        
        if (success) {
          Navigator.pop(context, true);
          // ✅ SINGLE notification shown only here
          _showBookingSuccess(
            'Booking confirmed! Pay driver after ride completion.',
          );
        }
      }
    });
  }

  void _initiateOnlinePayment() {
    setState(() => isProcessingPayment = true);

    _paymentService.startPayment(
      amount: widget.totalAmount,
      description: 'Ride booking from ${widget.ride.from} to ${widget.ride.to}',
      contact: '+919876543210', // Get from user profile
      email: 'user@example.com', // Get from user profile
      onSuccess: (PaymentSuccessResponse response) async {
        // Payment successful - create booking
        final success = await _createBooking();
        
        if (mounted) {
          setState(() => isProcessingPayment = false);
          
          if (success) {
            Navigator.pop(context, true);
            // ✅ SINGLE notification shown only here
            _showBookingSuccess('Payment successful! Booking confirmed.');
          }
        }
      },
      onError: (PaymentFailureResponse response) {
        setState(() => isProcessingPayment = false);
        // ✅ SINGLE notification for error
        _showPaymentError(response.message ?? 'Payment failed');
      },
      onExternalWallet: (ExternalWalletResponse response) async {
        // Payment via wallet successful - create booking
        final success = await _createBooking();
        
        if (mounted) {
          setState(() => isProcessingPayment = false);
          
          if (success) {
            Navigator.pop(context, true);
            // ✅ SINGLE notification shown only here
            _showBookingSuccess('Payment completed via ${response.walletName}');
          }
        }
      },
    );
  }

  /// ✅ Create booking through the service
  /// The service will send notification to driver, don't show duplicate here
  Future<bool> _createBooking() async {
    try {
      final result = await _bookingService.createBooking(
        rideId: widget.ride.id,
        seatsBooked: widget.selectedSeats,
        totalPrice: widget.totalAmount,
        pickupLat: widget.pickupLat ?? widget.ride.fromLat ?? 0.0,
        pickupLng: widget.pickupLng ?? widget.ride.fromLng ?? 0.0,
        pickupAddress: widget.pickupAddress ?? widget.ride.fromLocation,
        dropoffLat: widget.dropoffLat ?? widget.ride.toLat ?? 0.0,
        dropoffLng: widget.dropoffLng ?? widget.ride.toLng ?? 0.0,
        dropoffAddress: widget.dropoffAddress ?? widget.ride.toLocation,
      );

      if (!result['success']) {
        _showPaymentError(result['error'] ?? 'Failed to create booking');
        return false;
      }

      print('✅ Booking created successfully');
      return true;
    } catch (e) {
      print('❌ Error creating booking: $e');
      _showPaymentError('Error creating booking: $e');
      return false;
    }
  }

  /// ✅ Show ONE notification to user (in bottom sheet)
  void _showBookingSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.success ?? Colors.green,
        duration: Duration(seconds: 3),
      ),
    );
  }

  /// ✅ Show ONE notification for errors
  void _showPaymentError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error: $message'),
        backgroundColor: AppColors.error ?? Colors.red,
        duration: Duration(seconds: 3),
      ),
    );
  }
}
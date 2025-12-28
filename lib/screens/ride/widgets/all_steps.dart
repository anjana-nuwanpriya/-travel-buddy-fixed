import 'package:flutter/material.dart';

// Passengers Step
class PassengersStep extends StatefulWidget {
  final String title;
  final int initialCount;
  final Function(int) onCountChanged;
  final VoidCallback onNext;

  const PassengersStep({
    super.key,
    required this.title,
    required this.initialCount,
    required this.onCountChanged,
    required this.onNext,
  });

  @override
  State<PassengersStep> createState() => _PassengersStepState();
}

class _PassengersStepState extends State<PassengersStep> {
  late int _count;

  @override
  void initState() {
    super.initState();
    _count = widget.initialCount;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: _count > 1
                    ? () {
                        setState(() => _count--);
                        widget.onCountChanged(_count);
                      }
                    : null,
                icon: Icon(Icons.remove_circle_outline, size: 48),
                color: Color(0xFFFF4500),
              ),
              SizedBox(width: 48),
              Text(
                '$_count',
                style: TextStyle(fontSize: 64, fontWeight: FontWeight.bold),
              ),
              SizedBox(width: 48),
              IconButton(
                onPressed: _count < 8
                    ? () {
                        setState(() => _count++);
                        widget.onCountChanged(_count);
                      }
                    : null,
                icon: Icon(Icons.add_circle_outline, size: 48),
                color: Color(0xFFFF4500),
              ),
            ],
          ),
          Spacer(),
          Align(
            alignment: Alignment.bottomRight,
            child: FloatingActionButton(
              onPressed: widget.onNext,
              backgroundColor: Color(0xFFFF4500),
              child: Icon(Icons.arrow_forward, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

// Price Step
class PriceStep extends StatefulWidget {
  final String title;
  final double initialPrice;
  final Function(double) onPriceChanged;
  final VoidCallback onNext;

  const PriceStep({
    super.key,
    required this.title,
    required this.initialPrice,
    required this.onPriceChanged,
    required this.onNext,
  });

  @override
  State<PriceStep> createState() => _PriceStepState();
}

class _PriceStepState extends State<PriceStep> {
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initialPrice > 0) {
      _controller.text = widget.initialPrice.toStringAsFixed(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 48),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Rs',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: _controller,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    hintText: '',
                    border: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(
                        color: Color(0xFFFF4500),
                        width: 2,
                      ),
                    ),
                  ),
                  onChanged: (value) {
                    final price = double.tryParse(value) ?? 0.0;
                    widget.onPriceChanged(price);
                  },
                ),
              ),
            ],
          ),
          Spacer(),
          Align(
            alignment: Alignment.bottomRight,
            child: FloatingActionButton(
              onPressed: () {
                if (_controller.text.isNotEmpty &&
                    (double.tryParse(_controller.text) ?? 0) > 0) {
                  widget.onNext();
                }
              },
              backgroundColor: Color(0xFFFF4500),
              child: Icon(Icons.arrow_forward, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

// Instant Approval Step
class InstantApprovalStep extends StatelessWidget {
  final String title;
  final Function(bool) onSelected;

  const InstantApprovalStep({
    super.key,
    required this.title,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 48),
          _buildOption('Yeah, sure', true),
          SizedBox(height: 16),
          _buildOption('No, I\'ll squeeze in 3', false),
        ],
      ),
    );
  }

  Widget _buildOption(String text, bool value) {
    return Builder(
      builder: (context) => ListTile(
        title: Text(
          text,
          style: TextStyle(
            fontSize: 16,
            color: value ? Color(0xFF0066FF) : Colors.grey,
          ),
        ),
        trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        onTap: () => onSelected(value),
      ),
    );
  }
}

// Middle Seat Step
class MiddleSeatStep extends StatelessWidget {
  final String title;
  final Function(bool) onSelected;

  const MiddleSeatStep({
    super.key,
    required this.title,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Illustration
          Center(
            child: Image.asset(
              'assets/middle_seat.png', // Add this image
              height: 200,
              errorBuilder: (context, error, stackTrace) {
                return SizedBox(
                  height: 200,
                  child: Icon(Icons.event_seat, size: 100, color: Colors.grey),
                );
              },
            ),
          ),
          SizedBox(height: 24),
          Text(
            title,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 48),
          _buildOption('Yeah, sure', true),
          SizedBox(height: 16),
          _buildOption('No, I\'ll squeeze in 3', false),
        ],
      ),
    );
  }

  Widget _buildOption(String text, bool value) {
    return Builder(
      builder: (context) => ListTile(
        title: Text(
          text,
          style: TextStyle(
            fontSize: 16,
            color: value ? Color(0xFF0066FF) : Colors.grey,
          ),
        ),
        trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        onTap: () => onSelected(value),
      ),
    );
  }
}

// Preferences Step
class PreferencesStep extends StatefulWidget {
  final String title;
  final bool instantApproval;
  final bool allowsSmoking;
  final bool allowsPets;
  final bool luggageAllowed;
  final Function(bool smoking, bool pets, bool luggage) onChanged;
  final VoidCallback onNext;

  const PreferencesStep({
    super.key,
    required this.title,
    required this.instantApproval,
    required this.allowsSmoking,
    required this.allowsPets,
    required this.luggageAllowed,
    required this.onChanged,
    required this.onNext,
  });

  @override
  State<PreferencesStep> createState() => _PreferencesStepState();
}

class _PreferencesStepState extends State<PreferencesStep> {
  late bool _smoking;
  late bool _pets;
  late bool _luggage;

  @override
  void initState() {
    super.initState();
    _smoking = widget.allowsSmoking;
    _pets = widget.allowsPets;
    _luggage = widget.luggageAllowed;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 48),
          _buildToggle(
            icon: Icons.flash_on,
            label: 'Instant Approval',
            value: widget.instantApproval,
            enabled: false,
          ),
          _buildToggle(
            icon: Icons.smoking_rooms,
            label: 'Smoking Allowed',
            value: _smoking,
            onChanged: (value) {
              setState(() => _smoking = value);
              widget.onChanged(_smoking, _pets, _luggage);
            },
          ),
          _buildToggle(
            icon: Icons.pets,
            label: 'Pets Allowed',
            value: _pets,
            onChanged: (value) {
              setState(() => _pets = value);
              widget.onChanged(_smoking, _pets, _luggage);
            },
          ),
          _buildToggle(
            icon: Icons.luggage,
            label: 'Luggage Allowed',
            value: _luggage,
            onChanged: (value) {
              setState(() => _luggage = value);
              widget.onChanged(_smoking, _pets, _luggage);
            },
          ),
          Spacer(),
          Align(
            alignment: Alignment.bottomRight,
            child: FloatingActionButton(
              onPressed: widget.onNext,
              backgroundColor: Color(0xFFFF4500),
              child: Icon(Icons.arrow_forward, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggle({
    required IconData icon,
    required String label,
    required bool value,
    Function(bool)? onChanged,
    bool enabled = true,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 24),
          SizedBox(width: 16),
          Expanded(child: Text(label, style: TextStyle(fontSize: 16))),
          Row(
            children: [
              Text('Yes', style: TextStyle(fontSize: 14, color: Colors.grey)),
              Radio<bool>(
                value: true,
                groupValue: value,
                onChanged: enabled && onChanged != null
                    ? (val) => onChanged(val!)
                    : null,
                activeColor: Color(0xFFFF4500),
              ),
              SizedBox(width: 16),
              Text('No', style: TextStyle(fontSize: 14, color: Colors.grey)),
              Radio<bool>(
                value: false,
                groupValue: value,
                onChanged: enabled && onChanged != null
                    ? (val) => onChanged(val!)
                    : null,
                activeColor: Color(0xFFFF4500),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Return Trip Step
class ReturnTripStep extends StatelessWidget {
  final String title;
  final Function(bool) onSelected;

  const ReturnTripStep({
    super.key,
    required this.title,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 48),
          _buildOption('Yeah, sure', true),
          SizedBox(height: 16),
          _buildOption('No, thanks', false),
        ],
      ),
    );
  }

  Widget _buildOption(String text, bool value) {
    return Builder(
      builder: (context) => ListTile(
        title: Text(
          text,
          style: TextStyle(
            fontSize: 16,
            color: value ? Color(0xFF0066FF) : Colors.grey,
          ),
        ),
        trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        onTap: () => onSelected(value),
      ),
    );
  }
}

// Notes Step
class NotesStep extends StatefulWidget {
  final String title;
  final Function(String) onNotesChanged;
  final VoidCallback onPublish;
  final bool isLoading;

  const NotesStep({
    super.key,
    required this.title,
    required this.onNotesChanged,
    required this.onPublish,
    required this.isLoading,
  });

  @override
  State<NotesStep> createState() => _NotesStepState();
}

class _NotesStepState extends State<NotesStep> {
  final TextEditingController _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 24),
          TextField(
            controller: _controller,
            maxLines: 6,
            decoration: InputDecoration(
              hintText:
                  'Flexible about where and when to meet?\nNot taking the motorway? Got limited\nSpace in your boot? Keep passengers in\nthe loop',
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Color(0xFFFF4500), width: 2),
              ),
            ),
            onChanged: widget.onNotesChanged,
          ),
          Spacer(),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: widget.isLoading ? null : widget.onPublish,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFFF4500),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: widget.isLoading
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      'Publish ride',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

// Success Screen
class SuccessScreen extends StatelessWidget {
  final String fromLocation;
  final String toLocation;
  final VoidCallback onDone;

  const SuccessScreen({
    super.key,
    required this.fromLocation,
    required this.toLocation,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Color(0xFF4CAF50),
      padding: EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check, size: 60, color: Color(0xFF4CAF50)),
          ),
          SizedBox(height: 32),
          Text(
            'Your ride is online!',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16),
          Text(
            'Passengers can now\nbook and travel with\nyou!',
            style: TextStyle(fontSize: 18, color: Colors.white),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16),
          Text(
            'Go to "My rides" section to view and edit\nyour publication',
            style: TextStyle(fontSize: 14, color: Colors.white70),
            textAlign: TextAlign.center,
          ),
          Spacer(),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: onDone,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Color(0xFF4CAF50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'See my ride',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

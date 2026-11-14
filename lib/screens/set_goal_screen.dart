import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/recycling_goal.dart';
import '../repositories/goal_repository.dart';
import 'package:dino_tracker/service/notification_service.dart';


class SetGoalScreen extends StatefulWidget {
  final String userId;
  final DateTime? initialDate;

  const SetGoalScreen({super.key, required this.userId, this.initialDate});

  @override
  State<SetGoalScreen> createState() => _SetGoalScreenState();
}

class _SetGoalScreenState extends State<SetGoalScreen> {
  final GoalRepository _goalRepository = GoalRepository();

  // Controllers
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _targetAmountController = TextEditingController(text: "1.0");

  // Form key
  final _formKey = GlobalKey<FormState>();

  // Selected values
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(Duration(days: 7));
  String _frequency = 'daily'; // daily, weekly, custom
  double _targetAmount = 1.0;
  String _unit = 'kg';
  List<bool> _selectedDays = List.generate(7, (index) => false); // Initially no days selected

  // NEW: Reminder settings
  bool _reminderEnabled = false;
  TimeOfDay _reminderTime = TimeOfDay(hour: 9, minute: 0); // Default 9:00 AM
  bool _isCreatingGoal = false;

  // Unit options
  final List<String> _unitOptions = ['kg', 'g', 'items', 'times'];

  // Colors
  final Color primaryColor = Color(0xFF5E8C43);
  final Color backgroundColor = Color(0xFFF8F8F8);

  // UI Constants
  final double borderRadius = 12.0;

  @override
  void initState() {
    super.initState();

    // Use the initialDate if provided
    if (widget.initialDate != null) {
      _startDate = widget.initialDate!;
      _endDate = _startDate.add(Duration(days: 7));
    }

    // Set default day selection (Sunday)
    _selectedDays[6] = true;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _targetAmountController.dispose();
    super.dispose();
  }

  // Day names for selected days - using more distinguishable abbreviations
  final List<String> _dayNames = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];

  // Format date for display
  String _formatDate(DateTime date) {
    return DateFormat('MMM d, yyyy').format(date);
  }

  // Get frequency label for display
  String _getFrequencyLabel() {
    switch (_frequency.toLowerCase()) {
      case 'daily':
        return 'day';
      case 'weekly':
        return 'week';
      case 'custom':
        return 'occurrence';
      default:
        return 'occurrence';
    }
  }

  // Calculate maximum possible completions based on frequency and duration
  int _calculateMaxPossibleCompletions() {
    int totalDays = _endDate.difference(_startDate).inDays + 1;

    switch (_frequency.toLowerCase()) {
      case 'daily':
        return totalDays;
      case 'weekly':
        return (totalDays / 7).floor();
      case 'custom':
        int selectedDaysPerWeek = _selectedDays.where((selected) => selected).length;
        if (selectedDaysPerWeek == 0) return 0;
        return ((totalDays / 7) * selectedDaysPerWeek).floor();
      default:
        return 0;
    }
  }

  // Check if current settings meet point earning requirements
  bool _meetsPointRequirements() {
    int durationDays = _endDate.difference(_startDate).inDays + 1;
    int maxCompletions = _calculateMaxPossibleCompletions();

    return durationDays >= 7 && maxCompletions >= 3;
  }

  // Calculate total expected amount based on current settings
  double _calculateTotalExpectedAmount() {
    int totalDays = _endDate.difference(_startDate).inDays + 1;
    double targetAmount = _targetAmount.toDouble();

    switch (_frequency.toLowerCase()) {
      case 'daily':
        return targetAmount * totalDays;
      case 'weekly':
        return targetAmount * (totalDays / 7).ceil();
      case 'custom':
        int selectedDaysPerWeek = _selectedDays.where((selected) => selected).length;
        return targetAmount * ((totalDays / 7) * selectedDaysPerWeek).ceil();
      default:
        return 0.0;
    }
  }

  // NEW: Get reminder frequency text
  String _getReminderFrequencyText() {
    switch (_frequency.toLowerCase()) {
      case 'daily':
        return 'every day at ${_reminderTime.format(context)}';
      case 'weekly':
        return 'once per week at ${_reminderTime.format(context)}';
      case 'custom':
        int selectedDaysCount = _selectedDays.where((day) => day).length;
        if (selectedDaysCount == 1) return 'once per week at ${_reminderTime.format(context)}';
        if (selectedDaysCount == 7) return 'every day at ${_reminderTime.format(context)}';
        return '$selectedDaysCount days per week at ${_reminderTime.format(context)}';
      default:
        return 'at ${_reminderTime.format(context)}';
    }
  }

  // NEW: Handle reminder time picker
  Future<void> _selectReminderTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              backgroundColor: Colors.white,
              hourMinuteShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              dayPeriodBorderSide: BorderSide(color: primaryColor),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _reminderTime) {
      setState(() {
        _reminderTime = picked;
      });
    }
  }

  // NEW: Show permission dialog
  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.notifications_off, color: Colors.orange),
              SizedBox(width: 8),
              Text('Notification Permission'),
            ],
          ),
          content: Text(
            'To receive goal reminders, please enable notification permissions in your device settings.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // You can add code here to open app settings if needed
              },
              style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'New Recycling Goal',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: _isCreatingGoal ? null : _saveGoal,
              child: _isCreatingGoal
                  ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                ),
              )
                  : Text(
                'Create',
                style: TextStyle(
                  color: primaryColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title input with colored background
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(borderRadius),
                ),
                child: TextFormField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    hintText: 'Enter goal title',
                    hintStyle: TextStyle(color: Colors.grey.shade400),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    isDense: true,
                  ),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a title';
                    }
                    return null;
                  },
                ),
              ),

              SizedBox(height: 16),

              // Target amount section with more colorful design
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(borderRadius),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Target Amount ',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                        // Target frequency explanation
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'per ${_getFrequencyLabel()}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 6),
                    // Explanation text
                    Text(
                      'How much do you want to recycle each ${_getFrequencyLabel()}?',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    SizedBox(height: 12),
                    Row(
                      children: [
                        // Number input with equal size to unit selector
                        Expanded(
                          flex: 1,
                          child: Container(
                            height: 38,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(borderRadius),
                            ),
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: TextFormField(
                              controller: _targetAmountController,
                              keyboardType: TextInputType.numberWithOptions(decimal: true),
                              textAlign: TextAlign.center,
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                hintText: '0.0',
                                hintStyle: TextStyle(color: Colors.grey.shade400),
                              ),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Required';
                                }
                                if (double.tryParse(value) == null) {
                                  return 'Invalid';
                                }
                                return null;
                              },
                              onChanged: (value) {
                                if (value.isNotEmpty && double.tryParse(value) != null) {
                                  setState(() {
                                    _targetAmount = double.parse(value);
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        // Unit selector with equal design style
                        Expanded(
                          flex: 1,
                          child: Container(
                            height: 38,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(borderRadius),
                            ),
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _unit,
                                isExpanded: true,
                                items: _unitOptions.map((String unit) {
                                  return DropdownMenuItem<String>(
                                    value: unit,
                                    child: Center(
                                      child: Text(
                                        unit,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (String? newValue) {
                                  setState(() {
                                    _unit = newValue!;
                                  });
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Total expected amount
                    SizedBox(height: 16),
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 16,
                            color: Colors.grey.shade700,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Total Goal: ${_calculateTotalExpectedAmount().toStringAsFixed(1)} $_unit over entire period',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 16),

              // Date Range section - more obviously clickable
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(borderRadius),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Date Range',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => _selectDate(isStartDate: true),
                            child: Container(
                              height: 38,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(borderRadius),
                              ),
                              alignment: Alignment.center,
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              child: Text(
                                _formatDate(_startDate),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            'to',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () => _selectDate(isStartDate: false),
                            child: Container(
                              height: 38,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(borderRadius),
                              ),
                              alignment: Alignment.center,
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              child: Text(
                                _formatDate(_endDate),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              SizedBox(height: 16),

              // Frequency section with more colorful buttons
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(borderRadius),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Frequency',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 12),
                    // Frequency selection with colorful buttons
                    Container(
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(borderRadius),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _frequency = 'daily'),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: _frequency == 'daily' ? primaryColor : Colors.transparent,
                                  borderRadius: BorderRadius.horizontal(left: Radius.circular(borderRadius)),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'Daily',
                                  style: TextStyle(
                                    color: _frequency == 'daily' ? Colors.white : Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() {
                                _frequency = 'weekly';
                                // Clear previous day selections
                                _selectedDays = List.generate(7, (index) => false);
                                // Default to Sunday when switching to weekly
                                _selectedDays[6] = true;
                              }),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: _frequency == 'weekly' ? primaryColor : Colors.transparent,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'Weekly',
                                  style: TextStyle(
                                    color: _frequency == 'weekly' ? Colors.white : Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() {
                                _frequency = 'custom';
                                // Keep current selections when switching to custom
                                // If no days are currently selected, default to Sunday
                                if (!_selectedDays.contains(true)) {
                                  _selectedDays[6] = true;
                                }
                              }),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: _frequency == 'custom' ? primaryColor : Colors.transparent,
                                  borderRadius: BorderRadius.horizontal(right: Radius.circular(borderRadius)),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'Custom',
                                  style: TextStyle(
                                    color: _frequency == 'custom' ? Colors.white : Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Day selection for Weekly (single day) or Custom (multiple days)
                    if (_frequency == 'weekly' || _frequency == 'custom')
                      Container(
                        margin: EdgeInsets.only(top: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _frequency == 'weekly'
                                  ? 'Select one day'
                                  : 'Select multiple days',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 14,
                              ),
                            ),
                            SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: List.generate(7, (index) {
                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      if (_frequency == 'weekly') {
                                        // For weekly: clear all selections then select only this day
                                        for (int i = 0; i < _selectedDays.length; i++) {
                                          _selectedDays[i] = (i == index);
                                        }
                                      } else {
                                        // For custom: toggle the selected state of this day
                                        _selectedDays[index] = !_selectedDays[index];
                                      }
                                    });
                                  },
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _selectedDays[index]
                                          ? primaryColor
                                          : Colors.grey.shade200,
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      _dayNames[index],
                                      style: TextStyle(
                                        color: _selectedDays[index]
                                            ? Colors.white
                                            : Colors.grey.shade700,
                                        fontWeight: FontWeight.w500,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ],
                        ),
                      ),

                    // Frequency explanation
                    SizedBox(height: 16),
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade100),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.blue.shade700,
                            size: 16,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _getFrequencyExplanation(),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 16),

              // NEW: Reminder Settings Section
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(borderRadius),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.notifications, color: primaryColor, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Reminder Settings',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),

                    // Reminder toggle
                    Container(
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(borderRadius),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _reminderEnabled = false),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: !_reminderEnabled ? primaryColor : Colors.transparent,
                                  borderRadius: BorderRadius.horizontal(left: Radius.circular(borderRadius)),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'No Reminders',
                                  style: TextStyle(
                                    color: !_reminderEnabled ? Colors.white : Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _reminderEnabled = true),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: _reminderEnabled ? primaryColor : Colors.transparent,
                                  borderRadius: BorderRadius.horizontal(right: Radius.circular(borderRadius)),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'Enable Reminders',
                                  style: TextStyle(
                                    color: _reminderEnabled ? Colors.white : Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Reminder time setting (only show if enabled)
                    if (_reminderEnabled) ...[
                      SizedBox(height: 12),
                      InkWell(
                        onTap: _selectReminderTime,
                        child: Container(
                          height: 38,
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(borderRadius),
                            border: Border.all(color: primaryColor.withOpacity(0.3)),
                          ),
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.schedule, size: 16, color: primaryColor),
                                  SizedBox(width: 8),
                                  Text(
                                    'Reminder Time: ${_reminderTime.format(context)}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                              Icon(Icons.arrow_forward_ios, size: 12, color: primaryColor),
                            ],
                          ),
                        ),
                      ),

                      SizedBox(height: 12),
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade100),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue.shade700, size: 16),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'You\'ll receive reminders ${_getReminderFrequencyText()}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              SizedBox(height: 16),

              // Point Requirements Warning
              if (!_meetsPointRequirements())
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(borderRadius),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.orange.shade700,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Point Earning Requirements',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.orange.shade800,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Your current settings will not meet the requirements to earn points.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.orange.shade900,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'To earn 10 points, you need:\n• Goal duration: at least 7 days\n• Complete at least 3 times\n• Achieve 80% completion rate',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.orange.shade800,
                        ),
                      ),
                      SizedBox(height: 8),
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Current settings: ${_endDate.difference(_startDate).inDays + 1} days, maximum ${_calculateMaxPossibleCompletions()} completions possible',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange.shade900,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              if (!_meetsPointRequirements())
                SizedBox(height: 16),

              // Description field with better spacing
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(borderRadius),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Description',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(borderRadius),
                      ),
                      padding: EdgeInsets.all(12),
                      child: TextField(
                        controller: _descriptionController,
                        decoration: InputDecoration(
                          hintText: 'Add a description for your goal...',
                          border: InputBorder.none,
                          hintStyle: TextStyle(color: Colors.grey.shade400),
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          isDense: true,
                        ),
                        minLines: 3,
                        maxLines: 5,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 24),

              // Goal Summary
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _meetsPointRequirements() ? Colors.green.shade50 : Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(borderRadius),
                  border: Border.all(color: _meetsPointRequirements() ? Colors.green.shade200 : Colors.amber.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Goal Summary',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: _meetsPointRequirements() ? Colors.green.shade800 : Colors.amber.shade800,
                          ),
                        ),
                        if (_meetsPointRequirements()) ...[
                          SizedBox(width: 8),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.shade600,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '10 pts',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                        if (_reminderEnabled) ...[
                          SizedBox(width: 8),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: primaryColor,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.notifications, size: 12, color: Colors.white),
                                SizedBox(width: 2),
                                Text(
                                  'Reminders',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      'You will be recycling $_targetAmount $_unit per ${_getFrequencyLabel()}.',
                      style: TextStyle(
                        fontSize: 14,
                        color: _meetsPointRequirements() ? Colors.green.shade900 : Colors.amber.shade900,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Total goal: ${_calculateTotalExpectedAmount().toStringAsFixed(1)} $_unit over the entire period.',
                      style: TextStyle(
                        fontSize: 14,
                        color: _meetsPointRequirements() ? Colors.green.shade900 : Colors.amber.shade900,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Goal period: ${_formatDate(_startDate)} to ${_formatDate(_endDate)}',
                      style: TextStyle(
                        fontSize: 14,
                        color: _meetsPointRequirements() ? Colors.green.shade900 : Colors.amber.shade900,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Maximum completions possible: ${_calculateMaxPossibleCompletions()}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: _meetsPointRequirements() ? Colors.green.shade900 : Colors.amber.shade900,
                      ),
                    ),
                    if (_reminderEnabled) ...[
                      SizedBox(height: 4),
                      Text(
                        'Daily reminders: ${_getReminderFrequencyText()}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: _meetsPointRequirements() ? Colors.green.shade900 : Colors.amber.shade900,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              SizedBox(height: 24),

            ],
          ),
        ),
      ),
    );
  }

  String _getFrequencyExplanation() {
    switch (_frequency.toLowerCase()) {
      case 'daily':
        return 'You will be adding $_targetAmount $_unit to your goal every day.';
      case 'weekly':
        String day = !_selectedDays.contains(true) ? 'Sunday' :
        ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'][_selectedDays.indexOf(true)];
        return 'You will be adding $_targetAmount $_unit to your goal every $day.';
      case 'custom':
        int daysCount = _selectedDays.where((day) => day).length;
        return 'You will be adding $_targetAmount $_unit to your goal $daysCount times per week on your selected days.';
      default:
        return '';
    }
  }

  Future<void> _selectDate({required bool isStartDate}) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? _startDate : _endDate,
      firstDate: isStartDate ? DateTime.now() : _startDate,
      lastDate: DateTime.now().add(Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: primaryColor,
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: primaryColor,
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          // If end date is before start date, update it
          if (_endDate.isBefore(_startDate)) {
            _endDate = _startDate.add(Duration(days: 7));
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  void _saveGoal() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isCreatingGoal = true;
      });

      // Capture context-dependent objects before any await
      final messenger = ScaffoldMessenger.of(context);
      final navigator = Navigator.of(context);

      try {
        // Validate custom frequency day selection
        if (_frequency == 'custom' && !_selectedDays.any((day) => day)) {
          throw Exception('Please select at least one day for custom frequency');
        }

        // Check notification permissions if reminders are enabled (not supported on web)
        if (_reminderEnabled && !kIsWeb) {
          NotificationService notificationService = NotificationService();
          bool hasPermission = await notificationService.requestNotificationPermissions();
          if (!hasPermission) {
            _showPermissionDialog();
            if (mounted) setState(() { _isCreatingGoal = false; });
            return;
          }
        }

        final now = DateTime.now();
        final reminderDateTime = _reminderEnabled
            ? DateTime(now.year, now.month, now.day, _reminderTime.hour, _reminderTime.minute)
            : null;

        final goal = RecyclingGoal(
          id: '',
          userId: widget.userId,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          startDate: _startDate,
          endDate: _endDate,
          targetAmount: _targetAmount,
          unit: _unit,
          frequency: _frequency,
          completed: false,
          progress: 0,
          selectedDays: _selectedDays,
          completedActions: 0,
          pointsAwarded: false,
          checkInDates: const [],
          dailyProgress: const {},
          reminderEnabled: _reminderEnabled,
          reminderTime: reminderDateTime,
        );

        if (_reminderEnabled && !kIsWeb) {
          await _goalRepository.createRecyclingGoalWithReminder(
            goal,
            reminderEnabled: true,
            reminderTime: reminderDateTime,
          );
        } else {
          await _goalRepository.createRecyclingGoal(goal);
        }

        final message = _reminderEnabled
            ? 'Goal created with daily reminders!'
            : 'Goal created successfully!';
        navigator.pop();

        messenger.showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: primaryColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );

      } catch (e) {
        // Show error message
        if (mounted) {
          messenger.showSnackBar(
            SnackBar(
              content: Text('Failed to create goal: $e'),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isCreatingGoal = false;
          });
        }
      }
    }
  }
}
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import '../repositories/auth_repository.dart';
import '../repositories/record_repository.dart';
import '../models/recycling_record.dart';
import '../config/recycling_config.dart';

class AddRecyclingRecordPage extends StatefulWidget {
  const AddRecyclingRecordPage({super.key});

  @override
  _AddRecyclingRecordPageState createState() => _AddRecyclingRecordPageState();
}

class _AddRecyclingRecordPageState extends State<AddRecyclingRecordPage> {
  final AuthRepository _authRepository = AuthRepository();
  final RecordRepository _recordRepository = RecordRepository();
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();

  // Form controllers
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  // Form data
  String? selectedMaterial;
  String? selectedUnit;
  DateTime selectedDate = DateTime.now();
  File? selectedImage;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    // Add listener to update UI when amount changes
    _amountController.addListener(() {
      setState(() {
        // This will trigger a rebuild and update the save button state
      });
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Add Recycling Record',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green[400]!, Colors.green[600]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.2),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.recycling, color: Colors.white, size: 28),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Track Your Impact',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Earn 2 points per day for recycling!',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 32),

              // Date Selection
              _buildSectionTitle('Date', 'When did you recycle?'),
              SizedBox(height: 12),
              _buildDateSelector(),

              SizedBox(height: 32),

              // Material Type
              _buildSectionTitle('Material Type', 'What did you recycle?'),
              SizedBox(height: 12),
              _buildMaterialDropdown(),

              SizedBox(height: 32),

              // Unit Selection
              _buildSectionTitle('Unit', 'How do you measure it?'),
              SizedBox(height: 12),
              _buildUnitDropdown(),

              SizedBox(height: 32),

              // Amount
              _buildSectionTitle('Amount', 'How much did you recycle?'),
              SizedBox(height: 12),
              _buildAmountField(),

              SizedBox(height: 32),

              // Photo Section
              _buildSectionTitle('Photo', 'Show your recycling (optional)'),
              SizedBox(height: 12),
              _buildPhotoSection(),

              SizedBox(height: 32),

              // Notes
              _buildSectionTitle('Notes', 'Any additional details? (optional)'),
              SizedBox(height: 12),
              _buildNotesField(),

              SizedBox(height: 40),

              // Save Button
              _buildSaveButton(),

              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildDateSelector() {
    return GestureDetector(
      onTap: () async {
        final DateTime? picked = await showDatePicker(
          context: context,
          initialDate: selectedDate,
          firstDate: DateTime.now().subtract(Duration(days: 30)),
          lastDate: DateTime.now(),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: ColorScheme.light(
                  primary: Colors.green,
                  onPrimary: Colors.white,
                  surface: Colors.white,
                  onSurface: Colors.black,
                ),
              ),
              child: child!,
            );
          },
        );
        if (picked != null && picked != selectedDate) {
          setState(() {
            selectedDate = picked;
          });
        }
      },
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.calendar_today, color: Colors.blue[600], size: 20),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Selected Date',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Widget _buildMaterialDropdown() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedMaterial,
          hint: Row(
            children: [
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.category, color: Colors.grey[600], size: 20),
              ),
              SizedBox(width: 16),
              Text(
                'Choose material type',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                ),
              ),
            ],
          ),
          isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down, color: Colors.grey[600]),
          dropdownColor: Colors.white,
          elevation: 8,
          borderRadius: BorderRadius.circular(16),
          style: TextStyle(
            color: Colors.black87,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          items: RecyclingConfig.materialTypes.map((String material) {
            return DropdownMenuItem<String>(
              value: material,
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: RecyclingConfig.getColorForMaterial(material).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: RecyclingConfig.getColorForMaterial(material),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Text(material),
                ],
              ),
            );
          }).toList(),
          onChanged: (String? newValue) {
            setState(() {
              selectedMaterial = newValue;
              selectedUnit = null; // Reset unit when material changes
            });
          },
        ),
      ),
    );
  }

  Widget _buildUnitDropdown() {
    List<String> availableUnits = selectedMaterial != null
        ? RecyclingConfig.getUnitsForMaterial(selectedMaterial!)
        : [];

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: selectedMaterial != null ? Colors.white : Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selectedMaterial != null ? Colors.grey[200]! : Colors.grey[300]!,
        ),
        boxShadow: selectedMaterial != null ? [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ] : [],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedUnit,
          hint: Row(
            children: [
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: selectedMaterial != null ? Colors.orange[50] : Colors.grey[200],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.straighten,
                  color: selectedMaterial != null ? Colors.orange[600] : Colors.grey[500],
                  size: 20,
                ),
              ),
              SizedBox(width: 16),
              Text(
                selectedMaterial != null ? 'Choose unit' : 'Select material first',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                ),
              ),
            ],
          ),
          isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down, color: Colors.grey[600]),
          dropdownColor: Colors.white,
          elevation: 8,
          borderRadius: BorderRadius.circular(16),
          style: TextStyle(
            color: Colors.black87,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          items: availableUnits.map((String unit) {
            return DropdownMenuItem<String>(
              value: unit,
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      unit.substring(0, 1).toUpperCase(),
                      style: TextStyle(
                        color: Colors.orange[600],
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Text(unit),
                ],
              ),
            );
          }).toList(),
          onChanged: selectedMaterial != null
              ? (String? newValue) {
            setState(() {
              selectedUnit = newValue;
            });
          }
              : null,
        ),
      ),
    );
  }

  Widget _buildAmountField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: _amountController,
        keyboardType: TextInputType.numberWithOptions(decimal: true),
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: 'Enter amount',
          hintStyle: TextStyle(color: Colors.grey[500]),
          prefixIcon: Container(
            margin: EdgeInsets.all(12),
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.purple[50],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.numbers, color: Colors.purple[600], size: 20),
          ),
          suffixText: selectedUnit ?? '',
          suffixStyle: TextStyle(
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.all(20),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter an amount';
          }
          if (double.tryParse(value) == null) {
            return 'Please enter a valid number';
          }
          if (double.parse(value) <= 0) {
            return 'Amount must be greater than 0';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildPhotoSection() {
    return Column(
      children: [
        if (selectedImage != null) ...[
          Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(
                selectedImage!,
                fit: BoxFit.cover,
              ),
            ),
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green[300]!),
                  ),
                  child: TextButton.icon(
                    onPressed: _pickImage,
                    icon: Icon(Icons.camera_alt, color: Colors.green[600]),
                    label: Text(
                      'Change Photo',
                      style: TextStyle(color: Colors.green[600], fontWeight: FontWeight.w600),
                    ),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.all(16),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red[300]!),
                  ),
                  child: TextButton.icon(
                    onPressed: () {
                      setState(() {
                        selectedImage = null;
                      });
                    },
                    icon: Icon(Icons.delete_outline, color: Colors.red[600]),
                    label: Text(
                      'Remove',
                      style: TextStyle(color: Colors.red[600], fontWeight: FontWeight.w600),
                    ),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.all(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ] else ...[
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              height: 140,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[200]!, style: BorderStyle.solid),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.camera_alt, size: 32, color: Colors.grey[600]),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Tap to add photo',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Show off your recycling!',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildNotesField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: _notesController,
        maxLines: 4,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: 'Add notes about your recycling experience...',
          hintStyle: TextStyle(color: Colors.grey[500]),
          prefixIcon: Container(
            margin: EdgeInsets.all(12),
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.edit_note, color: Colors.blue[600], size: 20),
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.all(20),
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    bool canSave = _canSave();

    return Column(
      children: [
        // Progress indicator
        if (!canSave) ...[
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.orange[50]!, Colors.orange[100]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.orange[200]!),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange[600]),
                    SizedBox(width: 12),
                    Text(
                      'Complete these steps:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange[700],
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                _buildProgressItem('Material type', selectedMaterial != null),
                _buildProgressItem('Unit', selectedUnit != null),
                _buildProgressItem('Amount', _amountController.text.trim().isNotEmpty &&
                    double.tryParse(_amountController.text.trim()) != null &&
                    double.tryParse(_amountController.text.trim())! > 0),
              ],
            ),
          ),
          SizedBox(height: 24),
        ],

        Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: canSave ? [
              BoxShadow(
                color: Colors.green.withOpacity(0.3),
                blurRadius: 12,
                offset: Offset(0, 6),
              ),
            ] : [],
          ),
          child: ElevatedButton(
            onPressed: canSave ? _saveRecord : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: canSave ? Colors.green : Colors.grey[300],
              foregroundColor: canSave ? Colors.white : Colors.grey[600],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: isLoading
                ? SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
                : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.save, size: 20),
                SizedBox(width: 8),
                Text(
                  'Save Record',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressItem(String label, bool isCompleted) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: isCompleted ? Colors.green[100] : Colors.grey[200],
              shape: BoxShape.circle,
              border: Border.all(
                color: isCompleted ? Colors.green[400]! : Colors.grey[400]!,
                width: 2,
              ),
            ),
            child: isCompleted
                ? Icon(Icons.check, size: 12, color: Colors.green[600])
                : null,
          ),
          SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              color: isCompleted ? Colors.green[700] : Colors.orange[700],
              fontWeight: FontWeight.w500,
              decoration: isCompleted ? TextDecoration.lineThrough : null,
            ),
          ),
        ],
      ),
    );
  }

  bool _canSave() {
    bool canSave = selectedMaterial != null &&
        selectedUnit != null &&
        _amountController.text.trim().isNotEmpty &&
        double.tryParse(_amountController.text.trim()) != null &&
        double.tryParse(_amountController.text.trim())! > 0 &&
        !isLoading;

    return canSave;
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (image != null) {
        setState(() {
          selectedImage = File(image.path);
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _saveRecord() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      isLoading = true;
    });

    try {
      String? userId = _authRepository.getCurrentUserId();
      if (userId == null) {
        throw Exception('User not logged in');
      }

      // Create recycling record
      RecyclingRecord record = RecyclingRecord(
        id: '',
        userId: userId,
        materialType: selectedMaterial!,
        amount: double.parse(_amountController.text),
        unit: selectedUnit!,
        date: selectedDate,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        imageUrl: null,
      );

      // Save to Firebase
      await _recordRepository.addRecyclingRecord(record, imageFile: selectedImage);

      // Show success message
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Recycling record saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      // Return to previous screen with success result
      if (!mounted) return;
      Navigator.pop(context, true);

    } catch (e) {
      print('Error saving record: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving record: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }
}
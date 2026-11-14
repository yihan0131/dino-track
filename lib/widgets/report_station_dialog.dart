import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/recycling_station.dart';
import '../models/station_report.dart';

class ReportStationDialog extends StatefulWidget {
  final RecyclingStation station;

  const ReportStationDialog({
    super.key,
    required this.station,
  });

  @override
  State<ReportStationDialog> createState() => _ReportStationDialogState();
}

class _ReportStationDialogState extends State<ReportStationDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _addressController;
  late TextEditingController _latitudeController;
  late TextEditingController _longitudeController;
  List<String> _selectedMaterials = [];
  bool _isSubmitting = false;
  String? _errorMessage;

  final List<String> _availableMaterials = [
    'Plastic',
    'Paper',
    'Glass',
    'Metal',
    'Electronics',
    'Batteries',
    'Cardboard',
    'Textiles',
    'Organics',
    'Hazardous Waste',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.station.name);
    _addressController = TextEditingController(text: widget.station.address);
    _latitudeController = TextEditingController(text: widget.station.latitude.toString());
    _longitudeController = TextEditingController(text: widget.station.longitude.toString());
    _selectedMaterials = List.from(widget.station.acceptedMaterials);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _errorMessage = 'Please sign in to submit a report';
          _isSubmitting = false;
        });
        return;
      }

      // Create the report
      final report = StationReport(
        id: 'temporary-id',
        stationId: widget.station.id,
        reportedBy: user.uid,
        name: _nameController.text,
        address: _addressController.text,
        latitude: double.parse(_latitudeController.text),
        longitude: double.parse(_longitudeController.text),
        acceptedMaterials: _selectedMaterials.isEmpty 
            ? widget.station.acceptedMaterials 
            : _selectedMaterials,
        status: 'pending',
        reportDate: DateTime.now(),
      );

      // Add to Firestore
      await FirebaseFirestore.instance.collection('station_reports').add(report.toMap());

      // If this is an OSM station, create a new station with the corrected information
      if (widget.station.id.startsWith('osm_')) {
        final newStation = RecyclingStation(
          id: 'temporary-id',
          name: _nameController.text,
          address: _addressController.text,
          latitude: double.parse(_latitudeController.text),
          longitude: double.parse(_longitudeController.text),
          acceptedMaterials: _selectedMaterials.isEmpty 
              ? widget.station.acceptedMaterials 
              : _selectedMaterials,
          verified: false,
          submittedBy: user.uid,
          submissionDate: DateTime.now(),
          status: 'pending',
          originalStationId: widget.station.id,
          contactInfo: widget.station.contactInfo,
          operatingHours: widget.station.operatingHours,
          rating: widget.station.rating,
        );

        await FirebaseFirestore.instance.collection('recycling_stations').add(newStation.toMap());
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Report submitted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to submit report: $e';
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Report Incorrect Information',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue, size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Your changes will be reviewed before being applied.',
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Station Name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      value?.isEmpty ?? true ? 'Please enter a name' : null,
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: _addressController,
                  decoration: InputDecoration(
                    labelText: 'Address',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      value?.isEmpty ?? true ? 'Please enter an address' : null,
                ),
                SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _latitudeController,
                        decoration: InputDecoration(
                          labelText: 'Latitude',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                        validator: (value) {
                          if (value?.isEmpty ?? true) return 'Please enter latitude';
                          final lat = double.tryParse(value!);
                          if (lat == null || lat < -90 || lat > 90) {
                            return 'Invalid latitude';
                          }
                          return null;
                        },
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _longitudeController,
                        decoration: InputDecoration(
                          labelText: 'Longitude',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                        validator: (value) {
                          if (value?.isEmpty ?? true) return 'Please enter longitude';
                          final lng = double.tryParse(value!);
                          if (lng == null || lng < -180 || lng > 180) {
                            return 'Invalid longitude';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Row(
                  children: [
                    Text(
                      'Accepted Materials',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    SizedBox(width: 8),
                    Text(
                      '(Optional)',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: _availableMaterials.map((material) {
                    final isSelected = _selectedMaterials.contains(material);
                    return FilterChip(
                      label: Text(material),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedMaterials.add(material);
                          } else {
                            _selectedMaterials.remove(material);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                if (_errorMessage != null) ...[
                  SizedBox(height: 16),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitReport,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isSubmitting
                      ? CircularProgressIndicator()
                      : Text('Submit Report'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 
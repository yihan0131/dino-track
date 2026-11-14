import 'package:flutter/material.dart';
import '../models/recycling_record.dart';
import '../models/recycling_display_entry.dart';
import '../repositories/auth_repository.dart';
import '../repositories/record_repository.dart';

class RecyclingRecordDetailPage extends StatefulWidget {
  // ADD THESE PARAMETERS:
  final RecyclingDisplayEntry entry;
  final String date;

  const RecyclingRecordDetailPage({
    super.key,
    required this.entry,
    required this.date,
  });

  @override
  _RecyclingRecordDetailPageState createState() => _RecyclingRecordDetailPageState();
}

class _RecyclingRecordDetailPageState extends State<RecyclingRecordDetailPage> {
  final AuthRepository _authRepository = AuthRepository();
  final RecordRepository _recordRepository = RecordRepository();

  @override
  Widget build(BuildContext context) {
    // REMOVE THE ARGUMENTS PARSING - use widget.entry and widget.date instead
    final RecyclingDisplayEntry entry = widget.entry;
    final String date = widget.date;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '${entry.materialType} Records',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Summary Card
            _buildSummaryCard(entry, date),

            SizedBox(height: 24),

            // Individual Records Title
            Text(
              'Individual Records',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),

            SizedBox(height: 16),

            // Individual Records List
            ...entry.records.asMap().entries.map((mapEntry) {
              int index = mapEntry.key;
              RecyclingRecord record = mapEntry.value;
              return _buildRecordCard(record, index + 1);
            }),

            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<int> _calculatePointsEarned(RecyclingDisplayEntry entry, String date) async {
    try {
      // Format the display date to proper date string
      String formattedDate = _recordRepository.formatDateForPoints(date);

      // Check if this entry contains the first record of the day
      bool wasFirst = await _recordRepository.wasFirstRecordOfDay(
        entry.records, formattedDate,
        userId: _authRepository.getCurrentUserId() ?? '',
      );

      return wasFirst ? 2 : 0;
    } catch (e) {
      print("Error calculating points earned: $e");
      return 0;
    }
  }

  Widget _buildSummaryCard(RecyclingDisplayEntry entry, String date) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Material Icon and Info
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: entry.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  _getIconForMaterial(entry.materialType),
                  color: entry.color,
                  size: 30,
                ),
              ),

              SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.materialType,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '📅 $date',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          SizedBox(height: 20),

          // Summary Stats - Use FutureBuilder for points
          FutureBuilder<int>(
            future: _calculatePointsEarned(entry, date),
            builder: (context, snapshot) {
              int pointsEarned = snapshot.data ?? 0;

              return Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: entry.color.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: entry.color.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildStatItem(
                        'Total Amount',
                        '${entry.totalAmount.toStringAsFixed(entry.totalAmount == entry.totalAmount.roundToDouble() ? 0 : 1)} ${entry.unit}',
                        entry.color,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: Colors.grey[300],
                    ),
                    Expanded(
                      child: _buildStatItem(
                        'Records',
                        '${entry.records.length}',
                        entry.color,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: Colors.grey[300],
                    ),
                    Expanded(
                      child: _buildStatItem(
                        'Points Earned',
                        pointsEarned > 0 ? '+$pointsEarned' : '+0',
                        pointsEarned > 0 ? Colors.green : Colors.grey,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildRecordCard(RecyclingRecord record, int index) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Record Header
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '$index',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[700],
                    ),
                  ),
                ),
              ),

              SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${record.amount.toStringAsFixed(record.amount == record.amount.roundToDouble() ? 0 : 1)} ${record.unit}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      'Added at ${_formatTime(record.date)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),

              // Options Menu
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: Colors.grey[600]),
                onSelected: (value) {
                  if (value == 'delete') {
                    _showDeleteDialog(record);
                  }
                },
                itemBuilder: (BuildContext context) => [
                  PopupMenuItem<String>(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: Colors.red, size: 20),
                        SizedBox(width: 8),
                        Text('Delete', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Notes Section
          if (record.notes != null && record.notes!.isNotEmpty) ...[
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.note, color: Colors.grey[600], size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      record.notes!,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Photo Section - Made clickable
          if (record.imageUrl != null && record.imageUrl!.isNotEmpty) ...[
            SizedBox(height: 12),
            GestureDetector(
              onTap: () => _showImageViewer(record.imageUrl!),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    children: [
                      Image.network(
                        record.imageUrl!,
                        height: 160,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 160,
                            width: double.infinity,
                            color: Colors.grey[200],
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.broken_image, color: Colors.grey[400], size: 32),
                                  SizedBox(height: 8),
                                  Text(
                                    'Failed to load image',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            height: 160,
                            width: double.infinity,
                            color: Colors.grey[200],
                            child: Center(
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                    : null,
                                strokeWidth: 3,
                              ),
                            ),
                          );
                        },
                      ),
                      // Overlay to indicate it's clickable
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.zoom_in,
                                color: Colors.white,
                                size: 16,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Tap to view',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showImageViewer(String imageUrl) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.all(20),
          child: Stack(
            children: [
              // Image
              Center(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 20,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 300,
                            height: 300,
                            color: Colors.grey[800],
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.broken_image,
                                    color: Colors.white70,
                                    size: 48,
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'Failed to load image',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            width: 300,
                            height: 300,
                            color: Colors.grey[800],
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CircularProgressIndicator(
                                    value: loadingProgress.expectedTotalBytes != null
                                        ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                        : null,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    strokeWidth: 3,
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'Loading image...',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),

              // Close button
              Positioned(
                top: 40,
                right: 20,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),


            ],
          ),
        );
      },
    );
  }

  IconData _getIconForMaterial(String materialType) {
    switch (materialType.toLowerCase()) {
      case 'plastic':
        return Icons.local_drink;
      case 'paper':
        return Icons.description;
      case 'glass':
        return Icons.wine_bar;
      case 'metal':
        return Icons.build;
      case 'cardboard':
        return Icons.inventory_2;
      case 'electronics':
        return Icons.smartphone;
      case 'batteries':
        return Icons.battery_full;
      case 'textiles':
        return Icons.checkroom;
      case 'organic':
        return Icons.eco;
      default:
        return Icons.recycling;
    }
  }

  String _formatTime(DateTime dateTime) {
    int hour = dateTime.hour;
    int minute = dateTime.minute;
    String period = hour >= 12 ? 'PM' : 'AM';

    // Convert 24-hour to 12-hour format
    if (hour > 12) {
      hour = hour - 12;
    } else if (hour == 0) {
      hour = 12;
    }

    String minuteStr = minute.toString().padLeft(2, '0');
    return '$hour:$minuteStr $period';
  }

  void _showDeleteDialog(RecyclingRecord record) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete Record'),
          content: Text('Are you sure you want to delete this recycling record? This action cannot be undone.'),
          actions: [
            TextButton(
              child: Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text('Delete', style: TextStyle(color: Colors.red)),
              onPressed: () async {
                Navigator.of(context).pop();
                await _deleteRecord(record);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteRecord(RecyclingRecord record) async {
    try {
      await _recordRepository.deleteRecyclingRecord(record.id);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Record deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );

      // Go back to refresh the list
      if (!mounted) return;
      Navigator.pop(context, true);

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting record: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
import 'package:flutter/material.dart';
import '../repositories/auth_repository.dart';
import '../repositories/record_repository.dart';
import '../models/recycling_record.dart';
import '../models/recycling_display_entry.dart';
import '../config/recycling_config.dart';

class RecyclingRecordsPage extends StatefulWidget {
  const RecyclingRecordsPage({super.key});

  @override
  _RecyclingRecordsPageState createState() => _RecyclingRecordsPageState();
}

class _RecyclingRecordsPageState extends State<RecyclingRecordsPage> {
  final AuthRepository _authRepository = AuthRepository();
  final RecordRepository _recordRepository = RecordRepository();
  String selectedMonth = DateTime.now().month.toString();
  int selectedYear = DateTime.now().year;
  bool isLoading = true;
  Map<String, List<RecyclingDisplayEntry>> groupedRecords = {};

  final List<String> months = [
    '1', '2', '3', '4', '5', '6',
    '7', '8', '9', '10', '11', '12'
  ];

  final Map<String, String> monthNames = {
    '1': 'January', '2': 'February', '3': 'March', '4': 'April',
    '5': 'May', '6': 'June', '7': 'July', '8': 'August',
    '9': 'September', '10': 'October', '11': 'November', '12': 'December'
  };

  @override
  void initState() {
    super.initState();
    _loadRecyclingRecords();
  }

  Future<void> _loadRecyclingRecords() async {
    try {
      setState(() {
        isLoading = true;
      });

      String? userId = _authRepository.getCurrentUserId();
      if (userId == null) {
        print('ERROR: User ID is null');
        setState(() {
          isLoading = false;
        });
        return;
      }

      print('Loading records for user: $userId');
      print('Selected month: $selectedMonth');

      // Get records grouped by date from Firebase
      Map<String, List<RecyclingRecord>> recordsByDate =
      await _recordRepository.getUserRecyclingRecordsByDate(userId);

      print('Total record dates from Firebase: ${recordsByDate.keys.length}');
      print('Date keys from Firebase: ${recordsByDate.keys.toList()}');

      if (recordsByDate.isEmpty) {
        print('WARNING: No records found in Firebase for user $userId');
        setState(() {
          groupedRecords = {};
          isLoading = false;
        });
        return;
      }

      // Filter by selected month and convert to display format
      Map<String, List<RecyclingDisplayEntry>> filtered = {};

      recordsByDate.forEach((dateKey, records) {
        print('\nProcessing date: $dateKey with ${records.length} records');

        // Parse date to check month
        List<String> dateParts = dateKey.split('-');
        if (dateParts.length != 3) {
          print('WARNING: Invalid date format: $dateKey (expected YYYY-MM-DD)');
          return;
        }

        String recordYear = dateParts[0];
        String recordMonth = dateParts[1]; // Month part (e.g., "01", "02", etc.)
        String paddedSelectedMonth = selectedMonth.padLeft(2, '0'); // Ensure 2 digits

        print('Record month: "$recordMonth", Selected month (padded): "$paddedSelectedMonth"');
        print('Month comparison: "$recordMonth" == "$paddedSelectedMonth" = ${recordMonth == paddedSelectedMonth}');

        if (recordMonth == paddedSelectedMonth && recordYear == selectedYear.toString()) {
          print('SUCCESS: Month matches! Processing ${records.length} records for $dateKey');

          // Format date for display (e.g., "17/9")
          String day = int.parse(dateParts[2]).toString();
          String month = int.parse(dateParts[1]).toString();
          String displayDate = '$day/$month';

          print('Display date will be: $displayDate');

          // Group records by material type + unit
          Map<String, RecyclingDisplayEntry> materialGroups = {};

          for (var record in records) {
            print('Processing record: ${record.materialType} - ${record.amount} ${record.unit}');
            String key = '${record.materialType}_${record.unit}';

            if (materialGroups[key] == null) {
              materialGroups[key] = RecyclingDisplayEntry(
                materialType: record.materialType,
                unit: record.unit,
                totalAmount: record.amount,
                color: RecyclingConfig.getColorForMaterial(record.materialType),
                records: [record],
              );
              print('Created new material group: $key');
            } else {
              materialGroups[key]!.totalAmount += record.amount;
              materialGroups[key]!.records.add(record);
              print('Added to existing material group: $key (new total: ${materialGroups[key]!.totalAmount})');
            }
          }

          if (materialGroups.isNotEmpty) {
            filtered[displayDate] = materialGroups.values.toList();
            print('Added ${materialGroups.length} material groups for display date: $displayDate');
          } else {
            print('WARNING: No material groups created for $displayDate');
          }
        } else {
          print('INFO: Month does not match. Skipping $dateKey');
        }
      });

      print('\nFinal results:');
      print('Filtered records: ${filtered.keys.length} dates');
      print('Filtered date keys: ${filtered.keys.toList()}');

      // Log each filtered entry for detailed debugging
      filtered.forEach((date, entries) {
        print('Date $date has ${entries.length} entries:');
        for (var entry in entries) {
          print('   - ${entry.materialType} (${entry.unit}): ${entry.totalAmount}');
        }
      });

      setState(() {
        groupedRecords = filtered;
        isLoading = false;
      });

      print('State updated successfully');

    } catch (e, stackTrace) {
      print('ERROR loading recycling records: $e');
      print('Stack trace: $stackTrace');

      setState(() {
        isLoading = false;
      });

      // Show error to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading records: $e'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Recycling Records',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.bar_chart, color: Colors.black),
            onPressed: () {
              // Navigate to statistics page
              Navigator.pushNamed(context, '/recycling_stats');
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Month Selector
          Container(
            color: Colors.white,
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.calendar_month, color: Colors.green[600], size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Select Month',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.chevron_left, color: Colors.green[700]),
                          padding: EdgeInsets.zero,
                          constraints: BoxConstraints(),
                          onPressed: () {
                            setState(() { selectedYear--; });
                            _loadRecyclingRecords();
                          },
                        ),
                        Text(
                          '$selectedYear',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.green[800],
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.chevron_right,
                            color: selectedYear < DateTime.now().year
                                ? Colors.green[700]
                                : Colors.grey[400],
                          ),
                          padding: EdgeInsets.zero,
                          constraints: BoxConstraints(),
                          onPressed: selectedYear < DateTime.now().year
                              ? () {
                                  setState(() { selectedYear++; });
                                  _loadRecyclingRecords();
                                }
                              : null,
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedMonth,
                      isExpanded: true,
                      icon: Container(
                        padding: EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.green[100],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          Icons.keyboard_arrow_down,
                          color: Colors.green[700],
                          size: 16,
                        ),
                      ),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      dropdownColor: Colors.white,
                      elevation: 8,
                      borderRadius: BorderRadius.circular(12),
                      items: months.map((String month) {
                        return DropdownMenuItem<String>(
                          value: month,
                          child: Container(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: selectedMonth == month
                                        ? Colors.green[100]
                                        : Colors.grey[100],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Center(
                                    child: Text(
                                      month,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: selectedMonth == month
                                            ? Colors.green[700]
                                            : Colors.grey[600],
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text(
                                  '${monthNames[month]} $selectedYear',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: selectedMonth == month
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                    color: selectedMonth == month
                                        ? Colors.green[700]
                                        : Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          selectedMonth = newValue!;
                        });
                        _loadRecyclingRecords(); // Reload data for new month
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Records List
          Expanded(
            child: isLoading
                ? Center(child: CircularProgressIndicator())
                : groupedRecords.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
              onRefresh: _loadRecyclingRecords,
              child: ListView.builder(
                padding: EdgeInsets.all(16),
                itemCount: groupedRecords.keys.length,
                itemBuilder: (context, index) {
                  // Sort dates in descending order
                  List<String> sortedDates = groupedRecords.keys.toList();
                  sortedDates.sort((a, b) {
                    List<String> aParts = a.split('/');
                    List<String> bParts = b.split('/');
                    int aDay = int.parse(aParts[0]);
                    int bDay = int.parse(bParts[0]);
                    return bDay.compareTo(aDay); // Descending order
                  });

                  String date = sortedDates[index];
                  List<RecyclingDisplayEntry> entries = groupedRecords[date]!;

                  return _buildDateSection(date, entries);
                },
              ),
            ),
          ),
        ],
      ),

      // Floating Action Button
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // Navigate to add recycling record page
          final result = await Navigator.pushNamed(
              context,
              '/add_recycling_record'
          );

          if (result == true) {
            _loadRecyclingRecords(); // Refresh the list
          }
        },
        backgroundColor: Colors.green,
        child: Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildDateSection(String date, List<RecyclingDisplayEntry> entries) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Date Header
        Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Text(
                '🗓️ $date',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '+2 points',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Recycling Entry Cards
        ...entries.map((entry) => _buildRecyclingCard(entry, date)),

        SizedBox(height: 20),
      ],
    );
  }

  Widget _buildRecyclingCard(RecyclingDisplayEntry entry, String date) {
    return GestureDetector(
      onTap: () async {
        // Navigate to detail page and wait for result
        final result = await Navigator.pushNamed(
            context,
            '/recycling_record_detail',
            arguments: {
              'entry': entry,
              'date': date,
            }
        );

        // Check if we need to refresh the list
        // This will be true if a record was deleted or modified
        if (result == true) {
          print('Refreshing records after returning from detail screen');
          _loadRecyclingRecords();
        }
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 8),
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
        child: Row(
          children: [
            // Material Icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: entry.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _getIconForMaterial(entry.materialType),
                color: entry.color,
                size: 24,
              ),
            ),

            SizedBox(width: 12),

            // Material Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${entry.materialType} (${entry.unit})',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Total: ${entry.totalAmount.toStringAsFixed(entry.totalAmount == entry.totalAmount.roundToDouble() ? 0 : 1)} • ${entry.records.length} record${entry.records.length > 1 ? 's' : ''}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),

            // Amount Badge + Arrow
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: entry.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    entry.totalAmount.toStringAsFixed(entry.totalAmount == entry.totalAmount.roundToDouble() ? 0 : 1),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: entry.color,
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey[400],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.recycling,
            size: 64,
            color: Colors.grey[400],
          ),
          SizedBox(height: 16),
          Text(
            'No recycling records for ${monthNames[selectedMonth]}',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Tap + to add your first record',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
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
}
import 'package:flutter/material.dart';
import '../repositories/auth_repository.dart';
import '../repositories/record_repository.dart';
import '../config/recycling_config.dart';

class RecyclingStatsPage extends StatefulWidget {
  const RecyclingStatsPage({super.key});

  @override
  _RecyclingStatsPageState createState() => _RecyclingStatsPageState();
}

class _RecyclingStatsPageState extends State<RecyclingStatsPage> {
  final AuthRepository _authRepository = AuthRepository();
  final RecordRepository _recordRepository = RecordRepository();
  int selectedYear = DateTime.now().year;
  bool isLoading = true;
  Map<String, dynamic> stats = {};
  Map<String, double> materialDistribution = {};

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      setState(() {
        isLoading = true;
      });

      String? userId = _authRepository.getCurrentUserId();
      if (userId == null) return;

      // Load both stats and material distribution
      final statsData = await _recordRepository.getUserRecyclingStats(userId, year: selectedYear);
      final distributionData = await _recordRepository.getMaterialDistribution(userId, year: selectedYear);

      setState(() {
        stats = statsData;
        materialDistribution = distributionData;
        isLoading = false;
      });
    } catch (e) {
      print('Error loading stats: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
          'Recycling Statistics',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(Icons.chevron_left, color: Colors.green[700]),
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(),
                  onPressed: () {
                    setState(() { selectedYear--; });
                    _loadStats();
                  },
                ),
                SizedBox(width: 16),
                Text(
                  '$selectedYear',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.green[800],
                  ),
                ),
                SizedBox(width: 16),
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
                          _loadStats();
                        }
                      : null,
                ),
              ],
            ),
          ),
          Expanded(
            child: isLoading
                ? Center(child: CircularProgressIndicator())
                : stats.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
              onRefresh: _loadStats,
              child: SingleChildScrollView(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Overview Cards
                    _buildOverviewSection(),

                    SizedBox(height: 24),

                    // Material Distribution
                    _buildMaterialDistributionSection(),

                    SizedBox(height: 24),

                    // Detailed Material Stats
                    _buildDetailedStatsSection(),

                    SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bar_chart,
            size: 64,
            color: Colors.grey[400],
          ),
          SizedBox(height: 16),
          Text(
            'No recycling data yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Start logging your recycling efforts to see statistics',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Overview',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),

        SizedBox(height: 16),

        Row(
          children: [
            Expanded(
              child: _buildOverviewCard(
                'Total Records',
                '${stats['totalRecords'] ?? 0}',
                Icons.recycling,
                Colors.green,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _buildOverviewCard(
                'Active Days',
                '${stats['totalDays'] ?? 0}',
                Icons.calendar_today,
                Colors.blue,
              ),
            ),
          ],
        ),

        SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: _buildOverviewCard(
                'Avg Per Day',
                _calculateAveragePerDay().toStringAsFixed(1),
                Icons.trending_up,
                Colors.orange,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _buildOverviewCard(
                'Points Earned',
                '${(stats['totalDays'] ?? 0) * 2}',
                Icons.star,
                Colors.purple,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOverviewCard(String title, String value, IconData icon, Color color) {
    return Container(
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
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              Spacer(),
            ],
          ),

          SizedBox(height: 12),

          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),

          SizedBox(height: 4),

          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaterialDistributionSection() {
    if (materialDistribution.isEmpty) {
      return Container();
    }

    // Sort materials by count (descending)
    var sortedMaterials = materialDistribution.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Material Distribution',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),

        SizedBox(height: 16),

        Container(
          padding: EdgeInsets.all(20),
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
            children: [
              // Simple bar chart
              ...sortedMaterials.map((entry) {
                String material = entry.key;
                double count = entry.value;
                double maxCount = sortedMaterials.first.value;
                double percentage = (count / maxCount) * 100;

                return _buildMaterialBar(
                  material,
                  count.toInt(),
                  percentage,
                  RecyclingConfig.getColorForMaterial(material),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMaterialBar(String material, int count, double percentage, Color color) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                material.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              Text(
                '$count record${count > 1 ? 's' : ''}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),

          SizedBox(height: 6),

          Container(
            height: 8,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(4),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: percentage / 100,
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedStatsSection() {
    Map<String, Map<String, double>> materialTotals =
    Map<String, Map<String, double>>.from(stats['materialTotals'] ?? {});

    if (materialTotals.isEmpty) {
      return Container();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Detailed Breakdown',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),

        SizedBox(height: 16),

        ...materialTotals.entries.map((materialEntry) {
          String materialType = materialEntry.key;
          Map<String, double> units = materialEntry.value;

          return _buildMaterialDetailCard(materialType, units);
        }),
      ],
    );
  }

  Widget _buildMaterialDetailCard(String materialType, Map<String, double> units) {
    Color color = RecyclingConfig.getColorForMaterial(materialType);

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
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),

              SizedBox(width: 8),

              Text(
                materialType.toUpperCase(),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),

          SizedBox(height: 12),

          ...units.entries.map((unitEntry) {
            String unit = unitEntry.key;
            double amount = unitEntry.value;

            return Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    unit,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  Text(
                    amount.toStringAsFixed(amount == amount.roundToDouble() ? 0 : 1),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  double _calculateAveragePerDay() {
    int totalRecords = stats['totalRecords'] ?? 0;
    int totalDays = stats['totalDays'] ?? 0;

    if (totalDays == 0) return 0.0;
    return totalRecords / totalDays;
  }
}
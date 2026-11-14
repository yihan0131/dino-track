import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../repositories/challenge_repository.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  final ChallengeRepository _repo = ChallengeRepository();
  List<Map<String, dynamic>> _reports = [];
  bool _isLoading = true;
  final Set<String> _processingIds = {};

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() => _isLoading = true);
    try {
      final reports = await _repo.getPendingReports();
      reports.sort((a, b) {
        final aTime = a['reportedAt'];
        final bTime = b['reportedAt'];
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return (bTime as dynamic).compareTo(aTime);
      });
      if (!mounted) return;
      setState(() {
        _reports = reports;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load reports: $e')),
      );
    }
  }

  Future<void> _approve(Map<String, dynamic> report) async {
    final reportId = report['reportId'] as String;
    setState(() => _processingIds.add(reportId));
    try {
      await _repo.approveReportedPhoto(
        report['photoUrl'] as String,
        report['userChallengeId'] as String,
      );
      if (!mounted) return;
      setState(() {
        _reports.removeWhere((r) => r['reportId'] == reportId);
        _processingIds.remove(reportId);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Photo approved'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _processingIds.remove(reportId));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _reject(Map<String, dynamic> report) async {
    final reportId = report['reportId'] as String;
    setState(() => _processingIds.add(reportId));
    try {
      await _repo.rejectReportedPhoto(
        report['photoUrl'] as String,
        report['userChallengeId'] as String,
      );
      if (!mounted) return;
      setState(() {
        _reports.removeWhere((r) => r['reportId'] == reportId);
        _processingIds.remove(reportId);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Photo rejected — user penalised'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _processingIds.remove(reportId));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';
    try {
      final dt = (timestamp as Timestamp).toDate();
      return DateFormat('dd MMM yyyy, HH:mm').format(dt);
    } catch (_) {
      return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Admin — Photo Reports'),
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReports,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _reports.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  onRefresh: _loadReports,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _reports.length,
                    itemBuilder: (context, index) =>
                        _buildReportCard(_reports[index]),
                  ),
                ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline, size: 72, color: Colors.green[300]),
          const SizedBox(height: 16),
          const Text(
            'No pending reports',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildReportCard(Map<String, dynamic> report) {
    final reportId = report['reportId'] as String;
    final isProcessing = _processingIds.contains(reportId);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Photo
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(12)),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.network(
                report['photoUrl'] as String,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) => progress == null
                    ? child
                    : const Center(child: CircularProgressIndicator()),
                errorBuilder: (context, _, __) => Container(
                  color: Colors.grey[200],
                  child: const Icon(Icons.broken_image,
                      size: 48, color: Colors.grey),
                ),
              ),
            ),
          ),

          // Report details
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoRow(Icons.person_outline, 'Submitted by',
                    report['userId'] as String),
                const SizedBox(height: 6),
                _infoRow(Icons.flag_outlined, 'Reported by',
                    report['reportedBy'] as String),
                const SizedBox(height: 6),
                _infoRow(Icons.access_time, 'Reported at',
                    _formatDate(report['reportedAt'])),
                const SizedBox(height: 14),

                // Action buttons
                if (isProcessing)
                  const Center(child: CircularProgressIndicator())
                else
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _approve(report),
                          icon: const Icon(Icons.check, color: Colors.green),
                          label: const Text('Approve',
                              style: TextStyle(color: Colors.green)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.green),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _reject(report),
                          icon: const Icon(Icons.close, color: Colors.red),
                          label: const Text('Reject',
                              style: TextStyle(color: Colors.red)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 6),
        Text('$label: ', style: const TextStyle(color: Colors.grey)),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

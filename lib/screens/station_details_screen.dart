import 'package:flutter/material.dart';
import '../models/recycling_station.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

class StationDetailsScreen extends StatelessWidget {
  final RecyclingStation station;

  const StationDetailsScreen({super.key, required this.station});

  // Launch Google Maps with directions
  Future<void> _launchDirections(BuildContext context) async {
    try {
      // Get current location
      final position = await Geolocator.getCurrentPosition();
      
      // Create Google Maps URL with directions
      final url = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&origin=${position.latitude},${position.longitude}&destination=${station.latitude},${station.longitude}&travelmode=driving'
      );

      // Launch URL
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not launch Google Maps')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error getting location: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // App Bar
          SliverAppBar(
            expandedHeight: 200.0,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                station.name,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Theme.of(context).primaryColor,
                      Theme.of(context).primaryColor.withOpacity(0.7),
                    ],
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.recycling,
                    size: 80,
                    color: Colors.white.withOpacity(0.3),
                  ),
                ),
              ),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Address Section
                  _buildSection(
                    context,
                    'Location',
                    Icons.location_on,
                    station.address,
                  ),

                  const SizedBox(height: 16),

                  // Accepted Materials Section
                  _buildSection(
                    context,
                    'Accepted Materials',
                    Icons.category,
                    null,
                    child: Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      children: station.acceptedMaterials.map((material) {
                        return Chip(
                          label: Text(material),
                          backgroundColor: _getMaterialColor(material).withOpacity(0.1),
                          labelStyle: TextStyle(
                            color: _getMaterialColor(material),
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Contact Information Section
                  if (station.contactInfo != null) ...[
                    _buildSection(
                      context,
                      'Contact Information',
                      Icons.contact_phone,
                      null,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (station.contactInfo!['phone'] != null)
                            _buildContactItem(
                              context,
                              Icons.phone,
                              station.contactInfo!['phone']!,
                            ),
                          if (station.contactInfo!['email'] != null)
                            _buildContactItem(
                              context,
                              Icons.email,
                              station.contactInfo!['email']!,
                            ),
                          if (station.contactInfo!['website'] != null)
                            _buildContactItem(
                              context,
                              Icons.language,
                              station.contactInfo!['website']!,
                            ),
                          if (station.contactInfo!['opening_hours'] != null)
                            _buildContactItem(
                              context,
                              Icons.access_time,
                              station.contactInfo!['opening_hours']!,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Status Section
                  _buildSection(
                    context,
                    'Status',
                    Icons.verified,
                    station.verified ? 'Verified Station' : 'Pending Verification',
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: station.verified
                            ? Colors.green.withOpacity(0.1)
                            : Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            station.verified ? Icons.check_circle : Icons.pending,
                            color: station.verified ? Colors.green : Colors.orange,
                            size: 16,
                          ),
                          SizedBox(width: 4),
                          Text(
                            station.verified ? 'Verified' : 'Pending',
                            style: TextStyle(
                              color: station.verified ? Colors.green : Colors.orange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Navigation Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _launchDirections(context),
                      icon: Icon(Icons.directions),
                      label: Text('Get Directions'),
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    IconData icon,
    String? text, {
    Widget? child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Theme.of(context).primaryColor),
            SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        if (text != null)
          Text(
            text,
            style: TextStyle(fontSize: 16),
          ),
        if (child != null) ...[
          SizedBox(height: 8),
          child,
        ],
      ],
    );
  }

  Widget _buildContactItem(BuildContext context, IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Color _getMaterialColor(String material) {
    switch (material) {
      case 'Plastic':
        return Colors.blue;
      case 'Paper':
        return Colors.amber;
      case 'Glass':
        return Colors.teal;
      case 'Metal':
        return Colors.blueGrey;
      case 'Electronics':
        return Colors.deepPurple;
      case 'Batteries':
        return Colors.red;
      case 'Cardboard':
        return Colors.brown;
      case 'Textiles':
        return Colors.pink;
      case 'Organics':
        return Colors.green;
      case 'Hazardous Waste':
        return Colors.orange;
      default:
        return Colors.green;
    }
  }
} 
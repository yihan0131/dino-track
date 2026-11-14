import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../models/recycling_station.dart';
import 'report_station_dialog.dart';

class StationInfoCard extends StatefulWidget {
  final RecyclingStation station;
  final VoidCallback onClose;
  final VoidCallback onNavigate;
  final LatLng? currentLocation;

  const StationInfoCard({
    super.key,
    required this.station,
    required this.onClose,
    required this.onNavigate,
    this.currentLocation,
  });

  @override
  State<StationInfoCard> createState() => _StationInfoCardState();
}

class _StationInfoCardState extends State<StationInfoCard> {
  StreamSubscription<QuerySnapshot>? _reportsSubscription;
  StreamSubscription<DocumentSnapshot>? _stationSubscription;

  @override
  void initState() {
    super.initState();
    _setupStationListener();
  }

  @override
  void dispose() {
    _reportsSubscription?.cancel();
    _stationSubscription?.cancel();
    super.dispose();
  }

  void _setupStationListener() {
    if (!widget.station.id.startsWith('osm_')) {
      _stationSubscription = FirebaseFirestore.instance
          .collection('recycling_stations')
          .doc(widget.station.id)
          .snapshots()
          .listen((snapshot) {
        if (mounted && snapshot.exists) {
          final data = snapshot.data();
          if (data != null) {
            setState(() {
              // Create a new station object with updated data
              final updatedStation = RecyclingStation.fromMap({
                ...data,
                'id': widget.station.id,
              });
              
              // Update the widget's station
              widget.station.verified = updatedStation.verified;
              widget.station.status = updatedStation.status;
            });
          }
        }
      }, onError: (error) {
        print('Error listening to station: $error');
      });
    }
  }

  // Helper method to get icon for material type
  IconData _getIconForMaterial(String material) {
    switch (material) {
      case 'Plastic':
        return Icons.local_drink;
      case 'Paper':
        return Icons.description;
      case 'Glass':
        return Icons.wine_bar;
      case 'Metal':
        return Icons.settings;
      case 'Electronics':
        return Icons.devices;
      case 'Batteries':
        return Icons.battery_full;
      case 'Cardboard':
        return Icons.inventory_2;
      case 'Textiles':
        return Icons.checkroom;
      case 'Organics':
        return Icons.compost;
      case 'Hazardous Waste':
        return Icons.warning;
      default:
        return Icons.recycling;
    }
  }

  // Helper method to get color for material type
  Color _getColorForMaterial(String material) {
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

  @override
  Widget build(BuildContext context) {
    final secondaryColor = Colors.green;

    String distanceString = 'Calculate route';
    if (widget.currentLocation != null) {
      final distanceInMeters = Geolocator.distanceBetween(
        widget.currentLocation!.latitude,
        widget.currentLocation!.longitude,
        widget.station.latitude,
        widget.station.longitude,
      );

      final distanceInKm = distanceInMeters / 1000;
      distanceString = '${distanceInKm.toStringAsFixed(1)} km';
    }

    return Container(
      margin: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top section with image and basic info
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Station image or placeholder
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: widget.station.imageUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            widget.station.imageUrl!,
                            fit: BoxFit.cover,
                          ),
                        )
                      : Center(
                          child: Icon(
                            widget.station.acceptedMaterials.isNotEmpty
                                ? _getIconForMaterial(widget.station.acceptedMaterials.first)
                                : Icons.recycling,
                            size: 40,
                            color: widget.station.acceptedMaterials.isNotEmpty
                                ? _getColorForMaterial(widget.station.acceptedMaterials.first)
                                : Colors.green,
                          ),
                        ),
                ),

                SizedBox(width: 16),

                // Station info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Station name with verified badge and pending changes indicator
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.station.name,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (widget.station.verified)
                            Container(
                              margin: EdgeInsets.only(left: 4),
                              padding: EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.green.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.verified,
                                color: Colors.green,
                                size: 16,
                              ),
                            ),
                        ],
                      ),

                      SizedBox(height: 4),

                      // Address with icon
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 16,
                            color: Colors.grey,
                          ),
                          SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              widget.station.address,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade700,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 8),

                      // Rating and distance
                      Row(
                        children: [
                          // Rating stars
                          if (widget.station.rating > 0)
                            Row(
                              children: [
                                Icon(
                                  Icons.star,
                                  color: Colors.amber,
                                  size: 16,
                                ),
                                SizedBox(width: 2),
                                Text(
                                  widget.station.rating.toStringAsFixed(1),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(width: 8),
                              ],
                            ),

                          // Distance (would need to be calculated)
                          Icon(
                            Icons.directions,
                            color: secondaryColor,
                            size: 16,
                          ),
                          SizedBox(width: 2),
                          Text(
                            distanceString,
                            style: TextStyle(
                              fontSize: 14,
                              color: secondaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Close button
                Positioned(
                  top: 8,
                  right: 8,
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.report_problem),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => ReportStationDialog(station: widget.station),
                          );
                        },
                        tooltip: 'Report incorrect information',
                      ),
                      IconButton(
                        icon: Icon(Icons.close),
                        onPressed: widget.onClose,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Materials divider
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Text(
                  'Accepted Materials',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Container(
                    height: 1,
                    color: Colors.grey.shade300,
                  ),
                ),
              ],
            ),
          ),

          // Materials list
          Container(
            height: 56,
            margin: EdgeInsets.symmetric(vertical: 8),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 16),
              itemCount: widget.station.acceptedMaterials.length,
              itemBuilder: (context, index) {
                final material = widget.station.acceptedMaterials[index];
                return Container(
                  margin: EdgeInsets.only(right: 8),
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _getColorForMaterial(material).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _getColorForMaterial(material).withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getIconForMaterial(material),
                        color: _getColorForMaterial(material),
                        size: 18,
                      ),
                      SizedBox(width: 6),
                      Text(
                        material,
                        style: TextStyle(
                          fontSize: 14,
                          color: _getColorForMaterial(material).withOpacity(0.8),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Contact info section (if available)
          if (widget.station.contactInfo != null && widget.station.contactInfo!.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Contact divider
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    children: [
                      Text(
                        'Contact Information',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          height: 1,
                          color: Colors.grey.shade300,
                        ),
                      ),
                    ],
                  ),
                ),

                // Contact details
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    children: [
                      // Phone
                      if (widget.station.contactInfo!.containsKey('phone'))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4.0),
                          child: Row(
                            children: [
                              Icon(
                                Icons.phone,
                                size: 16,
                                color: Colors.grey.shade700,
                              ),
                              SizedBox(width: 8),
                              Text(
                                widget.station.contactInfo!['phone']!,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Website
                      if (widget.station.contactInfo!.containsKey('website'))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4.0),
                          child: Row(
                            children: [
                              Icon(
                                Icons.language,
                                size: 16,
                                color: Colors.grey.shade700,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  widget.station.contactInfo!['website']!,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.blue,
                                    decoration: TextDecoration.underline,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Email
                      if (widget.station.contactInfo!.containsKey('email'))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4.0),
                          child: Row(
                            children: [
                              Icon(
                                Icons.email,
                                size: 16,
                                color: Colors.grey.shade700,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  widget.station.contactInfo!['email']!,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.blue,
                                    decoration: TextDecoration.underline,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Opening hours
                      if (widget.station.contactInfo!.containsKey('opening_hours'))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 16,
                                color: Colors.grey.shade700,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  widget.station.contactInfo!['opening_hours']!,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade700,
                                  ),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),

                SizedBox(height: 8),
              ],
            ),

          // Button row
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                // Navigate button
                Expanded(
                  child: ElevatedButton(
                    onPressed: widget.onNavigate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: secondaryColor,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.navigation, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Get Directions',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
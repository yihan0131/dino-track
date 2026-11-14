import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import '../models/recycling_station.dart';
import '../widgets/station_info_card.dart';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // Map controller
  MapController? _mapController;
  bool _isMapReady = false;

  // FIX: Replace MarkerClusterController with a basic GlobalKey
  final GlobalKey _clusterKey = GlobalKey();

  // Current location
  LatLng? _currentLocation;
  bool _isLoadingLocation = false;

  // Selected station
  RecyclingStation? _selectedStation;

  // Search functionality
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  // Stations data
  List<RecyclingStation> _stations = [];
  bool _isLoadingStations = true;
  // Only the latest station request may update the map; older ones are stale.
  int _stationsRequestId = 0;

  // Default map center (will be updated with user location)
  LatLng _mapCenter = LatLng(3.1390, 101.6869); // Kuala Lumpur by default
  double _currentZoom = 13.0;

  String _currentLocationName = "Loading...";

  // New station marker
  LatLng? _newStationLocation;
  final TextEditingController _stationNameController = TextEditingController();
  final TextEditingController _stationAddressController = TextEditingController();
  final List<String> _acceptedMaterials = [];

  // Material type options with associated icons for visual enhancement
  final List<Map<String, dynamic>> _materialTypes = [
    {'name': 'Plastic', 'icon': Icons.local_drink},
    {'name': 'Paper', 'icon': Icons.description},
    {'name': 'Glass', 'icon': Icons.wine_bar},
    {'name': 'Metal', 'icon': Icons.settings},
    {'name': 'Electronics', 'icon': Icons.devices},
    {'name': 'Batteries', 'icon': Icons.battery_full},
    {'name': 'Cardboard', 'icon': Icons.inventory_2},
    {'name': 'Textiles', 'icon': Icons.checkroom},
    {'name': 'Organics', 'icon': Icons.compost},
    {'name': 'Hazardous Waste', 'icon': Icons.warning},
  ];

  // Add these new variables for search suggestions
  List<Map<String, dynamic>> _searchSuggestions = [];
  bool _showSuggestions = false;
  Timer? _debounceTimer;

  // Add this new variable for the stations subscription
  StreamSubscription<QuerySnapshot>? _stationsSubscription;

  // Add these new controllers
  final TextEditingController _newStationLatController = TextEditingController();
  final TextEditingController _newStationLngController = TextEditingController();

  // Add this new variable to track form state
  bool _isFormMinimized = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    // Delay map operations until after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Stations load from onMapReady once the map has bounds.
      _getCurrentLocation();
      _setupStationsListener();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _stationNameController.dispose();
    _stationAddressController.dispose();
    _newStationLatController.dispose();
    _newStationLngController.dispose();
    _stationsSubscription?.cancel();
    super.dispose();
  }

  // Helper method to extract contact information from OSM tags
  Map<String, String>? _extractContactInfo(Map<String, dynamic> tags) {
    final contactInfo = <String, String>{};

    // Extract phone number
    if (tags['phone'] != null) {
      contactInfo['phone'] = tags['phone'];
    } else if (tags['contact:phone'] != null) {
      contactInfo['phone'] = tags['contact:phone'];
    }

    // Extract website
    if (tags['website'] != null) {
      contactInfo['website'] = tags['website'];
    } else if (tags['contact:website'] != null) {
      contactInfo['website'] = tags['contact:website'];
    }

    // Extract email
    if (tags['email'] != null) {
      contactInfo['email'] = tags['email'];
    } else if (tags['contact:email'] != null) {
      contactInfo['email'] = tags['contact:email'];
    }

    // Extract opening hours
    if (tags['opening_hours'] != null) {
      contactInfo['opening_hours'] = tags['opening_hours'];
    }

    // Only return the map if it contains data
    return contactInfo.isNotEmpty ? contactInfo : null;
  }

  // Search for location by address using free OpenStreetMap Nominatim API
  Future<void> _searchLocation(String address) async {
    if (address.isEmpty) return;

    setState(() {
      _isSearching = true;
    });

    try {
      // URL encode the address
      final encodedAddress = Uri.encodeComponent(address);

      // Call Nominatim API (OpenStreetMap's free geocoding service)
      final response = await http.get(
        Uri.parse('https://nominatim.openstreetmap.org/search?q=$encodedAddress&format=json'),
        // Add required headers for Nominatim API
        headers: {
          'User-Agent': 'RecyclingStationApp/1.0', // Required by Nominatim ToS
          'Accept-Language': 'en-US,en', // Optional: preferred language for results
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;

        if (data.isNotEmpty) {
          // Get coordinates from first result
          final lat = double.parse(data[0]['lat']);
          final lon = double.parse(data[0]['lon']);
          final latLng = LatLng(lat, lon);

          setState(() {
            _mapCenter = latLng;
            _isSearching = false;
          });

          // FIX: Update how we move the map
          _mapController?.move(_mapCenter, _currentZoom);

          // Find nearby stations (optional)
          _findNearbyStations(latLng);
        } else {
          setState(() {
            _isSearching = false;
          });
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location not found')),
          );
        }
      } else {
        throw Exception('API Error: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _isSearching = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Search failed: $e')),
      );
    }
  }

  // Find recycling stations near a location
  void _findNearbyStations(LatLng location) {
    // Calculate distances to all stations
    final nearbyStations = _stations.map((station) {
      // Calculate distance between points
      final stationLatLng = LatLng(station.latitude, station.longitude);
      final distanceInMeters = Geolocator.distanceBetween(
        location.latitude,
        location.longitude,
        stationLatLng.latitude,
        stationLatLng.longitude,
      );

      return {
        'station': station,
        'distance': distanceInMeters,
      };
    }).toList();

    // Sort by distance
    nearbyStations.sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));

    // If there are nearby stations, show a message
    if (nearbyStations.isNotEmpty) {
      final nearest = nearbyStations.first;
      final station = nearest['station'] as RecyclingStation;
      final distance = (nearest['distance'] as double) / 1000; // Convert to km

      // Adjust map to show nearby stations
      _adjustMapToShowNearbyStations(location);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.fromLTRB(10, 0, 10, 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Text('Nearest station: ${station.name} (${distance.toStringAsFixed(1)} km)'),
          action: SnackBarAction(
            label: 'View',
            onPressed: () {
              setState(() {
                _selectedStation = station;
              });

              // Center map on station
              _mapController?.move(
                LatLng(station.latitude, station.longitude),
                _currentZoom,
              );
            },
          ),
        ),
      );
    }
  }

  // Handle map tap for adding new station
  void _handleMapTap(TapPosition tapPosition, LatLng point) {
    setState(() {
      if (_newStationLocation != null) {
        // We're in add mode, update the location
        _newStationLocation = point;
        
        // Update the coordinate text fields
        _newStationLatController.text = point.latitude.toStringAsFixed(6);
        _newStationLngController.text = point.longitude.toStringAsFixed(6);
        
        // Show feedback to user
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.fromLTRB(10, 0, 10, 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Text('Location selected: ${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}'),
            duration: Duration(seconds: 2),
          ),
        );
      } else if (_selectedStation != null) {
      // Clear selected station when tapping on map
        _selectedStation = null;
      }
    });
  }

  // Toggle add mode for new station
  void _toggleAddMode() {
    setState(() {
      if (_newStationLocation == null) {
        // Enter add mode
        _newStationLocation = _mapCenter;
        _selectedStation = null;
        
        // Initialize coordinate text fields
        _newStationLatController.text = _mapCenter.latitude.toStringAsFixed(6);
        _newStationLngController.text = _mapCenter.longitude.toStringAsFixed(6);
        
        // Show instructions to user
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.fromLTRB(10, 0, 10, 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Text('Tap on the map to select the recycling station location or enter coordinates manually'),
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        // Exit add mode
        _newStationLocation = null;
        _stationNameController.clear();
        _stationAddressController.clear();
        _newStationLatController.clear();
        _newStationLngController.clear();
        _acceptedMaterials.clear();
      }
    });
  }

  // Submit new station to Firebase
  Future<void> _submitNewStation() async {
    if (_newStationLocation == null) return;
    if (_stationNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.fromLTRB(10, 0, 10, 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Text('Please enter a station name'),
        ),
      );
      return;
    }
    if (_stationAddressController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.fromLTRB(10, 0, 10, 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Text('Please enter a station address'),
        ),
      );
      return;
    }
    if (_acceptedMaterials.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.fromLTRB(10, 0, 10, 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Text('Please select at least one accepted material'),
        ),
      );
      return;
    }

    try {
      // Get current user for attribution
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.fromLTRB(10, 0, 10, 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Text('Please sign in to submit a station'),
          ),
        );
        return;
      }

      // Create new station
      final newStation = RecyclingStation(
        id: 'temporary-id', // Will be replaced by Firestore
        name: _stationNameController.text,
        address: _stationAddressController.text,
        latitude: _newStationLocation!.latitude,
        longitude: _newStationLocation!.longitude,
        acceptedMaterials: List.from(_acceptedMaterials),
        verified: false,
        submittedBy: user.uid,
        submissionDate: DateTime.now(),
        status: 'pending',
      );

      // Add to Firestore
      await FirebaseFirestore.instance.collection('recycling_stations').add(
        newStation.toMap(),
      );

      // Reset UI
      setState(() {
        _newStationLocation = null;
        _stationNameController.clear();
        _stationAddressController.clear();
        _newStationLatController.clear();
        _newStationLngController.clear();
        _acceptedMaterials.clear();
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.fromLTRB(10, 0, 10, 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Text('Station submitted for review. It will appear on the map once approved.'),
          duration: Duration(seconds: 4),
        ),
      );

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.fromLTRB(10, 0, 10, 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Text('Failed to submit station: $e'),
        ),
      );
    }
  }

  void _onMapMoved() {
    if (!_isMapReady || _mapController == null) return;

    // Get camera properties
    final center = _mapController!.camera.center;
    final zoom = _mapController!.camera.zoom;

    setState(() {
      _mapCenter = center;
      _currentZoom = zoom;
    });
    
    // Load stations for the new view
    _loadStationsFromOSM();
  }

  // Add this new method to setup the stations listener
  void _setupStationsListener() {
    _stationsSubscription = FirebaseFirestore.instance
        .collection('recycling_stations')
        .where('status', isEqualTo: 'approved')  // Only listen to approved stations
        .snapshots()
        .listen((snapshot) {
      // Update stations when Firebase data changes
      final firebaseStations = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return RecyclingStation.fromMap(data);
      }).toList();

      setState(() {
        // Keep OSM stations that don't have verified replacements
        final osmStations = _stations.where((s) => 
          s.id.startsWith('osm_') && 
          !firebaseStations.any((fs) => 
            fs.verified && 
            fs.status == 'approved' && 
            fs.originalStationId == s.id
          )
        ).toList();
        
        // Add all Firebase stations
        _stations = [...osmStations, ...firebaseStations];
      });
    });
  }

  // Fix for the _loadStationsFromOSM method
  Future<void> _loadStationsFromOSM() async {
    if (!_isMapReady || _mapController == null) return;

    final requestId = ++_stationsRequestId;
    setState(() {
      _isLoadingStations = true;
    });

    try {
      // Get the visible map bounds
      final bounds = _mapController!.camera.visibleBounds;
      
      // Extract coordinates for the query
      final south = bounds.south;
      final west = bounds.west;
      final north = bounds.north;
      final east = bounds.east;

      final query = '''
    [out:json][timeout:25];
    (
      node["amenity"="recycling"]($south,$west,$north,$east);
      way["amenity"="recycling"]($south,$west,$north,$east);
      relation["amenity"="recycling"]($south,$west,$north,$east);
      
      node["amenity"="waste_disposal"]($south,$west,$north,$east);
      way["amenity"="waste_disposal"]($south,$west,$north,$east);
    );
    out body;
    >;
    out skel qt;
    ''';

      final encodedQuery = Uri.encodeComponent(query);
      final response = await http.get(
        Uri.parse('https://overpass-api.de/api/interpreter?data=$encodedQuery'),
        headers: {
          'User-Agent': 'RecyclingStationApp/1.0',
        },
      );

      // A newer request started (map moved or location found); drop this one.
      if (!mounted || requestId != _stationsRequestId) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final elements = data['elements'] as List;

        // Convert OSM elements to RecyclingStation objects
        final List<RecyclingStation> osmStations = [];

        for (var element in elements) {
          if (element['type'] == 'node') {
            final tags = element['tags'] ?? {};
            final List<String> materials = [];

            // Check common recycling types
            if (tags['recycling:glass'] == 'yes') materials.add('Glass');
            if (tags['recycling:paper'] == 'yes') materials.add('Paper');
            if (tags['recycling:plastic'] == 'yes') materials.add('Plastic');
            if (tags['recycling:metal'] == 'yes') materials.add('Metal');
            if (tags['recycling:batteries'] == 'yes') materials.add('Batteries');
            if (tags['recycling:clothes'] == 'yes') materials.add('Textiles');
            if (tags['recycling:electronics'] == 'yes') materials.add('Electronics');
            if (tags['recycling:organic'] == 'yes') materials.add('Organics');
            if (tags['recycling:hazardous_waste'] == 'yes') materials.add('Hazardous Waste');
            if (tags['recycling:cardboard'] == 'yes') materials.add('Cardboard');

            if (materials.isEmpty && tags['amenity'] == 'recycling') {
              materials.add('Recycling');
            }

            if (materials.isNotEmpty || tags['amenity'] == 'recycling') {
              String address = 'Unknown address';
              if (tags['addr:street'] != null) {
                final List<String> addressParts = [];
                if (tags['addr:housenumber'] != null) {
                  addressParts.add(tags['addr:housenumber']);
                }
                addressParts.add(tags['addr:street']);
                if (tags['addr:city'] != null) {
                  addressParts.add(tags['addr:city']);
                }
                if (tags['addr:postcode'] != null) {
                  addressParts.add(tags['addr:postcode']);
                }
                address = addressParts.join(', ');
              }

              final String stationId = 'osm_${element['id']}';
              
              // Check if we have a verified station that replaces this OSM station
              final hasVerifiedReplacement = _stations.any((s) => 
                !s.id.startsWith('osm_') && 
                s.verified && 
                s.status == 'approved' &&
                s.originalStationId == stationId
              );

              // Only add OSM station if there's no verified replacement
              if (!hasVerifiedReplacement) {
                final newStation = RecyclingStation(
                  id: stationId,
                  name: tags['name'] ?? tags['operator'] ?? 'Recycling Station',
                  address: address,
                  latitude: element['lat'],
                  longitude: element['lon'],
                  acceptedMaterials: materials,
                  verified: true,
                  submittedBy: 'osm',
                  contactInfo: _extractContactInfo(tags),
                );
                osmStations.add(newStation);
              }
            }
          }
        }

        setState(() {
          // Keep Firebase stations and add OSM stations
          final firebaseStations = _stations.where((s) => 
            !s.id.startsWith('osm_') && 
            s.status == 'approved'  // Only show approved stations
          ).toList();
          _stations = [...firebaseStations, ...osmStations];
          _isLoadingStations = false;
        });

      } else {
        throw Exception('API Error: ${response.statusCode}');
      }
    } catch (e) {
      print('Error loading stations from OSM: $e');
      if (!mounted || requestId != _stationsRequestId) return;
      setState(() {
        _isLoadingStations = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.fromLTRB(10, 0, 10, 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Text('Failed to load recycling stations from OpenStreetMap: $e'),
        ),
      );
    }
  }

  // Add the reverse geocoding method
  // Modified _getAddressFromLatLng method to show shorter location names
  Future<void> _getAddressFromLatLng(LatLng latLng) async {
    setState(() {
      _currentLocationName = "Getting location...";
    });

    try {
      // Use OpenStreetMap's Nominatim for reverse geocoding
      final response = await http.get(
        Uri.parse('https://nominatim.openstreetmap.org/reverse?format=json&lat=${latLng.latitude}&lon=${latLng.longitude}&zoom=18&addressdetails=1'),
        headers: {
          'User-Agent': 'RecyclingStationApp/1.0', // Required by Nominatim ToS
          'Accept-Language': 'en-US,en', // Optional: preferred language for results
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Initialize with a fallback
        String locationName = "Current Location";

        // Try to extract the most concise location name possible
        if (data['address'] != null) {
          final address = data['address'];

          // Prioritize finding the most meaningful, concise location name
          // First try neighborhood or suburb
          if (address['neighbourhood'] != null) {
            locationName = address['neighbourhood'];
          } else if (address['suburb'] != null) {
            locationName = address['suburb'];
          }
          // If not available, try city, town or village
          else if (address['city'] != null) {
            locationName = address['city'];
          } else if (address['town'] != null) {
            locationName = address['town'];
          } else if (address['village'] != null) {
            locationName = address['village'];
          }
          // If still nothing, try road name
          else if (address['road'] != null) {
            locationName = address['road'];
          }

          // Optionally add district if it would be helpful and not redundant
          if (address['city_district'] != null &&
              !locationName.contains(address['city_district']) &&
              locationName.length < 15) {
            locationName = "${address['city_district']}, $locationName";
          }
        } else if (data['name'] != null) {
          // If address structure isn't available but there's a name
          locationName = data['name'];
        }

        setState(() {
          _currentLocationName = locationName;
        });
      } else {
        throw Exception('API Error: ${response.statusCode}');
      }
    } catch (e) {
      print("Error getting address: $e");
      setState(() {
        _currentLocationName = "Current Location";
      });
    }
  }

// Update the _getCurrentLocation method to use reverse geocoding
  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
      _currentLocationName = "Loading...";
    });

    try {
      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permission denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permission permanently denied');
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition()
          .timeout(const Duration(seconds: 10));
      final latLng = LatLng(position.latitude, position.longitude);

      setState(() {
        _currentLocation = latLng;
        _mapCenter = latLng;
        _isLoadingLocation = false;
      });

      // Get location name
      await _getAddressFromLatLng(latLng);

      if (_isMapReady && _mapController != null) {
        _mapController?.move(_currentLocation!, _currentZoom);
        _loadStationsFromOSM();
      }
    } catch (e) {
      // Fall back to the default map center so stations still load.
      setState(() {
        _isLoadingLocation = false;
        _currentLocationName = "Kuala Lumpur";
      });
      if (_isMapReady && _mapController != null) {
        _mapController?.move(_mapCenter, _currentZoom);
        _loadStationsFromOSM();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location unavailable, showing Kuala Lumpur')),
        );
      }
    }
  }

  // Get icon for material type
  IconData _getIconForMaterial(String material) {
    final item = _materialTypes.firstWhere(
          (item) => item['name'] == material,
      orElse: () => {'name': material, 'icon': Icons.recycling},
    );
    return item['icon'];
  }

  // Get a color based on material type for visual variety
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

  // Add this new method for getting search suggestions
  Future<void> _getSearchSuggestions(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchSuggestions = [];
        _showSuggestions = false;
      });
      return;
    }

    try {
      // First, search in our existing stations
      final localSuggestions = _stations.where((station) {
        final searchLower = query.toLowerCase();
        final nameMatch = station.name.toLowerCase().contains(searchLower);
        final addressMatch = station.address.toLowerCase().contains(searchLower);
        final materialsMatch = station.acceptedMaterials.any(
          (material) => material.toLowerCase().contains(searchLower)
        );
        return nameMatch || addressMatch || materialsMatch;
      }).map((station) => {
        'display_name': '${station.name} - ${station.address}',
        'lat': station.latitude,
        'lon': station.longitude,
        'is_local': true,
        'station': station,
      }).toList();

      // Then, search using Nominatim API
      final encodedQuery = Uri.encodeComponent(query);
      final response = await http.get(
        Uri.parse('https://nominatim.openstreetmap.org/search?q=$encodedQuery&format=json&limit=5'),
        headers: {
          'User-Agent': 'RecyclingStationApp/1.0',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final osmSuggestions = data.map((item) => {
            'display_name': item['display_name'],
            'lat': double.parse(item['lat']),
            'lon': double.parse(item['lon']),
          'is_local': false,
          }).toList();

        setState(() {
          // Combine local and OSM suggestions, with local results first
          _searchSuggestions = [...localSuggestions, ...osmSuggestions];
          _showSuggestions = true;
        });
      }
    } catch (e) {
      print('Error getting suggestions: $e');
    }
  }

  // Add this method to find nearest station and appropriate zoom level
  void _adjustMapToShowNearbyStations(LatLng location) {
    if (_stations.isEmpty) return;

    // Find the nearest station
    double? nearestDistance;
    RecyclingStation? nearestStation;

    for (var station in _stations) {
      final distance = Geolocator.distanceBetween(
        location.latitude,
        location.longitude,
        station.latitude,
        station.longitude,
      );

      if (nearestDistance == null || distance < nearestDistance) {
        nearestDistance = distance;
        nearestStation = station;
      }
    }

    if (nearestStation != null) {
      // Calculate appropriate zoom level based on distance
      // Closer stations = higher zoom level
      double newZoom;
      if (nearestDistance! <= 500) { // Within 500m
        newZoom = 15.0;
      } else if (nearestDistance <= 2000) { // Within 2km
        newZoom = 14.0;
      } else if (nearestDistance <= 5000) { // Within 5km
        newZoom = 13.0;
      } else if (nearestDistance <= 10000) { // Within 10km
        newZoom = 12.0;
      } else {
        newZoom = 11.0; // Default for distances > 10km
      }

      setState(() {
        _currentZoom = newZoom;
      });
    }
  }

  // Update the location selection handler
  void _handleLocationSelection(Map<String, dynamic> location) async {
    final latLng = LatLng(location['lat'], location['lon']);
    
    setState(() {
      _mapCenter = latLng;
      _showSuggestions = false;
      _searchController.text = location['display_name'];
      // Start with a wider zoom level to see more area
      _currentZoom = 11.0;
    });

    // Move map to selected location with initial wider zoom
    _mapController?.move(_mapCenter, _currentZoom);
    
    // If it's a local station, select it and adjust zoom
    if (location['is_local'] == true) {
      final station = location['station'] as RecyclingStation;
      setState(() {
        _selectedStation = station;
      });
      _adjustMapToShowNearbyStations(latLng);
      return;
    }

    // For OSM locations, proceed with normal search
    await _searchLocation(location['display_name']);

    // First load stations in the area
    await _loadStationsFromOSM();

    // If no stations found, try loading with a wider area by decreasing zoom
    if (_stations.isEmpty) {
      setState(() {
        _currentZoom = 9.0; // Zoom out more to see a wider area
      });
      _mapController?.move(_mapCenter, _currentZoom);
      await _loadStationsFromOSM();

      // If still no stations, try one more time with even wider area
      if (_stations.isEmpty) {
        setState(() {
          _currentZoom = 7.0; // Zoom out even more
        });
        _mapController?.move(_mapCenter, _currentZoom);
        await _loadStationsFromOSM();

        // If still no stations found, show a message to the user
        if (_stations.isEmpty) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              margin: EdgeInsets.fromLTRB(10, 0, 10, 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              content: Text('No recycling stations found in this area. Try searching nearby areas or add a new station.'),
              duration: Duration(seconds: 4),
              action: SnackBarAction(
                label: 'Add Station',
                onPressed: _toggleAddMode,
              ),
            ),
          );
        }
      }
    }
  }

  // Add this new method to update marker position from coordinates
  void _updateNewStationLocationFromCoordinates() {
    try {
      final lat = double.parse(_newStationLatController.text);
      final lng = double.parse(_newStationLngController.text);
      
      if (lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180) {
        setState(() {
          _newStationLocation = LatLng(lat, lng);
          _mapCenter = _newStationLocation!;
        });
        _mapController?.move(_newStationLocation!, _currentZoom);
      }
    } catch (e) {
      // Invalid coordinates, ignore
    }
  }

  // Add this method to toggle form state
  void _toggleFormMinimize() {
    setState(() {
      _isFormMinimized = !_isFormMinimized;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Theme colors
    final primaryColor = Theme.of(context).primaryColor;
    final secondaryColor = Colors.green;

    return Scaffold(
      body: Stack(
        children: [
          // Map with rounded corners
          ClipRRect(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(30),
              topRight: Radius.circular(30),
            ),
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _mapCenter,
                initialZoom: _currentZoom,
                maxZoom: 18.0,
                minZoom: 3.0,
                onTap: (tapPosition, point) => _handleMapTap(tapPosition, point),
                onMapEvent: (event) {
                  if (event is MapEventMoveEnd) {
                    _onMapMoved();
                  }
                },
                onMapReady: () {
                  setState(() {
                    _isMapReady = true;
                  });
                  // Stations could not load before the map was ready.
                  _loadStationsFromOSM();
                },
              ),
              children: [
                // Base tile layer with lighter style
                TileLayer(
                  // CARTO basemaps now require an API key; OpenStreetMap tiles are free.
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.recyclingapp',
                ),

                // Custom markers for existing stations
                if (_isMapReady && _mapController != null)
                MarkerClusterLayer(
                  key: _clusterKey,
                  mapController: _mapController!,
                  mapCamera: _mapController!.camera,
                  options: MarkerClusterLayerOptions(
                    maxClusterRadius: 120,
                    size: const Size(40, 40),
                    padding: const EdgeInsets.all(50),
                    zoomToBoundsOnClick: true,
                    centerMarkerOnClick: true,
                    spiderfyCircleRadius: 80,
                    spiderfySpiralDistanceMultiplier: 2,
                    disableClusteringAtZoom: 15,
                    markers: _stations.map((station) {
                      // Set a primary material for the marker color
                      String primaryMaterial = station.acceptedMaterials.isNotEmpty
                          ? station.acceptedMaterials.first
                          : 'Recycling';

                      Color markerColor = _getColorForMaterial(primaryMaterial);

                      return Marker(
                        width: 60.0,
                        height: 80.0, // Increased height to accommodate the types count
                        point: LatLng(station.latitude, station.longitude),
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedStation = station;
                              _newStationLocation = null;
                            });
                          },
                          child: AnimatedContainer(
                            duration: Duration(milliseconds: 300),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Circular avatar with material icon
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 6,
                                        offset: Offset(0, 3),
                                      ),
                                    ],
                                    border: Border.all(
                                      color: station.verified ? Colors.green : Colors.orange,
                                      width: 3,
                                    ),
                                  ),
                                  child: ClipOval(
                                    child: Container(
                                      color: markerColor.withOpacity(0.2),
                                      child: Center(
                                        child: Icon(
                                          _getIconForMaterial(primaryMaterial),
                                          color: markerColor,
                                          size: 24,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                                // Number of materials
                                if (station.acceptedMaterials.length > 1)
                                  Container(
                                    margin: EdgeInsets.only(top: 4),
                                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 2,
                                          offset: Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      '${station.acceptedMaterials.length}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                    builder: (context, markers) {
                      return GestureDetector(
                        onTap: () {
                          // Calculate bounds of all markers in this cluster
                          double minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;
                          for (final marker in markers) {
                            minLat = math.min(minLat, marker.point.latitude);
                            maxLat = math.max(maxLat, marker.point.latitude);
                            minLng = math.min(minLng, marker.point.longitude);
                            maxLng = math.max(maxLng, marker.point.longitude);
                          }

                          // Calculate center point
                          final centerLat = (minLat + maxLat) / 2;
                          final centerLng = (minLng + maxLng) / 2;
                          
                          // Calculate appropriate zoom level based on the spread
                          final latSpread = (maxLat - minLat).abs();
                          final lngSpread = (maxLng - minLng).abs();
                          final maxSpread = math.max(latSpread, lngSpread);
                          
                          // Determine zoom level based on spread with more granular levels
                          double zoom;
                          if (maxSpread <= 0.001) {
                            zoom = 17.0;     // Extremely close markers
                          } else if (maxSpread <= 0.005) zoom = 16.0; // Very close markers
                          else if (maxSpread <= 0.01) zoom = 15.0;  // Close markers
                          else if (maxSpread <= 0.05) zoom = 14.0;  // Moderate spread
                          else if (maxSpread <= 0.1) zoom = 13.0;   // Wide spread
                          else zoom = 12.0;                         // Very wide spread

                          // Add a small buffer to the zoom level to ensure all markers are visible
                          zoom -= 0.5;

                          // Move to the center of the cluster with appropriate zoom
                          _mapController?.move(
                            LatLng(centerLat, centerLng),
                            zoom
                          );

                          // Force a rebuild of the cluster layer
                          setState(() {});
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 6,
                                offset: Offset(0, 3),
                              ),
                            ],
                            border: Border.all(
                              color: Colors.green,
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              markers.length.toString(),
                              style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // User location marker (updated for v7.0.0)
                if (_currentLocation != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        width: 50.0,
                        height: 50.0,
                        point: _currentLocation!,
                        child: Container(
                          child: Column(
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade500,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 4,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Text(
                                    'You',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              // Pulsing effect container at the bottom
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade200.withOpacity(0.5),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                // Marker for new station location (updated for v7.0.0)
                if (_newStationLocation != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        width: 40.0,
                        height: 60.0,
                        point: _newStationLocation!,
                        child: Container(
                          child: Column(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: Colors.red.shade400,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.location_on,
                                  color: Colors.white,
                                  size: 24.0,
                                ),
                              ),
                              // Shadow below pin
                              Container(
                                margin: EdgeInsets.only(top: 2),
                                width: 12,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          // Updated search bar with suggestions
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 16, 16, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Header with route name and location with submit button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Location indicator (left side) - with constrained width
                      Expanded(
                        child: Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              color: secondaryColor,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Current Location',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  Text(
                                    _currentLocationName,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Add some space between location and button
                      SizedBox(width: 12),

                      // Submit station button (right side)
                      Container(
                        decoration: BoxDecoration(
                          color: secondaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: _toggleAddMode,
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.add_location_alt,
                                    color: secondaryColor,
                                    size: 16,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    "Add Station",
                                    style: TextStyle(
                                      color: secondaryColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Search bar with suggestions
                  Container(
                    margin: EdgeInsets.only(top: 16),
                    child: Row(
                      children: [
                        // Search input
                        Expanded(
                          flex: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.search, color: Colors.grey),
                                SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: _searchController,
                                    decoration: const InputDecoration(
                                      hintText: 'Search location',
                                      border: InputBorder.none,
                                      hintStyle: TextStyle(color: Colors.grey),
                                    ),
                                    onChanged: (value) {
                                      if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
                                      _debounceTimer = Timer(const Duration(milliseconds: 500), () {
                                        _getSearchSuggestions(value);
                                      });
                                    },
                                  ),
                                ),
                                if (_isSearching)
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.0,
                                      valueColor: AlwaysStoppedAnimation<Color>(secondaryColor),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Suggestions dropdown
                  if (_showSuggestions && _searchSuggestions.isNotEmpty)
                    Container(
                      margin: EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Material(
                          color: Colors.transparent,
                          child: Column(
                            children: _searchSuggestions.map((suggestion) {
                              return InkWell(
                                onTap: () => _handleLocationSelection(suggestion),
                                child: Container(
                                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  child: Row(
                                    children: [
                                      Icon(Icons.location_on, color: Colors.grey, size: 20),
                                      SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          suggestion['display_name'],
                                          style: TextStyle(fontSize: 14),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Map controls
          Positioned(
            bottom: _selectedStation != null ? 216 : 24,
            right: 16,
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Zoom in
                      ClipRRect(
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              final newZoom = _currentZoom + 1;
                              setState(() {
                                _currentZoom = newZoom.clamp(3.0, 18.0);
                              });
                              _mapController?.move(_mapCenter, _currentZoom);
                            },
                            child: Container(
                              width: 40,
                              height: 40,
                              alignment: Alignment.center,
                              child: Icon(Icons.add, color: Colors.black87),
                            ),
                          ),
                        ),
                      ),

                      // Divider
                      Container(
                        height: 1,
                        color: Colors.grey.shade300,
                      ),

                      // Zoom out
                      ClipRRect(
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(16),
                          bottomRight: Radius.circular(16),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              final newZoom = _currentZoom - 1;
                              setState(() {
                                _currentZoom = newZoom.clamp(3.0, 18.0);
                              });
                              _mapController?.move(_mapCenter, _currentZoom);
                            },
                            child: Container(
                              width: 40,
                              height: 40,
                              alignment: Alignment.center,
                              child: Icon(Icons.remove, color: Colors.black87),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // My location button
                Container(
                  margin: EdgeInsets.only(top: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _getCurrentLocation,
                        child: Container(
                          padding: EdgeInsets.all(12),
                          child: _isLoadingLocation
                              ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.0,
                              valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                            ),
                          )
                              : Icon(Icons.my_location, color: primaryColor),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Loading overlay
          if (_isLoadingStations)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: Center(
                child: Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(secondaryColor),
                      ),
                      SizedBox(height: 16),
                      Text('Loading recycling stations...'),
                    ],
                  ),
                ),
              ),
            ),

          // Selected station card
          if (_selectedStation != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: StationInfoCard(
                station: _selectedStation!,
                currentLocation: _currentLocation,
                onClose: () => setState(() => _selectedStation = null),
                onNavigate: () async {
                  // Open Google Maps directly
                  if (_currentLocation != null) {
                    final url = Uri.parse(
                      'https://www.google.com/maps/dir/?api=1&origin=${_currentLocation!.latitude},${_currentLocation!.longitude}&destination=${_selectedStation!.latitude},${_selectedStation!.longitude}&travelmode=driving'
                    );
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url, mode: LaunchMode.externalApplication);
                    } else {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Could not launch Google Maps')),
                      );
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Current location not available')),
                    );
                  }
                },
              ),
            ),
          // New station form - with cute style
          if (_newStationLocation != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: _isFormMinimized ? 80 : MediaQuery.of(context).size.height * 0.7,
                margin: EdgeInsets.only(left: 16, right: 16, bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _toggleFormMinimize,
                      child: Container(
                        margin: EdgeInsets.only(top: 8),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: Icon(_isFormMinimized ? Icons.expand_less : Icons.expand_more),
                          onPressed: _toggleFormMinimize,
                        ),
                        IconButton(
                          icon: Icon(Icons.close),
                          onPressed: _toggleAddMode,
                        ),
                      ],
                    ),
                    if (!_isFormMinimized)
                      Expanded(
                        child: SingleChildScrollView(
                          physics: AlwaysScrollableScrollPhysics(),
                          padding: EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Add Recycling Station',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 16),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey.shade200),
                                ),
                                child: TextField(
                                  controller: _stationNameController,
                                  decoration: InputDecoration(
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    labelText: 'Station Name',
                                    hintText: 'Enter station name',
                                    floatingLabelBehavior: FloatingLabelBehavior.auto,
                                  ),
                                ),
                              ),
                              SizedBox(height: 12),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey.shade200),
                                ),
                                child: TextField(
                                  controller: _stationAddressController,
                                  decoration: InputDecoration(
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    labelText: 'Station Address',
                                    hintText: 'Enter station address',
                                    floatingLabelBehavior: FloatingLabelBehavior.auto,
                                  ),
                                ),
                              ),
                              SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade50,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.grey.shade200),
                                      ),
                                      child: TextField(
                                        controller: _newStationLatController,
                                        decoration: InputDecoration(
                                          border: InputBorder.none,
                                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                          labelText: 'Latitude',
                                          hintText: 'Enter latitude',
                                          floatingLabelBehavior: FloatingLabelBehavior.auto,
                                        ),
                                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                                        onChanged: (value) => _updateNewStationLocationFromCoordinates(),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade50,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.grey.shade200),
                                      ),
                                      child: TextField(
                                        controller: _newStationLngController,
                                        decoration: InputDecoration(
                                          border: InputBorder.none,
                                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                          labelText: 'Longitude',
                                          hintText: 'Enter longitude',
                                          floatingLabelBehavior: FloatingLabelBehavior.auto,
                                        ),
                                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                                        onChanged: (value) => _updateNewStationLocationFromCoordinates(),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 16),
                              Row(
                                children: [
                                  Text(
                                    'Accepted Materials',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: secondaryColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'Select at least one',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: secondaryColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8),
                              Wrap(
                                spacing: 8.0,
                                runSpacing: 8.0,
                                children: _materialTypes.map((materialMap) {
                                  final material = materialMap['name'];
                                  final icon = materialMap['icon'];
                                  final isSelected = _acceptedMaterials.contains(material);
                                  final color = _getColorForMaterial(material);

                                  return InkWell(
                                    onTap: () {
                                      setState(() {
                                        if (isSelected) {
                                          _acceptedMaterials.remove(material);
                                        } else {
                                          _acceptedMaterials.add(material);
                                        }
                                      });
                                    },
                                    child: Container(
                                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: isSelected ? color.withOpacity(0.1) : Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: isSelected ? color : Colors.grey.shade300,
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            icon as IconData,
                                            size: 18,
                                            color: isSelected ? color : Colors.grey.shade600,
                                          ),
                                          SizedBox(width: 6),
                                          Text(
                                            material,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                              color: isSelected ? color : Colors.grey.shade800,
                                            ),
                                          ),
                                          if (isSelected) ...[
                                            SizedBox(width: 4),
                                            Icon(
                                              Icons.check_circle,
                                              size: 14,
                                              color: color,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                              SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _submitNewStation,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: secondaryColor,
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.check_circle),
                                      SizedBox(width: 8),
                                      Text(
                                        'Submit Station',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              SizedBox(height: 16),
                            ],
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
}
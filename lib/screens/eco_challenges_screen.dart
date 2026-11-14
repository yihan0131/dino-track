import 'package:flutter/material.dart';
import '../repositories/challenge_repository.dart';
import '../models/eco_challenge.dart';
import 'challenge_detail_screen.dart';
import 'package:intl/intl.dart'; // Add this import for date formatting

class EcoChallengesScreen extends StatefulWidget {
  final String userId;
  const EcoChallengesScreen({super.key, required this.userId});

  @override
  State<EcoChallengesScreen> createState() => _EcoChallengesScreenState();
}

class _EcoChallengesScreenState extends State<EcoChallengesScreen> {
  final ChallengeRepository _challengeRepository = ChallengeRepository();
  late Future<List<EcoChallenge>> _challengesFuture;
  String _searchQuery = "";
  List<EcoChallenge> _filteredChallenges = [];
  List<EcoChallenge> _allChallenges = [];
  Set<String> _joinedChallengeIds = {}; // Track joined challenges

  @override
  void initState() {
    super.initState();
    _loadChallenges();
    _loadUserChallenges();
  }

  void _loadChallenges() {
    print("Loading challenges...");
    _challengesFuture = _challengeRepository.getAvailableEcoChallenges();
    _challengesFuture.then((challenges) {
      print("Challenges loaded: ${challenges.length}");
      if (!mounted) return;
      setState(() {
        _allChallenges = EcoChallenge.sortedForDisplay(challenges, DateTime.now());
        _filterChallenges();
        print("Filtered challenges: ${_filteredChallenges.length}");
      });
    }).catchError((error) {
      print("Error loading challenges: $error");
    });
  }

  // Load user's joined challenges to track which ones are already joined
  void _loadUserChallenges() async {
    try {
      final userChallenges = await _challengeRepository.getUserChallenges(widget.userId);
      if (!mounted) return;
      setState(() {
        _joinedChallengeIds = userChallenges
            .map((uc) => uc['challenge']['id'] as String)
            .toSet();
      });
    } catch (e) {
      print("Error loading user challenges: $e");
    }
  }

  void _filterChallenges() {
    if (_searchQuery.isEmpty) {
      _filteredChallenges = List.from(_allChallenges);
    } else {
      _filteredChallenges = _allChallenges
          .where((challenge) =>
      challenge.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          challenge.description.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }
  }

  String _formatDateRange(DateTime start, DateTime end) {
    // Format dates as "DD - DD MMM" or "DD MMM - DD MMM" if different months
    if (start.month == end.month) {
      return "${start.day} - ${end.day} ${_getMonthAbbr(start.month)}";
    } else {
      return "${start.day} ${_getMonthAbbr(start.month)} - ${end.day} ${_getMonthAbbr(end.month)}";
    }
  }

  String _getMonthAbbr(int month) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  void _showJoinByCodeDialog() async {
    String code = "";
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with title
                Text(
                  "Join Challenge",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF5E8C43),
                  ),
                ),
                SizedBox(height: 24),

                // Code input field
                TextField(
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.grey.shade200,
                    hintText: "Enter challenge code",
                    hintStyle: TextStyle(color: Colors.grey),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
          onChanged: (val) => code = val.trim(),
        ),
                SizedBox(height: 24),

                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
          TextButton(
                      child: Text(
                        "Cancel",
                        style: TextStyle(color: Colors.grey),
                      ),
            onPressed: () => Navigator.pop(dialogContext),
          ),
          ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF5E8C43),
                        padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
            child: Text("Join"),
            onPressed: () async {
                        if (code.isEmpty) {
                          // Show error message in dialog instead of SnackBar
                          showDialog(
                            context: dialogContext,
                            builder: (context) => AlertDialog(
                              title: Text("Error"),
                              content: Text("Please enter a challenge code"),
                              actions: [
                                TextButton(
                                  child: Text("OK"),
                                  onPressed: () => Navigator.pop(context),
                                ),
                              ],
                            ),
                          );
                          return;
                        }

                final result = await _challengeRepository.joinChallengeByCode(widget.userId, code);
                if (!mounted || !dialogContext.mounted) return;
                Navigator.pop(dialogContext);

                if (result != null) {
                          // Show success message in dialog
                          showDialog(
                            context: this.context,
                            builder: (context) => AlertDialog(
                              title: Text("Success"),
                              content: Text("Joined challenge successfully!"),
                              actions: [
                                TextButton(
                                  child: Text("OK"),
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _loadChallenges();
                                    _loadUserChallenges();
                                  },
                                ),
                              ],
                            ),
                          );
                } else {
                          // Show error message in dialog
                          showDialog(
                            context: this.context,
                            builder: (context) => AlertDialog(
                              title: Text("Error"),
                              content: Text("Invalid challenge code. Please try again."),
                              actions: [
                                TextButton(
                                  child: Text("OK"),
                                  onPressed: () => Navigator.pop(context),
                                ),
                              ],
                            ),
                          );
              }
            },
          ),
        ],
      ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCreateChallengeDialog() async {
    String title = "";
    String description = "";
    String code = "";
    bool isPrivate = false;
    int selectedImageIndex = 1;
    DateTime startDate = DateTime.now();
    DateTime endDate = DateTime.now().add(Duration(days: 30));
    String? errorMessage;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              insetPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.0),
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
                      // Header
                      Center(
                        child: Text(
                          "Create Challenge",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF5E8C43),
                          ),
                        ),
                      ),
                      SizedBox(height: 24),

                      // Error message display
                      if (errorMessage != null)
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(12),
                          margin: EdgeInsets.only(bottom: 16),
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
                                  errorMessage!,
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Image selection
                      Text(
                        "Select Image:",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF5E8C43),
                        ),
                      ),
                      SizedBox(height: 12),
                      SizedBox(
                        height: 100,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: 9,
                          itemBuilder: (context, index) {
                            final imageIndex = index + 1;
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  selectedImageIndex = imageIndex;
                                });
                              },
                              child: Container(
                                width: 80,
                                height: 80,
                                margin: EdgeInsets.only(right: 10),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: selectedImageIndex == imageIndex
                                        ? Color(0xFF5E8C43)
                                        : Colors.grey.shade300,
                                    width: selectedImageIndex == imageIndex ? 2 : 1,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(11),
                                  child: Image.asset(
                                    'assets/eco_challenge$imageIndex.png',
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      SizedBox(height: 16),

                      // Title
                      Text(
                        "Title:",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF5E8C43),
                        ),
                      ),
                      SizedBox(height: 8),
            TextField(
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.grey.shade200,
                          hintText: "Enter challenge title",
                          hintStyle: TextStyle(color: Colors.grey),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        onChanged: (val) {
                          title = val.trim();
                          if (errorMessage != null) {
                            setState(() => errorMessage = null);
                          }
                        },
                      ),
                      SizedBox(height: 16),

                      // Description
                      Text(
                        "Description:",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF5E8C43),
                        ),
                      ),
                      SizedBox(height: 8),
            TextField(
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.grey.shade200,
                          hintText: "Describe your challenge",
                          hintStyle: TextStyle(color: Colors.grey),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        maxLines: 3,
                        onChanged: (val) {
                          description = val.trim();
                          if (errorMessage != null) {
                            setState(() => errorMessage = null);
                          }
                        },
                      ),
                      SizedBox(height: 16),

                      // Challenge Period
                      Text(
                        "Challenge Period:",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF5E8C43),
                        ),
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          // Start date
                          Expanded(
                            child: GestureDetector(
                              onTap: () async {
                                final pickedDate = await showDatePicker(
                                  context: context,
                                  initialDate: startDate,
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime.now().add(Duration(days: 365)),
                                  builder: (context, child) {
                                    return Theme(
                                      data: Theme.of(context).copyWith(
                                        colorScheme: ColorScheme.light(
                                          primary: Color(0xFF5E8C43),
                                        ),
                                      ),
                                      child: child!,
                                    );
                                  },
                                );
                                if (pickedDate != null) {
                                  setState(() {
                                    startDate = pickedDate;
                                    if (endDate.isBefore(startDate)) {
                                      endDate = startDate.add(Duration(days: 7));
                                    }
                                  });
                                }
                              },
                              child: Container(
                                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.calendar_today,
                                      size: 18,
                                      color: Color(0xFF5E8C43),
                                    ),
                                    SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        DateFormat('MMM d, yyyy').format(startDate),
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontSize: 14),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Text("to"),
                          ),
                          // End date
                          Expanded(
                            child: GestureDetector(
                              onTap: () async {
                                final pickedDate = await showDatePicker(
                                  context: context,
                                  initialDate: endDate,
                                  firstDate: startDate,
                                  lastDate: DateTime.now().add(Duration(days: 365)),
                                  builder: (context, child) {
                                    return Theme(
                                      data: Theme.of(context).copyWith(
                                        colorScheme: ColorScheme.light(
                                          primary: Color(0xFF5E8C43),
                                        ),
                                      ),
                                      child: child!,
                                    );
                                  },
                                );
                                if (pickedDate != null) {
                                  setState(() {
                                    endDate = pickedDate;
                                  });
                                }
                              },
                              child: Container(
                                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.calendar_today,
                                      size: 18,
                                      color: Color(0xFF5E8C43),
                                    ),
                                    SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        DateFormat('MMM d, yyyy').format(endDate),
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontSize: 14),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),

                      // Private Challenge checkbox
                      Container(
                        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: Checkbox(
                                    value: isPrivate,
                                    activeColor: Color(0xFF5E8C43),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    onChanged: (val) {
                                      setState(() {
                                        isPrivate = val ?? false;
                                      });
                                    },
                                  ),
                                ),
                                SizedBox(width: 8),
                                Text(
                                  "Private Challenge",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF5E8C43),
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                            if (isPrivate) SizedBox(height: 12),
                            if (isPrivate)
            TextField(
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: Colors.white,
                                  hintText: "Enter unique code",
                                  hintStyle: TextStyle(color: Colors.grey),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                ),
              onChanged: (val) => code = val.trim(),
            ),
          ],
        ),
                      ),
                      SizedBox(height: 24),

                      // Action buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
          TextButton(
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            ),
                            child: Text(
                              "Cancel",
                              style: TextStyle(color: Colors.grey),
                            ),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFF5E8C43),
                              padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
            child: Text("Create"),
            onPressed: () async {
                              if (title.isEmpty || description.isEmpty) {
                                setState(() {
                                  errorMessage = "Please enter title and description";
                                });
                                return;
                              }

                              if (isPrivate && code.isEmpty) {
                                setState(() {
                                  errorMessage = "Please enter a code for private challenge";
                                });
                                return;
                              }

                              // Calculate duration in days
                              final durationDays = endDate.difference(startDate).inDays + 1;

                final challenge = EcoChallenge(
                  id: '',
                  title: title,
                  description: description,
                                durationDays: durationDays,
                                imageUrl: 'eco_challenge$selectedImageIndex',
                                startDate: startDate,
                                endDate: endDate,
                  participantsCount: 0,
                  isPrivate: isPrivate,
                );

                              try {
                                if (isPrivate) {
                await _challengeRepository.createEcoChallengeWithCode(challenge, code: code);
                                } else {
                                  await _challengeRepository.createEcoChallenge(challenge);
                                }

                if (!context.mounted) return;
                Navigator.pop(context);
                                _loadChallenges();
                                
                                // Show success message
                                if (!mounted) return;
                                ScaffoldMessenger.of(this.context).showSnackBar(
                                  SnackBar(
                                    content: Text("Challenge created successfully!"),
                                    backgroundColor: Color(0xFF5E8C43),
                                  ),
                                );
                              } catch (e) {
                                setState(() {
                                  errorMessage = "Error creating challenge: $e";
                                });
              }
            },
          ),
        ],
      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Map<String, dynamic> _getChallengeStatus(EcoChallenge challenge) {
    final now = DateTime.now();
    final hasEnded = now.isAfter(challenge.endDate);
    final hasNotStarted = now.isBefore(challenge.startDate);

    if (hasEnded) {
      return {
        'status': 'ENDED',
        'color': Colors.red,
        'icon': Icons.flag,
        'text': 'ENDED'
      };
    } else if (hasNotStarted) {
      return {
        'status': 'UPCOMING',
        'color': Colors.blue,
        'icon': Icons.schedule,
        'text': 'UPCOMING'
      };
    } else {
      return {
        'status': 'ACTIVE',
        'color': null,
        'icon': null,
        'text': null
      };
    }
  }

// NEW: Build status badge widget
  Widget _buildStatusBadge(String text, Color color, IconData icon) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white24, //
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14), //
          SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Eco-Challenge", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Color(0xFF5E8C43),
        elevation: 0,
      ),
      backgroundColor: Color(0xFF5E8C43),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: "Search challenges",
                prefixIcon: Icon(Icons.search, color: Colors.white70),
                fillColor: Colors.white24,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.symmetric(vertical: 0),
                hintStyle: TextStyle(color: Colors.white70),
              ),
              style: TextStyle(color: Colors.white),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                  _filterChallenges();
                });
              },
            ),
          ),

          // Challenges list
          Expanded(
            child: FutureBuilder<List<EcoChallenge>>(
        future: _challengesFuture,
        builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && _allChallenges.isEmpty) {
                  return Center(child: CircularProgressIndicator(color: Colors.white));
          }

                if (!snapshot.hasData && _filteredChallenges.isEmpty) {
                  return Center(child: Text("No challenges available.", style: TextStyle(color: Colors.white)));
          }
                final challenges = _filteredChallenges.isNotEmpty ? _filteredChallenges : _allChallenges;

                return ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: challenges.length,
                  itemBuilder: (context, i) {
                    final challenge = challenges[i];

                    // DEBUG: Track data sources
                    print("=== RENDER DEBUG ===");
                    print("Using _filteredChallenges: ${_filteredChallenges.isNotEmpty}");
                    print("Challenge: ${challenge.title}");
                    print("Start: ${challenge.startDate}");
                    print("End: ${challenge.endDate}");
                    print("Now: ${DateTime.now()}");


                    // Calculate these ONCE at the top
                    final isJoined = _joinedChallengeIds.contains(challenge.id);
                    final statusInfo = _getChallengeStatus(challenge);

                    print("IsJoined: $isJoined");
                    print("Status: ${statusInfo['status']}");
                    print("Button should show: ${isJoined ? 'Joined' : (statusInfo['status'] == 'ENDED' ? 'Ended' : (statusInfo['status'] == 'UPCOMING' ? 'Soon' : 'Join'))}");
                    print("==================");

                    // Get the image index from the challenge's imageUrl
                    final imageIndex = int.tryParse(
                        challenge.imageUrl.replaceAll(RegExp(r'[^0-9]'), '')
                    ) ?? (i % 9) + 1;

                    final colors = [
                      Colors.pink, Colors.blue, Colors.amber,
                      Colors.purple, Colors.teal, Colors.orange,
                      Colors.indigo, Colors.green, Colors.red
                    ];
                    final bgColor = colors[(imageIndex - 1) % colors.length];

                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChallengeDetailScreen(
                              challenge: challenge,
                              userId: widget.userId,
                            ),
                          ),
                        ).then((_) {
                          _loadUserChallenges();
                        });
                      },
                      child: Container(
                        margin: EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            _buildChallengeDateBanner(challenge, bgColor),
                            Padding(
                              padding: EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  // Challenge icon
                                  Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      color: bgColor.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Stack(
                                      children: [
                                        Image.asset(
                                          'assets/${challenge.imageUrl}.png',
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) {
                                            return Image.asset(
                                              'assets/eco_challenge$imageIndex.png',
                                              fit: BoxFit.cover,
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(width: 12),

                                  // Challenge details
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          challenge.title,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          challenge.description,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: Colors.black54,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Join/Joined button - NOW USING CALCULATED VARIABLES
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: () {
                                        //  Status-first priority
                                        if (statusInfo['status'] == 'ENDED') return Colors.grey;
                                        if (statusInfo['status'] == 'UPCOMING') return Colors.blue.shade300;

                                        // Then join status for active challenges
                                        if (isJoined) return Colors.grey;
                                        return Color(0xFF5E8C43); // Active challenge
                                      }(),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      padding: EdgeInsets.symmetric(horizontal: 16),
                                    ),
                                    child: Text(() {
                                      // Status-first priority
                                      if (statusInfo['status'] == 'ENDED') return "Ended";
                                      if (statusInfo['status'] == 'UPCOMING') return "Soon";

                                      // Then check join status for active challenges
                                      if (isJoined) return "Joined";
                                      return "Join"; // Active challenge, not joined
                                    }()),
                                    onPressed: () {
                                      // Disable button for non-active challenges or already joined
                                      if (isJoined || statusInfo['status'] != 'ACTIVE') {
                                        if (statusInfo['status'] == 'ENDED') {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text("This challenge has ended"))
                                          );
                                        } else if (statusInfo['status'] == 'UPCOMING') {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text("This challenge hasn't started yet"))
                                          );
                                        }
                                        return;
                                      }

                                      // Original join logic for active challenges
                                      _challengeRepository.joinChallenge(widget.userId, challenge.id).then((_) {
                                        if (!mounted) return;
                                        setState(() {
                                          _joinedChallengeIds.add(challenge.id);
                                        });
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text("Joined challenge!"))
                                        );
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Color(0xFF99C875),
        child: Icon(Icons.add, color: Colors.white),
        onPressed: () {
          showModalBottomSheet(
            context: context,
            builder: (context) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(Icons.add_circle, color: Color(0xFF5E8C43)),
                  title: Text("Create Challenge"),
                  onTap: () {
                    Navigator.pop(context);
                    _showCreateChallengeDialog();
                  },
                ),
                ListTile(
                  leading: Icon(Icons.qr_code, color: Color(0xFF18562D)),
                  title: Text("Join with Code"),
                  onTap: () {
                    Navigator.pop(context);
                    _showJoinByCodeDialog();
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Add these methods to your _EcoChallengesScreenState class
// Make sure they're inside the class

// Add this field at the top of your class with other fields
  final Map<String, bool> _defaultChallengeCache = {}; // Cache for default challenges

// Add this method
  Future<bool> _isDefaultChallenge(String challengeId) async {
    // Check cache first to avoid repeated calls
    if (_defaultChallengeCache.containsKey(challengeId)) {
      return _defaultChallengeCache[challengeId]!;
    }

    // Call the Firebase service to check if it's a default challenge
    // Use proper reference to the class field
    bool isDefault = await _challengeRepository.isDefaultChallenge(challengeId);

    // Cache the result
    _defaultChallengeCache[challengeId] = isDefault;

    return isDefault;
  }

// Add this method - referring to the class methods properly
  // REPLACE your _buildChallengeDateBanner method with this fixed version:

  Widget _buildChallengeDateBanner(EcoChallenge challenge, Color bgColor) {
    // Get challenge status first
    final statusInfo = _getChallengeStatus(challenge);
    final isActive = statusInfo['status'] == 'ACTIVE';

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor.withOpacity(0.8),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
          bottomLeft: Radius.circular(16),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Date range
          Text(
            _formatDateRange(challenge.startDate, challenge.endDate),
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),

          // NEW: Show BOTH status and type badges when needed
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // FIRST: Show type badge (Private/Official) - always visible if applicable
              FutureBuilder<bool>(
                future: _isDefaultChallenge(challenge.id),
                builder: (context, snapshot) {
                  final isDefault = snapshot.data ?? false;
                  Widget? typeBadge;

                  // Private Challenge Badge
                  if (challenge.isPrivate) {
                    typeBadge = Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lock, color: Colors.white, size: 14),
                          SizedBox(width: 4),
                          Text(
                            'Private',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  // Official Challenge Badge
                  else if (isDefault) {
                    typeBadge = Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified, color: Colors.white, size: 14),
                          SizedBox(width: 4),
                          Text(
                            'Official',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Show type badge if exists
                      if (typeBadge != null) typeBadge,

                      // Add spacing between badges if both exist
                      if (typeBadge != null && !isActive) SizedBox(width: 6),

                      // SECOND: Show status badge (ENDED/UPCOMING) if not active
                      if (!isActive)
                        _buildStatusBadge(
                            statusInfo['text'],
                            statusInfo['color'],
                            statusInfo['icon']
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

}


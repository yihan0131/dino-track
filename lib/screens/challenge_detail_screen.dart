import 'package:flutter/material.dart';
import '../repositories/challenge_repository.dart';
import '../models/eco_challenge.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'challenge_photos_screen.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class ChallengeDetailScreen extends StatefulWidget {
  final EcoChallenge challenge;
  final String userId;
  const ChallengeDetailScreen({super.key, required this.challenge, required this.userId});

  @override
  State<ChallengeDetailScreen> createState() => _ChallengeDetailScreenState();
}

class _ChallengeDetailScreenState extends State<ChallengeDetailScreen> {
  final ChallengeRepository _challengeRepository = ChallengeRepository();
  int currentStreak = 0;
  int highestStreak = 0;
  bool completed = false;
  bool isLoading = true;
  List<Map<String, dynamic>> leaderboard = [];
  bool showFullLeaderboard = false;
  int userRank = 0;
  String createdBy = "";
  bool hasJoined = false;
  String userChallengeId = "";
  bool canCheckInToday = true;

  File? _selectedImage;
  List<Map<String, dynamic>> checkInPhotos = [];
  bool _isDialogShowing = false;

  // NEW: Add computed property to check if challenge has ended
  bool get hasEnded {
    final now = DateTime.now();
    final endDate = widget.challenge.endDate;
    return now.isAfter(endDate);
  }

  // NEW: Add computed property to check if challenge hasn't started yet
  bool get hasNotStarted {
    final now = DateTime.now();
    final startDate = widget.challenge.startDate;
    return now.isBefore(startDate);
  }

  @override
  void initState() {
    super.initState();
    print("=== ChallengeDetailScreen initState ===");
    print("Challenge ID: ${widget.challenge.id}");
    print("User ID: ${widget.userId}");
    _loadUserChallenge();
    _loadLeaderboard();
    _loadChallengeCreator();
    _loadCheckInPhotos();
  }

  Future<void> _loadChallengeCreator() async {
    try {
      final creator = await _challengeRepository.getChallengeCreator(widget.challenge.id);
      setState(() {
        createdBy = creator;
      });
    } catch (e) {
      print("Error loading challenge creator: $e");
    }
  }

  Future<void> _loadCheckInPhotos() async {
    try {
      final photos = await _challengeRepository.getChallengeCheckInPhotos(widget.challenge.id);
      print("PHOTOS LOADED: ${photos.length} photos found");

      // Filter out invisible and rejected photos
      final visiblePhotos = photos.where((photo) =>
      photo['visible'] != false && photo['rejected'] != true
      ).toList();

      setState(() {
        checkInPhotos = visiblePhotos;
      });
    } catch (e) {
      print("Error loading check-in photos: $e");
    }
  }

  Future<void> _loadUserChallenge() async {
    final userChallenges = await _challengeRepository.getUserChallenges(widget.userId);
    final userChallenge = userChallenges.firstWhere(
          (uc) => uc['challenge']['id'] == widget.challenge.id,
      orElse: () => {},
    );

    if (userChallenge.isNotEmpty) {
      setState(() {
        hasJoined = true;
        userChallengeId = userChallenge['userChallenge']['id'] ?? "";
        currentStreak = userChallenge['userChallenge']['currentStreak'] ?? 0;
        highestStreak = userChallenge['userChallenge']['highestStreak'] ?? 0;
        completed = userChallenge['userChallenge']['completed'] ?? false;

        List<dynamic> checkInDatesRaw = userChallenge['userChallenge']['checkInDates'] ?? [];
        List<DateTime> checkInDates = checkInDatesRaw.map((timestamp) {
          return (timestamp is int)
              ? DateTime.fromMillisecondsSinceEpoch(timestamp)
              : DateTime.now();
        }).toList();

        DateTime today = DateTime.now();
        DateTime dateOnly = DateTime(today.year, today.month, today.day);
        bool alreadyCheckedInToday = checkInDates.any((date) {
          final checkDate = DateTime(date.year, date.month, date.day);
          return checkDate.isAtSameMomentAs(dateOnly);
        });

        // UPDATED: Include challenge end status in canCheckInToday logic
        canCheckInToday = !alreadyCheckedInToday && !hasEnded && !hasNotStarted;

        isLoading = false;
      });
    } else {
      setState(() {
        hasJoined = false;
        isLoading = false;
      });
    }
  }

  Future<void> _loadLeaderboard() async {
    try {
      print("=== Loading leaderboard for challenge: ${widget.challenge.id} ===");
      print("Current user ID: ${widget.userId}");

      setState(() {
        isLoading = true;
      });

      final lb = await _challengeRepository.getChallengeLeaderboard(widget.challenge.id);
      print("Received leaderboard with ${lb.length} entries");

      if (lb.isEmpty) {
        print("WARNING: Leaderboard is empty!");
        setState(() {
          leaderboard = [];
          userRank = 0;
          isLoading = false;
        });
        return;
      }

      lb.sort((a, b) => (b['score'] ?? 0).compareTo(a['score'] ?? 0));

      int rank = 0;
      for (int i = 0; i < lb.length; i++) {
        print("Checking entry $i: ${lb[i]['userId']} vs current user ${widget.userId}");
        if (lb[i]['userId'] == widget.userId) {
          rank = i + 1;
          print("Found user rank: $rank");
          break;
        }
      }

      setState(() {
        leaderboard = lb;
        userRank = rank;
        isLoading = false;
        print("Updated leaderboard state with ${lb.length} entries and user rank: $rank");
      });
    } catch (e) {
      print("ERROR loading leaderboard: $e");
      print("Stack trace: ${StackTrace.current}");
      setState(() {
        leaderboard = [];
        userRank = 0;
        isLoading = false;
      });
    }
  }

  Future<void> _joinChallenge() async {
    // Prevent joining ended challenges
    if (hasEnded) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Cannot join - this challenge has ended"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (hasNotStarted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Cannot join - this challenge hasn't started yet"),
          backgroundColor: Colors.blue,
        ),
      );
      return;
    }

    setState(() { isLoading = true; });
    try {
      final result = await _challengeRepository.joinChallenge(widget.userId, widget.challenge.id);
      userChallengeId = result;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Joined challenge successfully!"),
            backgroundColor: Color(0xFF5E8C43),
          )
      );

      await _loadUserChallenge();
      await _loadLeaderboard();

      setState(() {
        hasJoined = true;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error joining challenge: $e"),
            backgroundColor: Colors.redAccent,
          )
      );
    } finally {
      setState(() { isLoading = false; });
    }
  }

  Future<void> _checkIn() async {
    if (!hasJoined) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("You need to join the challenge first!"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // NEW: Check if challenge has ended
    if (hasEnded) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("This challenge has ended. No more check-ins allowed."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // NEW: Check if challenge hasn't started
    if (hasNotStarted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("This challenge hasn't started yet."),
          backgroundColor: Colors.blue,
        ),
      );
      return;
    }

    if (!canCheckInToday) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("You've already checked in today!"),
          backgroundColor: Colors.blue,
        ),
      );
      return;
    }

    await _showCheckInDialog();
  }

  // NEW: Get check-in button properties based on challenge status
  Map<String, dynamic> _getCheckInButtonProperties() {
    if (completed) {
      return {
        'text': 'Completed',
        'color': Colors.grey.shade300,
        'enabled': false,
      };
    }

    if (hasEnded) {
      return {
        'text': 'Challenge Ended',
        'color': Colors.red.shade300,
        'enabled': false,
      };
    }

    if (hasNotStarted) {
      return {
        'text': 'Not Started',
        'color': Colors.blue.shade300,
        'enabled': false,
      };
    }

    if (!canCheckInToday) {
      return {
        'text': 'Already Checked-in',
        'color': Colors.blue.shade300,
        'enabled': false,
      };
    }

    return {
      'text': 'Check-in',
      'color': _getColor(),
      'enabled': true,
    };
  }

  Future<void> _pickImageFrom(ImageSource source, StateSetter dialogSetState) async {
    try {
      print("=== Starting image pick from $source ===");
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        imageQuality: 80,
      );

      print("Image picked: ${image?.path}");
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
        print("Selected image set to: ${_selectedImage?.path}");

        dialogSetState(() {});
      } else {
        print("No image was selected");
      }
    } catch (e) {
      print("Error selecting image: $e");
      print("Stack trace: ${StackTrace.current}");
      rethrow;
    }
  }

  Future<bool> _requestCameraPermission() async {
    try {
      var status = await Permission.camera.status;
      print("Initial camera permission status: $status");

      if (status.isGranted) {
        print("Camera permission already granted");
        return true;
      }

      if (status.isDenied) {
        print("Requesting camera permission...");
        status = await Permission.camera.request();
        print("Camera permission request result: $status");
      }

      if (status.isPermanentlyDenied) {
        print("Camera permission permanently denied");
        if (mounted) {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: Text("Camera Permission Required"),
              content: Text("Camera permission is required to take photos. Please enable it in app settings."),
              actions: [
                TextButton(
                  child: Text("Cancel"),
                  onPressed: () => Navigator.pop(context),
                ),
                ElevatedButton(
                  child: Text("Open Settings"),
                  onPressed: () async {
                    Navigator.pop(context);
                    await openAppSettings();
                  },
                ),
              ],
            ),
          );
        }
        return false;
      }

      return status.isGranted;
    } catch (e) {
      print("Error requesting camera permission: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error requesting camera permission: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return false;
    }
  }

  Future<bool> _requestStoragePermission() async {
    try {
      if (await Permission.photos.status.isDenied) {
        print("Requesting photos permission...");
        var status = await Permission.photos.request();
        print("Photos permission request result: $status");
        if (status.isGranted) {
          return true;
        }
      }

      var storageStatus = await Permission.storage.status;
      print("Initial storage permission status: $storageStatus");

      if (storageStatus.isGranted) {
        print("Storage permission already granted");
        return true;
      }

      if (storageStatus.isDenied) {
        print("Requesting storage permission...");
        storageStatus = await Permission.storage.request();
        print("Storage permission request result: $storageStatus");
      }

      if (storageStatus.isPermanentlyDenied) {
        print("Storage permission permanently denied");
        if (mounted) {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: Text("Storage Permission Required"),
              content: Text("Storage permission is required to select photos. Please enable it in app settings."),
              actions: [
                TextButton(
                  child: Text("Cancel"),
                  onPressed: () => Navigator.pop(context),
                ),
                ElevatedButton(
                  child: Text("Open Settings"),
                  onPressed: () async {
                    Navigator.pop(context);
                    await openAppSettings();
                  },
                ),
              ],
            ),
          );
        }
        return false;
      }

      return storageStatus.isGranted;
    } catch (e) {
      print("Error requesting storage permission: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error requesting storage permission: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return false;
    }
  }

  Future<void> _showCheckInDialog() async {
    if (_isDialogShowing) return;
    _isDialogShowing = true;

    bool isDefault = await _challengeRepository.isDefaultChallenge(widget.challenge.id);
    final Color themeColor = _getColor();

    if (!mounted) {
      _isDialogShowing = false;
      return;
    }

    try {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return StatefulBuilder(
              builder: (context, setDialogState) {
                return Dialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.check_circle, color: themeColor, size: 24),
                              SizedBox(width: 8),
                              Text(
                                "Daily Check-in",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: Color(0xFF18562D),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 16),

                          SizedBox(
                            width: MediaQuery.of(context).size.width * 0.7,
                            child: Text(
                              isDefault
                                  ? "Please upload a photo of your activity (Required)"
                                  : "Would you like to upload a photo of your activity? (Optional)",
                              style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                            ),
                          ),

                          if (isDefault)
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: SizedBox(
                                width: MediaQuery.of(context).size.width * 0.7,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.emoji_events, color: Colors.amber, size: 16),
                                      SizedBox(width: 4),
                                      Text(
                                        "Official challenges with photo earn 2 points",
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.green.shade700,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                          SizedBox(height: 16),

                          if (_selectedImage != null) ...[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(
                                _selectedImage!,
                                height: 200,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                            SizedBox(height: 12),
                            Center(
                              child: TextButton.icon(
                                icon: Icon(Icons.delete, color: Colors.red.shade400, size: 20),
                                label: Text(
                                  "Remove",
                                  style: TextStyle(
                                    color: Colors.red.shade400,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                onPressed: () {
                                  setDialogState(() {
                                    _selectedImage = null;
                                  });
                                },
                              ),
                            )
                          ] else ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    icon: Icon(Icons.camera_alt),
                                    label: Text("Camera"),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Color(0xFFE8F5E9),
                                      foregroundColor: themeColor,
                                      padding: EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    onPressed: () async {
                                      if (await _requestCameraPermission()) {
                                        try {
                                          await _pickImageFrom(ImageSource.camera, setDialogState);
                                        } catch (e) {
                                          print("Error picking camera image: $e");
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text("Error accessing camera: $e"),
                                                backgroundColor: Colors.redAccent,
                                              ),
                                            );
                                          }
                                        }
                                      }
                                    },
                                  ),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    icon: Icon(Icons.photo_library),
                                    label: Text("Gallery"),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Color(0xFFE3F2FD),
                                      foregroundColor: themeColor,
                                      padding: EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    onPressed: () async {
                                      if (await _requestStoragePermission()) {
                                        try {
                                          await _pickImageFrom(ImageSource.gallery, setDialogState);
                                        } catch (e) {
                                          print("Error picking gallery image: $e");
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text("Error accessing gallery: $e"),
                                                backgroundColor: Colors.redAccent,
                                              ),
                                            );
                                          }
                                        }
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],

                          SizedBox(height: 20),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                child: Text(
                                  "Cancel",
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                onPressed: () {
                                  _selectedImage = null;
                                  Navigator.of(context).pop();
                                },
                              ),
                              SizedBox(width: 8),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Color(0xFF5E8C43),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                ),
                                child: Text(
                                  "Check In",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                onPressed: () {
                                  if (isDefault && _selectedImage == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text("Photo is required for this challenge"),
                                        backgroundColor: Colors.orange,
                                      ),
                                    );
                                    return;
                                  }

                                  Navigator.of(context).pop();
                                  _submitCheckIn();
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }
          );
        },
      );
    } finally {
      _isDialogShowing = false;
    }
  }

  Future<void> _submitCheckIn() async {
    if (!canCheckInToday) {
      print("Cannot check in today - already checked in or challenge ended/not started");
      if (context.mounted) {
        String message = "You've already checked in today!";
        if (hasEnded) message = "This challenge has ended.";
        if (hasNotStarted) message = "This challenge hasn't started yet.";

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: hasEnded ? Colors.red : Colors.blue,
          ),
        );
      }
      return;
    }

    setState(() { isLoading = true; });

    bool isUploading = _selectedImage != null;
    print("=== Starting check-in submission ===");
    print("Has selected image: $isUploading");
    print("Selected image path: ${_selectedImage?.path}");

    if (isUploading) {
      var connectivityResult = await Connectivity().checkConnectivity();
      print("Connectivity result: $connectivityResult");

      if (connectivityResult == ConnectivityResult.none) {
        print("No internet connection available");
        setState(() { isLoading = false; });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("No internet connection. Please connect and try again."),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return;
      }

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Color(0xFF5E8C43)),
                  SizedBox(height: 16),
                  Text("Uploading photo..."),
                ],
              ),
            );
          },
        );
      }
    }

    try {
      print("Submitting check-in with image: ${_selectedImage?.path}");

      Map<String, dynamic> result = await _challengeRepository.checkInChallenge(
        userChallengeId,
        photoFile: _selectedImage,
      );

      print("Check-in result: $result");

      if (!result['success']) {
        print("Check-in failed: ${result['error']}");
        if (result['isPhotoRequired'] == true) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("A photo is required for this challenge"),
                backgroundColor: Colors.orange,
              ),
            );
          }
          setState(() { isLoading = false; });
          if (isUploading && mounted) {
            Navigator.of(context).pop();
          }
          return;
        }

        throw Exception(result['error'] ?? "Failed to check in");
      }

      print("Check-in submitted successfully");

      if (result['pointsAwarded'] > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("You earned ${result['pointsAwarded']} points!"),
            backgroundColor: Colors.orange,
          ),
        );
      }

      _selectedImage = null;

      if (isUploading && mounted) {
        Navigator.of(context).pop();
      }

      setState(() {
        canCheckInToday = false;
      });

      await _loadUserChallenge();
      await _loadLeaderboard();
      await _loadCheckInPhotos();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Check-in successful!"),
            backgroundColor: Color(0xFF5E8C43),
          ),
        );
      }
    } catch (e) {
      print("Error during check-in: $e");

      if (isUploading && mounted) {
        Navigator.of(context).pop();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error checking in: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _showPhotosScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChallengePhotosScreen(
          challenge: widget.challenge,
          userId: widget.userId,
          photos: checkInPhotos,
        ),
      ),
    ).then((_) => _loadCheckInPhotos());
  }

  Future<void> _leaveChallenge() async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Leave Challenge"),
        content: Text("Are you sure you want to leave this challenge? Your progress will be lost."),
        actions: [
          TextButton(
            child: Text("Cancel", style: TextStyle(color: Colors.grey)),
            onPressed: () => Navigator.pop(context, false),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
            ),
            child: Text("Leave"),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    ) ?? false;

    if (confirm) {
      setState(() { isLoading = true; });
      try {
        final userChallenges = await _challengeRepository.getUserChallenges(widget.userId);
        final userChallenge = userChallenges.firstWhere(
              (uc) => uc['challenge']['id'] == widget.challenge.id,
          orElse: () => {},
        );

        if (userChallenge.isNotEmpty) {
          await _challengeRepository.leaveChallenge(userChallenge['userChallenge']['id']);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("You've left the challenge"),
                backgroundColor: Color(0xFF5E8C43),
              )
          );
          if (!mounted) return;
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Error leaving challenge: $e"),
              backgroundColor: Colors.redAccent,
            )
        );
      } finally {
        setState(() { isLoading = false; });
      }
    }
  }

  String _getMonthAbbr(int month) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  String _formatDateRange(DateTime start, DateTime end) {
    if (start.month == end.month) {
      return "${start.day} - ${end.day} ${_getMonthAbbr(start.month)}";
    } else {
      return "${start.day} ${_getMonthAbbr(start.month)} - ${end.day} ${_getMonthAbbr(end.month)}";
    }
  }

  int _getImageIndex() {
    return int.tryParse(
        widget.challenge.imageUrl.replaceAll(RegExp(r'[^0-9]'), '')
    ) ?? 1;
  }

  Color _getColor() {
    final colors = [
      Colors.pink, Colors.blue, Colors.amber,
      Colors.purple, Colors.teal, Colors.orange,
      Colors.indigo, Colors.green, Colors.red
    ];
    return colors[(_getImageIndex() - 1) % colors.length];
  }

  Widget _buildUserRankTile() {
    if (userRank <= 0 || leaderboard.isEmpty) return SizedBox.shrink();

    Map<String, dynamic>? userEntry;
    for (var entry in leaderboard) {
      if (entry['userId'] == widget.userId) {
        userEntry = entry;
        break;
      }
    }

    if (userEntry == null) return SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      child: Container(
        decoration: BoxDecoration(
          color: Color(0xFFEDF7E7),
          borderRadius: BorderRadius.circular(12),
        ),
        child: ListTile(
          dense: true,
          visualDensity: VisualDensity(horizontal: -1, vertical: -1),
          leading: CircleAvatar(
            radius: 16,
            backgroundColor: userRank <= 3
                ? (userRank == 1 ? Colors.amber : (userRank == 2 ? Colors.grey.shade300 : Colors.brown.shade300))
                : _getColor().withOpacity(0.2),
            child: Text(
              "$userRank",
              style: TextStyle(
                color: userRank <= 3 ? Color(0xFF18562D) : Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          title: Row(
            children: [
              Text(
                "Your Rank",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF18562D),
                  fontSize: 13,
                ),
              ),
              SizedBox(width: 4),
              Flexible(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getColor().withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    userEntry['username'] ?? "User",
                    style: TextStyle(
                      fontSize: 11,
                      color: _getColor(),
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ),
            ],
          ),
          trailing: SizedBox(
            width: 70,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.local_fire_department, color: Colors.orange, size: 14),
                SizedBox(width: 1),
                Flexible(
                  child: Text(
                    "${userEntry['streak'] ?? userEntry['currentStreak'] ?? 0} days",
                    style: TextStyle(
                      color: Color(0xFF18562D),
                      fontSize: 11,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (userEntry['completed'] == true)
                  Padding(
                    padding: const EdgeInsets.only(left: 2.0),
                    child: Icon(Icons.emoji_events, color: Colors.orange, size: 12),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPodium() {
    if (leaderboard.length < 2) return SizedBox.shrink();

    final topThree = leaderboard.take(min(3, leaderboard.length)).toList();

    return Container(
      height: 180,
      padding: EdgeInsets.only(bottom: 20, top: 10),
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (topThree.length >= 2)
                _buildPodiumPlatform(
                  topThree[1]['username'] ?? "User",
                  topThree[1]['streak'] ?? topThree[1]['currentStreak'] ?? 0,
                  Colors.grey.shade300,
                  height: 120,
                  rank: 2,
                  isCompleted: topThree[1]['completed'] == true,
                ),

              if (topThree.isNotEmpty)
                _buildPodiumPlatform(
                  topThree[0]['username'] ?? "User",
                  topThree[0]['streak'] ?? topThree[0]['currentStreak'] ?? 0,
                  Colors.amber,
                  height: 150,
                  rank: 1,
                  isCompleted: topThree[0]['completed'] == true,
                ),

              if (topThree.length >= 3)
                _buildPodiumPlatform(
                  topThree[2]['username'] ?? "User",
                  topThree[2]['streak'] ?? topThree[2]['currentStreak'] ?? 0,
                  Colors.brown.shade300,
                  height: 90,
                  rank: 3,
                  isCompleted: topThree[2]['completed'] == true,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPodiumPlatform(String name, int streak, Color color, {
    required double height,
    required int rank,
    bool isCompleted = false,
  }) {
    return Container(
      width: 85,
      margin: EdgeInsets.symmetric(horizontal: 3),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Stack(
            alignment: Alignment.topCenter,
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: color.withOpacity(0.3),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : "-",
                  style: TextStyle(
                    color: Color(0xFF18562D),
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              if (rank == 1)
                Positioned(
                  top: -8,
                  child: Icon(
                    Icons.emoji_events,
                    color: Colors.amber,
                    size: 20,
                  ),
                ),
            ],
          ),
          SizedBox(height: 2),
          Text(
            name,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF18562D),
              fontSize: 12,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.local_fire_department, color: Colors.orange, size: 12),
              SizedBox(width: 2),
              Text(
                "$streak",
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          SizedBox(height: 4),
          Container(
            height: height * 0.35,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.vertical(top: Radius.circular(6)),
            ),
            child: Center(
              child: Text(
                "$rank",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  int min(int a, int b) {
    return a < b ? a : b;
  }

  void _showPointsInfoDialog() async {
    bool isDefault = await _challengeRepository.isDefaultChallenge(widget.challenge.id);

    if (!isDefault || !mounted) return;

    final Color dialogBackgroundColor = Colors.white;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: dialogBackgroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.emoji_events, color: Colors.amber, size: 24),
                  SizedBox(width: 8),
                  Text(
                    "Points System",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: Color(0xFF18562D),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "2 points for each daily check-in with photo",
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),

              Row(
                children: [
                  Icon(Icons.workspace_premium, color: Colors.amber, size: 18),
                  SizedBox(width: 8),
                  Text(
                    "End of challenge rewards:",
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),

              Padding(
                padding: const EdgeInsets.only(left: 30.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "• 1st place: 50 points",
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.black87,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      "• 2nd place: 30 points",
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      "• 3rd place: 20 points",
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 20),

              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    backgroundColor: Color(0xFF5E8C43),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Text("Got it"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeaderboardTile(Map<String, dynamic> entry, int index) {
    final isCurrentUser = entry['userId'] == widget.userId;
    final themeColor = _getColor();

    return Container(
      margin: EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: isCurrentUser ? themeColor.withOpacity(0.1) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrentUser ? themeColor : Colors.grey.shade200,
          width: isCurrentUser ? 2 : 1,
        ),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: themeColor.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '${index + 1}',
              style: TextStyle(
                color: themeColor,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
        title: Text(
          entry['username'] ?? 'User',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isCurrentUser ? themeColor : Colors.black87,
          ),
        ),
        subtitle: Text(
          '${entry['totalCheckIns'] ?? 0} check-ins • ${entry['currentStreak'] ?? 0} day streak',
          style: TextStyle(
            color: isCurrentUser ? themeColor.withOpacity(0.8) : Colors.black54,
          ),
        ),
        trailing: Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: themeColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.local_fire_department, color: Colors.orange, size: 16),
              SizedBox(width: 4),
              Text(
                '${entry['streak'] ?? entry['currentStreak'] ?? 0} days',
                style: TextStyle(
                  color: themeColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    final Color themeColor = _getColor();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.challenge.title,
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Color(0xFF5E8C43),
        elevation: 0,
      ),
      backgroundColor: Color(0xFFF8F8F8),
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: Color(0xFF5E8C43)))
          : SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              color: Color(0xFF5E8C43),
              padding: EdgeInsets.only(left: 20, right: 20, bottom: 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // UPDATED: Show status badge and date info
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: themeColor.withOpacity(0.8),
                            borderRadius: BorderRadius.only(
                              topRight: Radius.circular(8),
                              bottomLeft: Radius.circular(8),
                            ),
                          ),
                          child: Text(
                            _formatDateRange(widget.challenge.startDate, widget.challenge.endDate),
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Image.asset(
                          'assets/${widget.challenge.imageUrl}.png',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Image.asset(
                              'assets/eco_challenge${_getImageIndex()}.png',
                              fit: BoxFit.cover,
                            );
                          },
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.challenge.title,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 22,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              widget.challenge.description,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 14,
                              ),
                            ),
                            SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.calendar_today, size: 16, color: Colors.white.withOpacity(0.9)),
                                SizedBox(width: 4),
                                Text(
                                    "${widget.challenge.durationDays} days",
                                    style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.9))
                                ),
                              ],
                            ),
                            if (createdBy.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Row(
                                  children: [
                                    Icon(Icons.person, size: 16, color: Colors.white.withOpacity(0.9)),
                                    SizedBox(width: 4),
                                    Text(
                                        "Created by: $createdBy",
                                        style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.9))
                                    ),
                                  ],
                                ),
                              ),
                            if (widget.challenge.toMap().containsKey('code') &&
                                widget.challenge.toMap()['code'] != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Row(
                                  children: [
                                    Icon(Icons.lock, size: 16, color: Colors.white.withOpacity(0.9)),
                                    SizedBox(width: 4),
                                    Text(
                                        "Code: ${widget.challenge.toMap()['code']}",
                                        style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.9))
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              margin: EdgeInsets.all(16),
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
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Your Progress",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Color(0xFF18562D),
                      ),
                    ),
                    SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Current Streak",
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontSize: 14,
                                ),
                              ),
                              SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(
                                    Icons.local_fire_department,
                                    color: Colors.orange,
                                    size: 24,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    "$currentStreak days",
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF18562D),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8),
                              Text(
                                "Highest: $highestStreak days",
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // UPDATED: Check-in button with improved logic
                            () {
                          final buttonProps = _getCheckInButtonProperties();
                          return ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: buttonProps['color'],
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                              elevation: 0,
                              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            ),
                            onPressed: buttonProps['enabled'] ? _checkIn : null,
                            child: Text(
                              buttonProps['text'],
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        }(),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Container(
              margin: EdgeInsets.symmetric(horizontal: 16),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(
                              "Leaderboard",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Color(0xFF18562D),
                              ),
                            ),
                            FutureBuilder<bool>(
                              future: _challengeRepository.isDefaultChallenge(widget.challenge.id),
                              builder: (context, snapshot) {
                                final isDefault = snapshot.data ?? false;
                                if (!isDefault) return SizedBox.shrink();

                                return GestureDetector(
                                  onTap: _showPointsInfoDialog,
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 8.0),
                                    child: Container(
                                      width: 18,
                                      height: 18,
                                      decoration: BoxDecoration(
                                        color: Colors.amber.withOpacity(0.2),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text(
                                          "?",
                                          style: TextStyle(
                                            color: Colors.amber,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),

                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (checkInPhotos.isNotEmpty)
                              GestureDetector(
                                onTap: _showPhotosScreen,
                                behavior: HitTestBehavior.opaque,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.photo_library, size: 16, color: themeColor),
                                      SizedBox(width: 4),
                                      Text(
                                        "${checkInPhotos.length}",
                                        style: TextStyle(
                                          color: themeColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                            SizedBox(width: 16),

                            if (leaderboard.isNotEmpty)
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    showFullLeaderboard = !showFullLeaderboard;
                                  });
                                },
                                behavior: HitTestBehavior.opaque,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
                                  child: Text(
                                    showFullLeaderboard ? "Hide" : "View",
                                    style: TextStyle(
                                      color: themeColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (leaderboard.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Center(
                        child: Text(
                          "No participants yet. Be the first to join!",
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                      ),
                    )
                  else if (!showFullLeaderboard && userRank > 0)
                    _buildUserRankTile()
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Column(
                        children: [
                          if (leaderboard.length >= 2)
                            _buildPodium(),

                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: ListView.separated(
                              shrinkWrap: true,
                              physics: NeverScrollableScrollPhysics(),
                              itemCount: leaderboard.length,
                              separatorBuilder: (context, i) => Divider(
                                height: 1,
                                indent: 16,
                                endIndent: 16,
                              ),
                              itemBuilder: (context, i) {
                                final entry = leaderboard[i];
                                return _buildLeaderboardTile(entry, i);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Container(
              margin: EdgeInsets.all(16),
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: hasJoined ? Colors.white : Color(0xFF5E8C43),
                  foregroundColor: hasJoined ? Colors.red.shade700 : Colors.white,
                  elevation: hasJoined ? 0 : 2,
                  side: hasJoined ? BorderSide(color: Colors.red.shade200) : null,
                  padding: EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: Text(hasJoined ? "Leave Challenge" : "Join Challenge"),
                onPressed: () {
                  if (hasJoined) {
                    _leaveChallenge();
                  } else {
                    _joinChallenge();
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
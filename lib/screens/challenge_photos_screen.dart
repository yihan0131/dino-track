import 'package:flutter/material.dart';
import '../models/eco_challenge.dart';
import '../repositories/challenge_repository.dart';

class ChallengePhotosScreen extends StatefulWidget {
  final EcoChallenge challenge;
  final String userId;
  final List<Map<String, dynamic>> photos;

  const ChallengePhotosScreen({
    super.key,
    required this.challenge,
    required this.userId,
    required this.photos,
  });

  @override
  State<ChallengePhotosScreen> createState() => _ChallengePhotosScreenState();
}

class _ChallengePhotosScreenState extends State<ChallengePhotosScreen> {
  final ChallengeRepository _challengeRepository = ChallengeRepository();
  bool isLoading = false;

  String _formatDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return "${date.day} ${months[date.month - 1]} ${date.year}";
  }

  Color _getColor() {
    final colors = [
      Colors.pink, Colors.blue, Colors.amber,
      Colors.purple, Colors.teal, Colors.orange,
      Colors.indigo, Colors.green, Colors.red
    ];
    int index = int.tryParse(
        widget.challenge.imageUrl.replaceAll(RegExp(r'[^0-9]'), '')
    ) ?? 1;
    return colors[(index - 1) % colors.length];
  }

  void _showPhotoDetail(Map<String, dynamic> photo) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final bool isRejected = photo['rejected'] == true;
        final bool isApproved = photo['approved'] == true;
        final bool isReported = photo['reported'] == true;
        final bool isUnderReview = isReported && !isApproved && !isRejected;
        final bool isCurrentUserPhoto = photo['userId'] == widget.userId;

        return Dialog(
          insetPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 40),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                    child: Image.network(
                      photo['photoUrl'],
                      width: double.infinity,
                      height: 300,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          height: 300,
                          width: double.infinity,
                          color: Colors.grey.shade200,
                          child: Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                                  : null,
                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF5E8C43)),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton(
                      icon: Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black.withOpacity(0.5),
                        padding: EdgeInsets.all(8),
                      ),
                    ),
                  ),
                  if (isRejected)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        color: Colors.red.withOpacity(0.7),
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          "This photo has been rejected",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  else if (isUnderReview)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        color: Colors.black.withOpacity(0.7),
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          "This photo has been reported and is under review",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: _getColor().withOpacity(0.2),
                          child: Text(
                            photo['username'] != null && photo['username'].isNotEmpty
                                ? photo['username'][0].toUpperCase()
                                : "?",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _getColor(),
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                photo['username'] ?? "User",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                _formatDate(photo['date']),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    // Only show report button if photo is not already reported/rejected and not user's own
                    if (!isReported && !isRejected && !isCurrentUserPhoto)
                      OutlinedButton.icon(
                        icon: Icon(Icons.flag, color: Colors.red),
                        label: Text(
                          "Report Photo",
                          style: TextStyle(color: Colors.red),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.red.shade200),
                        ),
                        onPressed: () {
                          Navigator.of(context).pop();
                          _reportPhoto(photo);
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _reportPhoto(Map<String, dynamic> photo) async {
    // Show confirmation dialog
    bool confirmReport = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Report Photo"),
        content: Text("Are you sure you want to report this photo as inappropriate or unrelated to the challenge?"),
        actions: [
          TextButton(
            child: Text("Cancel"),
            onPressed: () => Navigator.pop(context, false),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
            ),
            child: Text("Report"),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    ) ?? false;

    if (confirmReport) {
      setState(() { isLoading = true; });
      try {
        await _challengeRepository.reportCheckInPhoto(
          photo['userChallengeId'],
          photo['photoUrl'],
        );

        // Update photo in local list
        setState(() {
          final index = widget.photos.indexOf(photo);
          if (index >= 0) {
            widget.photos[index]['reported'] = true;
            widget.photos[index]['approved'] = false;
          }
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Photo reported successfully. It will be reviewed."),
              backgroundColor: Color(0xFF5E8C43),
            )
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Error reporting photo: $e"),
              backgroundColor: Colors.redAccent,
            )
        );
      } finally {
        setState(() { isLoading = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Challenge Photos", style: TextStyle(color: Colors.white)),
        backgroundColor: Color(0xFF5E8C43),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: Color(0xFF5E8C43)))
          : widget.photos.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            SizedBox(height: 16),
            Text(
              "No photos yet",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
            ),
            SizedBox(height: 8),
            Text(
              "Be the first to share your progress!",
              style: TextStyle(
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      )
          : GridView.builder(
        padding: EdgeInsets.all(12),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.8,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: widget.photos.length,
        itemBuilder: (context, index) {
          final photo = widget.photos[index];
          final bool isRejected = photo['rejected'] == true;
          final bool isApproved = photo['approved'] == true;
          final bool isReported = photo['reported'] == true;
          final bool canShowYourPhoto = photo['userId'] == widget.userId && !isReported && !isRejected;

          // Add this check to skip invisible photos
          if (photo['visible'] == false) {
            return SizedBox.shrink(); // Don't render this photo at all
          }

          // Also, if a photo is rejected, don't show it
          if (isRejected) {
            return SizedBox.shrink(); // Don't show rejected photos
          }

          return GestureDetector(
            onTap: () => _showPhotoDetail(photo),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                          child: Image.network(
                            photo['photoUrl'],
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Center(
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF5E8C43)),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.grey.shade200,
                                child: Center(
                                  child: Icon(
                                    Icons.broken_image,
                                    color: Colors.grey.shade400,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        // Different status overlays
                        if (isRejected)
                          Container(
                            color: Colors.black.withOpacity(0.7),
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  "Rejected",
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          )
                        else if (isReported && !isApproved && !isRejected)
                          Container(
                            color: Colors.black.withOpacity(0.6),
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  "Under Review",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                        if (canShowYourPhoto)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _getColor().withOpacity(0.8),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                "Your Photo",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: _getColor().withOpacity(0.2),
                              child: Text(
                                photo['username'] != null && photo['username'].isNotEmpty
                                    ? photo['username'][0].toUpperCase()
                                    : "?",
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: _getColor(),
                                ),
                              ),
                            ),
                            SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                photo['username'] ?? "User",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 2),
                        Text(
                          _formatDate(photo['date']),
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
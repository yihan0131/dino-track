import 'package:flutter/material.dart';
import '../models/recycling_guide.dart';

class GuideDetailScreen extends StatelessWidget {
  final RecyclingGuide guide;
  final Color primaryGreen;
  final Color mediumGreen;
  final Color lightGreen;

  const GuideDetailScreen({super.key, 
    required this.guide,
    required this.primaryGreen,
    required this.mediumGreen,
    required this.lightGreen,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green.shade50 ,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: primaryGreen),
        actions: [

        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Image section with curved shape
            if (guide.imageUrls.isNotEmpty || (guide.useLocalAssets && guide.assetImages.isNotEmpty))
              Stack(
                clipBehavior: Clip.none,
                children: [
                  // Main image with curved bottom
                  Container(
                    margin: EdgeInsets.symmetric(horizontal: 16),
                    child: ClipPath(
                      clipper: CurvedImageClipper(),
                      child: guide.useLocalAssets && guide.assetImages.isNotEmpty
                          ? Image.asset(
                              guide.assetImages[0],
                              height: 240,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            )
                          : guide.imageUrls.isNotEmpty
                              ? Image.network(
                                  guide.imageUrls[0],
                                  height: 240,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                )
                              : Container(
                                  height: 240,
                                  width: double.infinity,
                                  color: lightGreen,
                                  child: Icon(
                                    Icons.recycling,
                                    size: 80,
                                    color: primaryGreen,
                                  ),
                                ),
                    ),
                  ),
                  // Category badge - small pill in top left
                  Positioned(
                    top: 20,
                    left: 30,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: primaryGreen,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: primaryGreen.withOpacity(0.2),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        guide.category == 'recycling' ? "RECYCLING" : "DIY",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            // Title below the image
            Padding(
              padding: const EdgeInsets.only(top: 16.0, left: 20.0, right: 20.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  guide.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 26,
                    color: primaryGreen,
                    fontFamily: 'ComicSans',
                    letterSpacing: 1.1,
                  ),
                ),
              ),
            ),
            // Description in a rounded card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.08),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                padding: EdgeInsets.all(18),
                child: Text(
                  guide.description,
                  style: TextStyle(
                    fontSize: 15,
                    color: primaryGreen,
                    fontFamily: 'ComicSans',
                  ),
                ),
              ),
            ),
            // Details section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 6.0),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: mediumGreen, size: 22),
                  SizedBox(width: 8),
                  Text(
                    "Details",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: primaryGreen,
                      fontFamily: 'ComicSans',
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4.0),
              child: ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: guide.steps.length,
                itemBuilder: (context, idx) {
                  String step = guide.steps[idx];
                  
                  final icons = [
                    Icons.eco,
                    Icons.recycling,
                    Icons.lightbulb_outline,
                    Icons.star,
                    Icons.favorite,
                  ];
                  
                  return Container(
                    margin: EdgeInsets.only(bottom: 12),
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Color(0xFFB7C88E),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: mediumGreen.withOpacity(0.4)),
                      boxShadow: [
                        BoxShadow(
                          color: mediumGreen.withOpacity(0.08),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          icons[idx % icons.length],
                          color: primaryGreen,
                          size: 22,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            step,
                            style: TextStyle(
                              fontSize: 14,
                              color: primaryGreen,
                              fontFamily: 'ComicSans',
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}

// Add the custom clipper for the curved image
class CurvedImageClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.lineTo(0, size.height - 40);
    path.quadraticBezierTo(
      size.width / 2, size.height,
      size.width, size.height - 40,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

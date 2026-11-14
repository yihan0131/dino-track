import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/recycling_guide.dart';
import 'guide_detail_screen.dart';

class RecyclingGuidesScreen extends StatefulWidget {
  const RecyclingGuidesScreen({super.key});

  @override
  _RecyclingGuidesScreenState createState() => _RecyclingGuidesScreenState();
}

class _RecyclingGuidesScreenState extends State<RecyclingGuidesScreen> {
  int selectedTab = 0; // 0: Recycling, 1: DIY
  String searchQuery = '';
  TextEditingController searchController = TextEditingController();

  // Custom colors based on the requested hex values
  final Color primaryGreen = Color(0xFF18562D); // dark
  final Color mediumGreen = Color(0xFF5E8C43); // medium
  final Color lightGreen = Color(0xFFB8D086); // light

  @override
  void initState() {
    super.initState();
    _uploadOrUpdateGuides();
  }

  Future<void> _uploadOrUpdateGuides() async {
    // Get all existing guides from Firestore
    final snapshot = await FirebaseFirestore.instance.collection('recycling_guides').get();

    // Create a map of existing guides with title as key and document ID as value
    final Map<String, DocumentSnapshot> existingGuides = {};
    for (var doc in snapshot.docs) {
      final data = doc.data();
      if (data.containsKey('title')) {
        existingGuides[data['title'] as String] = doc;
      }
    }

    // Define all guides with their complete data
    final guides = [
      // Original guides
      {
        "title": "How to Recycle Paper",
        "description": "Learn the correct way to recycle paper in Malaysia.",
        "category": "recycling",
        "steps": [
          "Separate paper from other waste",
          "Keep paper dry",
          "Remove staples and tape",
          "Flatten cardboard boxes"
        ],
        "imageUrls": [],
        "assetImages": ["assets/recycling_guides/paper_recycling.png"],
        "useLocalAssets": true
      },
      {
        "title": "Plastic Types and How to Recycle",
        "description": "Understand which plastics can be recycled in Malaysia.",
        "category": "recycling",
        "steps": [
          "Empty and rinse the bottle",
          "Remove bottle caps and labels",
          "Crush bottles to save space",
          "Check for recycling codes (usually #1 or #2)",
          "Do not recycle bottles with food residues",
          "Place in plastic recycling bin"
        ],
        "imageUrls": [],
        "assetImages": ["assets/recycling_guides/plastic_types.png"],
        "useLocalAssets": true
      },
      {
        "title": "DIY Eco Bag",
        "description": "Make your own eco-friendly bag from old t-shirts.",
        "category": "diy",
        "steps": [
          "Cut the sleeves",
          "Sew the bottom",
          "Decorate your bag"
        ],
        "imageUrls": [],
        "assetImages": ["assets/diy_guides/eco_bag.png"],
        "useLocalAssets": true
      },

      // New recycling guides
      {
        "title": "How to Recycle Glass",
        "description": "Guide to recycling glass containers and bottles.",
        "category": "recycling",
        "steps": [
          "Sort glass by color if required (clear, green, brown)",
          "Remove lids, caps, and metal rings",
          "Rinse thoroughly to remove residue",
          "Do not recycle broken glass or ceramics",
          "Use a separate bin if glass is collected differently",
          "Avoid mixing glass with other recyclables"
        ],
        "imageUrls": [],
        "assetImages": ["assets/recycling_guides/glass_recycling.png"],
        "useLocalAssets": true
      },
      {
        "title": "How to Recycle Electronics",
        "description": "Safely dispose of electronic waste like phones and laptops.",
        "category": "recycling",
        "steps": [
          "Backup and erase personal data",
          "Remove batteries before recycling",
          "Check if item can be repaired or donated",
          "Drop off at e-waste collection points",
          "Avoid disposing in normal trash",
          "Follow local guidelines for safe e-waste disposal"
        ],
        "imageUrls": [],
        "assetImages": ["assets/recycling_guides/electronics_recycling.png"],
        "useLocalAssets": true
      },
      {
        "title": "How to Recycle Metal Cans",
        "description": "Recycle aluminium and steel cans the right way.",
        "category": "recycling",
        "steps": [
          "Rinse out food or drink residues",
          "Remove labels if possible",
          "Crush cans to save space",
          "Separate aluminium and steel if required",
          "Avoid recycling aerosol cans unless empty and safe",
          "Place in designated metal recycling bin"
        ],
        "imageUrls": [],
        "assetImages": ["assets/recycling_guides/metal_cans.png"],
        "useLocalAssets": true
      },
      {
        "title": "How to Recycle Cartons",
        "description": "Proper method to recycle milk and juice cartons.",
        "category": "recycling",
        "steps": [
          "Empty and rinse the carton",
          "Flatten to save space",
          "Remove plastic caps or straws",
          "Check if local recycling accepts cartons",
          "Avoid food-soiled or wet cartons",
          "Place in mixed paper or carton bin"
        ],
        "imageUrls": [],
        "assetImages": ["assets/recycling_guides/carton_recycling.png"],
        "useLocalAssets": true
      },
      {
        "title": "How to Recycle Used Cooking Oil",
        "description": "Prevent water pollution by recycling used cooking oil.",
        "category": "recycling",
        "steps": [
          "Cool and filter used oil to remove food bits",
          "Pour into a sealed, labelled container",
          "Store away from heat or sunlight",
          "Bring to special oil recycling points",
          "Never pour oil down the sink or drain",
          "Check for collection programs in your area"
        ],
        "imageUrls": [],
        "assetImages": ["assets/recycling_guides/cooking_oil.png"],
        "useLocalAssets": true
      },
      {
        "title": "How to Recycle Batteries",
        "description": "Learn the safe way to recycle used batteries.",
        "category": "recycling",
        "steps": [
          "Do not throw batteries in general waste",
          "Collect dead batteries in a container",
          "Separate by type (AA, AAA, lithium, etc.)",
          "Bring to a battery recycling point",
          "Avoid storing for long periods at home",
          "Never attempt to open or burn batteries"
        ],
        "imageUrls": [],
        "assetImages": ["assets/recycling_guides/battery_recycling.png"],
        "useLocalAssets": true
      },
      {
        "title": "How to Recycle Clothes",
        "description": "Give old clothes a second life through recycling.",
        "category": "recycling",
        "steps": [
          "Wash clothes before recycling or donating",
          "Sort by condition: reusable or not",
          "Donate wearable items to charity",
          "Bring non-wearable items to textile recycling bins",
          "Reuse as rags or in DIY projects",
          "Avoid sending clothes to landfills"
        ],
        "imageUrls": [],
        "assetImages": ["assets/recycling_guides/clothes_recycling.png"],
        "useLocalAssets": true
      },
      {
        "title": "How to Recycle Light Bulbs",
        "description": "Dispose of light bulbs safely and responsibly.",
        "category": "recycling",
        "steps": [
          "Do not put light bulbs in regular recycling bins",
          "Check type: LED, CFL, fluorescent, etc.",
          "Handle carefully to avoid breakage",
          "Bring to collection points for hazardous waste",
          "Store in original packaging if possible",
          "Wash hands after handling broken bulbs"
        ],
        "imageUrls": [],
        "assetImages": ["assets/recycling_guides/light_bulbs.png"],
        "useLocalAssets": true
      },

      // New DIY guides
      {
        "title": "DIY Eco-Bricks",
        "description": "Turn soft plastics into reusable building blocks.",
        "category": "diy",
        "steps": [
          "Collect clean, dry soft plastics",
          "Use a clean plastic bottle as the base",
          "Cut plastic into small pieces",
          "Stuff them tightly into the bottle using a stick",
          "Compress until the bottle becomes solid",
          "Use for garden edges or building material"
        ],
        "imageUrls": [],
        "assetImages": ["assets/diy_guides/eco_bricks.png"],
        "useLocalAssets": true
      },
      {
        "title": "Glass Jar Herb Garden",
        "description": "Reuse old jars to grow herbs indoors.",
        "category": "diy",
        "steps": [
          "Wash and dry empty glass jars",
          "Add small stones at the bottom for drainage",
          "Fill halfway with potting soil",
          "Plant herb seeds like basil or mint",
          "Place by a sunny window",
          "Water regularly and trim when grown"
        ],
        "imageUrls": [],
        "assetImages": ["assets/diy_guides/jar_garden.png"],
        "useLocalAssets": true
      },
      {
        "title": "Newspaper Seed Starters",
        "description": "Make biodegradable pots using old newspapers.",
        "category": "diy",
        "steps": [
          "Cut newspaper into strips",
          "Wrap around a small bottle or cup",
          "Fold and press the bottom to form a base",
          "Slide it off and fill with soil and seeds",
          "Place in a tray and water gently",
          "Plant directly into the ground when ready"
        ],
        "imageUrls": [],
        "assetImages": ["assets/diy_guides/seed_starters.png"],
        "useLocalAssets": true
      },
      {
        "title": "Plastic Bottle Bird Feeder",
        "description": "Create a simple bird feeder with a plastic bottle.",
        "category": "diy",
        "steps": [
          "Clean an empty plastic bottle",
          "Cut two small holes and insert wooden sticks as perches",
          "Make small holes above the sticks for seeds to fall out",
          "Fill with bird seeds",
          "Hang with a string on a tree branch",
          "Refill when empty and enjoy watching birds"
        ],
        "imageUrls": [],
        "assetImages": ["assets/diy_guides/bird_feeder.png"],
        "useLocalAssets": true
      },
      {
        "title": "Toothpaste Tube Pouch",
        "description": "Turn used toothpaste tubes into small pouches.",
        "category": "diy",
        "steps": [
          "Cut open a used toothpaste tube",
          "Clean thoroughly inside and out",
          "Flatten and cut to desired size",
          "Sew or glue the edges",
          "Add a zipper or button on top",
          "Use as a coin pouch or key holder"
        ],
        "imageUrls": [],
        "assetImages": ["assets/diy_guides/toothpaste_pouch.png"],
        "useLocalAssets": true
      },
      {
        "title": "Cardboard Drawer Organizer",
        "description": "Organize your drawers with recycled cardboard.",
        "category": "diy",
        "steps": [
          "Measure your drawer size",
          "Cut cardboard into small dividers",
          "Assemble boxes using glue or tape",
          "Place the compartments inside the drawer",
          "Use to organize socks, stationery, or accessories"
        ],
        "imageUrls": [],
        "assetImages": ["assets/diy_guides/drawer_organizer.png"],
        "useLocalAssets": true
      },
      {
        "title": "Tin Can Lanterns",
        "description": "Make beautiful lanterns using old cans.",
        "category": "diy",
        "steps": [
          "Clean and remove labels from tin cans",
          "Fill with water and freeze (to keep shape)",
          "Use a hammer and nail to punch holes in patterns",
          "Let ice melt and dry the can",
          "Place a candle or LED light inside",
          "Hang or place around your garden"
        ],
        "imageUrls": [],
        "assetImages": ["assets/diy_guides/tin_can_lantern.png"],
        "useLocalAssets": true
      },
      {
        "title": "Old Jeans Planter",
        "description": "Repurpose old jeans into quirky plant holders.",
        "category": "diy",
        "steps": [
          "Cut jeans legs into 20cm sections",
          "Sew one end shut",
          "Fill with soil and plant your seeds",
          "Decorate with patches or fabric paint",
          "Place on balcony or near a window"
        ],
        "imageUrls": [],
        "assetImages": ["assets/diy_guides/jeans_planter.png"],
        "useLocalAssets": true
      },
      {
        "title": "Upcycled Magazine Coasters",
        "description": "Create colorful coasters using old magazines.",
        "category": "diy",
        "steps": [
          "Cut magazine pages into long strips",
          "Roll tightly into a spiral shape",
          "Secure with glue as you roll",
          "Press to flatten the base",
          "Coat with clear varnish for waterproofing",
          "Use for drinks or decoration"
        ],
        "imageUrls": [],
        "assetImages": ["assets/diy_guides/magazine_coasters.png"],
        "useLocalAssets": true
      }
    ];

    // Add or update each guide
    for (var guide in guides) {
      final String title = guide['title'] as String;

      // Check if the guide already exists
      if (existingGuides.containsKey(title)) {
        // Update existing guide
        await FirebaseFirestore.instance
            .collection('recycling_guides')
            .doc(existingGuides[title]!.id)
            .update(guide);
        print('Updated guide: $title');
      } else {
        // Add new guide
        await FirebaseFirestore.instance
            .collection('recycling_guides')
            .add(guide);
        print('Added new guide: $title');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = ['recycling', 'diy'];
    final titles = ['Recycling Guides', 'DIY Guides'];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          titles[selectedTab],
          style: TextStyle(
            color: primaryGreen,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        centerTitle: true,
        iconTheme: IconThemeData(color: primaryGreen),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: searchController,
                onChanged: (value) {
                  setState(() {
                    searchQuery = value;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search ${titles[selectedTab].toLowerCase()}',
                  prefixIcon: Icon(Icons.search, color: primaryGreen),
                  suffixIcon: searchQuery.isNotEmpty
                      ? IconButton(
                    icon: Icon(Icons.clear, color: primaryGreen),
                    onPressed: () {
                      searchController.clear();
                      setState(() {
                        searchQuery = '';
                      });
                    },
                  )
                      : null,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ),
          ),

          // Tab Bar (Styled more like the image)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedTab = 0;
                      });
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: selectedTab == 0 ? primaryGreen : lightGreen,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Text(
                        titles[0],
                        style: TextStyle(
                          color: selectedTab == 0 ? Colors.white : primaryGreen,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedTab = 1;
                      });
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: selectedTab == 1 ? primaryGreen : lightGreen,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Text(
                        titles[1],
                        style: TextStyle(
                          color: selectedTab == 1 ? Colors.white : primaryGreen,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Guides Grid
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('recycling_guides')
                  .where('category', isEqualTo: categories[selectedTab])
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
                if (!snapshot.hasData) return Center(child: CircularProgressIndicator(color: primaryGreen));

                var guides = snapshot.data!.docs
                    .map((doc) => RecyclingGuide.fromMap(doc.data() as Map<String, dynamic>))
                    .toList();

                // Filter guides based on search query
                if (searchQuery.isNotEmpty) {
                  guides = guides
                      .where((guide) =>
                  guide.title.toLowerCase().contains(searchQuery.toLowerCase()) ||
                      guide.description.toLowerCase().contains(searchQuery.toLowerCase()))
                      .toList();
                }

                if (guides.isEmpty) {
                  return Center(child: Text(
                      searchQuery.isEmpty ? 'No guides found.' : 'No matches found.',
                      style: TextStyle(color: primaryGreen)
                  ));
                }

                return GridView.builder(
                  padding: EdgeInsets.all(16),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    mainAxisExtent: 200, // Adjusted to accommodate the new layout
                  ),
                  itemCount: guides.length,
                  itemBuilder: (context, i) => GuideGridCard(
                    guide: guides[i],
                    primaryGreen: primaryGreen,
                    mediumGreen: mediumGreen,
                    lightGreen: lightGreen,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class GuideGridCard extends StatelessWidget {
  final RecyclingGuide guide;
  final Color primaryGreen;
  final Color mediumGreen;
  final Color lightGreen;

  const GuideGridCard({super.key, 
    required this.guide,
    required this.primaryGreen,
    required this.mediumGreen,
    required this.lightGreen,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => GuideDetailScreen(
                  guide: guide,
                  primaryGreen: primaryGreen,
                  mediumGreen: mediumGreen,
                  lightGreen: lightGreen,
                )
            )
        );
      },
      child: Card(
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        elevation: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image section
            Expanded(
              flex: 3,
              child: ClipRRect(
                borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
                child: guide.useLocalAssets && guide.assetImages.isNotEmpty
                    ? Image.asset(
                  guide.assetImages[0],
                  fit: BoxFit.cover,
                  width: double.infinity,
                )
                    : guide.imageUrls.isNotEmpty
                    ? Image.network(
                  guide.imageUrls[0],
                  fit: BoxFit.cover,
                  width: double.infinity,
                )
                    : Container(
                  color: lightGreen,
                  child: Icon(
                    Icons.recycling,
                    size: 50,
                    color: primaryGreen,
                  ),
                ),
              ),
            ),
            // Text section - more compact
            Expanded(
              flex: 2,
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      guide.title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: primaryGreen,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    Text(
                      guide.description,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
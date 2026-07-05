import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyAU4QaqR7XFEciyEk0vVHITVUDuUeMc7Q0",
      appId: "1:713228731396:web:991bf9759ce9b63290a151",
      messagingSenderId: "713228731396",
      projectId: "smart-parking-system-995c3",
      storageBucket: "smart-parking-system-995c3.firebasestorage.app",
      authDomain: "smart-parking-system-995c3.firebaseapp.com",
      databaseURL: "https://smart-parking-system-995c3-default-rtdb.firebaseio.com",
    ),
  );
  runApp(const SmartParkingApp());
}

class SmartParkingApp extends StatefulWidget {
  const SmartParkingApp({super.key});
  @override
  State<SmartParkingApp> createState() => _SmartParkingAppState();
}

class _SmartParkingAppState extends State<SmartParkingApp> {
  bool _isDarkMode = false;
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: _isDarkMode ? Brightness.dark : Brightness.light,
        scaffoldBackgroundColor: _isDarkMode ? const Color(0xFF0A0E21) : const Color(0xFFF4F6F9),
      ),
      home: ParkingDashboard(
          isDarkMode: _isDarkMode,
          onThemeToggle: () => setState(() => _isDarkMode = !_isDarkMode)
      ),
    );
  }
}

class ParkingDashboard extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback onThemeToggle;
  const ParkingDashboard({super.key, required this.isDarkMode, required this.onThemeToggle});

  @override
  State<ParkingDashboard> createState() => _ParkingDashboardState();
}

class _ParkingDashboardState extends State<ParkingDashboard> {
  // المراجع الحية لعقد قاعدة البيانات (مجلد الحساسات ومجلد المواقع)
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref('parking');
  final DatabaseReference _zonesRef = FirebaseDatabase.instance.ref('parking_zones');

  final MapController _mapController = MapController();
  final SearchController _searchController = SearchController();

  int availableSlots = 0;
  int occupiedSlots = 0;
  String slot1 = 'empty';
  String slot2 = 'empty';
  String slot3 = 'empty';
  String slot4 = 'empty';
  String slot5 = 'empty';

  int _currentIndex = 0;

  // موقع افتراضي تبدأ الخريطة بالوقوف عليه أول ما تفتح (ساحة كلية الحاسبات FCIT)
  final LatLng _defaultLocation = const LatLng(21.497545, 39.245734);

  // القوائم والمصفوفات الديناميكية المستخرجة حياً من الفايربيس
  List<String> _parkingOptions = [];
  Map<String, LatLng> _parkingCoordinatesMap = {};

  @override
  void initState() {
    super.initState();

    // 1. الاستماع الحي لحالات كشافات المواقف والحسبة الديناميكية
    _dbRef.onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data != null) {
        setState(() {
          slot1 = data['slot1']?.toString() ?? 'empty';
          slot2 = data['slot2']?.toString() ?? 'empty';
          slot3 = data['slot3']?.toString() ?? 'empty';
          slot4 = data['slot4']?.toString() ?? 'empty';
          slot5 = data['slot5']?.toString() ?? 'empty';

          int calcAvailable = 0;
          int calcOccupied = 0;
          List<String> currentSlots = [slot1, slot2, slot3, slot4, slot5];

          for (var status in currentSlots) {
            if (status == 'empty') {
              calcAvailable++;
            } else {
              calcOccupied++;
            }
          }

          availableSlots = calcAvailable;
          occupiedSlots = calcOccupied;
        });
      }
    });

    // 2. الاستماع الحي لجلب أسماء المواقف وإحداثياتها الجغرافية من الفايربيس
    _zonesRef.onValue.listen((event) {
      final zonesData = event.snapshot.value as Map<dynamic, dynamic>?;
      if (zonesData != null) {
        setState(() {
          _parkingOptions.clear();
          _parkingCoordinatesMap.clear();

          zonesData.forEach((key, value) {
            String zoneName = value['name'].toString();
            double lat = double.parse(value['lat'].toString());
            double lng = double.parse(value['lng'].toString());

            _parkingOptions.add(zoneName);
            _parkingCoordinatesMap[zoneName] = LatLng(lat, lng);
          });
        });
      }
    });
  }

  // 3. دالة الحركة والتحريك الذكي بناءً على الخيار المختار في البحث
  void _navigateToParking(String selection) {
    if (selection.isEmpty) return;

    Color cardBg = widget.isDarkMode ? const Color(0xFF1D1E33) : Colors.white;
    Color textColor = widget.isDarkMode ? Colors.white : const Color(0xFF0A0E21);

    if (_parkingCoordinatesMap.containsKey(selection)) {
      LatLng targetLocation = _parkingCoordinatesMap[selection]!;

      // تحريك الكاميرا للموقع الجغرافي المسحوب من الفايربيس
      _mapController.move(targetLocation, 17.5);

      Future.delayed(const Duration(milliseconds: 300), () {
        // إذا كان الموقف المختار هو الموقع التجريبي الفعلي (Zone A) نفتح البطاقة الحية
        if (selection.contains('Zone A') || selection.contains('Testing Site')) {
          _showParkingDetailsBottomSheet(context, selection, cardBg, textColor);
        } else {
          // باقي المواقف المستقبلية القادمة من قاعدة البيانات تظهر "قريباً"
          _showComingSoonToast(selection);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Color cardBg = widget.isDarkMode ? const Color(0xFF1D1E33) : Colors.white;
    Color textColor = widget.isDarkMode ? Colors.white : const Color(0xFF0A0E21);
    Color navBg = widget.isDarkMode ? const Color(0xFF161930) : Colors.white;

    return Scaffold(
      body: SafeArea(
        child: _currentIndex == 0
            ? _buildMapPage(cardBg, textColor)
            : _buildComingSoonPage(_getPageTitle(), textColor, cardBg),
      ),
      bottomNavigationBar: Container(
        height: 75,
        decoration: BoxDecoration(
          color: navBg,
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, -2))],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(0, Icons.map_outlined, "Map"),
            _buildNavItem(1, Icons.calendar_month_outlined, "Bookings"),
            GestureDetector(
              onTap: () => setState(() => _currentIndex = 4),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _currentIndex == 4 ? Colors.cyanAccent : Colors.teal,
                  shape: BoxShape.circle,
                  boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 5, offset: Offset(0, 2))],
                ),
                child: Center(
                  child: Text(
                    "P",
                    style: TextStyle(
                        color: _currentIndex == 4 ? const Color(0xFF0A0E21) : Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold
                    ),
                  ),
                ),
              ),
            ),
            _buildNavItem(2, Icons.access_time_rounded, "History"),
            _buildNavItem(3, Icons.person_outline_rounded, "Profile"),
          ],
        ),
      ),
    );
  }

  Widget _buildMapPage(Color cardBg, Color textColor) {
    // جلب الإحداثيات حياً للماركرز، لو لم تكتمل دالة الـ listen بعد نضع القيم الافتراضية كخيار أمان
    LatLng pinA = _parkingCoordinatesMap['Testing Site (Zone A)'] ?? _defaultLocation;
    LatLng pinB = _parkingCoordinatesMap['Science Parking (Zone B)'] ?? const LatLng(21.497288, 39.244564);

    return Stack(
      children: [
        Positioned.fill(
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _defaultLocation,
              initialZoom: 16.5,
              minZoom: 3.0,
              maxZoom: 18.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.smart_parking',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: pinA,
                    width: 36, height: 36,
                    child: GestureDetector(
                      onTap: () => _showParkingDetailsBottomSheet(context, "Testing Site (Zone A)", cardBg, textColor),
                      child: _buildCustomMapPin(Colors.cyanAccent, true),
                    ),
                  ),
                  Marker(
                    point: pinB,
                    width: 36, height: 36,
                    child: GestureDetector(
                      onTap: () => _showComingSoonToast("Science Parking (Zone B)"),
                      child: _buildCustomMapPin(Colors.grey.shade600, false),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Positioned(
          top: 15, left: 15, right: 15,
          child: Row(
            children: [
              Expanded(
                child: SearchAnchor(
                  searchController: _searchController,
                  builder: (BuildContext context, SearchController controller) {
                    return SearchBar(
                      controller: controller,
                      padding: const WidgetStatePropertyAll<EdgeInsets>(EdgeInsets.symmetric(horizontal: 16.0)),
                      onTap: () => controller.openView(),
                      onChanged: (_) => controller.openView(),
                      leading: const Icon(Icons.search_rounded, color: Colors.cyanAccent),
                      hintText: "Search parking zones...",
                      hintStyle: WidgetStatePropertyAll<TextStyle>(TextStyle(color: textColor.withOpacity(0.4), fontSize: 13)),
                      backgroundColor: WidgetStatePropertyAll<Color>(cardBg),
                      elevation: const WidgetStatePropertyAll<double>(4.0),
                      shape: WidgetStatePropertyAll<OutlinedBorder>(RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                      textStyle: WidgetStatePropertyAll<TextStyle>(TextStyle(color: textColor, fontSize: 14)),
                    );
                  },
                  suggestionsBuilder: (BuildContext context, SearchController controller) {
                    final String keyword = controller.text.toLowerCase();
                    return _parkingOptions
                        .where((option) => option.toLowerCase().contains(keyword))
                        .map((String option) {
                      return ListTile(
                        leading: Icon(
                          option.contains('Testing') ? Icons.stars_rounded : Icons.lock_clock_rounded,
                          color: option.contains('Testing') ? Colors.cyanAccent : Colors.grey,
                        ),
                        title: Text(option, style: TextStyle(color: textColor)),
                        onTap: () {
                          setState(() {
                            controller.closeView(option);
                            _navigateToParking(option);
                          });
                        },
                      );
                    }).toList();
                  },
                ),
              ),
              const SizedBox(width: 10),
              Container(
                decoration: BoxDecoration(
                    color: cardBg,
                    shape: BoxShape.circle,
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)]
                ),
                child: IconButton(
                    icon: Icon(widget.isDarkMode ? Icons.light_mode : Icons.dark_mode, color: Colors.cyanAccent),
                    onPressed: widget.onThemeToggle
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildComingSoonPage(String title, Color textColor, Color cardBg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.teal.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_clock_rounded, size: 65, color: Colors.teal),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor, letterSpacing: 0.5),
            ),
            const SizedBox(height: 12),
            Text(
              "This feature is not supported yet.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: textColor.withOpacity(0.6)),
            ),
            const SizedBox(height: 6),
            const Text(
              "Coming soon!",
              style: TextStyle(fontSize: 16, color: Colors.teal, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    bool isSelected = _currentIndex == index;
    Color iconColor = isSelected ? Colors.teal : Colors.grey;

    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: iconColor, fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }

  String _getPageTitle() {
    switch (_currentIndex) {
      case 1: return "Bookings Center";
      case 2: return "History Logs";
      case 3: return "User Profile";
      case 4: return "Logo Control Center";
      default: return "Feature";
    }
  }

  Widget _buildCustomMapPin(Color accentColor, bool isActive) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0A0E21).withOpacity(0.9),
        shape: BoxShape.circle,
        border: Border.all(color: accentColor, width: 2.0),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(isActive ? 0.4 : 0.1),
            blurRadius: isActive ? 6 : 3,
            spreadRadius: isActive ? 1 : 0,
          )
        ],
      ),
      child: Center(
        child: Text(
          "P",
          style: TextStyle(
            color: accentColor,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void _showComingSoonToast(String zoneName) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.lock_clock_rounded, color: Colors.amberAccent),
            const SizedBox(width: 10),
            Text("$zoneName is coming soon!", style: const TextStyle(fontWeight: FontWeight.w500)),
          ],
        ),
        backgroundColor: const Color(0xFF1D1E33),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showParkingDetailsBottomSheet(BuildContext context, String zoneTitle, Color bg, Color txtColor) {
    showModalBottomSheet(
      context: context,
      backgroundColor: bg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.65,
          child: StatefulBuilder(
            builder: (BuildContext context, StateSetter setModalState) {
              _dbRef.onValue.listen((event) {
                final data = event.snapshot.value as Map<dynamic, dynamic>?;
                if (data != null && context.mounted) {
                  setModalState(() {
                    slot1 = data['slot1']?.toString() ?? 'empty';
                    slot2 = data['slot2']?.toString() ?? 'empty';
                    slot3 = data['slot3']?.toString() ?? 'empty';
                    slot4 = data['slot4']?.toString() ?? 'empty';
                    slot5 = data['slot5']?.toString() ?? 'empty';

                    int calcAvailable = 0;
                    int calcOccupied = 0;
                    List<String> currentSlots = [slot1, slot2, slot3, slot4, slot5];

                    for (var status in currentSlots) {
                      if (status == 'empty') {
                        calcAvailable++;
                      } else {
                        calcOccupied++;
                      }
                    }
                    availableSlots = calcAvailable;
                    occupiedSlots = calcOccupied;
                  });
                }
              });

              int totalCalculated = availableSlots + occupiedSlots;
              double occupancyRate = totalCalculated > 0 ? (occupiedSlots / totalCalculated) * 100 : 0;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(child: Container(width: 55, height: 5, decoration: BoxDecoration(color: txtColor.withOpacity(0.15), borderRadius: BorderRadius.circular(10)))),
                    const SizedBox(height: 25),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(zoneTitle, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: txtColor)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(color: Colors.green.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                          child: Text("$availableSlots / $totalCalculated Available", style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                        )
                      ],
                    ),
                    const Divider(height: 35, color: Colors.white10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _card("Available", "$availableSlots", Colors.green, txtColor),
                        _card("Occupied", "$occupiedSlots", Colors.red, txtColor),
                        _card("Total", "$totalCalculated", Colors.blueAccent, txtColor),
                        _card("Rate", "${occupancyRate.toInt()}%", Colors.orange, txtColor),
                      ],
                    ),
                    const SizedBox(height: 35),
                    Text("LIVE SENSORS STATUS", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: txtColor.withOpacity(0.5), letterSpacing: 1)),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 90,
                      child: GridView.count(
                        crossAxisCount: 5,
                        crossAxisSpacing: 10,
                        children: [
                          _tile("01", slot1),
                          _tile("02", slot2),
                          _tile("03", slot3),
                          _tile("04", slot4),
                          _tile("05", slot5),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _card(String title, String value, Color color, Color tc) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(12)),
      child: Column(
          children: [
            Text(value, style: TextStyle(color: tc, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(title, style: const TextStyle(fontSize: 10, color: Colors.grey))
          ]
      ),
    );
  }

  Widget _tile(String label, String status) {
    bool isEmpty = status == 'empty';
    return Container(
      decoration: BoxDecoration(
          color: isEmpty ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isEmpty ? Colors.green : Colors.red, width: 1.5)
      ),
      child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Icon(isEmpty ? Icons.lock_open : Icons.lock, size: 16, color: isEmpty ? Colors.green : Colors.red)
          ]
      ),
    );
  }
}
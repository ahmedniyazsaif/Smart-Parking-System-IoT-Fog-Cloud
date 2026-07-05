import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const SmartParkingApp());
}

class SmartParkingApp extends StatelessWidget {
  const SmartParkingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0A0E21),
        primaryColor: const Color(0xFF0A0E21),
      ),
      home: const ParkingDashboard(),
    );
  }
}

class ParkingDashboard extends StatefulWidget {
  const ParkingDashboard({super.key});

  @override
  State<ParkingDashboard> createState() => _ParkingDashboardState();
}

class _ParkingDashboardState extends State<ParkingDashboard> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  Map<String, String> slots = {
    "slot1": "empty",
    "slot2": "empty",
    "slot3": "empty",
    "slot4": "empty",
    "slot5": "empty",
  };

  @override
  void initState() {
    super.initState();
    _listenToParking();
  }

  void _listenToParking() {
    _dbRef.child('parking').onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data != null) {
        setState(() {
          slots["slot1"] = data["slot1"] ?? "empty";
          slots["slot2"] = data["slot2"] ?? "empty";
          slots["slot3"] = data["slot3"] ?? "empty";
          slots["slot4"] = data["slot4"] ?? "empty";
          slots["slot5"] = data["slot5"] ?? "empty";
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    int available = slots.values.where((v) => v == "empty").length;
    double occupancyRate = ((5 - available) / 5) * 100;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // الجزء العلوي: البحث والإعدادات
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      height: 50,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1D1E33),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const TextField(
                        decoration: InputDecoration(
                          hintText: "ابحث عن موقف (KAU...)",
                          border: InputBorder.none,
                          icon: Icon(Icons.search, color: Colors.white54),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  // زر الإعدادات (فوق يسار)
                  PopupMenuButton<String>(
                    icon: const Icon(
                      Icons.menu_open,
                      color: Colors.cyanAccent,
                      size: 30,
                    ),
                    color: const Color(0xFF1D1E33),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'lang',
                        child: Text("اللغة / Language"),
                      ),
                      const PopupMenuItem(
                        value: 'dark',
                        child: Text("الوضع الداكن"),
                      ),
                      const PopupMenuItem(
                        value: 'support',
                        child: Text("اتصل بالدعم"),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // عداد النسبة والعدد (زي الصورة)
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${occupancyRate.toInt()}%",
                        style: const TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: Colors.redAccent,
                        ),
                      ),
                      const Text(
                        "نسبة الإشغال",
                        style: TextStyle(color: Colors.white54),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        "$available/5",
                        style: const TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: Colors.greenAccent,
                        ),
                      ),
                      const Text(
                        "متاح حالياً",
                        style: TextStyle(color: Colors.white54),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // خريطة تفاعلية (في النص)
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1D1E33),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white10),
                ),
                child: Stack(
                  children: [
                    const Center(
                      child: Text(
                        "خريطة المواقف",
                        style: TextStyle(color: Colors.white10, fontSize: 30),
                      ),
                    ),
                    GridView.builder(
                      padding: const EdgeInsets.all(30),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 20,
                            mainAxisSpacing: 20,
                            childAspectRatio: 1.5,
                          ),
                      itemCount: 5,
                      itemBuilder: (context, index) {
                        String slotKey = "slot${index + 1}";
                        bool isOccupied = slots[slotKey] == "occupied";
                        return GestureDetector(
                          onTap: () {
                            // حركة لما يضغط على الموقف في الخريطة
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("موقف رقم ${index + 1}")),
                            );
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 500),
                            decoration: BoxDecoration(
                              color: isOccupied
                                  ? Colors.redAccent.withOpacity(0.3)
                                  : Colors.greenAccent.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isOccupied
                                    ? Colors.redAccent
                                    : Colors.greenAccent,
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: Icon(
                                isOccupied
                                    ? Icons.directions_car
                                    : Icons.local_parking,
                                color: isOccupied
                                    ? Colors.redAccent
                                    : Colors.greenAccent,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            const Padding(
              padding: EdgeInsets.only(bottom: 20),
              child: Text(
                "KAU Engineering Parking - Zone A",
                style: TextStyle(color: Colors.white24),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

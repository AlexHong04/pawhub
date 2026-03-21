import 'package:flutter/material.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => AdminDashboardPageState();
}

class AdminDashboardPageState extends State<AdminDashboardPage> {
  int _selectedFilterIndex = 1; // 0: Today, 1: Per Month, 2: Per Year
  int _bottomNavIndex = 0; // Dash is active

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Data View Toggle
            _buildDataViewToggle(),
            const SizedBox(height: 24),

            // 4 Stats Grid
            _buildStatsGrid(),
            const SizedBox(height: 24),

            // Bar Chart Card (Monthly Donations)
            _buildBarChartCard(),
            const SizedBox(height: 24),

            // Line Chart Card (Adoption Trends)
            _buildLineChartCard(),
            const SizedBox(height: 32),

            // Recent Applications Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Recent Adoption Applications",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF101828),
                  ),
                ),
                TextButton(
                  onPressed: () {},
                  child: const Text(
                    "VIEW ALL",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2E82F4),
                      fontSize: 12,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Applications List
            _buildApplicationCard(
              "Cooper",
              "Applied by Sarah Jenkins",
              "PENDING",
              "2 hours ago",
              Colors.orange,
            ),
            _buildApplicationCard(
              "Luna",
              "Applied by Mark Wilson",
              "APPROVED",
              "5 hours ago",
              Colors.green,
            ),
            _buildApplicationCard(
              "Oliver",
              "Applied by Emily Chen",
              "REVIEWING",
              "Yesterday",
              Colors.blue,
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // --- WIDGET BUILDERS ---

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: 70,
      leadingWidth: 70,
      leading: Padding(
        padding: const EdgeInsets.only(left: 20, top: 8, bottom: 8),
        child: const CircleAvatar(
          backgroundColor: Color(0xFFE0E5EC),
          backgroundImage: AssetImage(
            'assets/images/profile_placeholder.png',
          ), // Replace with your avatar
        ),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            "Admin Dashboard",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF101828),
            ),
          ),
          Text(
            "Welcome back, Alex",
            style: TextStyle(fontSize: 13, color: Color(0xFF667085)),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search, color: Color(0xFF667085)),
          onPressed: () {},
        ),
        Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: const Icon(
                Icons.notifications_none,
                color: Color(0xFF667085),
              ),
              onPressed: () {},
            ),
            Positioned(
              top: 15,
              right: 15,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF2E82F4),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 10),
      ],
    );
  }

  Widget _buildDataViewToggle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          "DATA VIEW",
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: Color(0xFF98A2B3),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFF2F4F7), // Light grey background
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              _buildTogglePill("Today", 0),
              _buildTogglePill("Per Month", 1),
              _buildTogglePill("Per Year", 2),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTogglePill(String text, int index) {
    bool isSelected = _selectedFilterIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilterIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected
                ? const Color(0xFF2E82F4)
                : const Color(0xFF667085),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsGrid() {
    return Row(
      children: [
        Expanded(
          child: Column(
            children: [
              _buildStatCard(
                "TOTAL FUND",
                "\$12,450",
                "+12%",
                "VS LAST MONTH",
                Icons.payments_outlined,
                true,
              ),
              const SizedBox(height: 16),
              _buildStatCard(
                "PENDING PICKUPS",
                "14",
                "-2%",
                "EFFICIENCY",
                Icons.local_shipping_outlined,
                false,
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            children: [
              _buildStatCard(
                "TOTAL PETS",
                "128",
                "+5%",
                "NEW ARRIVALS",
                Icons.pets,
                true,
              ),
              const SizedBox(height: 16),
              _buildStatCard(
                "UPCOMING EVENTS",
                "6",
                "+10%",
                "ENGAGEMENT",
                Icons.calendar_today_outlined,
                true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    String pct,
    String subtitle,
    IconData icon,
    bool isPositive,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E5EC), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: Color(0xFF667085),
                ),
              ),
              Icon(icon, size: 18, color: const Color(0xFF98A2B3)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF101828),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isPositive
                      ? const Color(0xFFE6F4EA)
                      : const Color(0xFFFCE8E8),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  pct,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isPositive
                        ? const Color(0xFF12B76A)
                        : const Color(0xFFF04438),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF98A2B3),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBarChartCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E5EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "MONTHLY DONATIONS",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: Color(0xFF667085),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE6F4EA),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  "+15%",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF12B76A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            "\$4,200",
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF101828),
            ),
          ),
          const SizedBox(height: 24),

          // Custom Bar Chart
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildBar(0.7, "JAN"),
              _buildBar(0.3, "FEB"),
              _buildBar(0.6, "MAR"),
              _buildBar(0.4, "APR"),
              _buildBar(0.8, "MAY"),
              _buildBar(0.5, "JUN"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBar(double percentage, String label) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Container(
              width: 36,
              height: 100,
              decoration: BoxDecoration(
                color: const Color(0xFFF2F4F7),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            Container(
              width: 36,
              height: 100 * percentage,
              decoration: BoxDecoration(
                color: const Color(0xFF539DF8),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Color(0xFF98A2B3),
          ),
        ),
      ],
    );
  }

  Widget _buildLineChartCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E5EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "ADOPTION TRENDS",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: Color(0xFF667085),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFCE8E8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  "-3%",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFF04438),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            "45 Pets",
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF101828),
            ),
          ),
          const SizedBox(height: 24),

          // Custom Curved Line Chart UI
          SizedBox(
            height: 120,
            width: double.infinity,
            child: Stack(
              children: [
                // Y-Axis Labels & Grid lines
                Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildGridLine("60"),
                    _buildGridLine("40"),
                    _buildGridLine("20"),
                    _buildGridLine("0"),
                  ],
                ),
                // The Line (Using CustomPaint for that smooth curve)
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.only(
                      left: 30,
                      right: 10,
                      top: 10,
                      bottom: 10,
                    ),
                    child: CustomPaint(painter: _CurvePainter()),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // X-Axis Labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: const [
              Text(
                "2021",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF667085),
                ),
              ),
              Text(
                "2022",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF667085),
                ),
              ),
              Text(
                "2023",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF667085),
                ),
              ),
              Text(
                "2024",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF667085),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGridLine(String value) {
    return Row(
      children: [
        SizedBox(
          width: 20,
          child: Text(
            value,
            style: const TextStyle(fontSize: 10, color: Color(0xFF98A2B3)),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Container(height: 1, color: const Color(0xFFF2F4F7))),
      ],
    );
  }

  Widget _buildApplicationCard(
    String petName,
    String applicant,
    String status,
    String time,
    MaterialColor colorBadge,
  ) {
    Color bgBadge = colorBadge.shade50;
    Color textBadge = colorBadge.shade700;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E5EC)),
      ),
      child: Row(
        children: [
          // Pet Image (Using a grey container as placeholder)
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFFE0E5EC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.pets,
              color: Colors.white,
            ), // Swap with Image.network or AssetImage
          ),
          const SizedBox(width: 16),
          // Names
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  petName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF101828),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  applicant,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF667085),
                  ),
                ),
              ],
            ),
          ),
          // Status & Time
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: bgBadge,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: textBadge,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                time,
                style: const TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: Color(0xFF98A2B3),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return BottomNavigationBar(
      currentIndex: _bottomNavIndex,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: const Color(0xFF2E82F4),
      unselectedItemColor: const Color(0xFF98A2B3),
      selectedLabelStyle: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 10,
      ),
      unselectedLabelStyle: const TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 10,
      ),
      onTap: (index) => setState(() => _bottomNavIndex = index),
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: "DASH"),
        BottomNavigationBarItem(icon: Icon(Icons.pets), label: "PETS"),
        BottomNavigationBarItem(
          icon: Icon(Icons.calendar_today_outlined),
          label: "EVENTS",
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.badge_outlined),
          label: "ADOPT",
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.people_outline),
          label: "COMM",
        ),
        BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: "ACC"),
      ],
    );
  }
}

// --- CUSTOM PAINTER FOR THE SMOOTH LINE CHART ---
class _CurvePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    var paint = Paint()
      ..color = const Color(0xFF2E82F4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    var path = Path();
    // Start at bottom left
    path.moveTo(0, size.height * 0.8);
    // Curve up to peak (2022)
    path.cubicTo(
      size.width * 0.2,
      size.height * 0.8,
      size.width * 0.2,
      size.height * 0.1,
      size.width * 0.35,
      size.height * 0.1,
    );
    // Curve down to dip (2023)
    path.cubicTo(
      size.width * 0.5,
      size.height * 0.1,
      size.width * 0.55,
      size.height * 0.7,
      size.width * 0.7,
      size.height * 0.7,
    );
    // Little bump to end (2024)
    path.cubicTo(
      size.width * 0.85,
      size.height * 0.7,
      size.width * 0.85,
      size.height * 0.5,
      size.width,
      size.height * 0.95,
    );

    canvas.drawPath(path, paint);

    // Draw the dots on the nodes
    var dotPaintWhite = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    var dotPaintBlue = Paint()
      ..color = const Color(0xFF2E82F4)
      ..style = PaintingStyle.fill;

    void drawDot(Offset offset) {
      canvas.drawCircle(offset, 6, dotPaintWhite); // White border
      canvas.drawCircle(offset, 4, dotPaintBlue); // Blue core
    }

    drawDot(Offset(0, size.height * 0.8));
    drawDot(Offset(size.width * 0.35, size.height * 0.1));
    drawDot(Offset(size.width * 0.7, size.height * 0.7));
    drawDot(Offset(size.width, size.height * 0.95));
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

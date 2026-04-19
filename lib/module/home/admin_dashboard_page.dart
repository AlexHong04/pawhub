import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:pawhub/core/widgets/profile_avatar.dart';
import 'package:pawhub/module/Profile/service/profile_service.dart';
import 'package:pawhub/module/donation/presentation/admin_donation_page.dart';
import 'package:pawhub/module/donation/service/donation_service.dart';

import '../../core/constants/colors.dart';
import '../../../core/utils/qr_service.dart';
import '../communityPost/model/post_model.dart';
import '../communityPost/service/post_service.dart';
import '../communityPost/presentation/post_details_page.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => AdminDashboardPageState();
}

class AdminDashboardPageState extends State<AdminDashboardPage> {
  int _selectedFilterIndex = 1; // 0: Today, 1: Per Month, 2: Per Year
  final DonationService _donationService = DonationService();
  final PostService _postService = PostService();

  bool _isLoading = true;
  List<dynamic> _allDonations = [];
  List<dynamic> _filteredDonations = [];
  int _totalUsers = 0;
  int _pendingCount = 0;
  double _totalFund = 0;
  String _currentUserId = '';
  String _currentUserName = 'Admin';
  String _currentUserAvatarUrl = '';

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);

    try {
      final donations = await _donationService.fetchAllDonations();
      final users = await ProfileService.getAllUsers();
      final currentProfile = await ProfileService.getCurrentUserProfile();

      _allDonations = donations;
      _totalUsers = users.length;
      _currentUserId = currentProfile?.id ?? '';
      _currentUserName = (currentProfile?.name ?? '').trim().isNotEmpty == true
          ? currentProfile!.name
          : 'Admin';
      _currentUserAvatarUrl = currentProfile?.avatarUrl ?? '';
      _recomputeMetrics();
    } catch (_) {
      _allDonations = [];
      _filteredDonations = [];
      _totalUsers = 0;
      _pendingCount = 0;
      _totalFund = 0;
      _currentUserId = '';
      _currentUserName = 'Admin';
      _currentUserAvatarUrl = '';
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _recomputeMetrics() {
    final now = DateTime.now();

    bool matchRange(DateTime date) {
      if (_selectedFilterIndex == 0) {
        return date.year == now.year && date.month == now.month && date.day == now.day;
      }
      if (_selectedFilterIndex == 1) {
        return date.year == now.year && date.month == now.month;
      }
      return date.year == now.year;
    }

    final filtered = _allDonations.where((row) {
      final created = DateTime.tryParse((row['created_at'] ?? '').toString());
      if (created == null) return false;
      return matchRange(created.toLocal());
    }).toList();

    double sum = 0;
    int pending = 0;
    for (final row in filtered) {
      final status = _parseDonationStatus(row);
      if (status == 'pending') pending++;
      if (status == 'successful') {
        sum += _parseDonationAmount(row);
      }
    }

    _filteredDonations = filtered;
    _pendingCount = pending;
    _totalFund = sum;
  }
  void _processScannedData(String? scannedValue) async {
    if (scannedValue == null || !scannedValue.startsWith("pawhub://post/")) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Invalid PawHub QR Code"), backgroundColor: Colors.orange),
        );
      }
      return;
    }

    final String postId = scannedValue.replaceFirst("pawhub://post/", "");

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Loading post...")),
      );
    }

    try {
      final CommunityPostModel? targetPost = await _postService.fetchPostById(postId);

      if (!mounted) return;

      if (targetPost != null) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => PostDetailsPage(post: targetPost, isAdmin: true)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Post not found or deleted"), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error loading post"), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showScanOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.only(bottom: 30, top: 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 5,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
            ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.blue.shade50, shape: BoxShape.circle),
                child: Icon(Icons.camera_alt_rounded, color: Colors.blue.shade600, size: 22),
              ),
              title: const Text('Scan with Camera', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              onTap: () async {
                Navigator.pop(context);
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const QRScannerPage(id: 'admin_dashboard')),
                );
                _processScannedData(result as String?);
              },
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle),
                child: Icon(Icons.photo_library_rounded, color: Colors.green.shade600, size: 22),
              ),
              title: const Text('Pick from Gallery', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              onTap: () async {
                Navigator.pop(context);
                final ImagePicker picker = ImagePicker();
                final XFile? image = await picker.pickImage(source: ImageSource.gallery);

                if (image != null) {
                  final MobileScannerController controller = MobileScannerController();
                  final BarcodeCapture? capture = await controller.analyzeImage(image.path);

                  if (capture != null && capture.barcodes.isNotEmpty) {
                    _processScannedData(capture.barcodes.first.rawValue);
                  } else {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("No QR Code found in the image"), backgroundColor: Colors.orange),
                      );
                    }
                  }
                  controller.dispose();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.dashboardBackground,
      appBar: _buildAppBar(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
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

            // Recent Donations Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    "Recent Donations",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.dashboardHeading,
                    ),
                  ),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AdminDonationPage()),
                    );
                  },
                  child: const Text(
                    "VIEW ALL",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.dashboardBlue,
                      fontSize: 12,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Donation List
            ..._buildRecentDonationCards(),

            const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  // --- WIDGET BUILDERS ---

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: 70,
      leadingWidth: 70,
      leading: Padding(
        padding: const EdgeInsets.only(left: 20, top: 8, bottom: 8),
        child: ProfileAvatar(
          userId: _currentUserId,
          name: _currentUserName,
          avatarUrl: _currentUserAvatarUrl,
          radius: 22,
          backgroundColor: AppColors.dashboardBorder,
          fallbackTextStyle: const TextStyle(
            color: AppColors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "Admin Dashboard",
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.dashboardHeading,
            ),
          ),
          Text(
            "Welcome back, $_currentUserName",
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, color: AppColors.dashboardSubtitle),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.qr_code_scanner_rounded, color:AppColors.dashboardSubtitle),
          onPressed: _showScanOptions,
        ),
        Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: const Icon(
                Icons.people_outline,
                color: AppColors.dashboardSubtitle,
              ),
              onPressed: () {
                Navigator.pushNamed(context, '/people_and_roles');
              },
            ),
            Positioned(
              top: 15,
              right: 15,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.dashboardBlue,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "DATA VIEW",
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: AppColors.dashboardHint,
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.chartBackground,
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
        ),
      ],
    );
  }

  Widget _buildTogglePill(String text, int index) {
    bool isSelected = _selectedFilterIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilterIndex = index;
          _recomputeMetrics();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
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
                    ? AppColors.dashboardBlue
                    : AppColors.dashboardSubtitle,
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
                "RM ${_totalFund.toStringAsFixed(0)}",
                "${_filteredDonations.length}",
                "REAL DONATIONS",
                Icons.payments_outlined,
                true,
              ),
              const SizedBox(height: 16),
              _buildStatCard(
                "PENDING DONATIONS",
                "$_pendingCount",
                "LIVE",
                "NEEDS ACTION",
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
                "TOTAL USERS",
                "$_totalUsers",
                "ACTIVE",
                "REGISTERED USERS",
                Icons.pets,
                true,
              ),
              const SizedBox(height: 16),
              _buildStatCard(
                "TOTAL RECORDS",
                "${_filteredDonations.length}",
                "THIS VIEW",
                "FILTERED DONATIONS",
                Icons.calendar_today_outlined,
                true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _monthLabel(int month) {
    const labels = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];
    return labels[(month - 1).clamp(0, 11)];
  }

  DateTime? _parseDonationDate(dynamic row) {
    final createdAt = row is Map ? row['created_at'] : null;
    return DateTime.tryParse((createdAt ?? '').toString())?.toLocal();
  }

  double _parseDonationAmount(dynamic row) {
    final amount = row is Map ? row['amount'] : null;
    if (amount is num) return amount.toDouble();
    return double.tryParse((amount ?? '0').toString()) ?? 0;
  }

  String _parseDonationStatus(dynamic row) {
    if (row is! Map) return 'pending';
    final raw = row['status'] ?? row['donation_status'];
    final normalized = (raw ?? '').toString().trim().toLowerCase();
    return normalized.isEmpty ? 'pending' : normalized;
  }

  String _parseDonorName(dynamic row) {
    if (row is! Map) return 'Anonymous';

    final user = row['User'];
    if (user is Map && (user['name'] ?? '').toString().trim().isNotEmpty) {
      return user['name'].toString();
    }

    final fallbackName = row['name'];
    if ((fallbackName ?? '').toString().trim().isNotEmpty) {
      return fallbackName.toString();
    }

    return 'Anonymous';
  }

  String? _parseDonorAvatar(dynamic row) {
    if (row is! Map) return null;

    final user = row['User'];
    if (user is Map && (user['avatar_url'] ?? '').toString().trim().isNotEmpty) {
      return user['avatar_url'].toString();
    }

    final avatar = row['avatar_url'];
    if ((avatar ?? '').toString().trim().isNotEmpty) {
      return avatar.toString();
    }

    return null;
  }

  List<_DonationChartBucket> _buildChartBuckets() {
    final source = _filteredDonations;

    if (_selectedFilterIndex == 0) {
      const labels = ['00-03', '04-07', '08-11', '12-15', '16-19', '20-23'];
      final totals = List<double>.filled(labels.length, 0);

      for (final row in source) {
        if (_parseDonationStatus(row) != 'successful') continue;
        final createdAt = _parseDonationDate(row);
        if (createdAt == null) continue;

        final bucketIndex = (createdAt.hour / 4).floor().clamp(0, labels.length - 1);
        totals[bucketIndex] += _parseDonationAmount(row);
      }

      return List.generate(
        labels.length,
        (index) => _DonationChartBucket(labels[index], totals[index]),
      );
    }

    if (_selectedFilterIndex == 1) {
      const labels = ['01-05', '06-10', '11-15', '16-20', '21-25', '26-31'];
      final totals = List<double>.filled(labels.length, 0);
      final now = DateTime.now();

      for (final row in source) {
        if (_parseDonationStatus(row) != 'successful') continue;
        final createdAt = _parseDonationDate(row);
        if (createdAt == null || createdAt.year != now.year || createdAt.month != now.month) continue;

        final day = createdAt.day;
        final bucketIndex = day <= 5
            ? 0
            : day <= 10
                ? 1
                : day <= 15
                    ? 2
                    : day <= 20
                        ? 3
                        : day <= 25
                            ? 4
                            : 5;
        totals[bucketIndex] += _parseDonationAmount(row);
      }

      return List.generate(
        labels.length,
        (index) => _DonationChartBucket(labels[index], totals[index]),
      );
    }

    final now = DateTime.now();
    final labels = <String>[];
    final monthDates = <DateTime>[];
    final totals = <double>[];

    for (int offset = 5; offset >= 0; offset--) {
      final monthDate = DateTime(now.year, now.month - offset, 1);
      monthDates.add(monthDate);
      labels.add(_monthLabel(monthDate.month));
      totals.add(0);
    }

    for (final row in source) {
      if (_parseDonationStatus(row) != 'successful') continue;
      final createdAt = _parseDonationDate(row);
      if (createdAt == null) continue;

      final index = monthDates.indexWhere(
        (monthDate) => monthDate.year == createdAt.year && monthDate.month == createdAt.month,
      );

      if (index == -1) continue;

      totals[index] += _parseDonationAmount(row);
    }

    return List.generate(
      labels.length,
      (index) => _DonationChartBucket(labels[index], totals[index]),
    );
  }

  Widget _buildChartBars(List<_DonationChartBucket> buckets) {
    final maxValue = buckets.fold<double>(0, (max, bucket) => bucket.value > max ? bucket.value : max);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: buckets
            .map((bucket) {
              final percentage = maxValue <= 0 ? 0.0 : (bucket.value / maxValue).toDouble();
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _buildBar(percentage, bucket.label, bucket.value),
              );
            })
            .toList(),
      ),
    );
  }

  Widget _buildTrendLabels(List<_DonationChartBucket> buckets) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: buckets
            .map(
              (bucket) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text(
                  bucket.label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.dashboardSubtitle,
                  ),
                ),
              ),
            )
            .toList(),
      ),
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
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.dashboardBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                    color: AppColors.dashboardSubtitle,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(icon, size: 18, color: AppColors.dashboardHint),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.dashboardHeading,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isPositive
                      ? AppColors.successBg
                      : AppColors.errorBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  pct,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isPositive
                        ? AppColors.successText
                        : AppColors.errorText,
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
                    color: AppColors.dashboardHint,
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
    final buckets = _buildChartBuckets();
    final successful = _filteredDonations.where((row) => _parseDonationStatus(row) == 'successful').length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.dashboardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "DONATION BREAKDOWN",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: AppColors.dashboardSubtitle,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.successBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  "LIVE",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.successText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            "RM ${_totalFund.toStringAsFixed(0)}",
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.dashboardHeading,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "$successful successful donations",
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.dashboardSubtitle,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 24),

          // Real data bar chart
          _buildChartBars(buckets),
        ],
      ),
    );
  }

  Widget _buildBar(double percentage, String label, double amount) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Container(
              width: 36,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.chartBackground,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            Container(
              width: 36,
              height: 100 * percentage,
              decoration: BoxDecoration(
                color: AppColors.chartBlue,
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
            color: AppColors.dashboardHint,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          amount <= 0 ? 'RM 0' : 'RM ${amount.toStringAsFixed(0)}',
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppColors.dashboardHint,
          ),
        ),
      ],
    );
  }

  Widget _buildLineChartCard() {
    final buckets = _buildChartBuckets();
    final successful = _filteredDonations.where((row) => _parseDonationStatus(row) == 'successful').length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.dashboardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "DONATION TRENDS",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: AppColors.dashboardSubtitle,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.errorBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  "FILTERED",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.errorText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            "$successful Successful",
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.dashboardHeading,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Based on the selected data view',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.dashboardSubtitle,
              fontWeight: FontWeight.w600,
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
                    child: CustomPaint(
                      painter: _DonationTrendPainter(
                        values: buckets.map((bucket) => bucket.value).toList(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // X-Axis Labels
          _buildTrendLabels(buckets),
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
            style: const TextStyle(fontSize: 10, color: AppColors.dashboardHint),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Container(height: 1, color: AppColors.chartBackground)),
      ],
    );
  }

  Widget _buildDonationCard(
    String amountText,
    String donorName,
    String status,
    String time,
    MaterialColor colorBadge,
    String? avatarUrl,
  ) {
    Color bgBadge = colorBadge.shade50;
    Color textBadge = colorBadge.shade700;
    final imageUrl = avatarUrl?.trim() ?? '';
    final hasAvatar = imageUrl.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.dashboardBorder),
      ),
      child: Row(
        children: [
          // Donor Avatar
          CircleAvatar(
            radius: 25,
            backgroundColor: AppColors.dashboardBorder,
            backgroundImage: hasAvatar ? NetworkImage(imageUrl) : null,
            child: hasAvatar
                ? null
                : const Icon(
                    Icons.person,
                    color: AppColors.white,
                  ),
          ),
          const SizedBox(width: 16),
          // Names
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  amountText,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.dashboardHeading,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  donorName,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.dashboardSubtitle,
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
                  color: AppColors.dashboardHint,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildRecentDonationCards() {
    if (_filteredDonations.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text(
            'No recent donations for this filter yet.',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.dashboardHint,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ];
    }

    return _filteredDonations.take(3).map((row) {
      final amount = _parseDonationAmount(row);
      final donor = _parseDonorName(row);
      final avatarUrl = _parseDonorAvatar(row);
      final status = (_parseDonationStatus(row).isEmpty ? 'pending' : _parseDonationStatus(row)).toUpperCase();
      final created = _parseDonationDate(row);
      final time = created == null ? 'Unknown' : _timeAgo(created);

      final MaterialColor badgeColor;
      if (status == 'SUCCESSFUL') {
        badgeColor = Colors.green;
      } else if (status == 'FAILED') {
        badgeColor = Colors.red;
      } else {
        badgeColor = Colors.orange;
      }

      return _buildDonationCard(
        'RM ${amount.toStringAsFixed(2)}',
        'By $donor',
        status,
        time,
        badgeColor,
        avatarUrl,
      );
    }).toList();
  }

  String _timeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes} min ago';
    if (diff.inDays < 1) return '${diff.inHours} hr ago';
    return '${diff.inDays} day ago';
  }
}

class _DonationChartBucket {
  final String label;
  final double value;

  const _DonationChartBucket(this.label, this.value);
}

// --- CUSTOM PAINTER FOR THE SMOOTH LINE CHART ---
class _DonationTrendPainter extends CustomPainter {
  final List<double> values;

  _DonationTrendPainter({required this.values});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final maxValue = values.fold<double>(0, (max, value) => value > max ? value : max);
    final normalized = values.map((value) {
      if (maxValue <= 0) return 0.0;
      return value / maxValue;
    }).toList();

    final paint = Paint()
      ..color = AppColors.dashboardBlue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final stepX = values.length == 1 ? 0 : size.width / (values.length - 1);

    for (int i = 0; i < normalized.length; i++) {
      final x = stepX * i.toDouble();
      final y = size.height - (normalized[i].toDouble() * size.height * 0.9) - (size.height * 0.05);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        final previousX = stepX * (i - 1).toDouble();
        final previousY = size.height - (normalized[i - 1].toDouble() * size.height * 0.9) - (size.height * 0.05);
        final controlX = (previousX + x) / 2;
        path.quadraticBezierTo(controlX, previousY, x, y);
      }
    }

    canvas.drawPath(path, paint);

    // Draw the dots on the nodes
    final dotPaintWhite = Paint()
      ..color = AppColors.white
      ..style = PaintingStyle.fill;
    final dotPaintBlue = Paint()
      ..color = AppColors.dashboardBlue
      ..style = PaintingStyle.fill;

    void drawDot(Offset offset) {
      canvas.drawCircle(offset, 6, dotPaintWhite); // White border
      canvas.drawCircle(offset, 4, dotPaintBlue); // Blue core
    }

    for (int i = 0; i < normalized.length; i++) {
      final x = stepX * i.toDouble();
      final y = size.height - (normalized[i].toDouble() * size.height * 0.9) - (size.height * 0.05);
      drawDot(Offset(x, y));
    }
  }

  @override
  bool shouldRepaint(covariant _DonationTrendPainter oldDelegate) {
    if (oldDelegate.values.length != values.length) return true;
    for (int i = 0; i < values.length; i++) {
      if (oldDelegate.values[i] != values[i]) return true;
    }
    return false;
  }
}

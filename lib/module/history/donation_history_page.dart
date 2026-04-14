import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/colors.dart';
import '../../../core/utils/current_user_store.dart';

class DonationHistoryPage extends StatefulWidget {
  const DonationHistoryPage({super.key});

  @override
  State<DonationHistoryPage> createState() => _DonationHistoryPageState();
}

class _DonationHistoryPageState extends State<DonationHistoryPage> {
  final _supabase = Supabase.instance.client;

  bool _isLoading = true;
  List<Map<String, dynamic>> _donations = [];
  String _currentUserId = '';
  double _totalDonated = 0.0;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    final currentUser = await CurrentUserStore.read();

    if (currentUser != null) {
      _currentUserId = currentUser.id;
      await _loadDonations();
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadDonations() async {
    setState(() => _isLoading = true);
    try {
      final response = await _supabase
          .from('Donation')
          .select('*')
          .eq('user_id', _currentUserId)
          .order('created_at', ascending: false);

      final List<dynamic> data = response as List;

      double total = 0;
      for (var item in data) {
        total += (item['amount'] ?? 0).toDouble();
      }

      if (mounted) {
        setState(() {
          _donations = List<Map<String, dynamic>>.from(data);
          _totalDonated = total;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Fetch Donations Error: $e");
    }
  }

  String _formatDate(String isoString) {
    try {
      DateTime date = DateTime.parse(isoString).toLocal();
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return "${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}, ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
    } catch (e) {
      return "Unknown Date";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.textDark,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Donation History",
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: AppColors.textDark,
            fontSize: 20,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _loadDonations,
              child: Column(
                children: [
                  if (_donations.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary,
                            AppColors.primary.withValues(alpha:0.8),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha:0.3),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.white.withValues(alpha:.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.volunteer_activism_rounded,
                              color: AppColors.white,
                              size: 32,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Total Impact",
                                style: TextStyle(
                                  color: AppColors.white.withValues(alpha:0.9),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "RM ${_totalDonated.toStringAsFixed(2)}",
                                style: const TextStyle(
                                  color: AppColors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                  Expanded(
                    child: _donations.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(
                                height:
                                    MediaQuery.of(context).size.height * 0.2,
                              ),
                              const Icon(
                                Icons.receipt_long_rounded,
                                size: 80,
                                color: AppColors.border,
                              ),
                              const SizedBox(height: 16),
                              const Center(
                                child: Text(
                                  "No donations yet",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Center(
                                child: Text(
                                  "Your support can change a pet's life.",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: _donations.length,
                            itemBuilder: (context, index) {
                              final donation = _donations[index];
                              final double amount = (donation['amount'] ?? 0)
                                  .toDouble();

                              final String method =
                                  donation['donation_method'] ??
                                  "Online Payment";
                              final String projectName = "$method Transfer";

                              final String date = _formatDate(
                                donation['created_at'] ?? "",
                              );
                              final String status =
                                  donation['status'] ?? "Completed";

                              final bool isSuccess =
                                  status.toLowerCase() == 'completed' ||
                                  status.toLowerCase() == 'successful';

                              return Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: AppColors.white,
                                  borderRadius: BorderRadius.circular(24),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha:0.03),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade50,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.favorite_rounded,
                                        color: Colors.redAccent,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 16),

                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            projectName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: AppColors.textPrimary,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 6),

                                          Text(
                                            date,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textLight,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          "RM ${amount.toStringAsFixed(2)}",
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 18,
                                            color: AppColors.textDark,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isSuccess
                                                ? Colors.green.shade50
                                                : Colors.orange.shade50,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Text(
                                            status.toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w900,
                                              color: isSuccess
                                                  ? Colors.green.shade700
                                                  : Colors.orange.shade700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}

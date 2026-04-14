import 'package:flutter/material.dart';
import '../../../core/widgets/filterButton.dart';
import '../service/donation_service.dart';

class AdminDonationPage extends StatefulWidget {
  const AdminDonationPage({super.key});

  @override
  State<AdminDonationPage> createState() => _AdminDonationPageState();
}

class _AdminDonationPageState extends State<AdminDonationPage> {
  final DonationService _donationService = DonationService();

  List<dynamic> _allDonations = [];
  List<dynamic> _filteredDonations = [];
  bool _isLoading = true;
  double _totalAmount = 0.0;
  int _totalDonors = 0;

  bool _isSearching = false;
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  // Time filter
  String _timeFilter = "All Time";
  final List<String> _timeOptions = ["All Time", "Today", "Weekly", "Monthly", "Yearly"];

  // Payment method filter
  String _selectedMethod = "ALL METHODS";

  @override
  void initState() {
    super.initState();
    _fetchDonationData();
  }

  Future<void> _fetchDonationData() async {
    setState(() => _isLoading = true);
    try {
      final data = await _donationService.fetchAllDonations();
      if (mounted) {
        setState(() {
          _allDonations = data;
          _isLoading = false;
        });
        _applyFilters();
      }
    } catch (e) {
      debugPrint("Admin Donation Fetch Error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Extract all available donation methods to generate dropdown options
  List<String> get _dynamicMethodOptions {
    final methods = _allDonations
        .map((tx) => (tx['donation_method'] ?? 'Unknown').toString().toUpperCase())
        .toSet()
        .toList();
    methods.sort();
    return ["ALL METHODS", ...methods];
  }

  // Filters data based on Search Query + Time + Payment Method
  void _applyFilters() {
    final now = DateTime.now();
    double tempSum = 0.0;
    Set<String> tempUniqueDonors = {};
    List<dynamic> tempList = [];

    for (var tx in _allDonations) {
      // --- Filter by Time ---
      DateTime txDate = tx['created_at'] != null
          ? DateTime.parse(tx['created_at'].toString())
          : DateTime.now();

      bool passTime = false;
      if (_timeFilter == "All Time") {
        passTime = true;
      } else if (_timeFilter == "Today") {
        passTime = txDate.year == now.year && txDate.month == now.month && txDate.day == now.day;
      } else if (_timeFilter == "Weekly") {
        passTime = now.difference(txDate).inDays <= 7;
      } else if (_timeFilter == "Monthly") {
        passTime = txDate.year == now.year && txDate.month == now.month;
      } else if (_timeFilter == "Yearly") {
        passTime = txDate.year == now.year;
      }
      if (!passTime) continue;

      // --- Filter by Search Query ---
      final query = _searchQuery.toLowerCase().trim();
      final name = (tx['User']?['name'] ?? "Anonymous").toString().toLowerCase();
      final amountStr = (tx['amount'] ?? 0).toStringAsFixed(2);
      bool passSearch = query.isEmpty || name.contains(query) || amountStr.contains(query);
      if (!passSearch) continue;

      // --- Filter by Payment Method ---
      final txMethod = (tx['donation_method'] ?? "Unknown").toString().toUpperCase();
      if (_selectedMethod != "ALL METHODS" && txMethod != _selectedMethod) {
        continue;
      }

      // Accumulate total amount
      tempList.add(tx);
      tempSum += (tx['amount'] ?? 0).toDouble();
      if (tx['user_id'] != null) {
        tempUniqueDonors.add(tx['user_id'].toString());
      }
    }

    setState(() {
      _filteredDonations = tempList;
      _totalAmount = tempSum;
      _totalDonors = tempUniqueDonors.length;
    });
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return "Unknown";
    DateTime time = timestamp is DateTime ? timestamp : DateTime.parse(timestamp.toString());
    return "${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";
  }

  IconData _getPaymentIcon(String method) {
    method = method.toLowerCase();
    if (method.contains('card') || method.contains('visa') || method.contains('master') || method.contains('debit')) {
      return Icons.credit_card_rounded;
    } else if (method.contains('tng') || method.contains('touch')) {
      return Icons.account_balance_wallet_rounded;
    } else if (method.contains('bank') || method.contains('fpx')) {
      return Icons.account_balance_rounded;
    } else if (method.contains('paypal')) {
      return Icons.payment_rounded;
    }
    return Icons.monetization_on_rounded;
  }

  @override
  Widget build(BuildContext context) {
    // Prevent errors if the selected method is no longer in the dynamic list
    if (!_dynamicMethodOptions.contains(_selectedMethod)) {
      _selectedMethod = "ALL METHODS";
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F9FC),
        elevation: 0,
        centerTitle: true,
        title: _isSearching
            ? TextField(
          controller: _searchController,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Search name or amount...', border: InputBorder.none),
          onChanged: (val) {
            _searchQuery = val;
            _applyFilters();
          },
        )
            : const Text("Donation Records", style: TextStyle(fontWeight: FontWeight.w900, color: Colors.black87)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _isSearching = !_isSearching;
                  if (!_isSearching) {
                    _searchController.clear();
                    _searchQuery = "";
                    _applyFilters();
                  }
                });
              },
              child: CircleAvatar(
                radius: 20,
                backgroundColor: Colors.blue.shade600,
                child: Icon(
                  _isSearching ? Icons.close : Icons.search,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _fetchDonationData,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          children: [

            // --- Time Filter Bar (Horizontal Scroll) ---
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12.0, top: 8.0),
                child: Row(
                  children: _timeOptions.map((option) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 12.0),
                      child: FilterButton(
                        text: option,
                        isSelected: _timeFilter == option,
                        onPressed: () {
                          setState(() {
                            _timeFilter = option;
                          });
                          _applyFilters();
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

            // --- Donation Method Dropdown ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Donation Method", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade700, fontSize: 13)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedMethod,
                      icon: const Icon(Icons.arrow_drop_down, color: Colors.blue),
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 13),
                      items: _dynamicMethodOptions.map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _selectedMethod = newValue;
                          });
                          _applyFilters();
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // --- Summary of the total fund and donors ---
            Row(
              children: [
                Expanded(child: _buildStatCard("TOTAL FUND", "RM ${_totalAmount.toStringAsFixed(2)}", Icons.insights_rounded, Colors.blue)),
                const SizedBox(width: 16),
                Expanded(child: _buildStatCard("DONORS", "$_totalDonors", Icons.groups_rounded, Colors.orange)),
              ],
            ),
            const SizedBox(height: 30),

            // --- Transaction List Header ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Transactions", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                Text("${_filteredDonations.length} items", style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 16),

            // --- Transaction Cards ---
            if (_filteredDonations.isEmpty)
              const Center(child: Padding(padding: EdgeInsets.only(top: 80), child: Text("No records found", style: TextStyle(color: Colors.grey))))
            else
              ..._filteredDonations.map((tx) => _buildDonationItem(tx)).toList(),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:0.04), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha:0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 16),
          Text(title, style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
          const SizedBox(height: 4),
          FittedBox(child: Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.black87))),
        ],
      ),
    );
  }

  Widget _buildDonationItem(dynamic tx) {
    final userData = tx['User'] ?? {};
    final String name = userData['name'] ?? "Anonymous";
    final String? avatar = userData['avatar_url'];
    final double amount = (tx['amount'] ?? 0).toDouble();
    final String method = (tx['donation_method'] ?? "Unknown");

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: Colors.grey.shade100,
            backgroundImage: (avatar != null && avatar.startsWith('http')) ? NetworkImage(avatar) : null,
            child: avatar == null ? const Icon(Icons.person, color: Colors.grey) : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(_formatDate(tx['created_at']), style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_getPaymentIcon(method), size: 10, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              method.toUpperCase(),
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(14)),
            child: Text(
              "+ RM ${amount.toStringAsFixed(2)}",
              style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.w900, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
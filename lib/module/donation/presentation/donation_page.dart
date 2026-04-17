import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pawhub/core/constants/colors.dart';
import '../model/donation_model.dart';
import '../service/donation_service.dart';
import 'payment_process_page.dart';

class DonationPage extends StatefulWidget {
  const DonationPage({super.key});

  @override
  State<DonationPage> createState() => _DonationPageState();
}

class _DonationPageState extends State<DonationPage> {
  final DonationService _donationService = DonationService();
  bool _isProcessing = false;
  final TextEditingController _customAmountController = TextEditingController(
    text: "1",
  );

  String _selectedAmount = "RM10";
  String _selectedPayment = "Card";

  static const double _spacing = 12.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: AppColors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            const Center(
              child: CircleAvatar(
                radius: 50,
                backgroundColor: Color(0xFFE3F2FD),
                child: Icon(Icons.favorite, color: Colors.red, size: 50),
              ),
            ),
            const SizedBox(height: 24),
            const Center(
              child: Text(
                "Support Our Shelter",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 40),

            // Select amount donation
            const Text(
              "SELECT AMOUNT",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: ["RM10", "RM25", "RM50", "RM100"].map((amount) {
                bool isSel = _selectedAmount == amount;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedAmount = amount),
                    child: Container(
                      margin: EdgeInsets.only(
                        right: amount == "RM100" ? 0 : _spacing,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: isSel
                            ? const Color(0xFFE3F2FD)
                            : AppColors.white,
                        border: Border.all(
                          color: isSel
                              ? AppColors.primary
                              : AppColors.borderGray,
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          amount,
                          style: TextStyle(
                            color: isSel ? AppColors.primary : Colors.black87,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: _spacing),

            Row(
              children: [
                GestureDetector(
                  onTap: () => setState(() => _selectedAmount = "Custom"),
                  child: Container(
                    width: 100,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: _selectedAmount == "Custom"
                          ? const Color(0xFFE3F2FD)
                          : AppColors.white,
                      border: Border.all(
                        color: _selectedAmount == "Custom"
                            ? AppColors.primary
                            : AppColors.borderGray,
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Text(
                        "Custom",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: _spacing),
                Expanded(
                  child: TextField(
                    controller: _customAmountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    enabled: _selectedAmount == "Custom",
                    textAlign: TextAlign.center,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                    ],
                    decoration: InputDecoration(
                      prefix: const Padding(
                        padding: EdgeInsets.only(left: 20),
                        child: Text(
                          "RM ",
                          style: TextStyle(color: Colors.black87),
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),
            // Select Payment Method ("TNG"/ "Credit/Debit")
            const Text(
              "PAYMENT METHOD",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 16),
            _buildPaymentTile("Card", "Credit/Debit Card", Icons.credit_card),
            const SizedBox(height: 12),
            _buildPaymentTile(
              "TNG",
              "TNG E-Wallet",
              Icons.account_balance_wallet,
            ),

            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : () async {
                  double amt = _selectedAmount == "Custom"
                      ? (double.tryParse(_customAmountController.text) ?? 0)
                      : double.parse(_selectedAmount.replaceAll("RM", ""));
                  amt = double.parse(amt.toStringAsFixed(2));
                  if (amt <= 0) return;
                  String method = _selectedPayment == "Card" ? "Credit/Debit" : "TNG";

                  setState(() => _isProcessing = true);

                  String currentUserId = await _donationService.getCurrentUserId();

                  DonationModel newDonation = DonationModel(
                    donationId: "",
                    userId: currentUserId,
                    amount: amt,
                    status: "pending",
                    createdAt: DateTime.now(),
                    userName: "User",
                    donationMethod: method,
                  );

                  String? newDonationId = await _donationService.createPendingDonation(newDonation);

                  if (mounted) setState(() => _isProcessing = false);

                  if (newDonationId != null && mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PaymentProcessPage(
                          amount: amt,
                          method: method,
                          donationId: newDonationId,
                        ),
                      ),
                    );
                  } else if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Failed to initiate payment.", style: TextStyle(color: Colors.white)), backgroundColor: Colors.red),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isProcessing
                    ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : const Text(
                  "Continue to Payment",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentTile(String value, String title, IconData icon) {
    bool isSelected = _selectedPayment == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedPayment = value),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.borderGray,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? AppColors.primary : Colors.grey,
            ),
            const SizedBox(width: 16),
            Icon(icon, color: AppColors.primary),
            const SizedBox(width: 12),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
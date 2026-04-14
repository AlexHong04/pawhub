import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:http/http.dart' as http;
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:pawhub/core/constants/colors.dart';
import '../../../core/widgets/appDecorations.dart';
import '../model/donation_model.dart';
import '../service/donation_service.dart';

class PaymentProcessPage extends StatefulWidget {
  final double amount;
  final String method;

  const PaymentProcessPage({
    super.key,
    required this.amount,
    required this.method,
  });

  @override
  State<PaymentProcessPage> createState() => _PaymentProcessPageState();
}

class _PaymentProcessPageState extends State<PaymentProcessPage>
    with SingleTickerProviderStateMixin {
  final DonationService _donationService = DonationService();
  bool _isProcessing = false;
  bool _hasPinError = false;
  final _formKey = GlobalKey<FormState>();
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;

  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();

  late TabController _tabController;

  // Error message color
  final Color _perfectRed = Colors.red.shade700;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _formKey.currentState?.reset();
          _autovalidateMode = AutovalidateMode.disabled;
          _hasPinError = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _phoneController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _startStripePayment() async {
    setState(() => _isProcessing = true);

    try {
      final url = Uri.parse(
        //Computer IP address , if emulator --> localhost
        'http://192.168.100.169:3000/create-payment-intent',
      );

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'amount': (widget.amount * 100).toInt(),
          'currency': 'myr',
        }),
      );

      final jsonResponse = jsonDecode(response.body);

      if (response.statusCode != 200) {
        throw Exception(
          jsonResponse['error'] ?? "Failed to create PaymentIntent",
        );
      }

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: jsonResponse['clientSecret'],
          merchantDisplayName: 'PawHub Adoption',
          style: ThemeMode.light,
        ),
      );

      await Stripe.instance.presentPaymentSheet();
      await _handleDonationSuccess("Credit/Debit (Stripe)");
    } catch (e) {
      debugPrint("Stripe Failed!: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is StripeException
                  ? e.error.localizedMessage!
                  : "Server Connection Error",
            ),
            backgroundColor: _perfectRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleDonationSuccess(String finalMethod) async {
    final myId = await _donationService.getCurrentUserId();

    //Get user email
    final String? userEmail = await _donationService.getUserEmail();

    // Retrieve donation data from model
    final donation = DonationModel(
      donationId: "",
      userId: myId,
      amount: widget.amount,
      status: "successful",
      createdAt: DateTime.now(),
      userName: "Me",
      donationMethod: finalMethod,
    );

    // update to db
    final success = await _donationService.recordDonation(donation);

    if (success && mounted) {
      //send email
      if (userEmail != null) {
        _triggerEmailAsync(userEmail);
      } else {
        debugPrint("Unable to obtain user's email, skipping the email sending step.");
      }

      _showSuccessDialog();
    }
  }

  void _triggerEmailAsync(String targetEmail) {
    final now = DateTime.now();
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final String formattedDate = "${now.day} ${months[now.month - 1]} ${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
    final String emailHtml = '''
      <div style="background-color: #f9f9f9; padding: 20px; font-family: 'Helvetica Neue', Helvetica, Arial, sans-serif;">
        <div style="max-width: 600px; margin: 0 auto; background-color: #ffffff; border-radius: 16px; overflow: hidden; box-shadow: 0 4px 12px rgba(0,0,0,0.05);">
          
          <div style="background-color: #2196F3; padding: 30px; text-align: center;">
            <h1 style="color: #ffffff; margin: 0; font-size: 24px; letter-spacing: 1px;">PawHub</h1>
            <p style="color: rgba(255,255,255,0.8); margin: 5px 0 0 0; font-size: 14px;">Kindness makes a difference</p>
          </div>

          <div style="padding: 40px 30px;">
            <div style="text-align: center; margin-bottom: 30px;">
              <div style="font-size: 50px; margin-bottom: 10px;">🐾</div>
              <h2 style="color: #333; margin: 0; font-size: 22px;">Thank You for Your Support!</h2>
            </div>

            <p style="color: #555; line-height: 1.6; font-size: 16px;">
              Hi there, we’ve received your kind donation. Your generosity provides food, medical care, and shelter for pets in need.
            </p>

            <div style="background-color: #f8fbfd; border: 1px solid #e1eef9; border-radius: 12px; padding: 25px; margin: 30px 0;">
              <table style="width: 100%; border-collapse: collapse;">
                <tr>
                  <td style="color: #888; font-size: 14px; padding-bottom: 10px;">Amount Donated</td>
                  <td style="text-align: right; color: #2196F3; font-weight: bold; font-size: 18px; padding-bottom: 10px;">RM ${widget.amount.toStringAsFixed(2)}</td>
                </tr>
                <tr>
                  <td style="color: #888; font-size: 14px; padding-bottom: 10px;">Payment Method</td>
                  <td style="text-align: right; color: #333; font-weight: 600; padding-bottom: 10px;">${widget.method}</td>
                </tr>
                <tr>
                  <td style="color: #888; font-size: 14px;">Date</td>
<td style="text-align: right; color: #333; font-weight: 600;">$formattedDate</td>
                </tr>
              </table>
            </div>

            <p style="color: #555; line-height: 1.6; font-size: 14px; text-align: center; font-style: italic;">
              "The greatness of a nation can be judged by the way its animals are treated."
            </p>
          </div>

          <div style="background-color: #f1f1f1; padding: 20px; text-align: center;">
            <p style="color: #999; font-size: 12px; margin: 0;">
              This is an official receipt from <strong>PawHub Shelter MY</strong>.<br>
              If you have any questions, feel free to reply to this email.
            </p>
          </div>
        </div>
      </div>
    ''';

    http.post(
      Uri.parse('http://192.168.100.169:3000/send-general-email'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': targetEmail,
        'subject': 'Your PawHub Donation Receipt 🐾',
        'htmlContent': emailHtml,
      }),
    ).then((response) {
      if (response.statusCode == 200) {
        debugPrint("Professional Email Sent to $targetEmail");
      } else {
        debugPrint("Email Failed: ${response.body}");
      }
    }).catchError((e) {
      debugPrint("Email Error: $e");
    });
  }


  Future<void> _onCompletePaymentPressed() async {
    if (widget.method == "TNG") {
      if (_tabController.index == 1) {
        bool isValid = _formKey.currentState!.validate();
        setState(() {
          _autovalidateMode = AutovalidateMode.onUserInteraction;
          _hasPinError = _pinController.text.length != 6;
        });
        if (!isValid) return;
      }
      setState(() => _isProcessing = true);
      await _donationService.processPaymentSimulation();
      await _handleDonationSuccess("TNG");
      if (mounted) setState(() => _isProcessing = false);
    } else {
      await _startStripePayment();
    }
  }

  void _showSuccessDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, anim1, anim2) => Container(),
      transitionBuilder: (context, anim1, anim2, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
          child: Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black..withValues(alpha:0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Paw Logo Design
                  Container(
                    height: 80,
                    width: 80,
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.pets,
                        color: Colors.green,
                        size: 45,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Payment Successful!",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Thank you for supporting our furry friends.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 24),

                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xfff8f9fa),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Payment Method",
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                            Text(
                              widget.method,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Divider(height: 1, thickness: 1),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Total Donation",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              "RM ${widget.amount.toStringAsFixed(2)}",
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Back button
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () {
                        Navigator.of(
                          context,
                        ).popUntil((route) => route.isFirst);
                      },
                      child: const Text(
                        "Back to Home",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final String tempRef =
        "DON-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}";

    return Scaffold(
      backgroundColor: const Color(0xfff8f9fa),
      appBar: AppBar(
        title: Text(
          widget.method == "TNG" ? "Touch 'n Go eWallet" : "Secure Payment",
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        elevation: 0.5,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: AppColors.textPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Text(
                    "RM ${widget.amount.toStringAsFixed(2)}",
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Form(
              key: _formKey,
              autovalidateMode: _autovalidateMode,
              child: Column(
                children: [
                  if (widget.method == "TNG")
                    _buildTNGPayCard()
                  else
                    _buildStripeInfoCard(),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isProcessing
                            ? null
                            : _onCompletePaymentPressed,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: _isProcessing
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Text(
                                "Complete Payment",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildStripeInfoCard() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          const Icon(Icons.lock_outline, color: Colors.green, size: 50),
          const SizedBox(height: 15),
          const Text(
            "Stripe Secure Payment",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 10),
          const Text(
            "We use Stripe to ensure your transaction is safe. A secure payment sheet will open to collect your card details.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildTNGPayCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black..withValues(alpha:0.03),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          TabBar(
            controller: _tabController,
            indicatorColor: Colors.blue,
            indicatorWeight: 3,
            labelColor: Colors.blue,
            unselectedLabelColor: Colors.grey,
            tabs: const [
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.qr_code, size: 18),
                    SizedBox(width: 8),
                    Text("QR Code"),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.phone_iphone, size: 18),
                    SizedBox(width: 8),
                    Text("Phone Login"),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(
            height: 380,
            child: TabBarView(
              controller: _tabController,
              children: [_buildTNGQRView(), _buildTNGPhoneView()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTNGQRView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image.network(
          "https://upload.wikimedia.org/wikipedia/commons/thumb/a/aa/Touch_%27n_Go_eWallet.svg/1280px-Touch_%27n_Go_eWallet.svg.png",
          height: 45,
        ),
        const SizedBox(height: 25),
        QrImageView(
          data: "tng-donation:${widget.amount}",
          version: QrVersions.auto,
          size: 180.0,
          eyeStyle: const QrEyeStyle(
            eyeShape: QrEyeShape.square,
            color: Colors.blue,
          ),
        ),
        const SizedBox(height: 15),
        Text(
          "Scan to donate RM ${widget.amount.toStringAsFixed(2)}",
          style: const TextStyle(color: Colors.grey, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildTNGPhoneView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Image.network(
              "https://upload.wikimedia.org/wikipedia/commons/thumb/a/aa/Touch_%27n_Go_eWallet.svg/1280px-Touch_%27n_Go_eWallet.svg.png",
              height: 40,
            ),
          ),
          const SizedBox(height: 25),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 55,
                width: 65,
                decoration: BoxDecoration(
                  color: const Color(0xfff1f3f5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: const Center(
                  child: Text(
                    "+60",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    TextInputFormatter.withFunction((old, n) {
                      int max = n.text.startsWith('11') ? 10 : 9;
                      return n.text.length > max ? old : n;
                    }),
                  ],
                  decoration: InputDecoration(
                    hintText: "Enter phone number",
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 18,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Colors.blue,
                        width: 1.5,
                      ),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: _perfectRed),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: _perfectRed, width: 1.5),
                    ),
                    errorStyle: TextStyle(color: _perfectRed, fontSize: 11),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return "Phone number required";
                    int req = v.startsWith('11') ? 10 : 9;
                    if (v.length != req) return "Must be $req digits";
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            "6-digit PIN",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 12),
          PinCodeTextField(
            appContext: context,
            length: 6,
            controller: _pinController,
            obscureText: true,
            animationType: AnimationType.fade,
            keyboardType: TextInputType.number,
            pinTheme: PinTheme(
              shape: PinCodeFieldShape.box,
              borderRadius: BorderRadius.circular(10),
              fieldHeight: 50,
              fieldWidth: 42,
              activeFillColor: Colors.white,
              inactiveFillColor: Colors.white,
              selectedFillColor: Colors.white,
              activeColor: _hasPinError ? _perfectRed : Colors.blue,
              inactiveColor: _hasPinError ? _perfectRed : Colors.grey.shade300,
              selectedColor: _hasPinError ? _perfectRed : Colors.blue,
              errorBorderColor: _perfectRed,
            ),
            enableActiveFill: true,
            validator: (v) =>
                (v == null || v.length != 6) ? "PIN required" : null,
            onChanged: (v) {
              if (_autovalidateMode == AutovalidateMode.onUserInteraction) {
                setState(() => _hasPinError = v.length != 6);
              }
              if (v.length == 6) _formKey.currentState!.validate();
            },
          ),
        ],
      ),
    );
  }
}

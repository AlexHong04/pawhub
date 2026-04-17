import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pawhub/core/constants/colors.dart';
import 'package:pawhub/core/widgets/appDecorations.dart';
import 'package:flutter/services.dart';

import '../../../core/utils/local_file_service.dart';
import '../../pet/model/pet_model.dart';
import '../../pet/service/pet_service.dart';
import '../service/pet_adoption_service.dart';

class PetAdoptionPage extends StatefulWidget {
  final String petId;
  final String userId;

  const PetAdoptionPage({super.key, required this.petId, required this.userId});

  @override
  State<PetAdoptionPage> createState() => _MyAdoptionPageState();
}

class _MyAdoptionPageState extends State<PetAdoptionPage> {
  final AdoptionService _adoptionService = AdoptionService();
  final PetService _petService = PetService();

  Pet? _pet;
  bool _isLoading = true;
  Map<int, File?> _localImages = {};
  List<String> _imageUrls = [];

  // Controllers
  final _icController = TextEditingController();
  final _emailController = TextEditingController();
  final _contactNoController = TextEditingController();
  final _addressController = TextEditingController();

  final _formKey = GlobalKey<FormState>();

  File? _icImage;

  // Assessment State
  int _hoursAlone = 1;
  final Map<int, bool?> _answers = {
    1: null,
    3: null,
    4: null,
    5: null,
    6: null,
  };

  Future<void> _captureIC() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
    );

    if (pickedFile != null) {
      setState(() {
        _icImage = File(pickedFile.path);
      });

      _processIC(_icImage!);
    }
  }

  Future<void> _processIC(File image) async {
    final inputImage = InputImage.fromFile(image);
    final textRecognizer = TextRecognizer();

    final RecognizedText recognizedText =
    await textRecognizer.processImage(inputImage);

    String fullText = recognizedText.text;
    debugPrint("IC TEXT:\n$fullText");

    _extractICDetails(fullText);

    textRecognizer.close();
  }

  void _extractICDetails(String text) {
    List<String> lines = text.split('\n');

    String? ic;

    // IC pattern
    final icRegex = RegExp(r'\d{6}-\d{2}-\d{4}');

    for (int i = 0; i < lines.length; i++) {
      String line = lines[i].trim();

      // IC number
      if (ic == null && icRegex.hasMatch(line)) {
        ic = icRegex.firstMatch(line)?.group(0);
        continue;
      }

    }

    setState(() {
      if (ic != null) _icController.text = ic.replaceAll('-', '');
    });
  }

  void _showCancelDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Cancel Applying Adoption?"),
          content: Text("Are you confirming to cancel applying pet adoption?"),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                "No, Discard",
                style: TextStyle(color: AppColors.textDark),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text(
                "Yes, Cancel Applying",
                style: TextStyle(color: AppColors.primary),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showApplyDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Submitting Adoption Application?"),
          content: Text("Are you confirming to apply pet adoption?"),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                "No, Discard",
                style: TextStyle(color: AppColors.textDark),
              ),
            ),
            TextButton(
              onPressed: () async {
                try {
                  final success = await _adoptionService.submitApplication(
                    petId: widget.petId,
                    userId: widget.userId,
                    address: _addressController.text,
                  );

                  if (!success) return;

                  final email = _emailController.text.trim();

                  await _sendEmail(email);

                  Navigator.pop(context);

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Adoption application submitted successfully.',
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );

                  Navigator.pop(context);
                } catch (e) {
                  log("Adoption application error: $e");
                }
              },
              child: const Text(
                "Yes, Submit",
                style: TextStyle(color: AppColors.primary),
              ),
            ),
          ],
        );
      },
    );
  }

  // fetch pet details
  Future<void> _fetchPet() async {
    setState(() => _isLoading = true);

    try {
      final pet = await _petService.fetchPetDetails(widget.petId);

      final urls = pet.image
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      Map<int, File?> localMap = {};

      for (int i = 0; i < urls.length; i++) {
        try {
          final file = await LocalFileService.loadSavedImage(
            urls[i].split('/').last,
          );
          localMap[i] = file;
        } catch (_) {
          localMap[i] = null;
        }
      }

      if (!mounted) return;

      setState(() {
        _pet = pet;
        _imageUrls = urls;
        _localImages = localMap;
        _isLoading = false;
      });

    } catch (e) {
      log('Error fetching pets: $e');
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendEmail(String targetEmail) async {
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
            Hi there, we've received your pet adoption application. Please stay updated to wait for the approval.
          </p>

          <p style="color: #555; line-height: 1.6; font-size: 14px; text-align: center; font-style: italic;">
            "The greatness of a nation can be judged by the way its animals are treated."
          </p>
        </div>

        <div style="background-color: #f1f1f1; padding: 20px; text-align: center;">
          <p style="color: #999; font-size: 12px; margin: 0;">
            This is an official confirmation message from <strong>PawHub Shelter MY</strong>.<br>
            If you have any questions, feel free to reply to this email.
          </p>
        </div>
      </div>
    </div>
  ''';

    try {
      debugPrint("📧 Attempting to send email to: $targetEmail");

      final Uri uri = Uri.parse('http://192.168.100.169:3000/send-general-email');
      debugPrint("📧 Sending to URL: $uri");

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': targetEmail,
          'subject': 'Your PawHub Adoption Application 🐾',
          'htmlContent': emailHtml,
        }),
      );

      debugPrint("📧 Response status: ${response.statusCode}");
      debugPrint("📧 Response body: ${response.body}");

      if (response.statusCode == 200) {
        debugPrint("✅ Email sent successfully to $targetEmail");

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Confirmation email sent successfully!"),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        debugPrint("❌ Email Failed with status ${response.statusCode}: ${response.body}");

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Email failed: ${response.statusCode}"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("❌ Email Error: $e");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error sending email: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void initState() {
    _fetchPet();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_pet == null) {
      return const Center(child: Text("Pet not found"));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF9FBFF),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Application",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildPetInfoCard(_pet!),
              const SizedBox(height: 24),
              _buildSectionHeader("Personal Details", Icons.person_outline),
              _buildPersonalForm(),
              const SizedBox(height: 24),
              _buildSectionHeader("Home Assessment", Icons.home_work_outlined),
              _buildAssessmentSection(),
              const SizedBox(height:10),
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPetInfoCard(Pet pet) {
    final firstImageUrl =
    _imageUrls.isNotEmpty ? _imageUrls.first : null;
    final firstLocalFile =
    _localImages.isNotEmpty ? _localImages.values.first : null;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Text(
            "Pet Information",
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: (firstImageUrl != null)
                    ? Image.network(
                  firstImageUrl,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return Container(
                      color: Colors.grey[200],
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    if (firstLocalFile != null &&
                        firstLocalFile.existsSync()) {
                      return Image.file(
                        firstLocalFile,
                        fit: BoxFit.cover,
                      );
                    }

                    return Container(
                      color: Colors.grey[300],
                      child: const Icon(Icons.pets, size: 40),
                    );
                  },
                )
                    : Container(
                  width: 85,
                  height: 85,
                  color: Colors.grey[300],
                  child: const Icon(Icons.pets, size: 40),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pet.name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Table(
                      columnWidths: const {
                        0: IntrinsicColumnWidth(),
                        1: IntrinsicColumnWidth(),
                      },
                      children: [
                        TableRow(
                          children: [
                            _buildPetDetail(
                              Icons.cake,
                              pet.age.toStringAsFixed(2),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(left: 30),
                              child: _buildPetDetail(
                                Icons.transgender_outlined,
                                pet.gender,
                              ),
                            ),
                          ],
                        ),
                        const TableRow(
                          children: [SizedBox(height: 8), SizedBox(height: 8)],
                        ),
                        TableRow(
                          children: [
                            _buildPetDetail(
                              Icons.scale_outlined,
                              pet.weight.toStringAsFixed(2),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(left: 30),
                              child: _buildPetDetail(
                                Icons.palette_outlined,
                                pet.color,
                              ),
                            ),
                          ],
                        ),
                        const TableRow(
                          children: [SizedBox(height: 8), SizedBox(height: 8)],
                        ),
                        TableRow(
                          children: [
                            _buildPetDetail(
                              Icons.add_box_outlined,
                              pet.health,
                              color: Colors.green,
                            ),
                            Padding(
                              padding: const EdgeInsets.only(left: 30),
                              child: _buildPetDetail(
                                Icons.vaccines_outlined,
                                pet.vaccination == true
                                    ? 'Vaccinated'
                                    : 'Not Yet Vaccinated',
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(
              fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildPetDetail(IconData icon,
      String text, {
        Color color = Colors.black,
      }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 13, color: color)),
      ],
    );
  }

  Widget _buildPersonalForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          _buildTextField(
            controller: _icController,
            label: "IC NO.",
            hint: "e.g. 950505105522",
            icon: Icons.badge_outlined,
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value == null || value.isEmpty)
                return 'IC number is required';
              if (value.length != 12)
                return 'IC must be exactly 12 digits';
              if (!RegExp(r'^[0-9]+$').hasMatch(value))
                return 'Enter digits only';
              return null;
            },
            suffixIcon: IconButton(
              icon: const Icon(Icons.camera_alt_outlined),
              color: AppColors.primary,
              onPressed: _captureIC,
              tooltip: "Scan IC",
            ),
          ),
          _buildTextField(
            controller: _emailController,
            label: "EMAIL",
            hint: "abc@gmail.com",
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.isEmpty)
                return 'Email is required';
              final emailRegex = RegExp(
                r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
              );
              if (!emailRegex.hasMatch(value))
                return 'Enter a valid email address';
              return null;
            },
          ),

          _buildTextField(
            controller: _contactNoController,
            label: "CONTACT NUMBER",
            hint: "e.g. 0123456789",
            icon: Icons.phone_android_outlined,
            keyboardType: TextInputType.phone,
            validator: (value) {
              if (value == null || value.isEmpty)
                return 'Phone number is required';
              if (value.length < 10 || value.length > 11)
                return 'Enter a valid phone (10-11 digits)';
              if (!RegExp(r'^[0-9]+$').hasMatch(value))
                return 'Enter digits only';
              return null;
            },
          ),

          _buildTextField(
            controller: _addressController,
            label: "ADDRESS",
            hint: "Enter your full address",
            icon: Icons.home_outlined,
            validator: (value) => (value == null || value.isEmpty)
                ? 'Address is required'
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
    Widget? suffixIcon, // 👈 change to Widget (more flexible)
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        validator: validator,
        keyboardType: keyboardType,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        decoration: AppDecorations.outlineInputDecoration(
          hintText: hint,
          labelText: label,
          prefixIcon: icon,
        ).copyWith(
          suffixIcon: suffixIcon,
        ),
      ),
    );
  }

  Widget _buildAssessmentSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          _buildQuestionRow(1, "1. Is your residence pet-friendly?"),
          const Divider(),
          _buildHoursPicker(),
          const Divider(),
          _buildQuestionRow(3, "3. Have you owned a pet before?"),
          const Divider(),
          _buildQuestionRow(
              4, "4. Are you familiar with basic pet training and care?"),
          const Divider(),
          _buildQuestionRow(5,
              "5. Are all family members in agreement about adopting a pet?"),
          const Divider(),
          _buildQuestionRow(
              6, "6. Are you willing to vaccinate and sterilize the pet?"),
        ],
      ),
    );
  }

  Widget _buildQuestionRow(int id, String question) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(question, style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildChoiceChip(id, true, "Yes"),
              const SizedBox(width: 10),
              _buildChoiceChip(id, false, "No"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChoiceChip(int id, bool value, String label) {
    bool isSelected = _answers[id] == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        HapticFeedback.lightImpact();
        setState(() => _answers[id] = value);
      },
      backgroundColor: Colors.white,
      selectedColor: AppColors.primary.withValues(alpha: 0.2),
      labelStyle: TextStyle(
          color: isSelected ? AppColors.primary : Colors.black,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
    );
  }

  Widget _buildHoursPicker() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Expanded(child: Text(
              "2. How many hours per day will the pet be left alone",
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w500))),
          Row(
            children: [
              _hourBtn(Icons.remove, () =>
                  setState(() => _hoursAlone > 0 ? _hoursAlone-- : null)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text("$_hoursAlone", style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              _hourBtn(Icons.add, () => setState(() => _hoursAlone++)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _hourBtn(IconData icon, VoidCallback tap) {
    return GestureDetector(
      onTap: tap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
            shape: BoxShape.circle, color: AppColors.primary.withValues(alpha: 0.1)),
        child: Icon(icon, size: 20, color: AppColors.primary),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () {
              _showCancelDialog();
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              "Cancel",
              style: TextStyle(color: Colors.black45),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                _showApplyDialog();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text("Apply", style: TextStyle(color: Colors.white)),
          ),
        ),
      ],
    );
  }
}
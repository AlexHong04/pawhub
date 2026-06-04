<div align="center">

# 🐾 PawHub

**A mobile platform connecting citizens with animal welfare authorities**

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.10+-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Supabase](https://img.shields.io/badge/Supabase-Backend-3ECF8E?logo=supabase&logoColor=white)](https://supabase.com)
[![Node.js](https://img.shields.io/badge/Node.js-Server-339933?logo=node.js&logoColor=white)](https://nodejs.org)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

*Bridging the gap between communities and animal welfare — one paw at a time.*

</div>

---

## 📖 About PawHub

PawHub is a mobile platform that connects citizens with animal welfare authorities through digital pet adoption, volunteer management, and fundraising. It helps reduce stray animal populations, improve adoption efficiency, and promote responsible pet ownership.

---

## 🚨 The Problem

| # | Problem | Impact |
|---|---------|--------|
| 1 | **Fragmented Information** across different platforms | Citizens struggle to find accurate, up-to-date animal welfare data |
| 2 | **Low Adoption Efficiency** for users | Complex, paper-based processes slow down pet adoptions |
| 3 | **High & Repetitive Workload** for admins | Manual management drains resources that could go toward animal care |

---

## 💡 Our Solution

| Feature | Description |
|---------|-------------|
| 🤝 **Community Engagement** | Connects citizens, volunteers, and authorities on a single platform |
| 🐶 **Digital Pet Adoption** | Streamlined end-to-end digital adoption flow |
| 📅 **Volunteer & Event Management** | Tools to coordinate and schedule volunteer activities |
| ⚡ **Improved Efficiency** | Automates repetitive admin tasks to free up resources |

---

## 🛠️ Tech Stack

### 📱 Frontend (Flutter)
| Package | Version | Purpose |
|---------|---------|---------|
| `supabase_flutter` | ^2.12.0 | Backend-as-a-service (auth, database, storage) |
| `provider` | ^6.1.5 | State management |
| `google_maps_flutter` | ^2.6.0 | Maps & location features |
| `flutter_stripe` | ^12.6.0 | Payment processing |
| `mobile_scanner` | ^5.1.1 | QR code scanning |
| `qr_flutter` | ^4.1.0 | QR code generation |
| `local_auth` | ^2.1.8 | Biometric authentication |
| `pdf` + `printing` | ^3.10.8 / ^5.12.0 | PDF export & printing |
| `google_mlkit_text_recognition` | ^0.11.0 | OCR / text recognition |
| `speech_to_text` | ^7.3.0 | Voice input |
| `image_picker` | ^1.2.1 | Camera & gallery access |
| `hive` + `hive_flutter` | ^2.2.3 | Local offline storage |

### 🖥️ Backend (Node.js)
- **Runtime:** Node.js
- **Entry point:** `server.js`
- **Location:** `pawhub-backend/`

---

## 📁 Project Structure

```
pawhub/
│
├── lib/                   ← Flutter app source code
├── assets/
│   └── images/            ← App images & icons
├── android/               ← Android platform files
├── ios/                   ← iOS platform files
├── web/                   ← Web platform files
├── linux/                 ← Linux platform files
├── macos/                 ← macOS platform files
├── windows/               ← Windows platform files
├── pawhub-backend/        ← Node.js backend server
├── test/                  ← Unit & widget tests
├── pubspec.yaml           ← Flutter dependencies
└── package.json           ← Node.js dependencies
```

---

## 🚀 Getting Started

### Prerequisites

Ensure the following are installed before you begin:

| Tool | Version | Download |
|------|---------|----------|
| **Flutter SDK** | 3.x+ | [flutter.dev](https://flutter.dev/docs/get-started/install) |
| **Dart SDK** | ^3.10.7 | Bundled with Flutter |
| **Node.js** | 18+ LTS | [nodejs.org](https://nodejs.org) |
| **Android Studio / Xcode** | Latest | For mobile emulators |

---

### 📱 Running the Flutter App

**1. Clone the repository**
```bash
git clone https://github.com/AlexHong04/pawhub.git
cd pawhub
```

**2. Install Flutter dependencies**
```bash
flutter pub get
```

**3. Run the app**
```bash
# Android / iOS emulator or physical device
flutter run

# Specific device
flutter run -d <device-id>

# List available devices
flutter devices
```

---

### 🖥️ Running the Backend Server

**1. Navigate to the backend folder**
```bash
cd pawhub-backend
```

**2. Install dependencies**
```bash
npm install
```

**3. Start the server**
```bash
node server.js
```

> 💡 **Tip:** On Windows, you can also right-click the `pawhub-backend` folder in File Explorer and select **"Open in Terminal"**, then run the commands above.

---

## 🔧 Development Commands

| Command | Description |
|---------|-------------|
| `flutter run` | Run app on connected device/emulator |
| `flutter build apk` | Build Android APK |
| `flutter build ios` | Build iOS app |
| `flutter test` | Run all unit tests |
| `flutter pub get` | Install/update packages |
| `flutter pub upgrade` | Upgrade packages to latest compatible versions |
| `flutter clean` | Clear build cache |
| `node server.js` | Start backend server |
| `npm install` | Install backend dependencies |

---

## 🌐 Platform Support

| Platform | Supported |
|----------|-----------|
| Android | ✅ |
| iOS | ✅ |
| Web | ✅ |
| Windows | ✅ |
| macOS | ✅ |
| Linux | ✅ |

---

## 🤝 Contributing

Contributions are welcome! Please follow these steps:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/your-feature`)
3. Commit your changes (`git commit -m 'Add some feature'`)
4. Push to the branch (`git push origin feature/your-feature`)
5. Open a Pull Request

---

## 📚 Resources

- [Flutter Documentation](https://docs.flutter.dev)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter Cookbook](https://docs.flutter.dev/cookbook)
- [Supabase Flutter Guide](https://supabase.com/docs/guides/getting-started/tutorials/with-flutter)
- [Dart Language Tour](https://dart.dev/guides/language/language-tour)

---

## 📝 Conclusion

PawHub provides a comprehensive digital solution to modern urban animal welfare challenges. By integrating adoption management, volunteer coordination, fundraising transparency, and community engagement into a single mobile platform, the system improves operational efficiency for authorities while empowering citizens to contribute actively to animal welfare in their communities.

---

<div align="center">

Made with ❤️ for animals everywhere &nbsp;|&nbsp; Built with Flutter & Dart

</div>

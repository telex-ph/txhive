# TeamsClone — Teams-style Messaging App

Cross-platform messaging app na parang Microsoft Teams. Built with Flutter (mobile + desktop + web), Node.js/Express backend, MongoDB, and Socket.IO for real-time messaging.

## 📁 Structure

```
teamsclone/
├── backend/          # Node.js + Express + Socket.IO + MongoDB
└── flutter_app/      # Flutter (Android, iOS, Windows, macOS, Linux, Web)
```

## ✨ Features (built-in)

- ✅ User auth (register, login, JWT)
- ✅ Workspaces with invite codes
- ✅ Channels (public/private)
- ✅ Direct Messages (1-on-1 + group)
- ✅ Real-time messaging (Socket.IO)
- ✅ Typing indicators
- ✅ User presence (online/offline)
- ✅ Message edit/delete
- ✅ Emoji reactions (API ready)
- ✅ File/image upload (Cloudinary)
- ✅ Read receipts (socket events)

## 🚀 Quick Start

### 1. Backend Setup

```bash
cd backend
npm install
cp .env.example .env
# Edit .env: MONGO_URI, JWT_SECRET, CLOUDINARY_*
npm run dev
```

Backend runs on `http://localhost:5000`.

**MongoDB Atlas:** Make a free cluster at https://www.mongodb.com/cloud/atlas — get the connection string.

**Cloudinary:** Free account at https://cloudinary.com — get cloud_name, api_key, api_secret.

### 2. Flutter App Setup

```bash
cd flutter_app
flutter pub get

# Enable platforms
flutter config --enable-windows-desktop
flutter config --enable-macos-desktop
flutter config --enable-linux-desktop

# Run on desktop
flutter run -d windows   # or macos / linux
# Run on mobile
flutter run              # connected device or emulator
# Run on web
flutter run -d chrome
```

**⚠ Update `lib/config/constants.dart`** with your backend URL:
- Android emulator: `http://10.0.2.2:5000`
- iOS simulator / desktop: `http://localhost:5000`
- Real device: `http://YOUR_LAN_IP:5000`
- Production: `https://your-app.onrender.com`

## 🌐 Deploy Backend to Render

1. Push `backend/` to a GitHub repo
2. Render dashboard → New + → Web Service → connect repo
3. Settings:
   - Build Command: `npm install`
   - Start Command: `npm start`
4. Environment Variables (kopyahin galing `.env`):
   - `MONGO_URI`
   - `JWT_SECRET`
   - `JWT_EXPIRES_IN` = `30d`
   - `CLOUDINARY_CLOUD_NAME`
   - `CLOUDINARY_API_KEY`
   - `CLOUDINARY_API_SECRET`
   - `CLIENT_URL` = `*` (or restrict later)
5. Deploy. Get your URL → update `flutter_app/lib/config/constants.dart`

## 📱 Build for Mobile Stores

```bash
# Android APK
flutter build apk --release

# Android App Bundle (Play Store)
flutter build appbundle --release

# iOS (kailangan macOS + Xcode)
flutter build ios --release
```

## 🖥 Build for Desktop

```bash
# Windows
flutter build windows --release
# Output: build/windows/runner/Release/

# macOS
flutter build macos --release

# Linux
flutter build linux --release
```

## 🔧 Architecture

```
┌─────────────────────────────────────────┐
│  Flutter App (Mobile + Desktop + Web)  │
│  • Provider state management            │
│  • Socket.IO client (real-time)         │
│  • Secure token storage                 │
└──────────────┬──────────────────────────┘
               │ HTTPS + WSS
               ▼
┌─────────────────────────────────────────┐
│  Node.js Backend (Render)               │
│  • Express REST API                     │
│  • Socket.IO (real-time events)         │
│  • JWT auth                             │
└─────┬───────────────────────┬───────────┘
      ▼                       ▼
┌──────────────┐    ┌────────────────────┐
│ MongoDB      │    │ Cloudinary         │
│ Atlas        │    │ (files/images)     │
└──────────────┘    └────────────────────┘
```

## 🗺 Next Steps / Roadmap

Things you can add next:

1. **Push notifications** — Firebase Cloud Messaging (`firebase_messaging` package)
2. **Voice/Video calls** — Agora SDK, LiveKit, or WebRTC
3. **Screen sharing** — for desktop, via WebRTC
4. **Threads/replies** — backend ready (`replyTo`), need UI
5. **Search** — MongoDB text index on messages
6. **Mentions (@user)** — parse content, notify users
7. **Rich text/markdown** — `flutter_markdown` package
8. **Voice messages** — `record` + `audioplayers` packages
9. **End-to-end encryption** — Signal Protocol / libsignal
10. **Admin panel** — separate web app for moderation

## 💡 Tips

- For local dev, run backend with `npm run dev` (nodemon auto-reloads)
- Test the API first with Postman/curl before connecting Flutter
- Socket.IO connects on app open (via `AuthProvider.tryAutoLogin()`)
- Mobile testing: use your LAN IP, hindi `localhost`, kasi kahit Android emulator may quirk
- Render free tier sleeps after 15 min idle — first request matagal mag-wake

## 📜 License

MIT — gawin mong sayo, brad.

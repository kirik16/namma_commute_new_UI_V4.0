# 🚀 Namma Commute — New UI

Bengaluru's real-time traffic & commute intelligence app.

## 📁 Repo Structure

```
namma_commute_new_UI/
├── namma_commute/          ← Flutter app (upload to GitHub)
│   ├── lib/                ← All Dart source code
│   ├── android/            ← Android config
│   └── pubspec.yaml
├── namma_backend/          ← FastAPI backend
│   ├── main.py             ← All API endpoints
│   ├── requirements.txt
│   ├── Procfile
│   └── railway.json
└── .github/workflows/
    └── build.yml           ← Auto-builds APK on every push
```

## 🛠️ Setup

### Backend (Railway)
1. Connect repo to Railway
2. Set Root Directory: `namma_backend`
3. Deploy → get your URL

### Flutter App
1. Update `namma_commute/lib/services/api_service.dart` line 7 with your Railway URL
2. Push to GitHub → APK builds automatically in Actions tab

## ✨ Features
- 🔴 Live traffic incidents with real-time updates
- 🚇 Namma Metro schedule, stations & fare calculator  
- 📋 Community incident reporting with GPS
- 🆘 SOS emergency with direct phone dialer
- 🌤️ Live weather impact on traffic
- 🚗 Animated vehicles on road & metro train

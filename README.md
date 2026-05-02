# Pulse Internet Speed Test

iOS speed tester backed by a GCP Cloud Run service. Measures download, upload, ping, and jitter using parallel streams.

## Structure

```
speedtest app/
├── ios/          # SwiftUI iOS app (Xcode project)
└── backend/      # Go HTTP server — deploys to GCP Cloud Run
```

## iOS

Open `ios/CapwareSpeedtest.xcodeproj` in Xcode 15+. Requires iOS 17+.

Before building, update `SpeedTestService.backendURL` in `ios/CapwareSpeedtest/Sources/Services/SpeedTestService.swift` with your deployed Cloud Run URL.

## Backend

### Local dev

```bash
cd backend
go run ./cmd/server
# Server on :8080
curl "http://localhost:8080/download?mb=5" | wc -c
```

### Deploy to GCP Cloud Run

```bash
cd backend
export GOOGLE_CLOUD_PROJECT=your-project-id
./deploy.sh
```

Copy the printed service URL into `SpeedTestService.backendURL`.

## How the speed test works

1. **Unloaded ping** — 8 sequential HEAD requests to Cloudflare `1.1.1.1` measure base latency and jitter
2. **Download** — 6 parallel streaming `GET /stream` tasks saturate bandwidth; bytes received drive a 3-second rolling window speed calculation
3. **Upload** — 4 parallel 50 MB POST tasks auto-restart on completion to keep bandwidth saturated
4. **Loaded ping** — concurrent HEAD requests to `/health` during download and upload measure latency under load
5. **ISP detection** — parallel `ipwho.is` lookup resolves the carrier name

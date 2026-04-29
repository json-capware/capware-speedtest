# Capware Speed Test

iOS download-speed tester backed by a GCP Cloud Run service.

## Structure

```
speedtest app/
├── ios/          # SwiftUI iOS app (Xcode project)
└── backend/      # Go HTTP server — deploys to GCP Cloud Run
```

## iOS

Open `ios/CapwareSpeedtest.xcodeproj` in Xcode 15+. Requires iOS 17+.

Before building, update `SpeedTestService.baseURL` with your deployed Cloud Run URL.

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

Copy the printed service URL into `ios/CapwareSpeedtest/Sources/Services/SpeedTestService.swift` → `baseURL`.

## How the speed test works

1. iOS app opens a streaming `URLSessionDataTask` to `GET /download?mb=25`
2. `URLSessionDataDelegate` accumulates bytes received and timestamps
3. Speed (Mbps) = `bytes / elapsed / 125_000` — updated every chunk
4. Final result displayed with a quality label (Slow / Fair / Good / Fast / Blazing)

package main

import (
	"encoding/json"
	"fmt"
	"log/slog"
	"math/rand"
	"net/http"
	"os"
	"strconv"
	"time"
)

const (
	defaultPort = "8080"
	maxMB       = 100
	defaultMB   = 25
)

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = defaultPort
	}

	mux := http.NewServeMux()
	mux.HandleFunc("/download", withCORS(handleDownload))
	mux.HandleFunc("/health", withCORS(handleHealth))

	slog.Info("capware speedtest backend starting", "port", port)
	if err := http.ListenAndServe(":"+port, mux); err != nil {
		slog.Error("server error", "err", err)
		os.Exit(1)
	}
}

// handleDownload streams N MB of random bytes so the iOS client can measure throughput.
func handleDownload(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	mb := defaultMB
	if s := r.URL.Query().Get("mb"); s != "" {
		if v, err := strconv.Atoi(s); err == nil && v > 0 && v <= maxMB {
			mb = v
		}
	}

	total := mb * 1_000_000
	chunk := make([]byte, 32*1024) // 32 KB chunks
	rand.Read(chunk)               // fill once; good enough for throughput tests

	w.Header().Set("Content-Type", "application/octet-stream")
	w.Header().Set("Content-Length", strconv.Itoa(total))
	w.Header().Set("Cache-Control", "no-store")
	w.Header().Set("X-Test-Size-MB", strconv.Itoa(mb))

	written := 0
	for written < total {
		n := min(len(chunk), total-written)
		if _, err := w.Write(chunk[:n]); err != nil {
			return // client disconnected — normal for cancelled tests
		}
		written += n
	}
}

func handleHealth(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]any{
		"status": "ok",
		"time":   time.Now().UTC().Format(time.RFC3339),
	})
}

func withCORS(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type")
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		next(w, r)
	}
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}

// Ensure fmt is used (for potential debug prints during dev).
var _ = fmt.Sprintf

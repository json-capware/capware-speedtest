package main

import (
	"encoding/json"
	"io"
	"log/slog"
	"math/rand"
	"net/http"
	"os"
	"strconv"
	"time"
)

const (
	defaultPort = "8080"
	maxMB       = 250
	defaultMB   = 200
)

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = defaultPort
	}

	mux := http.NewServeMux()
	mux.HandleFunc("/ping", withCORS(handlePing))
	mux.HandleFunc("/download", withCORS(handleDownload))
	mux.HandleFunc("/upload", withCORS(handleUpload))
	mux.HandleFunc("/health", withCORS(handleHealth))

	slog.Info("capware speedtest backend starting", "port", port)
	if err := http.ListenAndServe(":"+port, mux); err != nil {
		slog.Error("server error", "err", err)
		os.Exit(1)
	}
}

// handlePing returns a minimal payload for RTT measurement.
func handlePing(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Cache-Control", "no-store")
	w.Write([]byte(`{"pong":true}`))
}

// handleDownload streams N MB of pseudo-random bytes for download throughput measurement.
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
	chunk := make([]byte, 256*1024) // 256 KB chunks
	rand.Read(chunk)

	// Disable Cloud Run / proxy response buffering so bytes flow immediately.
	w.Header().Set("Content-Type", "application/octet-stream")
	w.Header().Set("Cache-Control", "no-store")
	w.Header().Set("X-Accel-Buffering", "no")
	// Omit Content-Length to force chunked transfer — better for streaming.

	flusher, canFlush := w.(http.Flusher)

	written := 0
	for written < total {
		n := min(len(chunk), total-written)
		if _, err := w.Write(chunk[:n]); err != nil {
			return
		}
		written += n
		if canFlush {
			flusher.Flush()
		}
	}
}

// handleUpload drains the request body and reports upload throughput.
func handleUpload(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	start := time.Now()
	n, err := io.Copy(io.Discard, r.Body)
	if err != nil {
		http.Error(w, "read error", http.StatusInternalServerError)
		return
	}
	elapsed := time.Since(start).Seconds()

	var mbps float64
	if elapsed > 0 {
		mbps = float64(n) / elapsed / 125_000
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]any{
		"bytes":   n,
		"elapsed": elapsed,
		"mbps":    mbps,
	})
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
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Content-Length")
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

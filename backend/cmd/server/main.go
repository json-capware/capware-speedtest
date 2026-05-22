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

const defaultPort = "8080"

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = defaultPort
	}

	mux := http.NewServeMux()
	mux.HandleFunc("/stream", withCORS(handleStream))
	mux.HandleFunc("/upload", withCORS(handleUpload))
	mux.HandleFunc("/health", withCORS(handleHealth))

	slog.Info("capware speedtest backend starting", "port", port)
	if err := http.ListenAndServe(":"+port, mux); err != nil {
		slog.Error("server error", "err", err)
		os.Exit(1)
	}
}

// handleStream sends bytes indefinitely until the client disconnects.
// The iOS client opens several parallel connections and cancels them after a fixed time window.
func handleStream(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	const maxBytes = 500 * 1024 * 1024 // hard cap — GFE can't buffer more than this
	const chunkSize = 256 * 1024

	// New clients send ?bytes=N and restart streams themselves.
	// Old clients send no param and expect to cancel after their time window.
	// Either way we cap at 500 MB and stop immediately on client disconnect.
	bytesParam := r.URL.Query().Get("bytes")
	requested, _ := strconv.ParseInt(bytesParam, 10, 64)
	if requested <= 0 || requested > maxBytes {
		requested = maxBytes
	}

	w.Header().Set("Content-Type", "application/octet-stream")
	if bytesParam != "" {
		// New clients: set Content-Length so URLSession knows when the stream ends
		w.Header().Set("Content-Length", strconv.FormatInt(requested, 10))
	}
	w.Header().Set("Cache-Control", "no-store")
	w.Header().Set("X-Accel-Buffering", "no")

	flusher, canFlush := w.(http.Flusher)
	ctx := r.Context()

	chunk := make([]byte, chunkSize)
	rand.Read(chunk)

	remaining := requested
	for remaining > 0 {
		select {
		case <-ctx.Done():
			return // client disconnected — stop immediately, don't feed GFE buffer
		default:
		}
		n := int64(chunkSize)
		if n > remaining {
			n = remaining
		}
		if _, err := w.Write(chunk[:n]); err != nil {
			return
		}
		if canFlush {
			flusher.Flush()
		}
		remaining -= n
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


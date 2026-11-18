// Command orders is the worked example service of the eBPF series.
// GET /orders/{customer}/summary runs one Postgres query, one HTTPS call
// to the LLM API and appends one line to the audit log.
//
// The LLM client retries like the SDKs of the LLM providers do: an attempt
// that has no answer after 2 s is given up and sent again. The service times
// the whole thing as one call. Article 5 shows the attempts from outside.
package main

import (
	"context"
	"crypto/tls"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

const auditPath = "/var/log/orders/audit.log"

// The 180 ms are staged with pg_sleep so the number is the same on every run.
// Keep the text under 96 bytes: bpftrace 0.20 cannot print a longer stored string.
const ordersQuery = `SELECT count(*), pg_sleep(0.18)::text FROM orders WHERE customer_id = $1`

type server struct {
	db     *pgxpool.Pool
	llm    *http.Client
	llmURL string
}

func main() {
	db, err := pgxpool.New(context.Background(), os.Getenv("DATABASE_URL"))
	if err != nil {
		log.Fatal(err)
	}
	if err := os.MkdirAll(filepath.Dir(auditPath), 0o755); err != nil {
		log.Fatal(err)
	}
	s := &server{
		db: db,
		// The LLM stub uses a self-signed certificate. Lab only.
		llm: &http.Client{Transport: &http.Transport{
			TLSClientConfig: &tls.Config{InsecureSkipVerify: true},
		}},
		llmURL: os.Getenv("LLM_URL"),
	}
	http.HandleFunc("GET /orders/{customer}/summary", s.summary)
	log.Fatal(http.ListenAndServe(":8080", nil))
}

func (s *server) summary(w http.ResponseWriter, r *http.Request) {
	customer, err := strconv.Atoi(r.PathValue("customer"))
	if err != nil {
		http.Error(w, "customer must be a number", http.StatusBadRequest)
		return
	}
	start := time.Now()

	var count int
	var slept string
	if err := s.db.QueryRow(r.Context(), ordersQuery, customer).Scan(&count, &slept); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	dbDone := time.Now()

	prompt := fmt.Sprintf(`{"prompt":"Summarize %d orders for customer %d"}`, count, customer)
	text, err := s.complete(r.Context(), prompt)
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadGateway)
		return
	}
	llmDone := time.Now()

	if err := audit(customer); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	// The timings are the ground truth that the probes are compared against.
	json.NewEncoder(w).Encode(map[string]any{
		"summary":  json.RawMessage(text),
		"db_ms":    dbDone.Sub(start).Milliseconds(),
		"llm_ms":   llmDone.Sub(dbDone).Milliseconds(),
		"total_ms": time.Since(start).Milliseconds(),
	})
}

// complete sends the prompt to the LLM API. Up to three attempts, 2 s each.
// The header with the number of the retry is the one the SDKs send.
func (s *server) complete(ctx context.Context, prompt string) ([]byte, error) {
	var err error
	for retry := range 3 {
		var text []byte
		if text, err = s.attempt(ctx, prompt, retry); err == nil {
			return text, nil
		}
	}
	return nil, err
}

func (s *server) attempt(ctx context.Context, prompt string, retry int) ([]byte, error) {
	ctx, cancel := context.WithTimeout(ctx, 2*time.Second)
	defer cancel()
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, s.llmURL, strings.NewReader(prompt))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("X-Stainless-Retry-Count", strconv.Itoa(retry))
	resp, err := s.llm.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	return io.ReadAll(resp.Body)
}

// audit opens the file on every call so each request produces one openat.
func audit(customer int) error {
	f, err := os.OpenFile(auditPath, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o644)
	if err != nil {
		return err
	}
	if _, err := fmt.Fprintf(f, "%s summary customer=%d\n", time.Now().Format(time.RFC3339), customer); err != nil {
		f.Close()
		return err
	}
	return f.Close()
}

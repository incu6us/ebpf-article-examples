// Command llmstub stands in for the LLM API: HTTPS on :8443, every call takes 1,200 ms.
// One exception for article 5: the first attempt of a prompt about customer 7
// takes 2,500 ms, longer than the client waits. The retry is answered as usual.
package main

import (
	"bytes"
	"io"
	"log"
	"net"
	"net/http"
	"net/http/httptest"
	"time"
)

func main() {
	l, err := net.Listen("tcp", ":8443")
	if err != nil {
		log.Fatal(err)
	}
	// ponytail: httptest brings its own self-signed certificate, enough for a lab stub.
	ts := httptest.NewUnstartedServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		prompt, _ := io.ReadAll(r.Body)
		// Article 6 checks here if a trace context arrived with the call.
		log.Printf("traceparent=%q", r.Header.Get("Traceparent"))
		wait := 1200 * time.Millisecond
		if bytes.Contains(prompt, []byte("customer 7")) && r.Header.Get("X-Stainless-Retry-Count") == "0" {
			wait = 2500 * time.Millisecond
		}
		time.Sleep(wait)
		w.Header().Set("Content-Type", "application/json")
		io.WriteString(w, `{"content":"A short summary of the orders."}`)
	}))
	ts.Listener.Close()
	ts.Listener = l
	ts.StartTLS()
	select {}
}

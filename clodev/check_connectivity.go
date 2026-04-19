package clodev

import (
	"net/http"
	"time"
)

// CheckConnection tests if a domain is reachable via HTTPS
// Returns nil if successful (including redirects), error otherwise
func CheckConnection(domain string) error {
	client := &http.Client{Timeout: 5 * time.Second}
	resp, err := client.Get("https://" + domain)
	if err != nil {
		return err
	}
	resp.Body.Close()
	return nil
}

// CheckAllConnections tests connectivity to multiple domains
func CheckAllConnections(domains []string) map[string]error {
	results := make(map[string]error)
	for _, domain := range domains {
		results[domain] = CheckConnection(domain)
	}
	return results
}
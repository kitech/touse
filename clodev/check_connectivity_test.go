package clodev

import "testing"

func TestCheckConnection(t *testing.T) {
	tests := []struct {
		domain string
	}{
		{"google.com"},
		{"twitter.com"},
	}

	for _, tt := range tests {
		t.Run(tt.domain, func(t *testing.T) {
			err := CheckConnection(tt.domain)
			if err != nil {
				t.Errorf("CheckConnection(%s) failed: %v", tt.domain, err)
			}
		})
	}
}

func TestCheckAllConnections(t *testing.T) {
	domains := []string{"google.com", "twitter.com"}
	results := CheckAllConnections(domains)

	for domain, err := range results {
		if err != nil {
			t.Errorf("CheckAllConnections(%v) failed for %s: %v", domains, domain, err)
		}
	}
}
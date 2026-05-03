package discovery

import (
	"encoding/json"
	"net/http"

	"github.com/kitech/touse/hturnal/storage"
)

// NewHandler returns handler for server discovery
func NewHandler(store storage.Storage) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Method != "GET" {
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
			return
		}

		resp := map[string]interface{}{
			"stun_servers": []map[string]interface{}{
				{
					"type": "http",
					"url":  "http://" + r.Host + "/stun/binding",
					"nat_check_url": "http://" + r.Host + "/stun/nat-check",
				},
			},
			"turn_servers": []map[string]interface{}{
				{
					"type":       "http",
					"allocate_url": "http://" + r.Host + "/turn/allocate",
					"send_url":     "http://" + r.Host + "/turn/send",
					"receive_url":  "http://" + r.Host + "/turn/receive",
				},
			},
			"http_only": true,
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(resp)
	}
}

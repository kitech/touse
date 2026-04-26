package nixpkgut

import (
	"bytes"
	"encoding/base64"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"net/http"
	"os"
	"os/exec"
	"runtime"
	"strings"
	"time"
)

type SearchResult struct {
	AttrName     string   `json:"package_attr_name"`
	Pname       string   `json:"package_pname"`
	Pversion    string   `json:"package_pversion"`
	Description string   `json:"package_description"`
	AttrSet     string   `json:"package_attr_set"`
	Platforms   []string `json:"package_platforms"`
	System     string   `json:"package_system"`
	Homepage   []string `json:"package_homepage"`
	Position   string   `json:"package_position"`
	Programs  []string `json:"package_programs"`
	License   []string `json:"package_license_set"`
	LastUpdated string  `json:"package_last_updated"`
}

type SearchResponse struct {
	Hits struct {
		Total struct {
			Value int `json:"value"`
		} `json:"total"`
		Hits []struct {
			Source SearchResult `json:"_source"`
		} `json:"hits"`
	} `json:"hits"`
}

type HydraResponse struct {
	BuildOutputs struct {
		Out struct {
			Path string `json:"path"`
		} `json:"out"`
	} `json:"buildoutputs"`
	Timestamp int64 `json:"timestamp"`
}

type SearchOptions struct {
	Query    string
	Arch     string
	Num      int
	Page     int
	Channel  string
	Plain    bool
	Details  bool
}

var (
	authUsername = "aWVSALXpZv"
	authPassword = "X8gPHnzL52wFEekuxsfQ9cSh"
	hydraURL   = "https://hydra.nixos.org"
)

var channelMap = map[string]string{
	"unstable":     "unstable",
	"staging":      "staging",
	"staging-next": "staging-next",
	"25.11":        "release-25.11",
	"25.04":        "release-25.04",
}

func getHydraJobset(channel string) string {
	if jobset, ok := channelMap[channel]; ok {
		return jobset
	}
	return "unstable"
}

func getSystemArch() string {
	arch := runtime.GOARCH
	os := runtime.GOOS
	archMap := map[string]string{
		"amd64": "x86_64",
		"arm64": "aarch64",
	}
	if mapped, ok := archMap[arch]; ok {
		arch = mapped
	}
	return arch + "-" + os
}

func makeAuthToken() string {
	credentials := authUsername + ":" + authPassword
	token := base64.StdEncoding.EncodeToString([]byte(credentials))
	return "Basic " + token
}

func searchPackages(opts *SearchOptions) ([]SearchResult, error) {
	channel := opts.Channel
	if channel == "" {
		channel = "unstable"
	}

	authToken := makeAuthToken()
	url := fmt.Sprintf("https://search.nixos.org/backend/latest-45-nixos-%s/_search", channel)

	from := opts.Page * opts.Num

	query := map[string]interface{}{
		"query": map[string]interface{}{
			"multi_match": map[string]interface{}{
				"query":  opts.Query,
				"fields": []string{"package_attr_name^9", "package_pname^6", "package_description"},
				"type":  "cross_fields",
			},
		},
		"size": opts.Num,
		"from": from,
	}

	jsonData, err := json.Marshal(query)
	if err != nil {
		return nil, err
	}

	req, err := http.NewRequest("POST", url, bytes.NewBuffer(jsonData))
	if err != nil {
		return nil, err
	}

	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", authToken)
	req.Header.Set("Accept", "application/json")

	client := &http.Client{Timeout: 30 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}

	var searchResp SearchResponse
	if err := json.Unmarshal(body, &searchResp); err != nil {
		return nil, err
	}

	results := make([]SearchResult, 0, len(searchResp.Hits.Hits))
	for _, hit := range searchResp.Hits.Hits {
		results = append(results, hit.Source)
	}

	return results, nil
}

func GetStorePath(attr string, arch string, jobset string) (string, error) {
	if jobset == "" {
		jobset = "unstable"
	}

	url := fmt.Sprintf("%s/job/nixpkgs/%s/%s.%s/latest-finished", hydraURL, jobset, attr, arch)

	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return "", err
	}

	req.Header.Set("Accept", "application/json")

	client := &http.Client{Timeout: 30 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		return "", nil
	}

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", err
	}

	var hydraResp HydraResponse
	if err := json.Unmarshal(body, &hydraResp); err != nil {
		return "", err
	}

	return hydraResp.BuildOutputs.Out.Path, nil
}

func GetStorePathNix(packageNixPath string) (string, error) {
	if packageNixPath == "" {
		return "", fmt.Errorf("package nix path required")
	}

	cmd := exec.Command("nix", "eval", "--raw", "-f", packageNixPath, "outPath")
	var out bytes.Buffer
	cmd.Stdout = &out
	cmd.Stderr = os.Stderr

	if err := cmd.Run(); err != nil {
		return "", err
	}

	return strings.TrimSpace(out.String()), nil
}

func formatDate(timestamp int64) string {
	if timestamp == 0 {
		return ""
	}
	t := time.Unix(timestamp, 0)
	now := time.Now()
	diff := now.Sub(t)

	if diff.Hours() < 24 {
		return fmt.Sprintf("%.0fh ago", diff.Hours())
	} else if diff.Hours() < 24*30 {
		return fmt.Sprintf("%.0fd ago", diff.Hours()/24)
	} else {
		return t.Format("2006-01-02")
	}
}

func printResults(results []SearchResult, opts *SearchOptions) {
	if len(results) == 0 {
		fmt.Println("No results found.")
		return
	}

	arch := opts.Arch
	if arch == "" {
		arch = getSystemArch()
	}

	for _, r := range results {
		storePath := ""
		if opts.Details {
			jobset := getHydraJobset(opts.Channel)
			sp, err := GetStorePath(r.AttrName, arch, jobset)
			if err == nil {
				storePath = sp
			}
		}

		if opts.Plain {
			fmt.Printf("%s %s\n", r.AttrName, r.Pversion)
			continue
		}

		fmt.Printf("%s %s %s\n", r.AttrName, r.Pversion, r.System)

		if r.Description != "" {
			fmt.Printf("    %s\n", r.Description)
		}

		date := ""
		if r.LastUpdated != "" {
			date = r.LastUpdated
		}
		platforms := strings.Join(r.Platforms, ",")
		fmt.Printf("    %s %s\n", date, platforms)

		if storePath != "" {
			fmt.Printf("    %s\n", storePath)
		}
	}
}

func Run(args []string) error {
	opts := &SearchOptions{}

	fs := flag.NewFlagSet("nixse", flag.ContinueOnError)
	fs.SetOutput(os.Stderr)
	
	fs.StringVar(&opts.Query, "query", "", "Search query")
	fs.StringVar(&opts.Arch, "a", "", "Target architecture")
	fs.IntVar(&opts.Num, "n", 20, "Number of results")
	fs.IntVar(&opts.Page, "p", 0, "Page number")
	fs.StringVar(&opts.Channel, "c", "unstable", "NixOS channel")

	var plain bool
	fs.BoolVar(&plain, "P", false, "Output only package names")
	fs.BoolVar(&plain, "plain", false, "Output only package names (alias for -P)")
	fs.BoolVar(&opts.Details, "d", false, "Show store path")
	fs.BoolVar(&opts.Details, "details", false, "Show store path (alias for -d)")

	fs.Parse(args)
	
	opts.Plain = plain

	parsedArgs := fs.Args()
	if len(parsedArgs) > 0 {
		opts.Query = strings.Join(parsedArgs, " ")
	}

	if opts.Query == "" {
		fmt.Fprintf(os.Stderr, "Usage: nixse [options] <query>\n")
		fmt.Fprintf(os.Stderr, "Options:\n")
		fs.PrintDefaults()
		fmt.Fprintf(os.Stderr, "\nNote: Flags must appear before the query argument.\n")
		fmt.Fprintf(os.Stderr, "Channels: unstable, staging, staging-next, 25.11, 25.04\n")
		return fmt.Errorf("query required")
	}

	if opts.Num > 50 {
		opts.Num = 50
	}

	results, err := searchPackages(opts)
	if err != nil {
		return err
	}

	printResults(results, opts)
	return nil
}
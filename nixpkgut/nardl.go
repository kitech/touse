package nixpkgut

import (
	"flag"
	"fmt"
	"io"
	"net/http"
	"os"
	"strings"
	"time"
)

type DownloadOptions struct {
	StorePath  string
	Output    string
	CacheURL  string
}

var defaultCacheURL = "https://cache.nixos.org"

func init() {
	if url := os.Getenv("NIX_CACHE_URL"); url != "" {
		defaultCacheURL = url
	}
}

func getNarURL(cacheURL, storePath string) (narinfoURL, narURL string, err error) {
	hash := strings.TrimPrefix(storePath, "/nix/store/")
	hash = strings.SplitN(hash, "-", 1)[0]
	hashpart := strings.Split(hash, "-")[0]

	hash = strings.TrimPrefix(storePath, "/nix/store/")
	parts := strings.SplitN(hash, "-", 2)
	if len(parts) < 2 {
		return "", "", fmt.Errorf("invalid store path: %s", storePath)
	}
	hashpart = parts[0]

	narinfoURL = fmt.Sprintf("%s/%s.narinfo", cacheURL, hashpart)
	narURL = fmt.Sprintf("%s/nar/%s.nar.xz", cacheURL, hashpart)

	return narinfoURL, narURL, nil
}

func downloadNar(opts *DownloadOptions) error {
	cacheURL := opts.CacheURL
	if cacheURL == "" {
		cacheURL = defaultCacheURL
	}

	storePath := opts.StorePath
	output := opts.Output

	if storePath == "" {
		flag.Usage()
		os.Exit(1)
	}

	_, narURL, err := getNarURL(cacheURL, storePath)
	if err != nil {
		return err
	}

	req, err := http.NewRequest("GET", narURL, nil)
	if err != nil {
		return err
	}

	client := &http.Client{Timeout: 60 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		return fmt.Errorf("HTTP %d", resp.StatusCode)
	}

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return err
	}

	if output == "" || output == "-" {
		os.Stdout.Write(body)
	} else {
		err = os.WriteFile(output, body, 0644)
		if err != nil {
			return err
		}
		fmt.Printf("Saved to %s\n", output)
	}

	return nil
}

func RunDownload(args []string) error {
	opts := &DownloadOptions{}

	flag.StringVar(&opts.StorePath, "s", "", "Store path (e.g., /nix/store/xxx-hello-2.12.3)")
	flag.StringVar(&opts.Output, "o", "", "Output file (default: stdout)")
	flag.StringVar(&opts.CacheURL, "c", "", "Cache URL (default: https://cache.nixos.org)")

	flag.Parse()

	parsedArgs := flag.Args()
	if len(parsedArgs) > 0 {
		opts.StorePath = parsedArgs[0]
	}

	if opts.StorePath == "" {
		flag.Usage()
		return fmt.Errorf("store path required")
	}

	return downloadNar(opts)
}

func main() {
	if err := Run(os.Args[1:]); err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}
}
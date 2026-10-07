// Package update finds the latest published game version (Google Drive folder or the accounts
// API), downloads it with resume/retry, checks SHA-256 and installs it atomically.
package update

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"regexp"
	"runtime"
	"strconv"
	"strings"
	"sync"

	"perdidos/launcher/internal/drive"
)

// FileInfo describes one platform build inside latest.json.
type FileInfo struct {
	Name   string `json:"name"`
	SHA256 string `json:"sha256"`
	Size   int64  `json:"size,omitempty"`
	// Optional direct URL (for a release served outside Drive).
	URL string `json:"url,omitempty"`
	// Executable inside the zip (default Perdidos.exe / Perdidos.x86_64).
	Exe string `json:"exe,omitempty"`
}

// Manifest is latest.json.
type Manifest struct {
	Version   string              `json:"version"`
	Files     map[string]FileInfo `json:"files"`
	Notes     string              `json:"notes,omitempty"`
	Server    string              `json:"server,omitempty"`
	Published string              `json:"published,omitempty"`
}

// ManifestName is the file the launcher looks for in the Drive folder.
const ManifestName = "latest.json"

// ErrNoRelease: the folder/API has no latest.json yet ("nenhuma versão publicada").
var ErrNoRelease = errors.New("no release published")

var reVersion = regexp.MustCompile(`^\d+(\.\d+){0,3}([-+][0-9A-Za-z.-]+)?$`)
var reSHA = regexp.MustCompile(`^[0-9a-f]{64}$`)

// Platform is the key used in Manifest.Files for this OS.
func Platform() string { return runtime.GOOS }

// DefaultExe is the game executable name produced by `make clients`.
func DefaultExe(platform string) string {
	if platform == "windows" {
		return "Perdidos.exe"
	}
	return "Perdidos.x86_64"
}

// ParseManifest validates latest.json.
func ParseManifest(data []byte) (Manifest, error) {
	var m Manifest
	if err := json.Unmarshal(data, &m); err != nil {
		return m, fmt.Errorf("latest.json inválido: %w", err)
	}
	m.Version = strings.TrimSpace(strings.TrimPrefix(m.Version, "v"))
	if !reVersion.MatchString(m.Version) {
		return m, fmt.Errorf("latest.json: versão inválida %q", m.Version)
	}
	for k, f := range m.Files {
		f.SHA256 = strings.ToLower(strings.TrimSpace(f.SHA256))
		if f.Name == "" || strings.ContainsAny(f.Name, `/\`) || !reSHA.MatchString(f.SHA256) {
			return m, fmt.Errorf("latest.json: arquivo de %s inválido (nome ou sha256)", k)
		}
		if f.Exe == "" {
			f.Exe = DefaultExe(k)
		}
		if strings.Contains(f.Exe, "..") {
			return m, fmt.Errorf("latest.json: exe inválido em %s", k)
		}
		m.Files[k] = f
	}
	return m, nil
}

// For returns the build for platform.
func (m Manifest) For(platform string) (FileInfo, bool) {
	f, ok := m.Files[platform]
	return f, ok
}

// CompareVersions returns -1, 0 or 1 comparing dotted numeric versions ("0.1.10" > "0.1.9").
func CompareVersions(a, b string) int {
	pa := strings.Split(strings.SplitN(strings.TrimPrefix(a, "v"), "-", 2)[0], ".")
	pb := strings.Split(strings.SplitN(strings.TrimPrefix(b, "v"), "-", 2)[0], ".")
	for i := 0; i < len(pa) || i < len(pb); i++ {
		var x, y int
		if i < len(pa) {
			x, _ = strconv.Atoi(pa[i])
		}
		if i < len(pb) {
			y, _ = strconv.Atoi(pb[i])
		}
		if x != y {
			if x < y {
				return -1
			}
			return 1
		}
	}
	return 0
}

// Source finds latest.json and opens the zips. Drive first; the accounts API as fallback.
type Source struct {
	HTTP     *http.Client
	Drive    *drive.Client
	FolderID string // public Drive folder ("" = skip Drive)
	APIBase  string // e.g. https://xyz.ngrok-free.dev ("" = skip API)

	mu       sync.Mutex
	root     drive.Folder
	subCache map[string]drive.Folder
}

// Latest returns the manifest and where it came from ("drive" or "api").
// ErrNoRelease when every source answered but none had a release.
func (s *Source) Latest(ctx context.Context) (Manifest, string, error) {
	var errs []string
	noRelease := 0
	if s.FolderID != "" && s.Drive != nil {
		m, err := s.latestFromDrive(ctx)
		if err == nil {
			return m, "drive", nil
		}
		if errors.Is(err, ErrNoRelease) {
			noRelease++
		} else {
			errs = append(errs, "Drive: "+err.Error())
		}
	}
	if s.APIBase != "" {
		m, err := s.latestFromAPI(ctx)
		if err == nil {
			return m, "api", nil
		}
		if errors.Is(err, ErrNoRelease) {
			noRelease++
		} else {
			errs = append(errs, "API: "+err.Error())
		}
	}
	if len(errs) == 0 && noRelease > 0 {
		return Manifest{}, "", ErrNoRelease
	}
	if len(errs) == 0 {
		return Manifest{}, "", errors.New("nenhuma fonte de atualização configurada")
	}
	if noRelease > 0 {
		// One source answered "nothing published", the other failed: still nothing to install.
		return Manifest{}, "", ErrNoRelease
	}
	return Manifest{}, "", errors.New(strings.Join(errs, "; "))
}

func (s *Source) latestFromDrive(ctx context.Context) (Manifest, error) {
	root, err := s.Drive.List(ctx, s.FolderID)
	if err != nil {
		return Manifest{}, err
	}
	s.mu.Lock()
	s.root = root
	s.subCache = map[string]drive.Folder{}
	s.mu.Unlock()
	e, ok := root.Find(ManifestName, false)
	if !ok {
		return Manifest{}, ErrNoRelease
	}
	resp, err := s.Drive.Open(ctx, e.ID, 0)
	if err != nil {
		return Manifest{}, err
	}
	defer resp.Body.Close()
	data, err := io.ReadAll(io.LimitReader(resp.Body, 1<<20))
	if err != nil {
		return Manifest{}, err
	}
	return ParseManifest(data)
}

func (s *Source) latestFromAPI(ctx context.Context) (Manifest, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, strings.TrimRight(s.APIBase, "/")+"/api/latest", nil)
	if err != nil {
		return Manifest{}, err
	}
	req.Header.Set("ngrok-skip-browser-warning", "1")
	resp, err := s.client().Do(req)
	if err != nil {
		return Manifest{}, err
	}
	defer resp.Body.Close()
	if resp.StatusCode == http.StatusNotFound {
		return Manifest{}, ErrNoRelease
	}
	if resp.StatusCode != http.StatusOK {
		return Manifest{}, fmt.Errorf("HTTP %d", resp.StatusCode)
	}
	data, err := io.ReadAll(io.LimitReader(resp.Body, 1<<20))
	if err != nil {
		return Manifest{}, err
	}
	return ParseManifest(data)
}

func (s *Source) client() *http.Client {
	if s.HTTP != nil {
		return s.HTTP
	}
	return http.DefaultClient
}

// Opener returns a function that opens the build file at a byte offset (for resume).
// Lookup order: direct URL in the manifest; Drive root folder by name; Drive subfolder named
// after the platform ("windows/", "linux/").
func (s *Source) Opener(ctx context.Context, platform string, f FileInfo) (func(offset int64) (*http.Response, error), error) {
	if f.URL != "" {
		return func(offset int64) (*http.Response, error) {
			req, err := http.NewRequestWithContext(ctx, http.MethodGet, f.URL, nil)
			if err != nil {
				return nil, err
			}
			if offset > 0 {
				req.Header.Set("Range", fmt.Sprintf("bytes=%d-", offset))
			}
			req.Header.Set("ngrok-skip-browser-warning", "1")
			resp, err := s.client().Do(req)
			if err == nil && resp.StatusCode >= 400 {
				resp.Body.Close()
				return nil, fmt.Errorf("HTTP %d", resp.StatusCode)
			}
			return resp, err
		}, nil
	}
	if s.Drive == nil || s.FolderID == "" {
		return nil, fmt.Errorf("sem endereço para baixar %s", f.Name)
	}
	id, err := s.findDriveFile(ctx, platform, f.Name)
	if err != nil {
		return nil, err
	}
	return func(offset int64) (*http.Response, error) { return s.Drive.Open(ctx, id, offset) }, nil
}

func (s *Source) findDriveFile(ctx context.Context, platform, name string) (string, error) {
	s.mu.Lock()
	root := s.root
	s.mu.Unlock()
	if len(root.Entries) == 0 {
		var err error
		if root, err = s.Drive.List(ctx, s.FolderID); err != nil {
			return "", err
		}
		s.mu.Lock()
		s.root = root
		s.mu.Unlock()
	}
	if e, ok := root.Find(name, false); ok {
		return e.ID, nil
	}
	if sub, ok := root.Find(platform, true); ok {
		folder, err := s.Drive.List(ctx, sub.ID)
		if err != nil {
			return "", err
		}
		if e, ok := folder.Find(name, false); ok {
			return e.ID, nil
		}
	}
	return "", fmt.Errorf("o arquivo %s não está na pasta do Drive", name)
}

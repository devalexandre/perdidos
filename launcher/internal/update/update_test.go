package update

import (
	"archive/zip"
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"sync/atomic"
	"testing"
	"time"

	"perdidos/launcher/internal/drive"
)

func init() {
	RetryBackoff = []time.Duration{10 * time.Millisecond}
	ReportEvery = time.Millisecond
}

func noReport(Progress) {}

func makeZip(t *testing.T, files map[string]string) []byte {
	t.Helper()
	var buf bytes.Buffer
	zw := zip.NewWriter(&buf)
	for name, body := range files {
		h := &zip.FileHeader{Name: name, Method: zip.Deflate}
		h.SetMode(0o755)
		w, err := zw.CreateHeader(h)
		if err != nil {
			t.Fatal(err)
		}
		io.WriteString(w, body)
	}
	zw.Close()
	return buf.Bytes()
}

func sha(b []byte) string { s := sha256.Sum256(b); return hex.EncodeToString(s[:]) }

func TestCompareVersions(t *testing.T) {
	cases := []struct {
		a, b string
		want int
	}{{"0.1.10", "0.1.9", 1}, {"0.1.3", "0.1.3", 0}, {"v1.0", "1.0.0", 0}, {"0.2", "0.10", -1}, {"1.0.0-beta", "1.0.0", 0}}
	for _, c := range cases {
		if got := CompareVersions(c.a, c.b); got != c.want {
			t.Errorf("%s vs %s: %d", c.a, c.b, got)
		}
	}
}

func TestParseManifest(t *testing.T) {
	good := `{"version":"0.1.3","files":{"windows":{"name":"Perdidos-0.1.3-windows.zip","sha256":"` +
		strings.Repeat("A", 64) + `"},"linux":{"name":"Perdidos-0.1.3-linux.zip","sha256":"` + strings.Repeat("b", 64) + `"}},"notes":"x"}`
	m, err := ParseManifest([]byte(good))
	if err != nil {
		t.Fatal(err)
	}
	if f, _ := m.For("windows"); f.Exe != "Perdidos.exe" || f.SHA256 != strings.Repeat("a", 64) {
		t.Fatalf("windows: %+v", f)
	}
	for _, bad := range []string{`{}`, `{"version":"abc"}`, `{"version":"1.0","files":{"linux":{"name":"../x.zip","sha256":"` + strings.Repeat("a", 64) + `"}}}`,
		`{"version":"1.0","files":{"linux":{"name":"x.zip","sha256":"123"}}}`} {
		if _, err := ParseManifest([]byte(bad)); err == nil {
			t.Errorf("accepted %s", bad)
		}
	}
}

// Server that drops the connection mid-file on the first request, then honours Range.
func flakyServer(t *testing.T, payload []byte, hits *int32, ranges *[]string) *httptest.Server {
	return httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		n := atomic.AddInt32(hits, 1)
		*ranges = append(*ranges, r.Header.Get("Range"))
		start := 0
		if rg := r.Header.Get("Range"); rg != "" {
			start, _ = strconv.Atoi(strings.TrimSuffix(strings.TrimPrefix(rg, "bytes="), "-"))
			w.Header().Set("Content-Range", fmt.Sprintf("bytes %d-%d/%d", start, len(payload)-1, len(payload)))
			w.Header().Set("Content-Length", strconv.Itoa(len(payload)-start))
			w.WriteHeader(http.StatusPartialContent)
		} else {
			w.Header().Set("Content-Length", strconv.Itoa(len(payload)))
		}
		body := payload[start:]
		if n == 1 {
			w.Write(body[:len(body)/3])
			w.(http.Flusher).Flush()
			conn, _, _ := w.(http.Hijacker).Hijack()
			conn.Close() // network drop
			return
		}
		w.Write(body)
	}))
}

func TestDownloadResumesAfterDrop(t *testing.T) {
	payload := bytes.Repeat([]byte("perdidos-"), 50000)
	var hits int32
	var ranges []string
	ts := flakyServer(t, payload, &hits, &ranges)
	defer ts.Close()
	dest := filepath.Join(t.TempDir(), "game.zip")
	open := func(off int64) (*http.Response, error) {
		req, _ := http.NewRequest("GET", ts.URL, nil)
		if off > 0 {
			req.Header.Set("Range", fmt.Sprintf("bytes=%d-", off))
		}
		return http.DefaultClient.Do(req)
	}
	var reports []Progress
	err := Download(context.Background(), open, dest, int64(len(payload)), func(p Progress) { reports = append(reports, p) })
	if err != nil {
		t.Fatal(err)
	}
	got, _ := os.ReadFile(dest)
	if !bytes.Equal(got, payload) {
		t.Fatalf("content differs (%d vs %d bytes)", len(got), len(payload))
	}
	if hits != 2 || ranges[0] != "" || !strings.HasPrefix(ranges[1], "bytes=") || ranges[1] == "bytes=0-" {
		t.Fatalf("expected one resumed request, got hits=%d ranges=%v", hits, ranges)
	}
	if err := VerifySHA256(dest, sha(payload)); err != nil {
		t.Fatal(err)
	}
	retried := false
	for _, p := range reports {
		if p.Attempt == 2 {
			retried = true
		}
	}
	if !retried {
		t.Fatal("no retry progress reported")
	}
}

func TestVerifyChecksumMismatchDeletes(t *testing.T) {
	p := filepath.Join(t.TempDir(), "x.zip")
	os.WriteFile(p, []byte("hello"), 0o644)
	if err := VerifySHA256(p, strings.Repeat("0", 64)); !errors.Is(err, ErrChecksum) {
		t.Fatalf("err %v", err)
	}
	if _, err := os.Stat(p); !os.IsNotExist(err) {
		t.Fatal("bad file kept")
	}
}

func TestInstallAtomicSwap(t *testing.T) {
	root := t.TempDir()
	z1 := filepath.Join(root, "v1.zip")
	os.WriteFile(z1, makeZip(t, map[string]string{"Perdidos.x86_64": "v1", "version.txt": "0.1.0"}), 0o644)
	in, err := Install(root, z1, "0.1.0", "Perdidos.x86_64", "srv", noReport)
	if err != nil {
		t.Fatal(err)
	}
	if got, ok := ReadInstalled(root); !ok || got.Version != "0.1.0" || got.Server != "srv" {
		t.Fatalf("installed: %+v %v", got, ok)
	}
	if b, _ := os.ReadFile(in.ExePath(root)); string(b) != "v1" {
		t.Fatal("exe content")
	}
	if st, _ := os.Stat(in.ExePath(root)); st.Mode().Perm()&0o100 == 0 {
		t.Fatal("exe not executable")
	}

	// A broken package must not touch the installed version.
	bad := filepath.Join(root, "bad.zip")
	os.WriteFile(bad, makeZip(t, map[string]string{"readme.txt": "no exe"}), 0o644)
	if _, err := Install(root, bad, "0.2.0", "Perdidos.x86_64", "", noReport); err == nil {
		t.Fatal("package without exe accepted")
	}
	if got, ok := ReadInstalled(root); !ok || got.Version != "0.1.0" {
		t.Fatal("failed install changed the active version")
	}
	slip := filepath.Join(root, "slip.zip")
	os.WriteFile(slip, makeZip(t, map[string]string{"../../evil": "x", "Perdidos.x86_64": "x"}), 0o644)
	if _, err := Install(root, slip, "0.2.0", "Perdidos.x86_64", "", noReport); err == nil {
		t.Fatal("zip slip accepted")
	}
	entries, _ := os.ReadDir(filepath.Join(root, VersionsDir))
	if len(entries) != 1 || entries[0].Name() != "0.1.0" {
		t.Fatalf("leftovers after failed installs: %v", entries)
	}

	// Simulated crash: staging dir left behind is cleaned, active version intact.
	os.MkdirAll(filepath.Join(root, VersionsDir, ".staging-9.9.9-123"), 0o755)
	CleanLeftovers(root)
	entries, _ = os.ReadDir(filepath.Join(root, VersionsDir))
	if len(entries) != 1 {
		t.Fatalf("staging not cleaned: %v", entries)
	}

	// Upgrade (exe inside a top-level folder): new version active, old one removed.
	z2 := filepath.Join(root, "v2.zip")
	os.WriteFile(z2, makeZip(t, map[string]string{"Perdidos/Perdidos.x86_64": "v2"}), 0o644)
	in2, err := Install(root, z2, "0.2.0", "Perdidos.x86_64", "", noReport)
	if err != nil {
		t.Fatal(err)
	}
	if b, _ := os.ReadFile(in2.ExePath(root)); string(b) != "v2" {
		t.Fatal("v2 exe")
	}
	if _, err := os.Stat(filepath.Join(root, VersionsDir, "0.1.0")); !os.IsNotExist(err) {
		t.Fatal("old version not removed")
	}
}

// Drive source: no latest.json in the owner's real folder -> ErrNoRelease; with latest.json the
// zip is found in the root or in the platform subfolder and downloaded through the confirm page.
func TestSourceDriveAndFallback(t *testing.T) {
	zipBytes := makeZip(t, map[string]string{"Perdidos.x86_64": "game"})
	manifest := fmt.Sprintf(`{"version":"0.1.3","files":{"linux":{"name":"Perdidos-0.1.3-linux.zip","sha256":"%s"}}}`, sha(zipBytes))
	root := readFixture(t, "folder_release_sample.html")
	empty := readFixture(t, "folder_root_2026-09.html")
	var listing = &root
	var apiHits int32
	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch {
		case r.URL.Path == "/embeddedfolderview":
			io.WriteString(w, *listing)
		case r.URL.Path == "/download" && r.URL.Query().Get("id") == "1LaTeStJsOnAAAAAAAAAAAAAAAAAAAAAA":
			w.Header().Set("Content-Type", "application/json")
			io.WriteString(w, manifest)
		case r.URL.Path == "/download" && r.URL.Query().Get("id") == "1LiNzIpCCCCCCCCCCCCCCCCCCCCCCCCCC":
			w.Header().Set("Content-Type", "application/zip")
			w.Write(zipBytes)
		case r.URL.Path == "/api/latest":
			atomic.AddInt32(&apiHits, 1)
			http.Error(w, `{"error":"no_release"}`, 404)
		default:
			http.NotFound(w, r)
		}
	}))
	defer ts.Close()
	dc := drive.New(http.DefaultClient)
	dc.FolderView = ts.URL + "/embeddedfolderview?id="
	dc.Download = ts.URL + "/download"
	src := &Source{Drive: dc, FolderID: "178ylieiRtCYsOtrr-8wTmd2hB3oymsNW", APIBase: ts.URL}

	m, origin, err := src.Latest(context.Background())
	if err != nil || origin != "drive" || m.Version != "0.1.3" {
		t.Fatalf("latest: %v %s %+v", err, origin, m)
	}
	f, _ := m.For("linux")
	open, err := src.Opener(context.Background(), "linux", f)
	if err != nil {
		t.Fatal(err)
	}
	dest := filepath.Join(t.TempDir(), f.Name)
	if err := Download(context.Background(), open, dest, 0, noReport); err != nil {
		t.Fatal(err)
	}
	if err := VerifySHA256(dest, f.SHA256); err != nil {
		t.Fatal(err)
	}

	listing = &empty // owner's folder today: only subfolders, no latest.json
	if _, _, err := src.Latest(context.Background()); !errors.Is(err, ErrNoRelease) {
		t.Fatalf("empty folder: %v", err)
	}
	if apiHits == 0 {
		t.Fatal("API fallback not tried")
	}
}

func readFixture(t *testing.T, name string) string {
	b, err := os.ReadFile(filepath.Join("..", "drive", "testdata", name))
	if err != nil {
		t.Fatal(err)
	}
	return string(b)
}

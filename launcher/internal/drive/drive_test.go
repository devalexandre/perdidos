package drive

import (
	"context"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"strings"
	"testing"
	"time"
)

func fixture(t *testing.T, name string) string {
	t.Helper()
	b, err := os.ReadFile("testdata/" + name)
	if err != nil {
		t.Fatal(err)
	}
	return string(b)
}

// Real listing of the owner's folder (saved 2026-09-30): two subfolders, no files.
func TestParseRealRootFolder(t *testing.T) {
	f, err := ParseFolder(fixture(t, "folder_root_2026-09.html"))
	if err != nil {
		t.Fatal(err)
	}
	if f.Title != "perdidos" || len(f.Entries) != 2 {
		t.Fatalf("got %+v", f)
	}
	win, ok := f.Find("windows", true)
	if !ok || win.ID != "1oZXOvVQQyBQVusr1U3hXT-V2aGRcaiNs" {
		t.Fatalf("windows folder: %+v", win)
	}
	if _, ok := f.Find("latest.json", false); ok {
		t.Fatal("latest.json should not exist in this listing")
	}
}

func TestParseRealSubfolderWithFile(t *testing.T) {
	f, err := ParseFolder(fixture(t, "folder_linux_2026-09.html"))
	if err != nil {
		t.Fatal(err)
	}
	e, ok := f.Find("Perdidos.x86_64", false)
	if !ok || e.ID != "1Z71MydJV6xL6pAXt5zVKzifWwW7ZrNp4" || e.IsFolder {
		t.Fatalf("file entry: %+v (%+v)", e, f)
	}
}

func TestParseReleaseSample(t *testing.T) {
	f, err := ParseFolder(fixture(t, "folder_release_sample.html"))
	if err != nil {
		t.Fatal(err)
	}
	if len(f.Entries) != 5 {
		t.Fatalf("entries: %+v", f.Entries)
	}
	if e, ok := f.Find("LATEST.json", false); !ok || e.ID != "1LaTeStJsOnAAAAAAAAAAAAAAAAAAAAAA" {
		t.Fatalf("latest.json: %+v", e)
	}
	if e, ok := f.Find("Perdidos-0.1.3-linux.zip", false); !ok || e.ID != "1LiNzIpCCCCCCCCCCCCCCCCCCCCCCCCCC" {
		t.Fatalf("linux zip: %+v", e)
	}
	if _, ok := f.Find("Notas & novidades.txt", false); !ok {
		t.Fatal("html entities not unescaped")
	}
}

func TestParseEmptyAndGarbage(t *testing.T) {
	f, err := ParseFolder(fixture(t, "folder_empty_sample.html"))
	if err != nil || len(f.Entries) != 0 {
		t.Fatalf("empty folder: %v %+v", err, f)
	}
	if _, err := ParseFolder("<html><body>Sign in to continue</body></html>"); err != ErrNotAFolder {
		t.Fatalf("garbage: %v", err)
	}
}

func TestConfirmURLFromWarningPage(t *testing.T) {
	u := ConfirmURL(fixture(t, "virus_warning.html"))
	if !strings.HasPrefix(u, "https://drive.usercontent.google.com/download?") ||
		!strings.Contains(u, "id=1cjVmycazx_O0q23jtRgRHj1ZNV3WJYoY") || !strings.Contains(u, "confirm=t") ||
		!strings.Contains(u, "uuid=") {
		t.Fatalf("confirm url: %s", u)
	}
	if ConfirmURL(`<form id="download-form" action="https://evil.example/x"><input type="hidden" name="id" value="1"></form>`) != "" {
		t.Fatal("non-google action accepted")
	}
}

// Open follows the warning page and passes Range for resume.
func TestOpenFollowsWarningAndResumes(t *testing.T) {
	var ts *httptest.Server
	ts = httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Query().Get("uuid") == "" {
			w.Header().Set("Content-Type", "text/html; charset=utf-8")
			// Same page Drive serves, but pointing to the test server (https check is bypassed below).
			io.WriteString(w, strings.ReplaceAll(fixture(t, "virus_warning.html"),
				"https://drive.usercontent.google.com/download", "https://drive.usercontent.google.com/download"))
			return
		}
		w.Header().Set("Content-Type", "application/octet-stream")
		if r.Header.Get("Range") == "bytes=4-" {
			w.WriteHeader(http.StatusPartialContent)
			io.WriteString(w, "456789")
			return
		}
		io.WriteString(w, "0123456789")
	}))
	defer ts.Close()
	c := New(&http.Client{Transport: rewriteTo(ts.URL)})
	c.Download = "https://drive.usercontent.google.com/download"
	for _, tc := range []struct {
		off  int64
		want string
		code int
	}{{0, "0123456789", 200}, {4, "456789", 206}} {
		resp, err := c.Open(context.Background(), "1cjVmycazx_O0q23jtRgRHj1ZNV3WJYoY", tc.off)
		if err != nil {
			t.Fatal(err)
		}
		b, _ := io.ReadAll(resp.Body)
		resp.Body.Close()
		if string(b) != tc.want || resp.StatusCode != tc.code {
			t.Fatalf("offset %d: %d %q", tc.off, resp.StatusCode, b)
		}
	}
}

// rewriteTo sends every request to the test server, keeping path and query.
type rewriteTo string

func (r rewriteTo) RoundTrip(req *http.Request) (*http.Response, error) {
	u := *req.URL
	u.Scheme = "http"
	u.Host = strings.TrimPrefix(string(r), "http://")
	out := req.Clone(req.Context())
	out.URL = &u
	out.Host = u.Host
	return http.DefaultTransport.RoundTrip(out)
}

// Real network test against the owner's public folder (read only). Run with PERDIDOS_DRIVE_LIVE=1.
func TestLiveOwnerFolder(t *testing.T) {
	if os.Getenv("PERDIDOS_DRIVE_LIVE") != "1" {
		t.Skip("set PERDIDOS_DRIVE_LIVE=1 to hit drive.google.com")
	}
	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()
	c := New(&http.Client{Timeout: 60 * time.Second})
	root, err := c.List(ctx, "178ylieiRtCYsOtrr-8wTmd2hB3oymsNW")
	if err != nil {
		t.Fatal(err)
	}
	t.Logf("root %q: %+v", root.Title, root.Entries)
	win, ok := root.Find("windows", true)
	if !ok {
		t.Skip("owner folder layout changed (no windows/ subfolder)")
	}
	sub, err := c.List(ctx, win.ID)
	if err != nil {
		t.Fatal(err)
	}
	t.Logf("windows/: %+v", sub.Entries)
	var file Entry
	for _, e := range sub.Entries {
		if !e.IsFolder {
			file = e
			break
		}
	}
	if file.ID == "" {
		t.Skip("no file to download")
	}
	// Read only the first bytes (big file: exercises the confirm path + Range).
	resp, err := c.Open(ctx, file.ID, 0)
	if err != nil {
		t.Fatal(err)
	}
	head := make([]byte, 64)
	n, _ := io.ReadFull(resp.Body, head)
	resp.Body.Close()
	t.Logf("%s: HTTP %d, %s, first bytes %q", file.Name, resp.StatusCode, resp.Header.Get("Content-Type"), head[:2])
	if n < 2 || (strings.HasSuffix(file.Name, ".exe") && string(head[:2]) != "MZ") {
		t.Fatalf("unexpected content: %q", head[:n])
	}
	resp, err = c.Open(ctx, file.ID, 1000)
	if err != nil {
		t.Fatal(err)
	}
	resp.Body.Close()
	if resp.StatusCode != http.StatusPartialContent {
		t.Fatalf("resume (Range) not honored: HTTP %d", resp.StatusCode)
	}
}

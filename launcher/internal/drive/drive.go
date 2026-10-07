// Package drive reads a PUBLIC Google Drive folder without an API key:
//
//   - listing: https://drive.google.com/embeddedfolderview?id=<FOLDER_ID> (HTML with name + id of
//     each entry, files and subfolders);
//   - download: https://drive.usercontent.google.com/download?id=<ID>&export=download&confirm=t
//     (big files may still answer with the "can't scan for viruses" HTML page; its form carries the
//     real download parameters, which we follow).
//
// This is not an official API: if Google changes the HTML, ParseFolder breaks. The launcher then
// falls back to the accounts API (/api/latest).
package drive

import (
	"context"
	"errors"
	"fmt"
	"html"
	"io"
	"net/http"
	"net/url"
	"regexp"
	"strings"
)

const (
	FolderViewURL = "https://drive.google.com/embeddedfolderview?id="
	DownloadURL   = "https://drive.usercontent.google.com/download"
	userAgent     = "PerdidosLauncher/1.0"
	maxListing    = 4 << 20
)

// Entry is a file or subfolder in a folder listing.
type Entry struct {
	ID       string
	Name     string
	IsFolder bool
}

// Folder is a parsed listing.
type Folder struct {
	Title   string
	Entries []Entry
}

// Find returns the entry with this exact name (case-insensitive), files before folders.
func (f Folder) Find(name string, folder bool) (Entry, bool) {
	for _, e := range f.Entries {
		if e.IsFolder == folder && strings.EqualFold(e.Name, name) {
			return e, true
		}
	}
	return Entry{}, false
}

var (
	reEntry = regexp.MustCompile(`(?s)<div class="flip-entry" id="entry-([A-Za-z0-9_-]+)"(.*?)<div class="flip-entry-title">(.*?)</div>`)
	reHref  = regexp.MustCompile(`href="([^"]+)"`)
	reTitle = regexp.MustCompile(`(?s)<title>(.*?)</title>`)
	// Drive ids are long base64url-ish strings.
	reID = regexp.MustCompile(`^[A-Za-z0-9_-]{10,}$`)
)

// ErrNotAFolder means the HTML did not look like a folder listing (private folder, bad id, layout change).
var ErrNotAFolder = errors.New("drive: response is not a public folder listing")

// ParseFolder extracts the entries of an embeddedfolderview page.
func ParseFolder(page string) (Folder, error) {
	var f Folder
	if m := reTitle.FindStringSubmatch(page); m != nil {
		f.Title = html.UnescapeString(strings.TrimSpace(m[1]))
	}
	if !strings.Contains(page, "flip-entries") && !strings.Contains(page, "flip-entry") {
		if strings.Contains(page, "flip-contents") || strings.Contains(page, "flip-embedded") {
			return f, nil // a public folder that is simply empty
		}
		return f, ErrNotAFolder
	}
	for _, m := range reEntry.FindAllStringSubmatch(page, -1) {
		id, body, name := m[1], m[2], html.UnescapeString(strings.TrimSpace(m[3]))
		if !reID.MatchString(id) || name == "" {
			continue
		}
		isFolder := false
		if h := reHref.FindStringSubmatch(body); h != nil {
			isFolder = strings.Contains(h[1], "/folders/")
		}
		f.Entries = append(f.Entries, Entry{ID: id, Name: name, IsFolder: isFolder})
	}
	return f, nil
}

// Client talks to Drive over plain HTTPS.
type Client struct {
	HTTP *http.Client
	// Overridable for tests.
	FolderView string
	Download   string
}

func New(h *http.Client) *Client {
	if h == nil {
		h = http.DefaultClient
	}
	return &Client{HTTP: h, FolderView: FolderViewURL, Download: DownloadURL}
}

// List fetches and parses a public folder.
func (c *Client) List(ctx context.Context, folderID string) (Folder, error) {
	if !reID.MatchString(folderID) {
		return Folder{}, fmt.Errorf("drive: invalid folder id %q", folderID)
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, c.FolderView+url.QueryEscape(folderID), nil)
	if err != nil {
		return Folder{}, err
	}
	req.Header.Set("User-Agent", userAgent)
	resp, err := c.HTTP.Do(req)
	if err != nil {
		return Folder{}, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return Folder{}, fmt.Errorf("drive: folder listing HTTP %d", resp.StatusCode)
	}
	body, err := io.ReadAll(io.LimitReader(resp.Body, maxListing))
	if err != nil {
		return Folder{}, err
	}
	return ParseFolder(string(body))
}

// FileURL is the direct download URL of a file id.
func (c *Client) FileURL(id string) string {
	q := url.Values{"id": {id}, "export": {"download"}, "confirm": {"t"}}
	return c.Download + "?" + q.Encode()
}

var (
	reForm   = regexp.MustCompile(`(?s)<form[^>]*id="download-form"[^>]*action="([^"]+)"[^>]*>(.*?)</form>`)
	reHidden = regexp.MustCompile(`<input type="hidden" name="([^"]+)" value="([^"]*)"`)
)

// ConfirmURL extracts the "download anyway" URL from Drive's warning page ("" if none).
func ConfirmURL(page string) string {
	m := reForm.FindStringSubmatch(page)
	if m == nil {
		return ""
	}
	action := html.UnescapeString(m[1])
	u, err := url.Parse(action)
	if err != nil || u.Scheme != "https" || !strings.HasSuffix(u.Hostname(), ".google.com") {
		return ""
	}
	q := url.Values{}
	for _, h := range reHidden.FindAllStringSubmatch(m[2], -1) {
		q.Set(html.UnescapeString(h[1]), html.UnescapeString(h[2]))
	}
	if q.Get("id") == "" {
		return ""
	}
	u.RawQuery = q.Encode()
	return u.String()
}

// Open starts a download of id (optionally from byte offset). When Drive answers with its HTML
// warning page, the confirm form is followed once. The caller closes the body.
func (c *Client) Open(ctx context.Context, id string, offset int64) (*http.Response, error) {
	target := c.FileURL(id)
	for attempt := 0; attempt < 2; attempt++ {
		req, err := http.NewRequestWithContext(ctx, http.MethodGet, target, nil)
		if err != nil {
			return nil, err
		}
		req.Header.Set("User-Agent", userAgent)
		if offset > 0 {
			req.Header.Set("Range", fmt.Sprintf("bytes=%d-", offset))
		}
		resp, err := c.HTTP.Do(req)
		if err != nil {
			return nil, err
		}
		if resp.StatusCode >= 400 {
			resp.Body.Close()
			return nil, fmt.Errorf("drive: download HTTP %d", resp.StatusCode)
		}
		if !strings.HasPrefix(resp.Header.Get("Content-Type"), "text/html") {
			return resp, nil
		}
		page, _ := io.ReadAll(io.LimitReader(resp.Body, 1<<20))
		resp.Body.Close()
		next := ConfirmURL(string(page))
		if next == "" {
			return nil, errors.New("drive: got an HTML page instead of the file (quota exceeded or file not public)")
		}
		target = next
	}
	return nil, errors.New("drive: still on the warning page after confirming")
}

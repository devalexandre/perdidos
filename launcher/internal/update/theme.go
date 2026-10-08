package update

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"time"
	"unicode"
	"unicode/utf8"
)

// Theme is the optional "theme" of latest.json: the launcher background and tagline of the
// current story arc, so a new arc changes the art without shipping a new launcher.
//
//	"theme": {"id": "arco1", "arc": "Arco I", "title": "A Terra de Pindorama", "tagline": "…",
//	          "background": {"name": "theme-arco1.jpg", "sha256": "…", "size": 123, "url": "(opcional)"}}
type Theme struct {
	ID string `json:"id"`
	// Arc and Title fill the arc seal of the login screen, around its dot:
	// "Arco I" • "A Terra de Pindorama". Plain text only.
	Arc        string   `json:"arc,omitempty"`
	Title      string   `json:"title,omitempty"`
	Tagline    string   `json:"tagline,omitempty"`
	Background FileInfo `json:"background"`
}

// Theme cache inside the install root:
//
//	theme/<id>/<name>    background image (only the current and the previous theme are kept)
//	theme/current.json   which theme is active (replaced atomically: write tmp + rename)
const (
	ThemeDir         = "theme"
	ThemeCurrentFile = "current.json"
	MaxThemeImage    = 8 << 20
	MaxTaglineRunes  = 140
	MaxTitleRunes    = 60
	MaxArcRunes      = 20
)

var (
	reThemeID   = regexp.MustCompile(`^[a-z0-9][a-z0-9_-]{0,31}$`)
	reThemeFile = regexp.MustCompile(`^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$`)
	themeMIME   = map[string]string{".jpg": "image/jpeg", ".jpeg": "image/jpeg", ".png": "image/png", ".webp": "image/webp"}
)

// ThemeMIME returns the image type for a theme file name ("" = extension not allowed).
func ThemeMIME(name string) string { return themeMIME[strings.ToLower(filepath.Ext(name))] }

func validThemeFile(name string) bool {
	return reThemeFile.MatchString(name) && !strings.Contains(name, "..") && ThemeMIME(name) != ""
}

func validateTheme(t Theme) (Theme, error) {
	t.ID = strings.TrimSpace(t.ID)
	t.Tagline = strings.TrimSpace(t.Tagline)
	t.Title = strings.TrimSpace(t.Title)
	t.Arc = strings.TrimSpace(t.Arc)
	b := &t.Background
	b.Name = strings.TrimSpace(b.Name)
	b.SHA256 = strings.ToLower(strings.TrimSpace(b.SHA256))
	switch {
	case !reThemeID.MatchString(t.ID):
		return t, fmt.Errorf("latest.json: tema com id inválido %q", t.ID)
	case utf8.RuneCountInString(t.Arc) > MaxArcRunes:
		return t, fmt.Errorf("latest.json: arco do tema passa de %d caracteres", MaxArcRunes)
	case utf8.RuneCountInString(t.Title) > MaxTitleRunes:
		return t, fmt.Errorf("latest.json: título do tema passa de %d caracteres", MaxTitleRunes)
	case !plainText(t.Arc) || !plainText(t.Title) || !plainText(t.Tagline):
		return t, errors.New("latest.json: arco/título/frase do tema só aceitam texto simples (sem <, > nem controle)")
	case utf8.RuneCountInString(t.Tagline) > MaxTaglineRunes:
		return t, fmt.Errorf("latest.json: frase do tema passa de %d caracteres", MaxTaglineRunes)
	case !validThemeFile(b.Name):
		return t, fmt.Errorf("latest.json: imagem do tema com nome inválido %q (use .jpg, .jpeg, .png ou .webp)", b.Name)
	case !reSHA.MatchString(b.SHA256):
		return t, errors.New("latest.json: imagem do tema sem sha256 válido")
	case b.Size <= 0 || b.Size > MaxThemeImage:
		return t, fmt.Errorf("latest.json: imagem do tema precisa ter tamanho entre 1 byte e %d MB", MaxThemeImage>>20)
	}
	if b.URL != "" {
		u, err := url.Parse(b.URL)
		if err != nil || (u.Scheme != "https" && u.Scheme != "http") || u.Host == "" {
			return t, errors.New("latest.json: url da imagem do tema inválida")
		}
	}
	b.Exe = ""
	return t, nil
}

// plainText rejects markup and control characters (the screen uses textContent anyway).
func plainText(s string) bool {
	return utf8.ValidString(s) && !strings.ContainsFunc(s, func(r rune) bool {
		return r == '<' || r == '>' || unicode.IsControl(r)
	})
}

// CachedTheme is theme/current.json.
type CachedTheme struct {
	ID      string    `json:"id"`
	Arc     string    `json:"arc,omitempty"`
	Title   string    `json:"title,omitempty"`
	Tagline string    `json:"tagline,omitempty"`
	File    string    `json:"file"`
	SHA256  string    `json:"sha256"`
	Updated time.Time `json:"updated"`
}

// ImagePath is the absolute path of the cached background.
func (c CachedTheme) ImagePath(root string) string {
	return filepath.Join(root, ThemeDir, c.ID, c.File)
}

// ReadCurrentTheme returns the active cached theme, checking that the image is really there.
func ReadCurrentTheme(root string) (CachedTheme, bool) {
	var c CachedTheme
	data, err := os.ReadFile(filepath.Join(root, ThemeDir, ThemeCurrentFile))
	if err != nil || json.Unmarshal(data, &c) != nil || !reThemeID.MatchString(c.ID) || !validThemeFile(c.File) {
		return CachedTheme{}, false
	}
	if st, err := os.Stat(c.ImagePath(root)); err != nil || !st.Mode().IsRegular() {
		return CachedTheme{}, false
	}
	return c, true
}

// ThemeCached reports whether t is already the active cached theme (nothing to download).
func ThemeCached(root string, t Theme) bool {
	c, ok := ReadCurrentTheme(root)
	return ok && c.ID == t.ID && c.File == t.Background.Name && c.SHA256 == t.Background.SHA256 &&
		c.Tagline == t.Tagline && c.Title == t.Title && c.Arc == t.Arc
}

// FetchTheme downloads the theme image (if needed), checks SHA-256, makes it the current theme and
// removes every cached theme except the new one and the previous one.
func FetchTheme(ctx context.Context, root string, t Theme, open Opener) (CachedTheme, error) {
	t, err := validateTheme(t)
	if err != nil {
		return CachedTheme{}, err
	}
	prev, hadPrev := ReadCurrentTheme(root)
	dir := filepath.Join(root, ThemeDir, t.ID)
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return CachedTheme{}, err
	}
	dest := filepath.Join(dir, t.Background.Name)
	if got, err := FileSHA256(dest); err != nil || got != t.Background.SHA256 {
		// Download as <name>.tmp (resumable through <name>.tmp.part), verify, then rename into place:
		// a half-written or corrupted image never gets the final name.
		tmp := dest + ".tmp"
		os.Remove(tmp)
		size := t.Background.Size
		if err := Download(ctx, capOpener(open, size), tmp, size, func(Progress) {}); err != nil {
			return CachedTheme{}, err
		}
		if err := VerifySHA256(tmp, t.Background.SHA256); err != nil {
			return CachedTheme{}, err
		}
		if err := os.Rename(tmp, dest); err != nil {
			return CachedTheme{}, err
		}
	}
	cur := CachedTheme{ID: t.ID, Arc: t.Arc, Title: t.Title, Tagline: t.Tagline, File: t.Background.Name, SHA256: t.Background.SHA256,
		Updated: time.Now().UTC()}
	if err := writeJSONAtomic(filepath.Join(root, ThemeDir, ThemeCurrentFile), cur); err != nil {
		return CachedTheme{}, err
	}
	keep := map[string]bool{t.ID: true}
	if hadPrev && prev.ID != t.ID {
		keep[prev.ID] = true
	}
	pruneThemes(root, keep, t.ID, t.Background.Name)
	return cur, nil
}

// pruneThemes removes theme dirs not in keep, and stray files inside the current theme dir.
func pruneThemes(root string, keep map[string]bool, curID, curFile string) {
	base := filepath.Join(root, ThemeDir)
	entries, _ := os.ReadDir(base)
	for _, e := range entries {
		if e.IsDir() && !keep[e.Name()] {
			os.RemoveAll(filepath.Join(base, e.Name()))
		}
	}
	files, _ := os.ReadDir(filepath.Join(base, curID))
	for _, f := range files {
		if f.Name() != curFile {
			os.RemoveAll(filepath.Join(base, curID, f.Name()))
		}
	}
}

// capOpener stops reading after the expected size (+1 byte, so an oversized answer is detected
// as "incompleto/diferente" instead of filling the disk).
func capOpener(open Opener, size int64) Opener {
	return func(offset int64) (*http.Response, error) {
		resp, err := open(offset)
		if err != nil || resp == nil {
			return resp, err
		}
		resp.Body = struct {
			io.Reader
			io.Closer
		}{io.LimitReader(resp.Body, size+1), resp.Body}
		return resp, nil
	}
}

// ThemeOpener finds the theme image: direct URL in the manifest, then the Drive folder (root or a
// "theme/" subfolder), then the accounts API (/api/theme/<name>, plan B).
func (s *Source) ThemeOpener(ctx context.Context, f FileInfo) (Opener, error) {
	var err error
	if f.URL != "" || (s.Drive != nil && s.FolderID != "") {
		var open Opener
		if open, err = s.Opener(ctx, ThemeDir, f); err == nil {
			return open, nil
		}
		if f.URL != "" || s.APIBase == "" {
			return nil, err
		}
	}
	if s.APIBase == "" {
		return nil, fmt.Errorf("sem endereço para baixar %s", f.Name)
	}
	api := FileInfo{Name: f.Name, URL: strings.TrimRight(s.APIBase, "/") + "/api/theme/" + url.PathEscape(f.Name)}
	return s.Opener(ctx, ThemeDir, api)
}

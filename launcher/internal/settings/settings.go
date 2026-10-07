// Package settings: install folder, launcher.json (remember e-mail, Drive folder, API address).
package settings

import (
	"encoding/json"
	"os"
	"path/filepath"
	"runtime"
	"strings"
)

// Defaults, overridable at build time:
//
//	go build -ldflags "-X perdidos/launcher/internal/settings.DefaultDriveFolder=<id> -X perdidos/launcher/internal/settings.DefaultAPIBase=https://..."
var (
	DefaultDriveFolder = "178ylieiRtCYsOtrr-8wTmd2hB3oymsNW"
	DefaultAPIBase     = "https://poetic-calculably-nayeli.ngrok-free.dev"
)

// Settings is launcher.json in the install root. Empty fields fall back to the defaults.
type Settings struct {
	RememberEmail bool   `json:"remember_email"`
	Email         string `json:"email,omitempty"`
	DriveFolderID string `json:"drive_folder_id,omitempty"`
	APIBase       string `json:"api_base,omitempty"`
}

const fileName = "launcher.json"

// Root is the install folder: %LOCALAPPDATA%\Perdidos or ~/.local/share/perdidos
// ($PERDIDOS_HOME overrides, used in tests).
func Root() string {
	if v := os.Getenv("PERDIDOS_HOME"); v != "" {
		return v
	}
	if runtime.GOOS == "windows" {
		if v := os.Getenv("LOCALAPPDATA"); v != "" {
			return filepath.Join(v, "Perdidos")
		}
	}
	if v := os.Getenv("XDG_DATA_HOME"); v != "" {
		return filepath.Join(v, "perdidos")
	}
	home, _ := os.UserHomeDir()
	return filepath.Join(home, ".local", "share", "perdidos")
}

func Load(root string) Settings {
	var s Settings
	if data, err := os.ReadFile(filepath.Join(root, fileName)); err == nil {
		_ = json.Unmarshal(data, &s)
	}
	return s
}

func Save(root string, s Settings) error {
	if err := os.MkdirAll(root, 0o755); err != nil {
		return err
	}
	data, _ := json.MarshalIndent(s, "", "  ")
	tmp := filepath.Join(root, fileName+".tmp")
	if err := os.WriteFile(tmp, data, 0o600); err != nil {
		return err
	}
	return os.Rename(tmp, filepath.Join(root, fileName))
}

// DriveFolder: env PERDIDOS_DRIVE_FOLDER > launcher.json > default. Accepts a full folder URL too.
func (s Settings) DriveFolder() string {
	v := firstNonEmpty(os.Getenv("PERDIDOS_DRIVE_FOLDER"), s.DriveFolderID, DefaultDriveFolder)
	return FolderIDFromURL(v)
}

// API: env PERDIDOS_API > launcher.json > default.
func (s Settings) API() string {
	return strings.TrimRight(firstNonEmpty(os.Getenv("PERDIDOS_API"), s.APIBase, DefaultAPIBase), "/")
}

// FolderIDFromURL turns https://drive.google.com/drive/folders/<ID>?usp=... into <ID>.
func FolderIDFromURL(v string) string {
	v = strings.TrimSpace(v)
	if i := strings.Index(v, "/folders/"); i >= 0 {
		v = v[i+len("/folders/"):]
	} else if i := strings.Index(v, "id="); i >= 0 {
		v = v[i+3:]
	}
	if i := strings.IndexAny(v, "?&#/"); i >= 0 {
		v = v[:i]
	}
	if v == "-" || v == "none" {
		return ""
	}
	return v
}

func firstNonEmpty(vs ...string) string {
	for _, v := range vs {
		if strings.TrimSpace(v) != "" {
			return strings.TrimSpace(v)
		}
	}
	return ""
}

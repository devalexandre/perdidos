package update

import (
	"archive/zip"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"time"
)

// Layout inside the install root (Windows %LOCALAPPDATA%\Perdidos, Linux ~/.local/share/perdidos):
//
//	installed.json        which version is active (replaced atomically: write tmp + rename)
//	versions/<version>/   extracted game (only complete extractions ever get this name)
//	versions/.staging-*   extraction in progress (removed on the next start if left behind)
//	downloads/            zips and .part files (resume)
const (
	InstalledFile = "installed.json"
	VersionsDir   = "versions"
	DownloadsDir  = "downloads"
	stagingPrefix = ".staging-"
	oldPrefix     = ".old-"
)

// Installed is the active version.
type Installed struct {
	Version     string    `json:"version"`
	Dir         string    `json:"dir"` // relative to the root: versions/<version>
	Exe         string    `json:"exe"`
	Server      string    `json:"server,omitempty"`
	InstalledAt time.Time `json:"installed_at"`
}

// ExePath is the absolute path of the game executable.
func (i Installed) ExePath(root string) string {
	return filepath.Join(root, filepath.FromSlash(i.Dir), filepath.FromSlash(i.Exe))
}

// ReadInstalled returns the active install, checking that the executable is really there.
func ReadInstalled(root string) (Installed, bool) {
	var in Installed
	data, err := os.ReadFile(filepath.Join(root, InstalledFile))
	if err != nil || json.Unmarshal(data, &in) != nil || in.Version == "" {
		return Installed{}, false
	}
	if _, err := os.Stat(in.ExePath(root)); err != nil {
		return Installed{}, false
	}
	return in, true
}

// CleanLeftovers removes staging/old dirs from an interrupted install.
func CleanLeftovers(root string) {
	entries, _ := os.ReadDir(filepath.Join(root, VersionsDir))
	for _, e := range entries {
		if strings.HasPrefix(e.Name(), stagingPrefix) || strings.HasPrefix(e.Name(), oldPrefix) {
			os.RemoveAll(filepath.Join(root, VersionsDir, e.Name()))
		}
	}
}

// Install extracts zipPath into a staging dir, then swaps it in: rename to versions/<version>,
// then rewrite installed.json atomically. A crash at any point leaves the previous version usable.
func Install(root, zipPath, version, exe, server string, report func(Progress)) (Installed, error) {
	if strings.ContainsAny(version, `/\`) || version == "" || version == "." || version == ".." {
		return Installed{}, fmt.Errorf("versão inválida %q", version)
	}
	vdir := filepath.Join(root, VersionsDir)
	if err := os.MkdirAll(vdir, 0o755); err != nil {
		return Installed{}, err
	}
	staging, err := os.MkdirTemp(vdir, stagingPrefix+version+"-")
	if err != nil {
		return Installed{}, err
	}
	ok := false
	defer func() {
		if !ok {
			os.RemoveAll(staging)
		}
	}()
	if err := extractZip(zipPath, staging, report); err != nil {
		return Installed{}, fmt.Errorf("falha ao extrair: %w", err)
	}
	// Accept the executable at the zip root or inside one top-level folder.
	exeRel, err := locateExe(staging, exe)
	if err != nil {
		return Installed{}, err
	}
	if runtime.GOOS != "windows" {
		os.Chmod(filepath.Join(staging, exeRel), 0o755)
	}

	final := filepath.Join(vdir, version)
	if _, err := os.Stat(final); err == nil {
		old := filepath.Join(vdir, fmt.Sprintf("%s%s-%d", oldPrefix, version, time.Now().UnixNano()))
		if err := os.Rename(final, old); err != nil {
			return Installed{}, fmt.Errorf("a versão %s está em uso (feche o jogo e tente de novo): %w", version, err)
		}
		defer os.RemoveAll(old)
	}
	if err := os.Rename(staging, final); err != nil {
		return Installed{}, err
	}
	ok = true
	in := Installed{Version: version, Dir: VersionsDir + "/" + version, Exe: filepath.ToSlash(exeRel),
		Server: server, InstalledAt: time.Now().UTC()}
	if err := writeJSONAtomic(filepath.Join(root, InstalledFile), in); err != nil {
		return Installed{}, err
	}
	// Old versions: best effort (on Windows a running game keeps its folder locked).
	entries, _ := os.ReadDir(vdir)
	for _, e := range entries {
		if e.IsDir() && e.Name() != version {
			os.RemoveAll(filepath.Join(vdir, e.Name()))
		}
	}
	report(Progress{Phase: "done", Done: 1, Total: 1})
	return in, nil
}

func locateExe(dir, exe string) (string, error) {
	if _, err := os.Stat(filepath.Join(dir, exe)); err == nil {
		return exe, nil
	}
	entries, _ := os.ReadDir(dir)
	if len(entries) == 1 && entries[0].IsDir() {
		rel := filepath.Join(entries[0].Name(), exe)
		if _, err := os.Stat(filepath.Join(dir, rel)); err == nil {
			return rel, nil
		}
	}
	return "", fmt.Errorf("o pacote não tem %s", exe)
}

func extractZip(zipPath, dest string, report func(Progress)) error {
	zr, err := zip.OpenReader(zipPath)
	if err != nil {
		return err
	}
	defer zr.Close()
	var total, done int64
	for _, f := range zr.File {
		total += int64(f.UncompressedSize64)
	}
	destAbs, err := filepath.Abs(dest)
	if err != nil {
		return err
	}
	last := time.Now()
	for _, f := range zr.File {
		name := filepath.FromSlash(f.Name)
		target := filepath.Join(destAbs, name)
		// Zip-slip guard: every entry must stay inside dest.
		if !strings.HasPrefix(target, destAbs+string(os.PathSeparator)) {
			return fmt.Errorf("caminho inválido no zip: %q", f.Name)
		}
		if f.FileInfo().IsDir() {
			if err := os.MkdirAll(target, 0o755); err != nil {
				return err
			}
			continue
		}
		if f.Mode()&os.ModeSymlink != 0 {
			return fmt.Errorf("link simbólico no zip não é aceito: %q", f.Name)
		}
		if err := os.MkdirAll(filepath.Dir(target), 0o755); err != nil {
			return err
		}
		n, err := extractFile(f, target)
		if err != nil {
			return err
		}
		done += n
		if time.Since(last) > ReportEvery {
			report(Progress{Phase: "extract", Done: done, Total: total, ETA: -1})
			last = time.Now()
		}
	}
	report(Progress{Phase: "extract", Done: total, Total: total, ETA: -1})
	return nil
}

func extractFile(f *zip.File, target string) (int64, error) {
	rc, err := f.Open()
	if err != nil {
		return 0, err
	}
	defer rc.Close()
	mode := f.Mode().Perm() | 0o600
	out, err := os.OpenFile(target, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, mode)
	if err != nil {
		return 0, err
	}
	n, err := io.Copy(out, rc)
	if cerr := out.Close(); err == nil {
		err = cerr
	}
	return n, err
}

func writeJSONAtomic(path string, v any) error {
	data, err := json.MarshalIndent(v, "", "  ")
	if err != nil {
		return err
	}
	tmp, err := os.CreateTemp(filepath.Dir(path), filepath.Base(path)+".tmp-*")
	if err != nil {
		return err
	}
	if _, err := tmp.Write(data); err != nil {
		tmp.Close()
		os.Remove(tmp.Name())
		return err
	}
	if err := tmp.Sync(); err != nil {
		tmp.Close()
		os.Remove(tmp.Name())
		return err
	}
	tmp.Close()
	if err := os.Rename(tmp.Name(), path); err != nil {
		os.Remove(tmp.Name())
		return errors.Join(errors.New("não foi possível gravar "+filepath.Base(path)), err)
	}
	return nil
}

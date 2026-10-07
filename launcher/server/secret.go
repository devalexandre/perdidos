package main

import (
	"bufio"
	"crypto/rand"
	"encoding/base64"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

// SecretKey is the env var (and key inside secrets.env) holding the JWT HMAC secret.
const SecretKey = "PERDIDOS_JWT_SECRET"

// minSecretLen guards against a truncated/hand-typed weak secret.
const minSecretLen = 32

// DefaultSecretsPath is ~/.config/perdidos/secrets.env (shared with the Godot server).
func DefaultSecretsPath() string {
	dir, err := os.UserConfigDir()
	if err != nil {
		home, _ := os.UserHomeDir()
		dir = filepath.Join(home, ".config")
	}
	return filepath.Join(dir, "perdidos", "secrets.env")
}

// LoadOrCreateSecret returns the JWT secret. Order: env var, then the file; when neither
// exists the file is created with a random 48-byte secret (mode 0600). The secret is never logged.
func LoadOrCreateSecret(path string) (string, bool, error) {
	if v := strings.TrimSpace(os.Getenv(SecretKey)); v != "" {
		if len(v) < minSecretLen {
			return "", false, fmt.Errorf("%s is too short (min %d chars)", SecretKey, minSecretLen)
		}
		return v, false, nil
	}
	if v, err := readSecretFile(path); err == nil {
		return v, false, nil
	} else if !errors.Is(err, os.ErrNotExist) {
		return "", false, err
	}
	buf := make([]byte, 48)
	if _, err := rand.Read(buf); err != nil {
		return "", false, err
	}
	secret := base64.RawURLEncoding.EncodeToString(buf)
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		return "", false, err
	}
	content := "# Perdidos: segredo do JWT (API de contas + servidor do jogo). Não compartilhe.\n" +
		SecretKey + "=" + secret + "\n"
	f, err := os.OpenFile(path, os.O_WRONLY|os.O_CREATE|os.O_EXCL, 0o600)
	if err != nil {
		return "", false, err
	}
	defer f.Close()
	if _, err := f.WriteString(content); err != nil {
		return "", false, err
	}
	return secret, true, os.Chmod(path, 0o600)
}

func readSecretFile(path string) (string, error) {
	f, err := os.Open(path)
	if err != nil {
		return "", err
	}
	defer f.Close()
	sc := bufio.NewScanner(f)
	for sc.Scan() {
		line := strings.TrimSpace(sc.Text())
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		k, v, ok := strings.Cut(line, "=")
		if ok && strings.TrimSpace(k) == SecretKey {
			v = strings.Trim(strings.TrimSpace(v), `"'`)
			if len(v) < minSecretLen {
				return "", fmt.Errorf("%s in %s is too short (min %d chars)", SecretKey, path, minSecretLen)
			}
			return v, nil
		}
	}
	if err := sc.Err(); err != nil {
		return "", err
	}
	return "", fmt.Errorf("%s not found in %s", SecretKey, path)
}

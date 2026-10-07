package account

import (
	"os"
	"path/filepath"
	"testing"
	"time"
)

func TestSessionPersistence(t *testing.T) {
	path := filepath.Join(t.TempDir(), "launcher", "session.json")
	want := Session{
		Token:     "test-session-token",
		AccountID: 42,
		Email:     "player@example.test",
		ExpiresAt: time.Now().Add(time.Hour).Unix(),
	}
	if err := SaveSession(path, want); err != nil {
		t.Fatalf("SaveSession() error = %v", err)
	}
	info, err := os.Stat(path)
	if err != nil {
		t.Fatalf("stat session: %v", err)
	}
	if got := info.Mode().Perm(); got != 0o600 {
		t.Fatalf("session permissions = %04o, want 0600", got)
	}
	got, err := LoadSession(path)
	if err != nil {
		t.Fatalf("LoadSession() error = %v", err)
	}
	if got != want {
		t.Fatalf("LoadSession() = %#v, want %#v", got, want)
	}
}

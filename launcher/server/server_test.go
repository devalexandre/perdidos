package main

import (
	"bufio"
	"bytes"
	"encoding/json"
	"io"
	"log/slog"
	"net"
	"net/http"
	"net/http/httptest"
	"net/url"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

var testSecret = []byte("0123456789abcdef0123456789abcdef-test-secret")

func newTestServer(t *testing.T, game *url.URL) (*Server, *httptest.Server, *bytes.Buffer) {
	t.Helper()
	store, err := OpenSQLite(filepath.Join(t.TempDir(), "accounts.db"))
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { store.Close() })
	logs := &bytes.Buffer{}
	tmp := t.TempDir()
	latest := filepath.Join(tmp, "latest.json")
	s := NewServer(Config{Secret: testSecret, TokenTTL: time.Hour, LatestPath: latest, GameURL: game,
		AdminUserDataDir: filepath.Join(tmp, "userdata"), AdminServerLog: filepath.Join(tmp, "server.log"),
		AdminAuthLog: filepath.Join(tmp, "auth.log")},
		store, slog.New(slog.NewTextHandler(logs, nil)))
	ts := httptest.NewServer(s.Handler())
	t.Cleanup(ts.Close)
	return s, ts, logs
}

func postJSON(t *testing.T, url string, body any) (*http.Response, map[string]any) {
	t.Helper()
	b, _ := json.Marshal(body)
	resp, err := http.Post(url, "application/json", bytes.NewReader(b))
	if err != nil {
		t.Fatal(err)
	}
	defer resp.Body.Close()
	out := map[string]any{}
	_ = json.NewDecoder(resp.Body).Decode(&out)
	return resp, out
}

func TestRegisterLoginFlow(t *testing.T) {
	s, ts, logs := newTestServer(t, nil)
	pw := "senha-secreta-123"
	resp, out := postJSON(t, ts.URL+"/api/register", map[string]string{"email": " Ana@Example.com ", "password": pw})
	if resp.StatusCode != http.StatusCreated {
		t.Fatalf("register: %d %v", resp.StatusCode, out)
	}
	claims, err := VerifyJWT(testSecret, out["token"].(string), time.Now())
	if err != nil {
		t.Fatalf("token from register invalid: %v", err)
	}
	if claims.Email != "ana@example.com" || claims.AccountID != 1 || claims.Exp <= time.Now().Unix() {
		t.Fatalf("bad claims: %+v", claims)
	}

	resp, out = postJSON(t, ts.URL+"/api/register", map[string]string{"email": "ana@example.com", "password": pw})
	if resp.StatusCode != http.StatusConflict || out["error"] != "email_taken" {
		t.Fatalf("duplicate register: %d %v", resp.StatusCode, out)
	}

	resp, out = postJSON(t, ts.URL+"/api/login", map[string]string{"email": "ANA@example.com", "password": pw})
	if resp.StatusCode != http.StatusOK || out["account_id"].(float64) != 1 {
		t.Fatalf("login: %d %v", resp.StatusCode, out)
	}
	resp, out = postJSON(t, ts.URL+"/api/login", map[string]string{"email": "ana@example.com", "password": "errada-123"})
	if resp.StatusCode != http.StatusUnauthorized || out["error"] != "bad_credentials" {
		t.Fatalf("wrong password: %d %v", resp.StatusCode, out)
	}
	resp, out = postJSON(t, ts.URL+"/api/login", map[string]string{"email": "nobody@example.com", "password": pw})
	if resp.StatusCode != http.StatusUnauthorized || out["error"] != "bad_credentials" {
		t.Fatalf("unknown e-mail: %d %v", resp.StatusCode, out)
	}
	if strings.Contains(logs.String(), pw) || strings.Contains(logs.String(), "errada-123") {
		t.Fatal("password leaked into logs")
	}
	if strings.Contains(logs.String(), "ana@example.com") {
		t.Fatal("full e-mail in logs (should be masked)")
	}
	_ = s
}

func TestGoogleLoginFlow(t *testing.T) {
	s, ts, _ := newTestServer(t, nil)
	google := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Query().Get("id_token") != "valid-google-token" {
			http.Error(w, "invalid token", http.StatusUnauthorized)
			return
		}
		_ = json.NewEncoder(w).Encode(map[string]any{
			"aud": "perdidos-web.apps.googleusercontent.com", "email": "Google.User@example.com",
			"email_verified": true, "exp": time.Now().Add(time.Hour).Unix(),
			"iss": "https://accounts.google.com", "sub": "google-subject-123",
		})
	}))
	defer google.Close()
	s.cfg.GoogleClientID = "perdidos-web.apps.googleusercontent.com"
	s.cfg.PublicBaseURL = "https://poetic-calculably-nayeli.ngrok-free.dev"
	s.cfg.GoogleTokenInfoURL = google.URL
	s.googleHTTP = google.Client()

	resp, start := postJSON(t, ts.URL+"/api/google/start", map[string]string{})
	if resp.StatusCode != http.StatusCreated {
		t.Fatalf("google start: %d %v", resp.StatusCode, start)
	}
	flowID := start["flow_id"].(string)
	loginURL := start["login_url"].(string)
	if !strings.HasPrefix(loginURL, s.cfg.PublicBaseURL+"/auth/google?flow=") {
		t.Fatalf("unexpected browser URL: %q", loginURL)
	}
	for range 12 {
		pending, err := http.Get(ts.URL + "/api/google/poll?flow=" + url.QueryEscape(flowID))
		if err != nil {
			t.Fatal(err)
		}
		pending.Body.Close()
		if pending.StatusCode != http.StatusAccepted {
			t.Fatalf("pending Google poll: %d", pending.StatusCode)
		}
	}

	page, err := http.Get(ts.URL + "/auth/google?flow=" + flowID)
	if err != nil {
		t.Fatal(err)
	}
	pageBody, _ := io.ReadAll(page.Body)
	page.Body.Close()
	if page.StatusCode != http.StatusOK || !strings.Contains(string(pageBody), s.cfg.GoogleClientID) ||
		strings.Contains(string(pageBody), `"token":"`) {
		t.Fatalf("Google page response: %d", page.StatusCode)
	}

	resp, complete := postJSON(t, ts.URL+"/api/google/complete", map[string]string{
		"flow_id": flowID, "credential": "valid-google-token",
	})
	if resp.StatusCode != http.StatusOK || complete["ok"] != true {
		t.Fatalf("google complete: %d %v", resp.StatusCode, complete)
	}

	resp, err = http.Get(ts.URL + "/api/google/poll?flow=" + url.QueryEscape(flowID))
	if err != nil {
		t.Fatal(err)
	}
	var session tokenResponse
	if err := json.NewDecoder(resp.Body).Decode(&session); err != nil {
		resp.Body.Close()
		t.Fatal(err)
	}
	resp.Body.Close()
	if resp.StatusCode != http.StatusOK || session.Email != "google.user@example.com" {
		t.Fatalf("google poll: %d %+v", resp.StatusCode, session)
	}
	claims, err := VerifyJWT(testSecret, session.Token, time.Now())
	if err != nil || claims.Email != session.Email || claims.AccountID != session.AccountID {
		t.Fatalf("invalid game session from Google flow: %+v %v", claims, err)
	}
}

func TestRegisterValidation(t *testing.T) {
	_, ts, _ := newTestServer(t, nil)
	cases := []struct {
		email, pw, code string
	}{
		{"not-an-email", "12345678", "invalid_email"},
		{"a@b", "12345678", "invalid_email"},
		{"Ana <ana@x.com>", "12345678", "invalid_email"},
		{"ok@example.com", "1234567", "weak_password"},
		{"ok@example.com", "        ", "weak_password"},
		{"ok@example.com", strings.Repeat("x", 200), "weak_password"},
	}
	for _, c := range cases {
		resp, out := postJSON(t, ts.URL+"/api/register", map[string]string{"email": c.email, "password": c.pw})
		if resp.StatusCode != http.StatusBadRequest || out["error"] != c.code {
			t.Errorf("%q/%d chars: got %d %v, want %s", c.email, len(c.pw), resp.StatusCode, out, c.code)
		}
	}
	resp, _ := http.Post(ts.URL+"/api/register", "application/json", strings.NewReader(`{"email":1}`))
	if resp.StatusCode != http.StatusBadRequest {
		t.Errorf("bad json: %d", resp.StatusCode)
	}
}

func TestLoginLockoutPerEmail(t *testing.T) {
	_, ts, _ := newTestServer(t, nil)
	postJSON(t, ts.URL+"/api/register", map[string]string{"email": "bia@example.com", "password": "boa-senha-1"})
	var last int
	for i := 0; i < 9; i++ {
		resp, _ := postJSON(t, ts.URL+"/api/login", map[string]string{"email": "bia@example.com", "password": "errada!!"})
		last = resp.StatusCode
	}
	if last != http.StatusTooManyRequests {
		t.Fatalf("expected 429 after repeated failures, got %d", last)
	}
	// Even the right password is refused while locked.
	resp, out := postJSON(t, ts.URL+"/api/login", map[string]string{"email": "bia@example.com", "password": "boa-senha-1"})
	if resp.StatusCode != http.StatusTooManyRequests || resp.Header.Get("Retry-After") == "" {
		t.Fatalf("locked login: %d %v", resp.StatusCode, out)
	}
}

func TestRegisterRateLimitPerIP(t *testing.T) {
	_, ts, _ := newTestServer(t, nil)
	codes := []int{}
	for i := 0; i < 7; i++ {
		resp, _ := postJSON(t, ts.URL+"/api/register", map[string]string{
			"email": "u" + string(rune('a'+i)) + "@example.com", "password": "12345678"})
		codes = append(codes, resp.StatusCode)
	}
	if codes[4] != http.StatusCreated || codes[5] != http.StatusTooManyRequests {
		t.Fatalf("register limit per IP: %v", codes)
	}
}

func TestLatestAndHealth(t *testing.T) {
	s, ts, _ := newTestServer(t, nil)
	resp, err := http.Get(ts.URL + "/api/latest")
	if err != nil || resp.StatusCode != http.StatusNotFound {
		t.Fatalf("latest without file: %v %d", err, resp.StatusCode)
	}
	manifest := `{"version":"0.1.3","files":{"linux":{"name":"Perdidos-0.1.3-linux.zip","sha256":"ab"}}}`
	os.WriteFile(s.cfg.LatestPath, []byte(manifest), 0o644)
	resp, _ = http.Get(ts.URL + "/api/latest")
	body, _ := io.ReadAll(resp.Body)
	if resp.StatusCode != 200 || string(body) != manifest {
		t.Fatalf("latest: %d %s", resp.StatusCode, body)
	}
	resp, _ = http.Get(ts.URL + "/api/health")
	if resp.StatusCode != 200 {
		t.Fatalf("health: %d", resp.StatusCode)
	}
}

// The gatekeeper forwards a WebSocket upgrade (any non-/api path) to the game server.
func TestGameProxyWebSocketUpgrade(t *testing.T) {
	backend := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if !strings.EqualFold(r.Header.Get("Upgrade"), "websocket") {
			http.Error(w, "no upgrade", 400)
			return
		}
		conn, rw, _ := w.(http.Hijacker).Hijack()
		defer conn.Close()
		rw.WriteString("HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n\r\n")
		rw.Flush()
		line, _ := rw.ReadString('\n')
		rw.WriteString("echo:" + line)
		rw.Flush()
	}))
	defer backend.Close()
	u, _ := url.Parse(backend.URL)
	_, ts, _ := newTestServer(t, u)

	addr := strings.TrimPrefix(ts.URL, "http://")
	conn, err := net.Dial("tcp", addr)
	if err != nil {
		t.Fatal(err)
	}
	defer conn.Close()
	conn.SetDeadline(time.Now().Add(5 * time.Second))
	conn.Write([]byte("GET / HTTP/1.1\r\nHost: x\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n" +
		"Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\nSec-WebSocket-Version: 13\r\n\r\n"))
	br := bufio.NewReader(conn)
	resp, err := http.ReadResponse(br, nil)
	if err != nil || resp.StatusCode != http.StatusSwitchingProtocols {
		t.Fatalf("upgrade through proxy: %v %v", err, resp)
	}
	conn.Write([]byte("hello\n"))
	got, _ := br.ReadString('\n')
	if got != "echo:hello\n" {
		t.Fatalf("tunnel data: %q", got)
	}
}

func TestJWT(t *testing.T) {
	now := time.Now()
	tok, _ := SignJWT(testSecret, Claims{AccountID: 7, Email: "x@y.z", Iat: now.Unix(), Exp: now.Add(time.Minute).Unix()})
	if c, err := VerifyJWT(testSecret, tok, now); err != nil || c.AccountID != 7 {
		t.Fatalf("verify: %v %+v", err, c)
	}
	if _, err := VerifyJWT([]byte("other-secret-other-secret-other-secret"), tok, now); err != errTokenSignature {
		t.Fatalf("wrong secret: %v", err)
	}
	if _, err := VerifyJWT(testSecret, tok, now.Add(2*time.Minute)); err != errTokenExpired {
		t.Fatalf("expired: %v", err)
	}
	parts := strings.Split(tok, ".")
	if _, err := VerifyJWT(testSecret, parts[0]+"."+parts[1]+"x."+parts[2], now); err == nil {
		t.Fatal("tampered payload accepted")
	}
}

func TestPasswordHash(t *testing.T) {
	h, err := HashPassword("correct horse")
	if err != nil || !strings.HasPrefix(h, "$argon2id$v=19$m=65536,t=3,p=2$") {
		t.Fatalf("hash: %v %s", err, h)
	}
	if ok, _ := VerifyPassword("correct horse", h); !ok {
		t.Fatal("right password rejected")
	}
	if ok, _ := VerifyPassword("wrong horse", h); ok {
		t.Fatal("wrong password accepted")
	}
	if _, err := VerifyPassword("x", "$2a$10$bcrypt"); err == nil {
		t.Fatal("non-argon2 hash accepted")
	}
}

func TestSecretFileCreatedPrivate(t *testing.T) {
	t.Setenv(SecretKey, "")
	path := filepath.Join(t.TempDir(), "perdidos", "secrets.env")
	s1, created, err := LoadOrCreateSecret(path)
	if err != nil || !created || len(s1) < minSecretLen {
		t.Fatalf("create: %v %v", err, created)
	}
	st, _ := os.Stat(path)
	if st.Mode().Perm() != 0o600 {
		t.Fatalf("mode %v, want 0600", st.Mode().Perm())
	}
	s2, created, err := LoadOrCreateSecret(path)
	if err != nil || created || s2 != s1 {
		t.Fatal("secret not reused")
	}
	t.Setenv(SecretKey, "short")
	if _, _, err := LoadOrCreateSecret(path); err == nil {
		t.Fatal("short env secret accepted")
	}
}

func TestClientIPBehindTunnel(t *testing.T) {
	r := httptest.NewRequest("GET", "/", nil)
	r.RemoteAddr = "127.0.0.1:5000"
	r.Header.Set("X-Forwarded-For", "203.0.113.9, 10.0.0.1")
	if ip := clientIP(r); ip != "203.0.113.9" {
		t.Fatalf("got %s", ip)
	}
	r.RemoteAddr = "198.51.100.2:5000" // not loopback: header is not trusted
	if ip := clientIP(r); ip != "198.51.100.2" {
		t.Fatalf("got %s", ip)
	}
}

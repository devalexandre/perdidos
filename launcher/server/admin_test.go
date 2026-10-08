package main

import (
	"bytes"
	"encoding/json"
	"net/http"
	"os"
	"path/filepath"
	"testing"
	"time"
)

func adminRequest(t *testing.T, method, url string) (*http.Response, map[string]any) {
	t.Helper()
	token, err := SignJWT(testSecret, Claims{AccountID: 1, Email: adminEmail, Iat: time.Now().Unix(),
		Exp: time.Now().Add(time.Hour).Unix(), Iss: jwtIssuer})
	if err != nil {
		t.Fatal(err)
	}
	req, _ := http.NewRequest(method, url, nil)
	req.Header.Set("Authorization", "Bearer "+token)
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	defer resp.Body.Close()
	out := map[string]any{}
	_ = json.NewDecoder(resp.Body).Decode(&out)
	return resp, out
}

func TestAdminRequiresAuthentication(t *testing.T) {
	_, ts, _ := newTestServer(t, nil)
	for _, path := range []string{"/api/admin/me", "/api/admin/overview", "/api/admin/players", "/api/admin/logs"} {
		resp, err := http.Get(ts.URL + path)
		if err != nil {
			t.Fatal(err)
		}
		resp.Body.Close()
		if resp.StatusCode != http.StatusUnauthorized {
			t.Errorf("%s: got %d, want 401", path, resp.StatusCode)
		}
	}
}

func TestAdminPlayersOverviewAndLogs(t *testing.T) {
	s, ts, _ := newTestServer(t, nil)
	dataDir := s.admin.cfg.UserDataDir
	if err := os.MkdirAll(filepath.Join(dataDir, "server_saves"), 0o755); err != nil {
		t.Fatal(err)
	}
	character := `{"name":"Ana","level":7,"stars":321,"hp":88,"home_map":"fields_pindorama","inventory":[{}, {"item":"potion","qty":2}]}`
	if err := os.WriteFile(filepath.Join(dataDir, "server_saves", "ana.json"), []byte(character), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(filepath.Join(dataDir, "server_state"), 0o755); err != nil {
		t.Fatal(err)
	}
	live := `{"online_count":1,"players":[{"name":"Ana","level":7,"stars":321,"hp":88,"max_hp":100,"map":"fields_pindorama","pos":[1,0,2]}],"instances":["fields_pindorama"]}`
	if err := os.WriteFile(filepath.Join(dataDir, "server_state", "live_server.json"), []byte(live), 0o600); err != nil {
		t.Fatal(err)
	}
	_ = os.WriteFile(s.admin.cfg.ServerLog, []byte("game line\n"), 0o600)
	_ = os.WriteFile(s.admin.cfg.AuthLog, []byte("auth line\n"), 0o600)

	resp, players := adminRequest(t, http.MethodGet, ts.URL+"/api/admin/players")
	if resp.StatusCode != http.StatusOK || int(players["total"].(float64)) != 1 {
		t.Fatalf("players: %d %v", resp.StatusCode, players)
	}
	resp, overview := adminRequest(t, http.MethodGet, ts.URL+"/api/admin/overview")
	if resp.StatusCode != http.StatusOK || int(overview["online_count"].(float64)) != 1 || len(overview["players"].([]any)) != 1 {
		t.Fatalf("overview: %d %v", resp.StatusCode, overview)
	}
	resp, logs := adminRequest(t, http.MethodGet, ts.URL+"/api/admin/logs")
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("logs: %d %v", resp.StatusCode, logs)
	}
	lines := logs["logs"].([]any)
	if len(lines) < 5 || lines[1] != "game line" || lines[len(lines)-1] != "auth line" {
		t.Fatalf("combined logs missing: %v", lines)
	}
}

func TestAdminCreatesEvent(t *testing.T) {
	s, ts, _ := newTestServer(t, nil)
	token, _ := SignJWT(testSecret, Claims{AccountID: 1, Email: adminEmail, Iat: time.Now().Unix(),
		Exp: time.Now().Add(time.Hour).Unix(), Iss: jwtIssuer})
	body := []byte(`{"name":"Festival das Águas","description":"Chuva e bônus","xp_mult":1.5,"drop_mult":2,"active":true,"announcement":"O festival começou!"}`)
	req, _ := http.NewRequest(http.MethodPost, ts.URL+"/api/admin/events/create", bytes.NewReader(body))
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("Content-Type", "application/json")
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	defer resp.Body.Close()
	var out map[string]any
	_ = json.NewDecoder(resp.Body).Decode(&out)
	if resp.StatusCode != http.StatusOK || out["ok"] != true {
		t.Fatalf("create event: %d %v", resp.StatusCode, out)
	}
	created := out["event"].(map[string]any)
	if created["name"] != "Festival das Águas" || created["active"] != true {
		t.Fatalf("created event mismatch: %v", created)
	}
	cfg := s.admin.loadEventsConfig()
	if cfg.Events[created["id"].(string)].Name != "Festival das Águas" || cfg.BroadcastMessage != "O festival começou!" {
		t.Fatalf("event not persisted correctly: %+v", cfg)
	}
}

func TestEventCatalogMigrationAddsNewContentInactive(t *testing.T) {
	s, _, _ := newTestServer(t, nil)
	cfg := s.admin.loadEventsConfig()
	for _, id := range []string{"carnaval_das_aguas", "festival_mouras", "hanami_sol", "solsticio_fiordes", "lanternas_jade"} {
		event, ok := cfg.Events[id]
		if !ok {
			t.Fatalf("evento de catálogo ausente: %s", id)
		}
		if event.Active {
			t.Fatalf("evento novo deve entrar inativo: %s", id)
		}
		for _, cosmetic := range event.Cosmetics {
			if cfg.ActiveCosmetics[cosmetic] {
				t.Fatalf("cosmético novo deve entrar inativo: %s", cosmetic)
			}
		}
	}
}

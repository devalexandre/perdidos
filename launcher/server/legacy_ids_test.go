package main

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
)

// Renomeação da nação para Pindorama: o active_events.json antigo é migrado ao subir o painel (idempotente).
func TestLegacyEventsFileMigration(t *testing.T) {
	dir := t.TempDir()
	file := filepath.Join(dir, "server_state", "active_events.json")
	_ = os.MkdirAll(filepath.Dir(file), 0o755)
	old := `{"events":{"semana_independencia":{"id":"semana_independencia","name":"Semana","region":"Terra do Sabiá",
		"cosmetics":["cosmetic_lenco_verde_ouro","cosmetic_broche_sabia"],"active":true}},
		"active_decorations":{},"active_cosmetics":{"cosmetic_broche_sabia":true,"straw_hat":false},"updated_at":1}`
	if err := os.WriteFile(file, []byte(old), 0o644); err != nil {
		t.Fatal(err)
	}
	as := &AdminServer{activeEventsFile: file}
	for i := 0; i < 2; i++ { // duas vezes: a segunda não muda nada
		as.migrateLegacyEventsFile()
	}
	var cfg ActiveEventsConfig
	data, _ := os.ReadFile(file)
	if err := json.Unmarshal(data, &cfg); err != nil {
		t.Fatal(err)
	}
	ev := cfg.Events["semana_independencia"]
	if ev.Region != "Terra de Pindorama" || ev.Cosmetics[1] != "cosmetic_broche_pindorama" || !ev.Active {
		t.Fatalf("evento não migrado: %+v", ev)
	}
	if _, stale := cfg.ActiveCosmetics["cosmetic_broche_sabia"]; stale || !cfg.ActiveCosmetics["cosmetic_broche_pindorama"] {
		t.Fatalf("cosméticos ativos não migrados: %v", cfg.ActiveCosmetics)
	}
	for in, want := range map[string]string{"fields_sabia": "fields_pindorama", "fields_pindorama": "fields_pindorama",
		"waystone:fields_sabia_buriti": "waystone:fields_pindorama_buriti", "city_awakening": "city_awakening", "Sabia": "Sabia"} {
		if got := migrateLegacyID(in); got != want {
			t.Errorf("migrateLegacyID(%q) = %q, want %q", in, got, want)
		}
	}
}

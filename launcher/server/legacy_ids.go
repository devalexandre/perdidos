package main

import (
	"encoding/json"
	"os"
	"regexp"
	"strings"
)

// Renomeação da nação "Sabiá" para "Pindorama" (08/10/2026; docs/mundo/renomeacao-pindorama.md).
// Espelha game/scripts/shared/legacy_ids.gd para o que o painel lê ou grava: active_events.json
// (região, cosméticos) e o mapa dos personagens na lista. Idempotente.

// legacyIDs: ids antigos -> novos usados pelo painel. Ids fora da tabela com o segmento "sabia"
// também trocam (migrateLegacyID).
var legacyIDs = map[string]string{
	"sabia":                   "pindorama",
	"fields_sabia":            "fields_pindorama",
	"fields_sabia_buriti":     "fields_pindorama_buriti",
	"fields_sabia_crossroads": "fields_pindorama_crossroads",
	"cosmetic_broche_sabia":   "cosmetic_broche_pindorama",
}

// legacyTexts: nomes visíveis antigos -> novos (região dos eventos e textos livres do painel).
var legacyTexts = [][2]string{
	{"Terra do Sabiá", "Terra de Pindorama"},
	{"Campos do Sabiá", "Campos de Pindorama"},
}

var legacyIDShape = regexp.MustCompile(`^[a-z0-9_:]+$`)

func migrateLegacyID(s string) string {
	if !strings.Contains(s, "sabia") {
		return s
	}
	if v, ok := legacyIDs[s]; ok {
		return v
	}
	if !legacyIDShape.MatchString(s) {
		return s
	}
	parts := strings.Split(s, ":")
	for i, p := range parts {
		if v, ok := legacyIDs[p]; ok {
			parts[i] = v
			continue
		}
		seg := strings.Split(p, "_")
		for j := range seg {
			if seg[j] == "sabia" {
				seg[j] = "pindorama"
			}
		}
		parts[i] = strings.Join(seg, "_")
	}
	return strings.Join(parts, ":")
}

func migrateLegacyText(s string) string {
	for _, r := range legacyTexts {
		s = strings.ReplaceAll(s, r[0], r[1])
	}
	return s
}

// migrateEventsConfig troca ids e nomes antigos na configuração de eventos. Devolve true se mudou algo.
func migrateEventsConfig(cfg *ActiveEventsConfig) bool {
	changed := false
	str := func(p *string, f func(string) string) {
		if n := f(*p); n != *p {
			*p = n
			changed = true
		}
	}
	for id, ev := range cfg.Events {
		str(&ev.Region, migrateLegacyText)
		str(&ev.Name, migrateLegacyText)
		str(&ev.Description, migrateLegacyText)
		str(&ev.Announcement, migrateLegacyText)
		str(&ev.VisualChange, migrateLegacyText)
		for i := range ev.Cosmetics {
			str(&ev.Cosmetics[i], migrateLegacyID)
		}
		for i := range ev.Decorations {
			str(&ev.Decorations[i], migrateLegacyID)
		}
		cfg.Events[id] = ev
	}
	for _, m := range []map[string]bool{cfg.ActiveCosmetics, cfg.ActiveDecorations} {
		for k, v := range m {
			if n := migrateLegacyID(k); n != k {
				delete(m, k)
				m[n] = m[n] || v
				changed = true
			}
		}
	}
	return changed
}

// migrateLegacyEventsFile regrava o active_events.json no formato novo, uma vez, ao subir o painel.
func (as *AdminServer) migrateLegacyEventsFile() {
	data, err := os.ReadFile(as.activeEventsFile)
	if err != nil {
		return
	}
	var cfg ActiveEventsConfig
	if json.Unmarshal(data, &cfg) != nil || !migrateEventsConfig(&cfg) {
		return
	}
	if out, err := json.MarshalIndent(cfg, "", "  "); err == nil {
		_ = os.WriteFile(as.activeEventsFile, out, 0o644)
	}
}

package main

import (
	"encoding/csv"
	"encoding/json"
	"fmt"
	"image"
	_ "image/jpeg"
	_ "image/png"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strconv"
	"strings"
)

const maxItemIconBytes = 2 << 20

var itemIDPattern = regexp.MustCompile(`^[a-z][a-z0-9_]{2,63}$`)

type adminItem struct {
	ID, Name, Description, Type, Rarity, WeaponKind, Icon string
	BuyPrice, SellPrice, MaxStack                         int
	Stackable, Tradeable, TwoHanded, IsCosmetic           bool
	Stats, StatPercent, UseEffect                         map[string]int
}

type adminDrop struct {
	ItemID string `json:"item_id"`
	MonsterID string `json:"monster_id"`
	Stage int `json:"stage"`
	Chance float64 `json:"chance"`
	MinQty int `json:"min_qty"`
	MaxQty int `json:"max_qty"`
}

var itemTypes = []string{"CONSUMABLE", "WEAPON", "OFFHAND", "HEAD", "BODY", "FEET", "ACCESSORY", "MATERIAL", "GLOVES", "CRENDICE"}
var itemRarities = []string{"COMMON", "UNCOMMON", "RARE", "EPIC"}
var weaponKinds = []string{"NONE", "BLADE", "ARCANE", "BOW"}

func findGameDir() string {
	wd, _ := os.Getwd()
	for dir := wd; ; dir = filepath.Dir(dir) {
		candidate := filepath.Join(dir, "game")
		if _, err := os.Stat(filepath.Join(candidate, "project.godot")); err == nil {
			return candidate
		}
		parent := filepath.Dir(dir)
		if parent == dir {
			break
		}
	}
	return "game"
}

func (as *AdminServer) handleItems(w http.ResponseWriter, _ *http.Request) {
	itemsDir := filepath.Join(as.gameDir, "data", "items")
	entries, err := os.ReadDir(itemsDir)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "catálogo de itens indisponível"})
		return
	}
	names := loadItemTranslations(filepath.Join(as.gameDir, "localization", "content.csv"))
	items := make([]adminItem, 0, len(entries))
	for _, entry := range entries {
		if entry.IsDir() || filepath.Ext(entry.Name()) != ".tres" {
			continue
		}
		data, err := os.ReadFile(filepath.Join(itemsDir, entry.Name()))
		if err != nil {
			continue
		}
		text := string(data)
		id := tresString(text, "id")
		if id == "" {
			id = strings.TrimSuffix(entry.Name(), ".tres")
		}
		typeIndex := tresInt(text, "type", 7)
		rarityIndex := tresInt(text, "rarity", 0)
		kindIndex := tresInt(text, "weapon_kind", 0)
		item := adminItem{ID: id, Name: names[tresQuoted(text, "name_key")], Description: names[tresQuoted(text, "desc_key")], Type: enumAt(itemTypes, typeIndex), Rarity: enumAt(itemRarities, rarityIndex), WeaponKind: enumAt(weaponKinds, kindIndex), BuyPrice: tresInt(text, "buy_price", 0), SellPrice: tresInt(text, "sell_price", 0), MaxStack: tresInt(text, "max_stack", 1), Stackable: tresBool(text, "stackable", false), Tradeable: tresBool(text, "tradeable", true), TwoHanded: tresBool(text, "two_handed", false), IsCosmetic: tresBool(text, "is_cosmetic", false)}
		item.Stats = tresIntMap(text, "stats")
		item.StatPercent = tresIntMap(text, "stat_percent")
		item.UseEffect = tresIntMap(text, "use_effect")
		if item.Name == "" {
			item.Name = id
		}
		items = append(items, item)
	}
	sort.Slice(items, func(i, j int) bool { return items[i].ID < items[j].ID })
	writeJSON(w, http.StatusOK, map[string]any{"items": items, "total": len(items), "monsters": listMonsterIDs(filepath.Join(as.gameDir, "data", "monsters")), "drops": as.loadAdminDrops()})
}

func (as *AdminServer) handleItemCreate(w http.ResponseWriter, r *http.Request) {
	r.Body = http.MaxBytesReader(w, r.Body, maxItemIconBytes+128<<10)
	if err := r.ParseMultipartForm(maxItemIconBytes + 64<<10); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "formulário ou imagem grande demais (máximo 2 MB)"})
		return
	}
	id := strings.TrimSpace(r.FormValue("id"))
	if !itemIDPattern.MatchString(id) {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "ID inválido: use 3–64 caracteres minúsculos, números e _"})
		return
	}
	typeIndex := enumIndex(itemTypes, r.FormValue("type"))
	rarityIndex := enumIndex(itemRarities, r.FormValue("rarity"))
	kindIndex := enumIndex(weaponKinds, r.FormValue("weapon_kind"))
	if typeIndex < 0 || rarityIndex < 0 || kindIndex < 0 {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "tipo, raridade ou classe da arma inválidos"})
		return
	}
	name, desc := strings.TrimSpace(r.FormValue("name")), strings.TrimSpace(r.FormValue("description"))
	if name == "" || desc == "" {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "nome e descrição são obrigatórios"})
		return
	}
	buy, ok1 := formNonNegativeInt(r.FormValue("buy_price"))
	sell, ok2 := formNonNegativeInt(r.FormValue("sell_price"))
	maxStack, ok3 := formNonNegativeInt(r.FormValue("max_stack"))
	if !ok1 || !ok2 || !ok3 || maxStack < 1 || maxStack > 999 {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "preços e pilha devem ser números válidos"})
		return
	}
	stats, err := parseIntMap(r.FormValue("stats"))
	if err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "atributos inválidos; use JSON, por exemplo {\"atk\": 10}"})
		return
	}
	effects, err := parseIntMap(r.FormValue("use_effect"))
	if err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "efeitos inválidos; use JSON, por exemplo {\"heal_hp\": 60}"})
		return
	}
	percent, err := parseIntMap(r.FormValue("stat_percent"))
	if err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "percentuais inválidos; use JSON, por exemplo {\"atk\": 10}"})
		return
	}
	itemsDir, iconsDir := filepath.Join(as.gameDir, "data", "items"), filepath.Join(as.gameDir, "assets", "items", "icons")
	itemPath := filepath.Join(itemsDir, id+".tres")
	if _, err := os.Stat(itemPath); err == nil {
		writeJSON(w, http.StatusConflict, map[string]string{"error": "já existe um item com esse ID"})
		return
	}
	file, header, err := r.FormFile("icon")
	if err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "selecione um ícone PNG ou JPEG"})
		return
	}
	defer file.Close()
	config, format, err := image.DecodeConfig(io.LimitReader(file, maxItemIconBytes))
	if err != nil || (format != "png" && format != "jpeg") || config.Width < 1 || config.Height < 1 || config.Width > 2048 || config.Height > 2048 {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "ícone inválido; envie PNG/JPEG de até 2048×2048 e 2 MB"})
		return
	}
	if _, err = file.Seek(0, io.SeekStart); err != nil {
		writeJSON(w, 500, map[string]string{"error": "falha ao processar ícone"})
		return
	}
	ext := ".png"
	if format == "jpeg" {
		ext = ".jpg"
	}
	_ = header
	iconName := "icon_item_" + id + ext
	iconPath := filepath.Join(iconsDir, iconName)
	if err = os.MkdirAll(iconsDir, 0o755); err != nil {
		writeJSON(w, 500, map[string]string{"error": "não foi possível preparar a pasta de ícones"})
		return
	}
	out, err := os.OpenFile(iconPath, os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0o644)
	if err != nil {
		writeJSON(w, 500, map[string]string{"error": "não foi possível salvar o ícone"})
		return
	}
	_, copyErr := io.Copy(out, io.LimitReader(file, maxItemIconBytes+1))
	closeErr := out.Close()
	if copyErr != nil || closeErr != nil {
		_ = os.Remove(iconPath)
		writeJSON(w, 500, map[string]string{"error": "não foi possível salvar o ícone"})
		return
	}
	item := adminItem{ID: id, Name: name, Description: desc, Type: itemTypes[typeIndex], Rarity: itemRarities[rarityIndex], WeaponKind: weaponKinds[kindIndex], BuyPrice: buy, SellPrice: sell, MaxStack: maxStack, Stackable: r.FormValue("stackable") == "true", Tradeable: r.FormValue("tradeable") == "true", TwoHanded: r.FormValue("two_handed") == "true", IsCosmetic: r.FormValue("is_cosmetic") == "true", Stats: stats, StatPercent: percent, UseEffect: effects}
	if err = os.WriteFile(itemPath, []byte(renderItemTRES(item, iconName, typeIndex, rarityIndex, kindIndex)), 0o644); err != nil {
		_ = os.Remove(iconPath)
		writeJSON(w, 500, map[string]string{"error": "não foi possível gravar a definição"})
		return
	}
	if err = appendItemTranslations(filepath.Join(as.gameDir, "localization", "content.csv"), id, name, desc); err != nil {
		_ = os.Remove(itemPath)
		_ = os.Remove(iconPath)
		writeJSON(w, 500, map[string]string{"error": "não foi possível gravar as traduções"})
		return
	}
	if err = as.addItemDropFromForm(r, id); err != nil {
		_ = os.Remove(itemPath)
		_ = os.Remove(iconPath)
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": err.Error()})
		return
	}
	writeJSON(w, http.StatusCreated, map[string]any{"ok": true, "item": item, "message": "Item criado. Reinicie o jogo/servidor para carregar o novo conteúdo."})
}

func renderItemTRES(i adminItem, icon string, typ, rarity, kind int) string {
	upper := strings.ToUpper(i.ID)
	b := &strings.Builder{}
	fmt.Fprintf(b, "[gd_resource type=\"Resource\" script_class=\"ItemDef\" format=3]\n\n[ext_resource type=\"Texture2D\" path=\"res://assets/items/icons/%s\" id=\"icon\"]\n[ext_resource type=\"Script\" path=\"res://scripts/shared/data/item_def.gd\" id=\"item\"]\n\n[resource]\nscript = ExtResource(\"item\")\nid = &\"%s\"\nname_key = \"ITEM_%s_NAME\"\ndesc_key = \"ITEM_%s_DESC\"\nicon = ExtResource(\"icon\")\ntype = %d\nweapon_kind = %d\nrarity = %d\nstackable = %t\nmax_stack = %d\nbuy_price = %d\nsell_price = %d\ntradeable = %t\ntwo_handed = %t\nis_cosmetic = %t\n", icon, i.ID, upper, upper, typ, kind, rarity, i.Stackable, i.MaxStack, i.BuyPrice, i.SellPrice, i.Tradeable, i.TwoHanded, i.IsCosmetic)
	writeTresMap(b, "stats", i.Stats)
	writeTresMap(b, "stat_percent", i.StatPercent)
	writeTresMap(b, "use_effect", i.UseEffect)
	return b.String()
}

func writeTresMap(b *strings.Builder, name string, values map[string]int) {
	if len(values) == 0 {
		return
	}
	keys := make([]string, 0, len(values))
	for k := range values {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	fmt.Fprintf(b, "%s = Dictionary[StringName, int]({\n", name)
	for n, k := range keys {
		if n > 0 {
			b.WriteString(",\n")
		}
		fmt.Fprintf(b, "&\"%s\": %d", k, values[k])
	}
	b.WriteString("\n})\n")
}
func parseIntMap(raw string) (map[string]int, error) {
	out := map[string]int{}
	if strings.TrimSpace(raw) == "" {
		return out, nil
	}
	err := json.Unmarshal([]byte(raw), &out)
	for k, v := range out {
		if !itemIDPattern.MatchString("a_"+k) || v < -99999 || v > 99999 {
			return nil, fmt.Errorf("invalid")
		}
	}
	return out, err
}
func formNonNegativeInt(v string) (int, bool) { n, e := strconv.Atoi(v); return n, e == nil && n >= 0 }
func enumIndex(values []string, v string) int {
	v = strings.ToUpper(v)
	for i, x := range values {
		if x == v {
			return i
		}
	}
	return -1
}
func enumAt(values []string, i int) string {
	if i < 0 || i >= len(values) {
		return values[0]
	}
	return values[i]
}
func tresQuoted(text, key string) string {
	re := regexp.MustCompile(`(?m)^` + regexp.QuoteMeta(key) + ` = \"([^\"]*)\"`)
	m := re.FindStringSubmatch(text)
	if len(m) > 1 {
		return m[1]
	}
	return ""
}
func tresString(text, key string) string {
	re := regexp.MustCompile(`(?m)^` + regexp.QuoteMeta(key) + ` = &\"([^\"]*)\"`)
	m := re.FindStringSubmatch(text)
	if len(m) > 1 {
		return m[1]
	}
	return ""
}
func tresInt(text, key string, def int) int {
	re := regexp.MustCompile(`(?m)^` + regexp.QuoteMeta(key) + ` = (-?\d+)`)
	m := re.FindStringSubmatch(text)
	if len(m) > 1 {
		if n, e := strconv.Atoi(m[1]); e == nil {
			return n
		}
	}
	return def
}
func tresBool(text, key string, def bool) bool {
	re := regexp.MustCompile(`(?m)^` + regexp.QuoteMeta(key) + ` = (true|false)`)
	m := re.FindStringSubmatch(text)
	if len(m) > 1 {
		return m[1] == "true"
	}
	return def
}
func tresIntMap(text, key string) map[string]int {
	out := map[string]int{}
	block := regexp.MustCompile(`(?s)` + regexp.QuoteMeta(key) + ` = Dictionary[^\{]*\{(.*?)\n\}\)`).FindStringSubmatch(text)
	if len(block) < 2 {
		return out
	}
	pairs := regexp.MustCompile(`&\"([a-z0-9_]+)\":\s*(-?\d+)`).FindAllStringSubmatch(block[1], -1)
	for _, pair := range pairs {
		value, _ := strconv.Atoi(pair[2])
		out[pair[1]] = value
	}
	return out
}
func loadItemTranslations(path string) map[string]string {
	out := map[string]string{}
	f, e := os.Open(path)
	if e != nil {
		return out
	}
	defer f.Close()
	rows, e := csv.NewReader(f).ReadAll()
	if e != nil {
		return out
	}
	for _, r := range rows {
		if len(r) > 1 {
			out[r[0]] = r[1]
		}
	}
	return out
}
func appendItemTranslations(path, id, name, desc string) error {
	f, e := os.OpenFile(path, os.O_APPEND|os.O_WRONLY, 0o644)
	if e != nil {
		return e
	}
	defer f.Close()
	w := csv.NewWriter(f)
	upper := strings.ToUpper(id)
	if e = w.Write([]string{"ITEM_" + upper + "_NAME", name}); e != nil {
		return e
	}
	if e = w.Write([]string{"ITEM_" + upper + "_DESC", desc}); e != nil {
		return e
	}
	w.Flush()
	return w.Error()
}

func listMonsterIDs(dir string) []string {
	entries, _ := os.ReadDir(dir)
	out := []string{}
	for _, entry := range entries {
		if !entry.IsDir() && filepath.Ext(entry.Name()) == ".tres" {
			out = append(out, strings.TrimSuffix(entry.Name(), ".tres"))
		}
	}
	sort.Strings(out)
	return out
}

func containsString(values []string, wanted string) bool {
	for _, value := range values { if value == wanted { return true } }
	return false
}

func (as *AdminServer) loadAdminDrops() []adminDrop {
	as.mu.RLock()
	defer as.mu.RUnlock()
	var drops []adminDrop
	if data, err := os.ReadFile(as.itemDropsFile); err == nil { _ = json.Unmarshal(data, &drops) }
	return drops
}

func (as *AdminServer) saveAdminDrops(drops []adminDrop) error {
	as.mu.Lock()
	defer as.mu.Unlock()
	data, err := json.MarshalIndent(drops, "", "  ")
	if err != nil { return err }
	if err = os.MkdirAll(filepath.Dir(as.itemDropsFile), 0o755); err != nil { return err }
	return os.WriteFile(as.itemDropsFile, data, 0o644)
}

func (as *AdminServer) addItemDropFromForm(r *http.Request, itemID string) error {
	monsterID := strings.TrimSpace(r.FormValue("drop_monster"))
	if monsterID == "" { return nil }
	stage, okStage := formNonNegativeInt(r.FormValue("drop_stage"))
	chance, chanceErr := strconv.ParseFloat(r.FormValue("drop_chance"), 64)
	minQty, okMin := formNonNegativeInt(r.FormValue("drop_min_qty"))
	maxQty, okMax := formNonNegativeInt(r.FormValue("drop_max_qty"))
	if !containsString(listMonsterIDs(filepath.Join(as.gameDir, "data", "monsters")), monsterID) { return fmt.Errorf("criatura de drop inválida") }
	if !okStage || stage < 1 || stage > 4 || chanceErr != nil || chance <= 0 || chance > 100 || !okMin || !okMax || minQty < 1 || maxQty < minQty { return fmt.Errorf("estágio, chance ou quantidade do drop inválidos") }
	drops := as.loadAdminDrops()
	drops = append(drops, adminDrop{ItemID:itemID, MonsterID:monsterID, Stage:stage, Chance:chance/100.0, MinQty:minQty, MaxQty:maxQty})
	if err := as.saveAdminDrops(drops); err != nil { return fmt.Errorf("não foi possível salvar o drop") }
	return nil
}

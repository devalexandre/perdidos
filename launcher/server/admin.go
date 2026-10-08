package main

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"sync"
	"time"
)

const adminEmail = "progsphp@gmail.com"

// AdminConfig holds paths and settings for admin management.
type AdminConfig struct {
	UserDataDir string
	ServerLog   string
	AuthLog     string
	Secret      []byte
	GameDir     string
}

type AdminServer struct {
	cfg   AdminConfig
	store Store
	log   *slog.Logger
	mu    sync.RWMutex

	activeEventsFile string
	liveServerFile   string
	serverSavesDir   string
	ownersFile       string
	gameDir          string
	itemDropsFile    string
}

func NewAdminServer(cfg AdminConfig, store Store, log *slog.Logger) *AdminServer {
	if cfg.UserDataDir == "" {
		home, _ := os.UserHomeDir()
		cfg.UserDataDir = filepath.Join(home, ".local/share/godot/app_userdata/Perdidos")
	}
	if cfg.ServerLog == "" {
		cfg.ServerLog = ".run/server.log"
	}
	if cfg.AuthLog == "" {
		cfg.AuthLog = ".run/auth.log"
	}
	if cfg.GameDir == "" {
		cfg.GameDir = findGameDir()
	}
	as := &AdminServer{
		cfg:              cfg,
		store:            store,
		log:              log,
		activeEventsFile: filepath.Join(cfg.UserDataDir, "server_state", "active_events.json"),
		liveServerFile:   filepath.Join(cfg.UserDataDir, "server_state", "live_server.json"),
		serverSavesDir:   filepath.Join(cfg.UserDataDir, "server_saves"),
		ownersFile:       filepath.Join(cfg.UserDataDir, "server_saves", "character_owners.json"),
		gameDir:          cfg.GameDir,
		itemDropsFile:    filepath.Join(cfg.UserDataDir, "server_state", "custom_item_drops.json"),
	}
	as.ensureDefaultEventsFile()
	as.migrateLegacyEventsFile()
	return as
}

// EventItem represents an event template or custom event.
type EventItem struct {
	ID           string   `json:"id"`
	Name         string   `json:"name"`
	Description  string   `json:"description"`
	Icon         string   `json:"icon"`
	Active       bool     `json:"active"`
	XpMult       float64  `json:"xp_mult"`
	DropMult     float64  `json:"drop_mult"`
	Decorations  []string `json:"decorations"`
	Cosmetics    []string `json:"cosmetics"`
	Announcement string   `json:"announcement"`
	Region       string   `json:"region,omitempty"`
	Countries    []string `json:"countries,omitempty"`
	Period       string   `json:"period,omitempty"`
	VisualChange string   `json:"visual_change,omitempty"`
}

type ActiveEventsConfig struct {
	Events            map[string]EventItem `json:"events"`
	ActiveDecorations map[string]bool      `json:"active_decorations"`
	ActiveCosmetics   map[string]bool      `json:"active_cosmetics"`
	BroadcastMessage  string               `json:"broadcast_message,omitempty"`
	UpdatedAt         int64                `json:"updated_at"`
}

func (as *AdminServer) ensureDefaultEventsFile() {
	_ = os.MkdirAll(filepath.Dir(as.activeEventsFile), 0o755)
	if _, err := os.Stat(as.activeEventsFile); err == nil {
		return
	}

	defaults := ActiveEventsConfig{
		Events: map[string]EventItem{
			"festa_junina": {
				ID:           "festa_junina",
				Name:         "Festa Junina & São João",
				Description:  "Bandeirolas nos portos e cidades, fogueira festiva, bônus de XP de culinária e monstros.",
				Icon:         "🌽",
				Active:       false,
				XpMult:       1.5,
				DropMult:     1.5,
				Decorations:  []string{"bandeirinhas_juninas", "fogueira_festiva"},
				Cosmetics:    []string{"straw_hat", "cosmetic_traje_caipira"},
				Announcement: "🔥 O Arraiá de Perdidos começou! Bônus de 50% de XP e Drops em todos os mapas!",
				Region:       "Terra de Pindorama", Countries: []string{"Brasil"}, Period: "Junho",
				VisualChange: "Bandeirinhas, fogueira comunitária e barracas de comidas típicas nas praças.",
			},
			"dia_folclore": {
				ID:           "dia_folclore",
				Name:         "Semana do Folclore Brasileiro",
				Description:  "Homenagem às lendas de Pindorama: bênção do Saci e proteção do Curupira contra criaturas das matas.",
				Icon:         "🌪️",
				Active:       false,
				XpMult:       1.5,
				DropMult:     2.0,
				Decorations:  []string{"lanternas_folcloricas", "totem_curupira"},
				Cosmetics:    []string{"red_cap", "cosmetic_bumbah_mask"},
				Announcement: "🌿 A magia dos encantos acordou! Semana do Folclore com 2x Drops de essências mágicas!",
				Region:       "Terra de Pindorama", Countries: []string{"Brasil"}, Period: "22 de agosto",
				VisualChange: "Lanternas, redemoinhos de folhas e totens protetores nas trilhas da mata.",
			},
			"florada_ipes": {
				ID:           "florada_ipes",
				Name:         "Primavera dos Ipês Dourados",
				Description:  "A floração mágica dos ipês espalha pétalas douradas e bênçãos de vitalidade por todo o arquipélago.",
				Icon:         "🌸",
				Active:       false,
				XpMult:       1.25,
				DropMult:     1.5,
				Decorations:  []string{"petalas_ipe", "arcos_florais"},
				Cosmetics:    []string{"ipe_flower_crown", "ipe_circlet"},
				Announcement: "🌸 As flores de Ipê cobrem os caminhos! Bênção da Primavera ativada!",
				Region:       "Terra de Pindorama", Countries: []string{"Brasil"}, Period: "Agosto a setembro",
				VisualChange: "Ipês floridos, arcos florais e chuva suave de pétalas nas vilas.",
			},
			"lua_lobisomem": {
				ID:           "lua_lobisomem",
				Name:         "Noite da Lua Cheia & O Uivo do Atroz",
				Description:  "A maldição de Guimarães atinge seu ápice! Criaturas atrozes rondam as fronteiras nas noites.",
				Icon:         "🐺",
				Active:       false,
				XpMult:       2.0,
				DropMult:     1.5,
				Decorations:  []string{"tochas_misticas", "neblina_estelar"},
				Cosmetics:    []string{"silver_moon_circlet", "silver_hunter_hat"},
				Announcement: "🌕 A Lua Cheia se ergue no horizonte! Noites com 2x XP e perigos redobrados!",
				Region:       "Reino das Mouras", Countries: []string{"Portugal"}, Period: "Noites de lua cheia",
				VisualChange: "Lua ampliada, neblina estelar e tochas azuis nas estradas do reino.",
			},
			"natal_tropical": {
				ID:           "natal_tropical",
				Name:         "Celebração Festiva de Fim de Ano",
				Description:  "Luzes cintilantes nos telhados coloniais, presentes misteriosos pelo chão e Estrelas em dobro.",
				Icon:         "✨",
				Active:       false,
				XpMult:       1.5,
				DropMult:     2.0,
				Decorations:  []string{"luzes_festivas", "arvore_enfeitada"},
				Cosmetics:    []string{"cosmetic_golden_sash", "cosmetic_gorro_festivo"},
				Announcement: "✨ Boas Festas em Perdidos! Estrelas e drops em dobro para todos os viajantes!",
				Region:       "Global", Countries: []string{"Brasil", "Portugal e demais nações"}, Period: "Dezembro",
				VisualChange: "Luzes quentes, árvores ornamentadas e presentes cenográficos nas cidades.",
			},
		},
		ActiveDecorations: map[string]bool{
			"petalas_ipe":           false,
			"bandeirinhas_juninas":  false,
			"fogueira_festiva":      false,
			"lanternas_folcloricas": false,
			"tochas_misticas":       false,
			"luzes_festivas":        false,
		},
		ActiveCosmetics: map[string]bool{
			"ipe_flower_crown":    false,
			"straw_hat":           false,
			"red_cap":             false,
			"silver_moon_circlet": false,
			"silver_hunter_hat":   false,
		},
		UpdatedAt: time.Now().Unix(),
	}

	data, err := json.MarshalIndent(defaults, "", "  ")
	if err == nil {
		_ = os.WriteFile(as.activeEventsFile, data, 0o644)
	}
}

func (as *AdminServer) loadEventsConfig() ActiveEventsConfig {
	as.mu.RLock()
	defer as.mu.RUnlock()

	var cfg ActiveEventsConfig
	data, err := os.ReadFile(as.activeEventsFile)
	if err != nil {
		return cfg
	}
	_ = json.Unmarshal(data, &cfg)
	migrateEventsConfig(&cfg) // ids/nomes renomeados (legacy_ids.go)
	if cfg.Events == nil {
		cfg.Events = map[string]EventItem{}
	}
	if cfg.ActiveDecorations == nil {
		cfg.ActiveDecorations = map[string]bool{}
	}
	if cfg.ActiveCosmetics == nil {
		cfg.ActiveCosmetics = map[string]bool{}
	}
	// A configuração é persistente. Acrescenta modelos lançados em versões novas sem alterar
	// escolhas já feitas pelo administrador; todos entram inativos.
	for id, event := range additionalEventCatalog() {
		if _, exists := cfg.Events[id]; !exists {
			cfg.Events[id] = event
		}
		for _, decoration := range event.Decorations {
			if _, exists := cfg.ActiveDecorations[decoration]; !exists {
				cfg.ActiveDecorations[decoration] = false
			}
		}
		for _, cosmetic := range event.Cosmetics {
			if _, exists := cfg.ActiveCosmetics[cosmetic]; !exists {
				cfg.ActiveCosmetics[cosmetic] = false
			}
		}
	}
	// Também registra itens de eventos antigos que ainda não existiam nos mapas de ativação.
	for _, event := range cfg.Events {
		for _, decoration := range event.Decorations {
			if _, exists := cfg.ActiveDecorations[decoration]; !exists {
				cfg.ActiveDecorations[decoration] = false
			}
		}
		for _, cosmetic := range event.Cosmetics {
			if _, exists := cfg.ActiveCosmetics[cosmetic]; !exists {
				cfg.ActiveCosmetics[cosmetic] = false
			}
		}
	}
	return cfg
}

func additionalEventCatalog() map[string]EventItem {
	return map[string]EventItem{
		"carnaval_das_aguas":   {ID: "carnaval_das_aguas", Name: "Carnaval das Águas", Icon: "🎭", Region: "Terra de Pindorama", Countries: []string{"Brasil"}, Period: "Fevereiro ou março", Active: false, XpMult: 1.25, DropMult: 1.25, Description: "Cortejo comunitário no Porto, com música, fitas e barcos ornamentados.", Decorations: []string{"fitas_carnaval", "barcos_festivos", "confetes_folhas"}, Cosmetics: []string{"cosmetic_mascara_carnaval", "cosmetic_capa_fitas"}, VisualChange: "Fitas nas ruas, barcos coloridos e folhas de papel biodegradável; sem caricaturas culturais.", Announcement: "🎭 O Carnaval das Águas chegou ao Porto do Despertar!"},
		"semana_independencia": {ID: "semana_independencia", Name: "Semana dos Caminhos Livres", Icon: "🟢", Region: "Terra de Pindorama", Countries: []string{"Brasil"}, Period: "7 de setembro", Active: false, XpMult: 1.15, DropMult: 1.15, Description: "Celebra a autonomia das comunidades e os caminhos abertos pelos Viajantes.", Decorations: []string{"estandartes_verde_ouro", "flores_caminhos"}, Cosmetics: []string{"cosmetic_lenco_verde_ouro", "cosmetic_broche_pindorama"}, VisualChange: "Estandartes verdes e dourados e canteiros floridos nas entradas das cidades.", Announcement: "🟢 A Semana dos Caminhos Livres começou!"},
		"dia_criancas":         {ID: "dia_criancas", Name: "Dia das Brincadeiras", Icon: "🪁", Region: "Terra de Pindorama", Countries: []string{"Brasil"}, Period: "12 de outubro", Active: false, XpMult: 1.1, DropMult: 1.1, Description: "Jogos cooperativos, pipas e caça ao tesouro sem competição paga.", Decorations: []string{"pipas_coloridas", "brinquedos_praca"}, Cosmetics: []string{"cosmetic_chapeu_pipa", "cosmetic_mochila_brinquedos"}, VisualChange: "Pipas no céu, amarelinha e brinquedos artesanais na praça.", Announcement: "🪁 As brincadeiras tomaram as praças de Perdidos!"},
		"reveillon_estrelas":   {ID: "reveillon_estrelas", Name: "Virada das Estrelas", Icon: "🌟", Region: "Terra de Pindorama", Countries: []string{"Brasil"}, Period: "31 de dezembro a 1º de janeiro", Active: false, XpMult: 1.25, DropMult: 1.5, Description: "Celebração à beira-rio com luzes silenciosas, desejos e roupas claras.", Decorations: []string{"lampioes_rio", "estrelas_flutuantes"}, Cosmetics: []string{"cosmetic_roupa_branca", "cosmetic_coroa_estrelas"}, VisualChange: "Lanternas refletidas no rio e céu estrelado reforçado, sem fogos ruidosos.", Announcement: "🌟 Uma nova volta do céu começa na Virada das Estrelas!"},
		"festival_mouras":      {ID: "festival_mouras", Name: "Vigília das Mouras Encantadas", Icon: "🏰", Region: "Reino das Mouras", Countries: []string{"Portugal"}, Period: "Evento regional", Active: false, XpMult: 1.25, DropMult: 1.4, Description: "Fontes, cantigas e tesouros encantados despertam nas noites do reino.", Decorations: []string{"fontes_mouras", "fitas_azulejo"}, Cosmetics: []string{"cosmetic_coroa_moura", "cosmetic_capa_azulejo"}, VisualChange: "Azulejos luminosos, fontes encantadas e lua refletida nas muralhas.", Announcement: "🏰 As Mouras Encantadas despertaram junto às fontes antigas!"},
		"hanami_sol":           {ID: "hanami_sol", Name: "Florada das Ilhas", Icon: "🌸", Region: "Ilhas do Sol Nascente", Countries: []string{"Japão"}, Period: "Primavera regional", Active: false, XpMult: 1.2, DropMult: 1.35, Description: "Contemplação das flores e pequenos encontros comunitários nas ilhas.", Decorations: []string{"petalas_cerejeira", "lanternas_ilhas"}, Cosmetics: []string{"cosmetic_presilha_sakura", "cosmetic_manto_hanami"}, VisualChange: "Cerejeiras floridas, pétalas ao vento e lanternas discretas.", Announcement: "🌸 A florada começou nas Ilhas do Sol Nascente."},
		"solsticio_fiordes":    {ID: "solsticio_fiordes", Name: "Solstício dos Fiordes", Icon: "❄️", Region: "Fiordes de Gelo", Countries: []string{"Noruega", "Islândia"}, Period: "Solstício regional", Active: false, XpMult: 1.25, DropMult: 1.4, Description: "Fogueiras, auroras e histórias atravessam a noite mais longa.", Decorations: []string{"aurora_fiordes", "fogueiras_solsticio"}, Cosmetics: []string{"cosmetic_capa_aurora", "cosmetic_gorro_lanoso"}, VisualChange: "Aurora mais intensa, neve suave e fogueiras comunitárias protegidas do vento.", Announcement: "❄️ As auroras anunciam o Solstício dos Fiordes!"},
		"jogos_colunas":        {ID: "jogos_colunas", Name: "Jogos das Sete Colunas", Icon: "🏺", Region: "Costa das Colunas", Countries: []string{"Grécia"}, Period: "Evento regional", Active: false, XpMult: 1.3, DropMult: 1.2, Description: "Provas cooperativas de corrida, precisão e estratégia entre as cidades costeiras.", Decorations: []string{"louros_colunas", "tochas_estadio"}, Cosmetics: []string{"cosmetic_coroa_louros", "cosmetic_manto_atleta"}, VisualChange: "Tochas cerimoniais, faixas nas colunas e pistas temporárias.", Announcement: "🏺 Começaram os Jogos das Sete Colunas!"},
		"cheia_nilo":           {ID: "cheia_nilo", Name: "Festival da Cheia", Icon: "🌊", Region: "Areias do Nilo", Countries: []string{"Egito"}, Period: "Evento regional", Active: false, XpMult: 1.2, DropMult: 1.4, Description: "Celebra a água, a agricultura e o trabalho das comunidades do rio.", Decorations: []string{"jardins_nilo", "barcos_papiro"}, Cosmetics: []string{"cosmetic_colar_lotus", "cosmetic_manto_papiro"}, VisualChange: "Canais cheios, jardins floridos e barcos ornamentais de papiro.", Announcement: "🌊 As águas chegaram: começou o Festival da Cheia!"},
		"colheita_brumas":      {ID: "colheita_brumas", Name: "Colheita das Brumas", Icon: "🍂", Region: "Brumas Verdes", Countries: []string{"Irlanda", "Escócia"}, Period: "Outono regional", Active: false, XpMult: 1.2, DropMult: 1.4, Description: "Feira de colheita, música e histórias junto às fogueiras.", Decorations: []string{"folhas_brumas", "feira_colheita"}, Cosmetics: []string{"cosmetic_broche_cardodourado", "cosmetic_capa_brumas"}, VisualChange: "Folhas cobrem os caminhos, barracas de colheita e névoa dourada ao entardecer.", Announcement: "🍂 A Colheita das Brumas reuniu aldeias e viajantes!"},
		"noite_estepe":         {ID: "noite_estepe", Name: "Noite das Mil Fogueiras", Icon: "🔥", Region: "Estepe de Ferro", Countries: []string{"Polônia", "Ucrânia", "Rússia e povos eslavos"}, Period: "Inverno regional", Active: false, XpMult: 1.25, DropMult: 1.4, Description: "Fogueiras guiam viajantes pela estepe e mantêm antigas criaturas à distância.", Decorations: []string{"fogueiras_estepe", "fitas_betula"}, Cosmetics: []string{"cosmetic_coroa_betula", "cosmetic_casaco_estepe"}, VisualChange: "Fogueiras ao longo das estradas, bétulas com fitas e neve iluminada.", Announcement: "🔥 Mil fogueiras iluminam a Estepe de Ferro!"},
		"lanternas_jade":       {ID: "lanternas_jade", Name: "Festival das Lanternas de Jade", Icon: "🏮", Region: "Império de Jade", Countries: []string{"China"}, Period: "Evento regional", Active: false, XpMult: 1.2, DropMult: 1.35, Description: "Enigmas, lanternas e encontros familiares encerram o ciclo festivo.", Decorations: []string{"lanternas_jade", "arcos_papel"}, Cosmetics: []string{"cosmetic_presilha_jade", "cosmetic_manto_lanternas"}, VisualChange: "Lanternas coloridas, enigmas nas praças e reflexos sobre os canais.", Announcement: "🏮 As Lanternas de Jade iluminam os caminhos do império!"},
		"ancestrais_obsidiana": {ID: "ancestrais_obsidiana", Name: "Caminho dos Ancestrais", Icon: "🕯️", Region: "Selvas de Obsidiana", Countries: []string{"México"}, Period: "Fim de outubro e início de novembro", Active: false, XpMult: 1.15, DropMult: 1.25, Description: "Celebração respeitosa da memória, preparada com consulta cultural antes da ativação.", Decorations: []string{"flores_cempasuchil", "altares_memoria"}, Cosmetics: []string{"cosmetic_coroa_cempasuchil", "cosmetic_xale_memoria"}, VisualChange: "Caminhos de flores, velas e altares de memória; sem inimigos ou caricaturas dos mortos.", Announcement: "🕯️ Os caminhos de flores guardam a memória dos ancestrais."},
	}
}

func (as *AdminServer) saveEventsConfig(cfg ActiveEventsConfig) error {
	as.mu.Lock()
	defer as.mu.Unlock()

	cfg.UpdatedAt = time.Now().Unix()
	data, err := json.MarshalIndent(cfg, "", "  ")
	if err != nil {
		return err
	}
	_ = os.MkdirAll(filepath.Dir(as.activeEventsFile), 0o755)
	return os.WriteFile(as.activeEventsFile, data, 0o644)
}

// LiveServerState mirrors what the Godot server outputs.
type LiveServerState struct {
	OnlineCount     int          `json:"online_count"`
	Players         []LivePlayer `json:"players"`
	Drops           []LiveDrop   `json:"drops"`
	DropsCount      int          `json:"drops_count"`
	Instances       []string     `json:"instances"`
	ServerUptimeSec int          `json:"server_uptime_sec"`
	Timestamp       int64        `json:"timestamp"`
}

type LivePlayer struct {
	Name     string    `json:"name"`
	PeerID   int       `json:"peer_id"`
	Level    int       `json:"level"`
	Stars    int       `json:"stars"`
	HP       int       `json:"hp"`
	MaxHP    int       `json:"max_hp"`
	MP       int       `json:"mp"`
	MaxMP    int       `json:"max_mp"`
	Instance string    `json:"instance"`
	Map      string    `json:"map"`
	Pos      []float64 `json:"pos"`
}

type LiveDrop struct {
	ID   int       `json:"id"`
	Item string    `json:"item"`
	Qty  int       `json:"qty"`
	Map  string    `json:"map"`
	Pos  []float64 `json:"pos"`
}

func (as *AdminServer) readLiveState() LiveServerState {
	var st LiveServerState
	data, err := os.ReadFile(as.liveServerFile)
	if err != nil {
		return st
	}
	_ = json.Unmarshal(data, &st)
	return st
}

// PlayerSummary is for listing in the players table.
type PlayerSummary struct {
	Name            string    `json:"name"`
	AccountID       int64     `json:"account_id"`
	Email           string    `json:"email"`
	Level           int       `json:"level"`
	Stars           int       `json:"stars"`
	HP              int       `json:"hp"`
	MaxHP           int       `json:"max_hp"`
	Map             string    `json:"map"`
	Pos             []float64 `json:"pos"`
	IsOnline        bool      `json:"is_online"`
	LastSaved       string    `json:"last_saved"`
	InventoryCount  int       `json:"inventory_count"`
	EquippedSummary []string  `json:"equipped_summary"`
}

func (as *AdminServer) loadCharacterOwners() map[string]int64 {
	owners := map[string]int64{}
	data, err := os.ReadFile(as.ownersFile)
	if err == nil {
		var raw map[string]float64
		if err := json.Unmarshal(data, &raw); err == nil {
			for k, v := range raw {
				owners[strings.ToLower(k)] = int64(v)
			}
		}
	}
	return owners
}

func (as *AdminServer) listAllPlayers() []PlayerSummary {
	live := as.readLiveState()
	onlineMap := map[string]LivePlayer{}
	for _, p := range live.Players {
		onlineMap[strings.ToLower(p.Name)] = p
	}

	owners := as.loadCharacterOwners()
	var list []PlayerSummary

	entries, err := os.ReadDir(as.serverSavesDir)
	if err != nil {
		return list
	}

	for _, e := range entries {
		if e.IsDir() || !strings.HasSuffix(e.Name(), ".json") || e.Name() == "character_owners.json" {
			continue
		}
		path := filepath.Join(as.serverSavesDir, e.Name())
		data, err := os.ReadFile(path)
		if err != nil {
			continue
		}
		var char map[string]any
		if err := json.Unmarshal(data, &char); err != nil {
			continue
		}

		name, _ := char["name"].(string)
		if name == "" {
			name = strings.TrimSuffix(e.Name(), ".json")
		}
		level := int(getFloat(char, "level", 1))
		stars := int(getFloat(char, "stars", 0))
		hp := int(getFloat(char, "hp", 100))
		homeMap, _ := char["home_map"].(string)
		homeMap = migrateLegacyID(homeMap) // save ainda não regravado pelo servidor do jogo
		if homeMap == "" {
			homeMap = "city_awakening"
		}

		invCount := 0
		if inv, ok := char["inventory"].([]any); ok {
			for _, item := range inv {
				if m, isMap := item.(map[string]any); isMap && len(m) > 0 {
					invCount++
				}
			}
		}

		var equipped []string
		if eq, ok := char["equipment"].(map[string]any); ok {
			for slot, it := range eq {
				if m, isMap := it.(map[string]any); isMap {
					if id, ok := m["id"].(string); ok && id != "" {
						equipped = append(equipped, fmt.Sprintf("%s: %s", slot, id))
					}
				}
			}
		}

		info, _ := e.Info()
		lastSaved := ""
		if info != nil {
			lastSaved = info.ModTime().Format("02/01/2006 15:04:05")
		}

		lowerName := strings.ToLower(name)
		accountID := owners[lowerName]
		email := ""
		if accountID > 0 {
			// Find account email if possible
			email = fmt.Sprintf("Conta #%d", accountID)
		}

		pos := []float64{0, 0, 0}
		isOnline := false
		if lp, found := onlineMap[lowerName]; found {
			isOnline = true
			pos = lp.Pos
			hp = lp.HP
			homeMap = lp.Map
			level = lp.Level
			stars = lp.Stars
		}

		list = append(list, PlayerSummary{
			Name:            name,
			AccountID:       accountID,
			Email:           email,
			Level:           level,
			Stars:           stars,
			HP:              hp,
			MaxHP:           hp,
			Map:             homeMap,
			Pos:             pos,
			IsOnline:        isOnline,
			LastSaved:       lastSaved,
			InventoryCount:  invCount,
			EquippedSummary: equipped,
		})
	}

	sort.Slice(list, func(i, j int) bool {
		if list[i].IsOnline != list[j].IsOnline {
			return list[i].IsOnline
		}
		return list[i].Stars > list[j].Stars
	})

	return list
}

func getFloat(m map[string]any, key string, fallback float64) float64 {
	if v, ok := m[key]; ok {
		switch num := v.(type) {
		case float64:
			return num
		case int:
			return float64(num)
		}
	}
	return fallback
}

// Admin Auth Middleware
func (as *AdminServer) requireAdmin(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		tokenStr := ""
		if auth := r.Header.Get("Authorization"); strings.HasPrefix(auth, "Bearer ") {
			tokenStr = strings.TrimPrefix(auth, "Bearer ")
		} else if cookie, err := r.Cookie("admin_token"); err == nil {
			tokenStr = cookie.Value
		}

		if tokenStr == "" {
			writeError(w, http.StatusUnauthorized, "unauthorized", "Acesso restrito ao administrador.")
			return
		}

		claims, err := VerifyJWT(as.cfg.Secret, tokenStr, time.Now())
		if err != nil || claims.Email != adminEmail {
			writeError(w, http.StatusForbidden, "forbidden", "Apenas progsphp@gmail.com tem acesso de administrador.")
			return
		}

		ctx := context.WithValue(r.Context(), "admin_email", claims.Email)
		next(w, r.WithContext(ctx))
	}
}

// Handlers
func (as *AdminServer) handleLogin(w http.ResponseWriter, r *http.Request) {
	var body struct {
		Email    string `json:"email"`
		Password string `json:"password"`
	}
	if err := json.NewDecoder(io.LimitReader(r.Body, maxBodyBytes)).Decode(&body); err != nil {
		writeError(w, http.StatusBadRequest, "bad_json", "Corpo da requisição inválido.")
		return
	}

	email := strings.ToLower(strings.TrimSpace(body.Email))
	if email != adminEmail {
		writeError(w, http.StatusForbidden, "forbidden", "Email não autorizado para acesso administrativo.")
		return
	}

	acc, err := as.store.FindByEmail(r.Context(), email)
	if err != nil {
		writeError(w, http.StatusUnauthorized, "invalid_credentials", "Credenciais incorretas.")
		return
	}

	ok, err := VerifyPassword(body.Password, acc.PasswordHash)
	if err != nil || !ok {
		writeError(w, http.StatusUnauthorized, "invalid_credentials", "Senha incorreta.")
		return
	}

	token, err := SignJWT(as.cfg.Secret, Claims{
		AccountID: acc.ID,
		Email:     acc.Email,
		Iat:       time.Now().Unix(),
		Exp:       time.Now().Add(24 * time.Hour).Unix(),
		Iss:       jwtIssuer,
	})
	if err != nil {
		writeError(w, http.StatusInternalServerError, "jwt_error", "Erro ao gerar token.")
		return
	}

	http.SetCookie(w, &http.Cookie{
		Name:     "admin_token",
		Value:    token,
		Path:     "/",
		Expires:  time.Now().Add(24 * time.Hour),
		HttpOnly: true,
		SameSite: http.SameSiteLaxMode,
	})

	writeJSON(w, http.StatusOK, map[string]any{
		"token": token,
		"email": acc.Email,
	})
}

func (as *AdminServer) handleLogout(w http.ResponseWriter, r *http.Request) {
	http.SetCookie(w, &http.Cookie{
		Name:     "admin_token",
		Value:    "",
		Path:     "/",
		Expires:  time.Unix(0, 0),
		HttpOnly: true,
	})
	writeJSON(w, http.StatusOK, map[string]any{"ok": true})
}

func (as *AdminServer) handleMe(w http.ResponseWriter, r *http.Request) {
	email := r.Context().Value("admin_email")
	writeJSON(w, http.StatusOK, map[string]any{
		"email": email,
		"role":  "admin",
	})
}

func (as *AdminServer) handleOverview(w http.ResponseWriter, r *http.Request) {
	live := as.readLiveState()
	players := as.listAllPlayers()
	eventsCfg := as.loadEventsConfig()

	totalAccounts, _ := as.store.CountAccounts(r.Context())
	totalStars := 0
	for _, p := range players {
		totalStars += p.Stars
	}

	activeEventsCount := 0
	xpMult := 1.0
	dropMult := 1.0
	var activeEventsList []EventItem
	for _, ev := range eventsCfg.Events {
		if ev.Active {
			activeEventsCount++
			activeEventsList = append(activeEventsList, ev)
			if ev.XpMult > xpMult {
				xpMult = ev.XpMult
			}
			if ev.DropMult > dropMult {
				dropMult = ev.DropMult
			}
		}
	}

	writeJSON(w, http.StatusOK, map[string]any{
		"online_count":        live.OnlineCount,
		"players":             live.Players,
		"total_players":       len(players),
		"total_accounts":      totalAccounts,
		"total_stars":         totalStars,
		"total_drops":         len(live.Drops),
		"server_uptime_sec":   live.ServerUptimeSec,
		"active_events_count": activeEventsCount,
		"active_events":       activeEventsList,
		"active_decorations":  eventsCfg.ActiveDecorations,
		"active_cosmetics":    eventsCfg.ActiveCosmetics,
		"xp_mult":             xpMult,
		"drop_mult":           dropMult,
		"instances":           live.Instances,
	})
}

func (as *AdminServer) handlePlayers(w http.ResponseWriter, r *http.Request) {
	players := as.listAllPlayers()
	writeJSON(w, http.StatusOK, map[string]any{
		"players": players,
		"total":   len(players),
	})
}

func (as *AdminServer) handlePlayerDetail(w http.ResponseWriter, r *http.Request) {
	name := strings.TrimSpace(r.URL.Query().Get("name"))
	if name == "" {
		writeError(w, http.StatusBadRequest, "missing_name", "Parâmetro 'name' obrigatório.")
		return
	}
	cleanName := filepath.Base(strings.ToLower(name)) + ".json"
	path := filepath.Join(as.serverSavesDir, cleanName)

	data, err := os.ReadFile(path)
	if err != nil {
		writeError(w, http.StatusNotFound, "not_found", "Personagem não encontrado.")
		return
	}
	var char map[string]any
	if err := json.Unmarshal(data, &char); err != nil {
		writeError(w, http.StatusInternalServerError, "corrupt_data", "Erro ao decodificar save.")
		return
	}
	writeJSON(w, http.StatusOK, char)
}

func (as *AdminServer) handleDrops(w http.ResponseWriter, r *http.Request) {
	live := as.readLiveState()
	writeJSON(w, http.StatusOK, map[string]any{
		"drops": live.Drops,
		"total": len(live.Drops),
	})
}

func (as *AdminServer) handleEvents(w http.ResponseWriter, r *http.Request) {
	cfg := as.loadEventsConfig()
	var list []EventItem
	for _, ev := range cfg.Events {
		list = append(list, ev)
	}
	sort.Slice(list, func(i, j int) bool {
		return list[i].Name < list[j].Name
	})

	writeJSON(w, http.StatusOK, map[string]any{
		"events":             list,
		"active_decorations": cfg.ActiveDecorations,
		"active_cosmetics":   cfg.ActiveCosmetics,
	})
}

func (as *AdminServer) handleEventToggle(w http.ResponseWriter, r *http.Request) {
	var req struct {
		EventID string `json:"event_id"`
		Active  bool   `json:"active"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "bad_json", "Requisição inválida.")
		return
	}

	cfg := as.loadEventsConfig()
	ev, found := cfg.Events[req.EventID]
	if !found {
		writeError(w, http.StatusNotFound, "not_found", "Evento não encontrado.")
		return
	}

	ev.Active = req.Active
	cfg.Events[req.EventID] = ev

	// Automatically toggle associated decorations and cosmetics if specified
	for _, dec := range ev.Decorations {
		cfg.ActiveDecorations[dec] = req.Active
	}
	for _, cos := range ev.Cosmetics {
		cfg.ActiveCosmetics[cos] = req.Active
	}

	if req.Active && ev.Announcement != "" {
		cfg.BroadcastMessage = ev.Announcement
	}

	if err := as.saveEventsConfig(cfg); err != nil {
		writeError(w, http.StatusInternalServerError, "save_error", "Erro ao salvar eventos.")
		return
	}

	writeJSON(w, http.StatusOK, map[string]any{"ok": true, "event": ev})
}

func (as *AdminServer) handleEventCreate(w http.ResponseWriter, r *http.Request) {
	var ev EventItem
	if err := json.NewDecoder(io.LimitReader(r.Body, maxBodyBytes)).Decode(&ev); err != nil {
		writeError(w, http.StatusBadRequest, "bad_json", "Requisição inválida.")
		return
	}
	ev.Name = strings.TrimSpace(ev.Name)
	ev.Description = strings.TrimSpace(ev.Description)
	ev.Announcement = strings.TrimSpace(ev.Announcement)
	if ev.Name == "" {
		writeError(w, http.StatusBadRequest, "missing_name", "Informe o nome do evento.")
		return
	}
	if len([]rune(ev.Name)) > 80 || len([]rune(ev.Description)) > 300 || len([]rune(ev.Announcement)) > 300 {
		writeError(w, http.StatusBadRequest, "too_long", "Nome, descrição ou anúncio excede o limite permitido.")
		return
	}
	if strings.TrimSpace(ev.ID) == "" {
		ev.ID = fmt.Sprintf("event_%d", time.Now().UnixNano())
	}
	if ev.XpMult <= 0 || ev.XpMult > 10 {
		ev.XpMult = 1.0
	}
	if ev.DropMult <= 0 || ev.DropMult > 10 {
		ev.DropMult = 1.0
	}
	if ev.Icon == "" {
		ev.Icon = "🎉"
	}

	cfg := as.loadEventsConfig()
	cfg.Events[ev.ID] = ev
	if ev.Active && ev.Announcement != "" {
		cfg.BroadcastMessage = ev.Announcement
	}
	if err := as.saveEventsConfig(cfg); err != nil {
		writeError(w, http.StatusInternalServerError, "save_error", "Erro ao salvar evento.")
		return
	}

	writeJSON(w, http.StatusOK, map[string]any{"ok": true, "event": ev})
}

func (as *AdminServer) handleDecorationToggle(w http.ResponseWriter, r *http.Request) {
	var req struct {
		DecorationID string `json:"decoration_id"`
		Active       bool   `json:"active"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "bad_json", "Requisição inválida.")
		return
	}

	cfg := as.loadEventsConfig()
	cfg.ActiveDecorations[req.DecorationID] = req.Active
	if err := as.saveEventsConfig(cfg); err != nil {
		writeError(w, http.StatusInternalServerError, "save_error", "Erro ao salvar enfeite.")
		return
	}

	writeJSON(w, http.StatusOK, map[string]any{"ok": true, "active_decorations": cfg.ActiveDecorations})
}

func (as *AdminServer) handleCosmeticToggle(w http.ResponseWriter, r *http.Request) {
	var req struct {
		CosmeticID string `json:"cosmetic_id"`
		Active     bool   `json:"active"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "bad_json", "Requisição inválida.")
		return
	}

	cfg := as.loadEventsConfig()
	cfg.ActiveCosmetics[req.CosmeticID] = req.Active
	if err := as.saveEventsConfig(cfg); err != nil {
		writeError(w, http.StatusInternalServerError, "save_error", "Erro ao salvar cosmético.")
		return
	}

	writeJSON(w, http.StatusOK, map[string]any{"ok": true, "active_cosmetics": cfg.ActiveCosmetics})
}

func (as *AdminServer) handleBroadcast(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Message string `json:"message"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || strings.TrimSpace(req.Message) == "" {
		writeError(w, http.StatusBadRequest, "bad_json", "Mensagem não informada.")
		return
	}

	cfg := as.loadEventsConfig()
	cfg.BroadcastMessage = req.Message
	if err := as.saveEventsConfig(cfg); err != nil {
		writeError(w, http.StatusInternalServerError, "save_error", "Erro ao salvar anúncio.")
		return
	}

	writeJSON(w, http.StatusOK, map[string]any{"ok": true, "broadcast": req.Message})
}

func (as *AdminServer) handleLogs(w http.ResponseWriter, r *http.Request) {
	logs := append([]string{"=== SERVIDOR DO JOGO ==="}, readLogTail(as.cfg.ServerLog, 120)...)
	logs = append(logs, "", "=== API / AUTENTICAÇÃO ===")
	logs = append(logs, readLogTail(as.cfg.AuthLog, 80)...)
	writeJSON(w, http.StatusOK, map[string]any{
		"logs":    logs,
		"sources": map[string]string{"server": as.cfg.ServerLog, "auth": as.cfg.AuthLog},
	})
}

func readLogTail(path string, limit int) []string {
	data, err := os.ReadFile(path)
	if err != nil {
		return []string{fmt.Sprintf("(Não foi possível ler %s: %v)", path, err)}
	}
	lines := strings.Split(strings.TrimRight(string(data), "\n"), "\n")
	if len(lines) > limit {
		lines = lines[len(lines)-limit:]
	}
	return lines
}

func (as *AdminServer) RegisterRoutes(mux *http.ServeMux) {
	mux.HandleFunc("GET /admin", as.handleAdminPage)
	mux.HandleFunc("GET /admin/", as.handleAdminPage)

	mux.HandleFunc("POST /api/admin/login", as.handleLogin)
	mux.HandleFunc("POST /api/admin/logout", as.handleLogout)
	mux.HandleFunc("GET /api/admin/me", as.requireAdmin(as.handleMe))

	mux.HandleFunc("GET /api/admin/overview", as.requireAdmin(as.handleOverview))
	mux.HandleFunc("GET /api/admin/players", as.requireAdmin(as.handlePlayers))
	mux.HandleFunc("GET /api/admin/player-detail", as.requireAdmin(as.handlePlayerDetail))
	mux.HandleFunc("GET /api/admin/drops", as.requireAdmin(as.handleDrops))
	mux.HandleFunc("GET /api/admin/items", as.requireAdmin(as.handleItems))
	mux.HandleFunc("POST /api/admin/items/create", as.requireAdmin(as.handleItemCreate))
	mux.HandleFunc("GET /api/admin/events", as.requireAdmin(as.handleEvents))
	mux.HandleFunc("POST /api/admin/events/toggle", as.requireAdmin(as.handleEventToggle))
	mux.HandleFunc("POST /api/admin/events/create", as.requireAdmin(as.handleEventCreate))
	mux.HandleFunc("POST /api/admin/decorations/toggle", as.requireAdmin(as.handleDecorationToggle))
	mux.HandleFunc("POST /api/admin/cosmetics/toggle", as.requireAdmin(as.handleCosmeticToggle))
	mux.HandleFunc("POST /api/admin/broadcast", as.requireAdmin(as.handleBroadcast))
	mux.HandleFunc("GET /api/admin/logs", as.requireAdmin(as.handleLogs))
}

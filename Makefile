# Perdidos — comandos do dia a dia.   `make help` lista tudo.
#
# A Godot certa (4.7.2) é baixada sozinha para .tools/ na primeira vez.
# Para usar outra instalação:  make run GODOT=/caminho/da/godot

GODOT_VERSION ?= 4.7.2
TOOLS         := $(CURDIR)/.tools
GODOT         ?= $(TOOLS)/godot-$(GODOT_VERSION)
GAME          := $(CURDIR)/game
BUILD         := $(CURDIR)/build
RUN_DIR       := $(CURDIR)/.run
PORT          ?= 7777
# Servidor público pelo ngrok (túnel HTTP → o jogo usa WebSocket). Os clientes exportados já vêm com ele.
NGROK_URL     ?= poetic-calculably-nayeli.ngrok-free.dev
SERVER_URL    ?= $(NGROK_URL)
# Servidor público pelo Cloudflare Tunnel (túnel nomeado; config em ~/.cloudflared/config.yml).
CF_TUNNEL     ?= perdidos-dev
CF_HOST       ?= perdidos-dev.dev2learn.com
PLAYIT_URL    ?= perdidos.auto.playit.gg
PLAYIT_PORT   ?= 7777
GOOGLE_CLIENT_JSON ?= $(CURDIR)/client_secret_910576501627-8s6eumk2efoin2454cnd5l1hcf5g9hm6.apps.googleusercontent.com.json
GOOGLE_CLIENT_ID ?= $(shell node -e 'try { const c = require("$(GOOGLE_CLIENT_JSON)"); process.stdout.write(c.web?.client_id || ""); } catch {}')
NAME          ?= Viajante
BODY          ?= male
TEMPLATES_DIR := $(HOME)/.local/share/godot/export_templates/$(GODOT_VERSION).stable
GODOT_URL     := https://github.com/godotengine/godot/releases/download/$(GODOT_VERSION)-stable
COMPOSE       := docker compose -f infra/docker-compose.yml --env-file infra/.env
# Launcher (Wails v3) + API de contas/porteiro (Go). Ver launcher/README.md.
GO            ?= go
LAUNCHER      := $(CURDIR)/launcher
AUTH_BIN      := $(BUILD)/auth/perdidos-auth
WAILS3        ?= wails3
AUTH_PORT     ?= 8080
SECRETS       ?= $(HOME)/.config/perdidos/secrets.env
RELEASE_DIR   := $(BUILD)/release

.DEFAULT_GOAL := help
.PHONY: launcher launcher-windows launcher-frontend launcher-test auth release serve-ngrok run-ngrok-client serve-cloudflare serve-cloudflare-quick run-cloudflare-client serve-playit run-playit-client client-config clients check-names help godot import run run-dev run-server run-client run-duo stop test build build-windows \
        build-linux build-server build-apk apk templates up down logs ps db-shell db-reset clean site site-deploy

help: ## Lista os comandos
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36mmake %-14s\033[0m %s\n", $$1, $$2}'

# ---------------------------------------------------------------- engine
$(GODOT):
	@echo ">> baixando Godot $(GODOT_VERSION)"
	@mkdir -p $(TOOLS)
	@curl -fsSL -o $(TOOLS)/godot.zip $(GODOT_URL)/Godot_v$(GODOT_VERSION)-stable_linux.x86_64.zip
	@unzip -qo $(TOOLS)/godot.zip -d $(TOOLS) && rm $(TOOLS)/godot.zip
	@mv $(TOOLS)/Godot_v$(GODOT_VERSION)-stable_linux.x86_64 $(GODOT) && chmod +x $(GODOT)

godot: $(GODOT) ## Baixa a Godot do projeto para .tools/

import: $(GODOT) ## Importa os assets (necessário após mudar arte/áudio)
	@$(GODOT) --headless --path $(GAME) --import >/dev/null 2>&1 || $(GODOT) --headless --path $(GAME) --import

# ---------------------------------------------------------------- rodar local
run: import ## Sobe o servidor local e abre o jogo (tela de título). Fechar o jogo derruba o servidor
	@mkdir -p $(RUN_DIR)
	@$(GODOT) --headless --path $(GAME) -- --server --port=$(PORT) > $(RUN_DIR)/server.log 2>&1 & \
	 echo $$! > $(RUN_DIR)/server.pid; \
	 trap 'kill $$(cat $(RUN_DIR)/server.pid 2>/dev/null) 2>/dev/null; rm -f $(RUN_DIR)/server.pid' EXIT; \
	 sleep 2; echo ">> servidor na porta $(PORT) (log: .run/server.log)"; \
	 $(GODOT) --path $(GAME) -- --port=$(PORT)

run-dev: import ## Igual ao run, com os comandos de teste no chat (/chefe, /atroz, /noite, /dia, /abates, /ajuda; e os /dev da progressão)
	@mkdir -p $(RUN_DIR)
	@$(GODOT) --headless --path $(GAME) -- --server --port=$(PORT) --dev-commands > $(RUN_DIR)/server.log 2>&1 & \
	 echo $$! > $(RUN_DIR)/server.pid; \
	 trap 'kill $$(cat $(RUN_DIR)/server.pid 2>/dev/null) 2>/dev/null; rm -f $(RUN_DIR)/server.pid' EXIT; \
	 sleep 2; echo ">> servidor (comandos de teste ligados) na porta $(PORT) (log: .run/server.log)"; \
	 $(GODOT) --path $(GAME) -- --port=$(PORT)

run-duo: import ## Servidor + 2 jogos lado a lado (Ana e Bia) para testar multiplayer
	@mkdir -p $(RUN_DIR)
	@$(GODOT) --headless --path $(GAME) -- --server --port=$(PORT) > $(RUN_DIR)/server.log 2>&1 & \
	 echo $$! > $(RUN_DIR)/server.pid; \
	 trap 'kill $$(cat $(RUN_DIR)/server.pid 2>/dev/null) $$(jobs -p) 2>/dev/null; rm -f $(RUN_DIR)/server.pid' EXIT; \
	 sleep 2; \
	 $(GODOT) --path $(GAME) --resolution 960x540 --position 0,0 -- --name=Ana --body=female --port=$(PORT) & \
	 $(GODOT) --path $(GAME) --resolution 960x540 --position 960,0 -- --name=Bia --body=male --port=$(PORT); \
	 wait

serve-ngrok: import auth ## Servidor na internet pelo ngrok: jogo (WebSocket, exige login do launcher) + API de contas/porteiro. NO_AUTH=1 desliga o login
serve-ngrok: PUBLIC_HOST = $(NGROK_URL)
serve-ngrok: TUNNEL_CHECK = command -v ngrok >/dev/null || { echo "ngrok não encontrado: instale e rode 'ngrok config add-authtoken <token>'"; exit 1; }
serve-ngrok: TUNNEL_CMD = ngrok http --url=$(NGROK_URL) $(AUTH_PORT) --log=stdout --log-level=warn

serve-cloudflare: import auth ## Servidor na internet pelo Cloudflare Tunnel (CF_TUNNEL/CF_HOST, config em ~/.cloudflared/config.yml). NO_AUTH=1 desliga o login
serve-cloudflare: PUBLIC_HOST = $(CF_HOST)
serve-cloudflare: TUNNEL_CHECK = command -v cloudflared >/dev/null || { echo "cloudflared não encontrado: instale e rode 'cloudflared tunnel login'"; exit 1; }; \
	test -f $(HOME)/.cloudflared/config.yml || { echo "falta ~/.cloudflared/config.yml (ver docs/servidor-cloudflare.md)"; exit 1; }; \
	! pgrep -f "cloudflared tunnel.* run $(CF_TUNNEL)" >/dev/null || { echo ">> o túnel $(CF_TUNNEL) já está rodando em outro terminal: pare-o antes"; exit 1; }
serve-cloudflare: TUNNEL_CMD = cloudflared tunnel --no-autoupdate run $(CF_TUNNEL)

serve-cloudflare-quick: import auth ## Servidor na internet por um Quick Tunnel da Cloudflare (sem domínio; endereço *.trycloudflare.com muda a cada vez). NO_AUTH=1 desliga o login
serve-cloudflare-quick: PUBLIC_HOST = endereco-trycloudflare-mostrado-abaixo
serve-cloudflare-quick: TUNNEL_CHECK = command -v cloudflared >/dev/null || { echo "cloudflared não encontrado"; exit 1; }
serve-cloudflare-quick: TUNNEL_CMD = cloudflared tunnel --no-autoupdate --url http://127.0.0.1:$(AUTH_PORT)

# Receita comum aos túneis: sobe o jogo e a API em segundo plano e o túnel em primeiro plano (Ctrl+C derruba tudo).
serve-ngrok serve-cloudflare serve-cloudflare-quick:
	@$(TUNNEL_CHECK)
	@mkdir -p $(RUN_DIR)
	@$(AUTH_BIN) ensure-secret -secrets=$(SECRETS)
	@$(GODOT) --headless --path $(GAME) -- --server --transport=ws --port=$(PORT) $(if $(DEV),--dev-commands,) \
	   $(if $(NO_AUTH),,--require-auth --auth-secrets=$(SECRETS)) > $(RUN_DIR)/server.log 2>&1 & \
	 echo $$! > $(RUN_DIR)/server.pid; \
	 PERDIDOS_GOOGLE_CLIENT_ID="$(GOOGLE_CLIENT_ID)" PERDIDOS_PUBLIC_URL="https://$(PUBLIC_HOST)" \
	 $(AUTH_BIN) -addr=127.0.0.1:$(AUTH_PORT) -game=127.0.0.1:$(PORT) -db=$(RUN_DIR)/accounts.db \
	   -latest=$(RELEASE_DIR)/latest.json -secrets=$(SECRETS) > $(RUN_DIR)/auth.log 2>&1 & \
	 echo $$! > $(RUN_DIR)/auth.pid; \
	 trap 'kill $$(cat $(RUN_DIR)/server.pid $(RUN_DIR)/auth.pid 2>/dev/null) 2>/dev/null; rm -f $(RUN_DIR)/server.pid $(RUN_DIR)/auth.pid' EXIT; \
	 sleep 2; \
	 kill -0 $$(cat $(RUN_DIR)/server.pid) 2>/dev/null || { echo ">> servidor não iniciou; confira se a porta $(PORT) já está ocupada"; tail -n 15 $(RUN_DIR)/server.log; exit 1; }; \
	 kill -0 $$(cat $(RUN_DIR)/auth.pid) 2>/dev/null || { echo ">> API não iniciou; confira .run/auth.log"; exit 1; }; \
	 echo ">> jogo (WebSocket) na porta $(PORT) $(if $(NO_AUTH),SEM login,com login obrigatório) (log: .run/server.log)"; \
	 echo ">> API de contas + porteiro na porta $(AUTH_PORT) (log: .run/auth.log; contas em .run/accounts.db)"; \
	 echo ">> endereço público: https://$(PUBLIC_HOST)   (Ctrl+C derruba o túnel, a API e o servidor)"; \
	 $(TUNNEL_CMD)

run-ngrok-client: import ## Abre o jogo local já apontando para o servidor do ngrok (para conferir o túnel)
	@$(GODOT) --path $(GAME) -- --host=wss://$(NGROK_URL)

run-cloudflare-client: import ## Abre o jogo local já apontando para o servidor do Cloudflare (para conferir o túnel)
	@$(GODOT) --path $(GAME) -- --host=wss://$(CF_HOST)

serve-playit: import ## Servidor na internet pelo playit.gg (ENet/UDP nativo na porta 7777)
	@command -v playit >/dev/null || { echo "playit não encontrado. Instale com: curl -SsL https://playit-cloud.github.io/ppa/key.gpg | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/playit.gpg >/dev/null && echo 'deb [signed-by=/etc/apt/trusted.gpg.d/playit.gpg] https://playit-cloud.github.io/ppa/data ./' | sudo tee /etc/apt/sources.list.d/playit.list && sudo apt update && sudo apt install playit"; exit 1; }
	@mkdir -p $(RUN_DIR)
	@$(GODOT) --headless --path $(GAME) -- --server --port=$(PORT) $(if $(DEV),--dev-commands,) > $(RUN_DIR)/server.log 2>&1 & \
	 echo $$! > $(RUN_DIR)/server.pid; \
	 trap 'kill $$(cat $(RUN_DIR)/server.pid 2>/dev/null) 2>/dev/null; rm -f $(RUN_DIR)/server.pid' EXIT; \
	 sleep 2; echo ">> servidor Godot (UDP) na porta $(PORT) (log: .run/server.log)"; \
	 echo ">> iniciando playit.gg... (Ctrl+C encerra o túnel e o servidor)"; \
	 playit

run-playit-client: import ## Abre o jogo local apontando para o servidor do playit.gg
	@$(GODOT) --path $(GAME) -- --host=$(PLAYIT_URL) --port=$(PLAYIT_PORT)

run-server: import ## Só o servidor local (Ctrl+C para parar)
	@$(GODOT) --headless --path $(GAME) -- --server --port=$(PORT)

run-client: import ## Só o jogo, entrando direto:  make run-client NAME=Ana BODY=female [HOST=1.2.3.4]
	@$(GODOT) --path $(GAME) -- --name=$(NAME) --body=$(BODY) --host=$(or $(HOST),127.0.0.1) --port=$(PORT)

stop: ## Derruba um servidor local que ficou rodando
	@-kill $$(cat $(RUN_DIR)/server.pid 2>/dev/null) 2>/dev/null; rm -f $(RUN_DIR)/server.pid; echo ">> parado"

# ---------------------------------------------------------------- testes
test: import check-names ## Testes automáticos (nomes sensíveis, ligações de conteúdo, servidor + clientes headless e testes do cliente)
	@$(GODOT) --headless --path $(GAME) res://tests/beta/test_content_links.tscn
	@$(GODOT) --headless --path $(GAME) res://tests/auth/test_character_slots.tscn
	@$(GODOT) --headless --path $(GAME) res://tests/progression/test_fletching_and_ammo.tscn
	@$(GODOT) --headless --path $(GAME) res://tests/waystone/test_waystone_service.tscn
	@SHOTS=0 GODOT=$(GODOT) $(GAME)/tests/waystone/run_waystone_test.sh
	@GODOT=$(GODOT) $(GAME)/tools/run_autotest.sh
	@GODOT=$(GODOT) $(GAME)/tests/moderation/run_moderation_autotest.sh
	@GODOT=$(GODOT) $(GAME)/tests/monsters/run_night_test.sh
	@$(GODOT) --headless --path $(GAME) res://tests/client/test_direction.tscn
	@$(GODOT) --headless --path $(GAME) res://tests/client/test_skill_fx.tscn
	@xvfb-run -a $(GODOT) --path $(GAME) --resolution 1280x720 res://tests/client/test_ui.tscn
	@xvfb-run -a $(GODOT) --path $(GAME) --resolution 1280x720 res://tests/client/test_gamepad.tscn

check-names: ## Checa nomes sensíveis (religiões vivas em todos os idiomas, nomes de Ragnarok)
	@python3 game/tools/check_names.py

# ---------------------------------------------------------------- executáveis
templates: $(TEMPLATES_DIR)/version.txt ## Baixa os templates de export (~1,3 GB, só na primeira vez)

$(TEMPLATES_DIR)/version.txt:
	@echo ">> baixando templates de export $(GODOT_VERSION) (~1,3 GB)"
	@mkdir -p $(TEMPLATES_DIR) $(TOOLS)
	@curl -fL -o $(TOOLS)/templates.tpz $(GODOT_URL)/Godot_v$(GODOT_VERSION)-stable_export_templates.tpz
	@unzip -qo $(TOOLS)/templates.tpz -d $(TOOLS)/tpl && mv $(TOOLS)/tpl/templates/* $(TEMPLATES_DIR)/
	@rm -rf $(TOOLS)/templates.tpz $(TOOLS)/tpl

build: build-windows build-linux build-server build-apk ## Gera os executáveis em build/ (Windows, Linux, Servidor e Android APK)

client-config: ## Grava o servidor padrão dos clientes exportados (SERVER_URL=...; padrão: o do ngrok)
	@printf '[server]\nhost="%s"\n' "$(SERVER_URL)" > $(GAME)/client_config.cfg
	@echo ">> clientes exportados vão conectar em: $(SERVER_URL)"

clients: build-windows build-linux build-apk ## Gera os clientes (Windows, Linux e Android) já apontando para o servidor (SERVER_URL) e empacota em build/*.zip
	@cd $(BUILD)/windows && rm -f ../Perdidos-windows.zip && zip -q -r ../Perdidos-windows.zip .
	@cd $(BUILD)/linux && rm -f ../Perdidos-linux.zip && zip -q -r ../Perdidos-linux.zip .
	@echo ">> pronto: build/Perdidos-windows.zip, build/Perdidos-linux.zip e build/android/Perdidos.apk (servidor: $(SERVER_URL))"

build-windows: import templates client-config ## Executável do jogo para Windows → build/windows/
	@mkdir -p $(BUILD)/windows
	@$(GODOT) --headless --path $(GAME) --export-release "Windows Client" $(BUILD)/windows/Perdidos.exe

build-linux: import templates client-config ## Executável do jogo para Linux → build/linux/
	@mkdir -p $(BUILD)/linux
	@$(GODOT) --headless --path $(GAME) --export-release "Linux Client" $(BUILD)/linux/Perdidos.x86_64
	@cp $(GAME)/assets/branding/icon.png $(BUILD)/linux/perdidos.png
	@install -m 755 $(GAME)/tools/install_linux_shortcut.sh $(BUILD)/linux/instalar-atalho.sh

build-server: import templates ## Servidor dedicado para Linux → build/server/
	@mkdir -p $(BUILD)/server
	@$(GODOT) --headless --path $(GAME) --export-release "Linux Dedicated Server" $(BUILD)/server/PerdidosServer.x86_64

build-apk: import templates client-config ## Gera o APK Android para smartphones → build/android/Perdidos.apk
	@mkdir -p $(BUILD)/android
	@PATH="$(PATH):/home/devalexandre/Android/Sdk/build-tools/34.0.0" ANDROID_HOME="/home/devalexandre/Android/Sdk" \
	  $(GODOT) --headless --path $(GAME) --export-debug "Android" $(BUILD)/android/Perdidos.apk
	@echo ">> pronto: build/android/Perdidos.apk"

apk: build-apk ## Atalho para build-apk

# ---------------------------------------------------------------- launcher, contas e versões
launcher-frontend:
	@cd $(LAUNCHER)/frontend && { test -d node_modules || npm ci --no-audit --no-fund; } && npm run build

launcher: launcher-frontend ## Launcher para Linux → build/launcher/perdidos-launcher
	@mkdir -p $(BUILD)/launcher
	@cd $(LAUNCHER) && CGO_ENABLED=1 $(GO) build -tags production,gtk3 -trimpath -buildvcs=false -ldflags="-w -s" \
	   -o $(BUILD)/launcher/perdidos-launcher .
	@echo ">> pronto: build/launcher/perdidos-launcher"

launcher-windows: launcher-frontend ## Launcher para Windows (compila no Linux, sem mingw) → build/launcher/PerdidosLauncher.exe
	@mkdir -p $(BUILD)/launcher
	@cd $(LAUNCHER) && if command -v $(WAILS3) >/dev/null; then $(WAILS3) generate syso -arch amd64 -icon build/windows/icon.ico \
	   -manifest build/windows/launcher.exe.manifest -info build/windows/info.json -out launcher_windows_amd64.syso >/dev/null; \
	 else echo ">> (sem wails3 no PATH: o .exe sai sem ícone)"; fi
	@cd $(LAUNCHER) && GOOS=windows GOARCH=amd64 CGO_ENABLED=0 $(GO) build -tags production -trimpath -buildvcs=false \
	   -ldflags="-w -s -H windowsgui" -o $(BUILD)/launcher/PerdidosLauncher.exe .; rc=$$?; rm -f launcher_windows_amd64.syso; exit $$rc
	@echo ">> pronto: build/launcher/PerdidosLauncher.exe"

auth: ## API de contas + porteiro → build/auth/perdidos-auth
	@mkdir -p $(dir $(AUTH_BIN))
	@cd $(LAUNCHER)/server && CGO_ENABLED=0 $(GO) build -trimpath -buildvcs=false -o $(AUTH_BIN) .

launcher-test: ## Testes Go do launcher e da API (Drive, download/troca atômica, JWT, contas)
	@cd $(LAUNCHER)/server && $(GO) test ./...
	@cd $(LAUNCHER) && $(GO) test ./internal/...
	@GODOT=$(GODOT) GO=$(GO) $(LAUNCHER)/tests/auth_integration.sh

release: ## Publica uma versão: make release VERSION=0.1.3 [NOTES="o que mudou"] [THEME_ID=arco2] → build/release/ (zips + tema + latest.json)
	@test -n "$(VERSION)" || { echo "use: make release VERSION=x.y.z"; exit 1; }
	@echo "$(VERSION)" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$$' || { echo "VERSION precisa ser x.y.z (ex.: 0.1.3)"; exit 1; }
	@sed -i 's/^config\/version=".*"/config\/version="$(VERSION)"/' $(GAME)/project.godot
	@echo ">> versão do jogo: $(VERSION) (game/project.godot)"
	@$(MAKE) --no-print-directory build-windows build-linux build-apk
	@VERSION=$(VERSION) NOTES="$(NOTES)" SERVER_URL="$(SERVER_URL)" BUILD="$(BUILD)" \
	   THEME_ID="$(THEME_ID)" THEME_IMAGE="$(THEME_IMAGE)" THEME_TAGLINE="$(THEME_TAGLINE)" \
	   THEME_ARC="$(THEME_ARC)" THEME_TITLE="$(THEME_TITLE)" \
	   DRIVE_URL="https://drive.google.com/drive/folders/178ylieiRtCYsOtrr-8wTmd2hB3oymsNW" $(LAUNCHER)/release.sh

# ---------------------------------------------------------------- site (GitHub Pages)
# Todo push no master que muda site/** já publica sozinho (.github/workflows/site-pages.yml).
SITE_PORT     ?= 8000

site: ## Abre o site localmente em http://localhost:8000 (SITE_PORT=...)
	@echo ">> site em http://localhost:$(SITE_PORT)  (Ctrl+C para parar)"
	@cd site && python3 -m http.server $(SITE_PORT) --bind 127.0.0.1

site-deploy: ## Publica o site no GitHub Pages agora (usa o que já está no master do GitHub)
	@command -v gh >/dev/null || { echo "instale o GitHub CLI (gh) e rode: gh auth login"; exit 1; }
	@git fetch -q origin master && [ -z "$$(git diff --name-only origin/master -- site; git ls-files -o --exclude-standard site)" ] || \
	   echo ">> aviso: site/ local difere do origin/master — faça commit e push antes, senão publica a versão antiga"
	@gh workflow run site-pages.yml --ref master
	@sleep 3; gh run watch $$(gh run list --workflow=site-pages.yml --limit 1 --json databaseId -q '.[0].databaseId') --exit-status
	@echo ">> publicado: https://devalexandre.github.io/perdidos/"

# ---------------------------------------------------------------- docker (servidor + PostgreSQL)
infra/.env:
	@cp infra/.env.example infra/.env && echo ">> criado infra/.env a partir do exemplo — troque a senha antes de produção"

up: infra/.env ## Sobe servidor do jogo + PostgreSQL no Docker (porta UDP 7777)
	@$(COMPOSE) up -d --build
	@$(COMPOSE) ps

down: infra/.env ## Derruba os containers (mantém os dados)
	@$(COMPOSE) down

logs: infra/.env ## Acompanha os logs do servidor do jogo
	@$(COMPOSE) logs -f game-server

ps: infra/.env ## Estado dos containers
	@$(COMPOSE) ps

db-shell: infra/.env ## Abre o psql no banco
	@$(COMPOSE) exec postgres sh -c 'psql -U "$$POSTGRES_USER" -d "$$POSTGRES_DB"'

db-reset: infra/.env ## APAGA o banco e recria com infra/db/schema.sql (só desenvolvimento)
	@read -p "Apagar TODOS os dados do banco? [s/N] " ok && [ "$$ok" = "s" ]
	@$(COMPOSE) rm -sfv postgres && docker volume rm -f perdidos_pgdata && $(COMPOSE) up -d postgres

clean: ## Remove build/ e .run/
	@rm -rf $(BUILD) $(RUN_DIR)

# Deploy da Lista de Espera no Render (Gratuito)

Este guia ensina como colocar a API da **Lista de Espera** rodando 24/7 no [Render](https://render.com) (plano gratuito), sem precisar manter o servidor ou o ngrok rodando no seu computador.

---

## 1. O que já está preparado no projeto

- **`render.yaml`**: Arquivo de blueprint na raiz do repositório configurado para Go.
- **`launcher/server/Dockerfile`**: Alternativa caso prefira deploy via Docker.
- **Porta dinâmica (`PORT`)**: O servidor detecta automaticamente a porta fornecida pelo Render.
- **`healthCheckPath` (`/api/health`)**: Rota pronta para verificação de status pelo Render.
- **CORS dinâmico**: Aceita a origem configurada em `PERDIDOS_SITE_ORIGIN` (ou origens separadas por vírgula).

---

## 2. Como criar o serviço no Render

### Opção A: Pelo Blueprint (`render.yaml`) — Mais Fácil
1. Acesse o [dashboard do Render](https://dashboard.render.com).
2. Clique em **New +** > **Blueprint**.
3. Conecte o repositório do GitHub (`devalexandre/game-mmo`).
4. O Render lerá o `render.yaml` automaticamente.
5. Preencha o valor da variável **`PERDIDOS_WAITLIST_DATABASE_URL`** com a URL do seu PostgreSQL (ex: Neon).
6. Clique em **Apply**.

---

### Opção B: Criar Web Service Manualmente
1. No [Render Dashboard](https://dashboard.render.com), clique em **New +** > **Web Service**.
2. Conecte o repositório (`game-mmo`).
3. Configure os seguintes campos:
   - **Name:** `perdidos-waitlist`
   - **Region:** Qualquer uma (ex: `Oregon` ou `Frankfurt`)
   - **Root Directory:** `launcher/server`
   - **Runtime:** `Go`
   - **Build Command:** `go build -o authgate .`
   - **Start Command:** `./authgate -game=""`
   - **Instance Type:** `Free`
4. Na aba **Environment Variables**, adicione:
   - `PERDIDOS_WAITLIST_DATABASE_URL`: URL de conexão do PostgreSQL (Neon).
   - `PERDIDOS_SITE_ORIGIN`: `https://devalexandre.github.io`
   - `PERDIDOS_JWT_SECRET`: Uma string aleatória de 32+ caracteres.
   - `PERDIDOS_GAME_ADDR`: `""` (vazio, para não tentar conectar ao Godot).
5. Em **Advanced** > **Health Check Path**, defina:
   - `/api/health`
6. Clique em **Deploy Web Service**.

---

## 3. Site + API no mesmo serviço

O mesmo serviço serve o site (`site/`) em `/` e a API em `/api/*`: **https://perdidos.onrender.com**

- **Docker** (`Dockerfile` da raiz): copia `site/` para `/app/site` e define `PERDIDOS_SITE_DIR=/app/site`.
- **Runtime Go** (`render.yaml`): `PERDIDOS_SITE_DIR=../../site` (relativo a `launcher/server`).
- O formulário usa `data-endpoint="/api/waitlist"` (mesma origem, sem CORS). O servidor aceita
  automaticamente a própria origem; `PERDIDOS_SITE_ORIGIN` só importa para sites em outro domínio.
- O site só é servido quando `-game` está vazio (sem proxy para o Godot).

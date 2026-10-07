# Launcher do Perdidos

Aplicativo de desktop (Wails v3: Go + HTML/TypeScript) que:

1. **cria conta / entra** com e-mail e senha (API de contas, `launcher/server/`);
2. **verifica sempre a última versão** do jogo numa **pasta pública do Google Drive** (plano B: a própria API em `/api/latest`);
3. **baixa e instala** a versão nova: retoma o download se a rede cair, confere o SHA-256 e só troca a versão quando a nova está inteira;
4. **abre o jogo** com a sessão (`--token=<jwt>`) e o servidor do manifesto; o launcher minimiza e volta quando o jogo fecha.

```
launcher/
  main.go, service.go        app Wails (janela 980×620) e as ações chamadas pela tela
  frontend/                  tela (index.html, src/main.ts, src/style.css, fundo e fontes do jogo)
  internal/drive/            leitura da pasta pública do Drive (sem chave de API) + download
  internal/update/           latest.json, download com retomada, SHA-256, instalação atômica
  internal/account/          cliente da API de contas e sessão salva
  internal/settings/         pasta de instalação e launcher.json
  server/                    API de contas + porteiro (módulo Go separado, sem CGO)
  tests/auth_integration.sh  teste ponta a ponta: API + porteiro + servidor Godot + clientes
  release.sh                 empacota uma versão (chamado por `make release`)
```

## Compilar

Pré-requisitos (no Linux de quem compila):

- Go 1.26 e Node 20 (já usados no projeto);
- Linux: `webkit2gtk-4.1` e `gtk3` (no Arch: `sudo pacman -S webkit2gtk-4.1`; no Ubuntu/Debian:
  `sudo apt install libgtk-3-dev libwebkit2gtk-4.1-dev`). Compilamos com a tag `gtk3`, que roda em
  mais distribuições do que o GTK4 padrão do Wails beta;
- Windows: **nada a mais**. O launcher do Windows é compilado no Linux sem CGO (não precisa de mingw).
  Com o `wails3` no PATH o `.exe` sai com ícone e manifesto; sem ele, sai sem ícone (funciona igual).

```bash
make launcher           # build/launcher/perdidos-launcher        (Linux)
make launcher-windows   # build/launcher/PerdidosLauncher.exe      (Windows 10/11, usa o WebView2 do sistema)
make auth               # build/auth/perdidos-auth                 (API de contas + porteiro)
make launcher-test      # testes Go + integração com o servidor Godot
```

Para distribuir: mande o `PerdidosLauncher.exe` (Windows) ou o `perdidos-launcher` (Linux) para os
amigos. Eles não precisam mais do zip do jogo: o launcher baixa sozinho.

## Onde o launcher instala

| Sistema | Pasta |
|---|---|
| Windows | `%LOCALAPPDATA%\Perdidos` |
| Linux | `~/.local/share/perdidos` (ou `$XDG_DATA_HOME/perdidos`) |

Dentro dela: `installed.json` (versão ativa), `versions/<versão>/` (o jogo), `downloads/` (zip e `.part`
para retomar), `launcher.json` (configuração), `session.json` (sessão, só o usuário lê) e `launcher.log`.

**Troca atômica:** o zip é extraído em `versions/.staging-*`; só depois de completo ele vira
`versions/<versão>` e o `installed.json` é regravado (arquivo temporário + rename). Se o PC desligar no
meio, a versão anterior continua funcionando e a sobra é apagada na próxima abertura.

## Configurar a pasta do Drive e a API

Padrões compilados no launcher:

- pasta do Drive: `178ylieiRtCYsOtrr-8wTmd2hB3oymsNW`
  (<https://drive.google.com/drive/folders/178ylieiRtCYsOtrr-8wTmd2hB3oymsNW>);
- API de contas: `https://poetic-calculably-nayeli.ngrok-free.dev` (o mesmo domínio do jogo; o porteiro
  separa `/api/*` do WebSocket).

Para trocar sem recompilar, edite `launcher.json` na pasta de instalação:

```json
{
  "remember_email": true,
  "email": "eu@exemplo.com",
  "drive_folder_id": "https://drive.google.com/drive/folders/OUTRO_ID",
  "api_base": "https://outro-dominio.ngrok-free.dev"
}
```

(`drive_folder_id` aceita o ID ou o link inteiro; `"-"` desliga o Drive e usa só a API.)
Para mudar o padrão de todos, compile com
`-ldflags "-X perdidos/launcher/internal/settings.DefaultDriveFolder=<id> -X perdidos/launcher/internal/settings.DefaultAPIBase=https://..."`.
Variáveis de ambiente (testes): `PERDIDOS_HOME`, `PERDIDOS_DRIVE_FOLDER`, `PERDIDOS_API`.

### Login com Google no launcher e no Android

O login por e-mail/senha e o cadastro continuam disponíveis. Google abre uma página de autenticação
no navegador do sistema; o servidor valida o ID token e devolve a mesma sessão JWT usada pelo jogo.
O APK usa esse mesmo fluxo web e não incorpora segredo OAuth.

- No Google Cloud, use um cliente OAuth do tipo **Web application** e cadastre como origem JavaScript
  `https://poetic-calculably-nayeli.ngrok-free.dev` (ou a URL pública configurada em `NGROK_URL`).
- Coloque o JSON do cliente na raiz com o nome `client_secret_*.json`. O `.gitignore` exclui esses
  arquivos; o `Makefile` lê apenas `web.client_id` para configurar o servidor.
- Inicie/reinicie a API com `make serve-ngrok`. Para informar o ID manualmente, use
  `make serve-ngrok GOOGLE_CLIENT_ID=<client-id-web>`; esse ID é público. O `client_secret` não é
  necessário nesse fluxo e nunca deve ser incluído no APK, launcher ou repositório.
- A API precisa de saída HTTPS para `oauth2.googleapis.com/tokeninfo`. O navegador e o app recebem
  apenas o JWT de jogo após a verificação da assinatura/audience pelo Google, e o backend ainda
  exige esse JWT no handshake.

Se a tela do ngrok mostrar um aviso de visita, prossiga no navegador; a autenticação acontece na
origem pública autorizada. Em outro domínio, atualize a origem JavaScript no Google Cloud e use o
mesmo domínio em `NGROK_URL`.

## Publicar uma versão no Drive (passo a passo)

1. Rode:

   ```bash
   make release VERSION=0.1.3 NOTES="Grupo, troca e pergaminho de volta."
   ```

  Isso grava `config/version="0.1.3"` em `game/project.godot`, exporta Windows, Linux e Android e cria em
   `build/release/`:
   - `Perdidos-0.1.3-windows.zip` e `Perdidos-0.1.3-linux.zip` (com `version.txt` dentro);
  - `Perdidos-0.1.3-android.apk`;
  - `latest.json` (versão, nome, SHA-256 e tamanho dos arquivos, notas e servidor);
   - `COMO-PUBLICAR.txt` (este passo a passo).

2. Abra a pasta do Drive logado na sua conta. Ela precisa estar como **"Qualquer pessoa com o link: Leitor"**.
3. Suba **os dois zips e o APK Android** antes do manifesto. Os zips podem ficar na raiz da pasta ou
  nas subpastas `windows/` e `linux/`; o launcher procura nos dois lugares. Espere terminar.
4. Só então suba o **`latest.json` na raiz**. Se já existir um, use *Gerenciar versões → Enviar nova
   versão* (ou apague o antigo antes). Nunca deixe dois `latest.json`.
5. Confira numa aba anônima: `https://drive.google.com/embeddedfolderview?id=<ID-da-pasta>` deve listar
  os quatro arquivos com o nome exato.
6. Abra o launcher: aparece "Nova versão 0.1.3 disponível" e o botão **Atualizar**.

Formato do `latest.json`:

```json
{
  "version": "0.1.3",
  "files": {
    "windows": { "name": "Perdidos-0.1.3-windows.zip", "sha256": "…64 hex…", "size": 123, "exe": "Perdidos.exe" },
    "linux":   { "name": "Perdidos-0.1.3-linux.zip",   "sha256": "…64 hex…", "size": 123, "exe": "Perdidos.x86_64" },
    "android": { "name": "Perdidos-0.1.3-android.apk", "sha256": "…64 hex…", "size": 123 }
  },
  "notes": "O que mudou (aparece em Novidades).",
  "server": "poetic-calculably-nayeli.ngrok-free.dev",
  "published": "2026-10-01T12:00:00Z"
}
```

Opcional por arquivo: `"url"` (baixa de outro lugar em vez do Drive).

**Plano B:** o `make serve-ngrok` serve `build/release/latest.json` em `/api/latest`. Se o Drive mudar o
HTML ou estiver fora, o launcher lê a versão da API e ainda procura os zips no Drive pelo nome (ou na
`url`, se você colocar).

### Como o launcher lê o Drive sem chave de API

- Lista a pasta por `https://drive.google.com/embeddedfolderview?id=<ID>` (HTML com nome e id de cada
  arquivo e subpasta).
- Baixa por `https://drive.usercontent.google.com/download?id=<ID>&export=download&confirm=t`. Arquivo
  grande pode vir com a página "não foi possível verificar vírus"; o launcher lê o formulário dessa
  página e segue o link de download. O download aceita `Range`, então retoma de onde parou.
- Isso **não é uma API oficial**: o Google pode mudar o HTML ou limitar downloads de arquivos muito
  baixados (cota diária). Por isso existe o plano B.

## API de contas e porteiro (`launcher/server`)

Um binário só (`perdidos-auth`), porta 8080:

| Rota | O que faz |
|---|---|
| `POST /api/register` `{"email","password"}` | cria a conta (senha ≥ 8, e-mail validado) e devolve `{"token","account_id","email","expires_at"}` |
| `POST /api/login` | mesmo retorno; senha errada → 401 "E-mail ou senha incorretos." |
| `GET /api/latest` | o `latest.json` de `build/release/` (404 = nenhuma versão publicada) |
| `GET /api/health` | `{"ok":true}` |
| qualquer outra | **proxy reverso WebSocket** para o servidor Godot (`127.0.0.1:7777`) |

- **JWT HS256** com `account_id`, `email`, `iat` e `exp` (12 h). O segredo fica em
  `~/.config/perdidos/secrets.env` (`PERDIDOS_JWT_SECRET`), criado na primeira vez com `chmod 600`;
  nunca vai para o repositório nem para o log. O servidor Godot lê o mesmo arquivo.
- **Senhas com argon2id** (m=64 MiB, t=3, p=2; formato `$argon2id$...`, compatível com `infra/db/schema.sql`).
- **Limites:** 30 pedidos/min por IP nas rotas de conta; 5 contas novas/hora por IP; 8 senhas erradas
  em 15 min bloqueiam aquele e-mail por 15 min (HTTP 429 com `Retry-After`). Atrás do ngrok o IP real
  vem do `X-Forwarded-For` (só aceito quando a conexão vem de 127.0.0.1).
- **Logs** sem senha nem token; e-mail mascarado (`an***@gmail.com`).
- **Armazenamento: SQLite** em `.run/accounts.db` (driver Go puro, `modernc.org/sqlite`). Escolhemos
  SQLite porque o Postgres do `infra/` não está em uso: o jogo ainda salva personagens em JSON e o
  `make serve-ngrok` não sobe Docker. A tabela tem as mesmas colunas de `accounts` do
  `infra/db/schema.sql` e o código usa uma interface `Store`, então trocar para Postgres depois é
  só escrever outra implementação.

## Jogo com login (`--require-auth`)

- O `make serve-ngrok` sobe: servidor Godot WebSocket **com `--require-auth`** (porta 7777) + API e
  porteiro (porta 8080) e aponta o ngrok para a **8080**. `make serve-ngrok NO_AUTH=1` volta ao modo
  antigo (sem login).
- O cliente manda o token no handshake (`Net._srv_hello`). O servidor confere HMAC-SHA256 e validade
  (`HMACContext` da Godot) e liga o **nome do personagem à conta**: o primeiro que entra com um nome
  vira dono; outra conta recebe "Esse personagem pertence a outra conta". Os donos ficam em
  `<pasta dos saves>/character_owners.json`. Personagens que já existiam ficam com quem entrar
  primeiro com eles depois da mudança.
- Sem token → "Este servidor exige login. Abra o jogo pelo launcher."
- O executável exportado aberto **sem** o launcher mostra a tela "Abra pelo launcher".
- `make run`, `make run-dev`, `make test` e o editor continuam **sem** login (nada muda).

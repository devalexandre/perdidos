# Servidor público pelo Cloudflare Tunnel

Alternativa ao ngrok para expor o servidor local (jogo por WebSocket + API de contas/porteiro na porta 8080).
O jogo e a API sobem iguais nos três modos; só muda o túnel.

| Comando | Endereço | Precisa de domínio na Cloudflare? |
|---|---|---|
| `make serve-ngrok` | `poetic-calculably-nayeli.ngrok-free.dev` (fixo) | Não |
| `make serve-cloudflare` | `perdidos-dev.dev2learn.com` (fixo, `CF_HOST`) | **Sim** |
| `make serve-cloudflare-quick` | `https://<aleatório>.trycloudflare.com` (muda a cada vez) | Não |

## Túnel nomeado (`make serve-cloudflare`)

Configuração em `~/.cloudflared/config.yml` (túnel `perdidos-dev`, `CF_TUNNEL`):

```yaml
tunnel: 164dd27f-ed48-448b-8f12-cd46e29c7dd9
credentials-file: /home/devalexandre/.cloudflared/164dd27f-ed48-448b-8f12-cd46e29c7dd9.json
ingress:
  - hostname: perdidos-dev.dev2learn.com
    service: http://localhost:8080
  - service: http_status:404
```

WebSocket passa pelo túnel sem configuração extra.

**Pré-requisito: o DNS do domínio precisa estar na Cloudflare.** Em 07/10/2026 o `dev2learn.com` usava os
nameservers da Umbler, então `perdidos-dev.dev2learn.com` não resolvia, mesmo com o túnel conectado.
A Cloudflare não aceita delegar só um subdomínio no plano grátis. Opções:

1. **Mover o DNS do `dev2learn.com` para a Cloudflare** (plano Free): adicionar o site no painel, conferir
   se todos os registros atuais (site, e-mail/MX, SPF/DKIM) foram importados, e trocar os nameservers na Umbler
   pelos dois que a Cloudflare indicar. Depois: `cloudflared tunnel route dns perdidos-dev perdidos-dev.dev2learn.com`.
2. **Usar um domínio só do jogo** registrado ou apontado para a Cloudflare (ex.: comprado no Cloudflare Registrar,
   a preço de custo). Depois: trocar `hostname` no `config.yml`, `CF_HOST` no Makefile e rodar o `route dns`.

Conferir: `dig +short perdidos-dev.dev2learn.com` deve responder, e `curl https://perdidos-dev.dev2learn.com/api/health` deve dar 200.

O alvo recusa subir se outro `cloudflared tunnel run perdidos-dev` já estiver rodando.

## Quick Tunnel (`make serve-cloudflare-quick`)

Sem conta e sem domínio: o `cloudflared` mostra um endereço `https://<aleatório>.trycloudflare.com` ao subir.
Bom para testes rápidos. Limitações:

- O endereço muda a cada vez: é preciso passar o novo endereço para quem vai testar
  (`--host=wss://<endereço>` no cliente, ou `SERVER_URL=<endereço> make clients`).
- Login com Google não funciona (a URL pública não é conhecida antes de subir e não está autorizada no Google).
- Sem garantia de disponibilidade; feito para desenvolvimento.

## Login com Google no domínio novo

Se o login com Google for usado pelo túnel nomeado, autorize `https://perdidos-dev.dev2learn.com` no cliente
OAuth do Google Cloud (origem e URI de redirecionamento `/auth/google`), como foi feito para o ngrok.

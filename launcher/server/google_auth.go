package main

import (
	"context"
	"crypto/rand"
	"encoding/base64"
	"encoding/json"
	"errors"
	"html/template"
	"io"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"time"
)

const (
	googleFlowTTL       = 5 * time.Minute
	googleTokenInfoURL  = "https://oauth2.googleapis.com/tokeninfo"
	maxGoogleTokenBytes = 8192
)

type googleFlow struct {
	createdAt time.Time
	working   bool
	session   *tokenResponse
	errCode   string
	errText   string
}

type googleStartResponse struct {
	FlowID   string `json:"flow_id"`
	LoginURL string `json:"login_url"`
}

type googleCredentialRequest struct {
	FlowID     string `json:"flow_id"`
	Credential string `json:"credential"`
}

type googleIdentity struct {
	Subject string
	Email   string
}

type googleTokenInfo struct {
	Audience      string          `json:"aud"`
	Email         string          `json:"email"`
	EmailVerified json.RawMessage `json:"email_verified"`
	Expires       json.RawMessage `json:"exp"`
	Issuer        string          `json:"iss"`
	Subject       string          `json:"sub"`
}

var googleLoginPage = template.Must(template.New("google-login").Parse(`<!doctype html>
<html lang="pt-BR"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Entrar no Perdidos</title>
<script src="https://accounts.google.com/gsi/client" async defer></script>
<style>
*{box-sizing:border-box}body{margin:0;min-height:100vh;display:grid;place-items:center;background:#18110c;color:#f0dfbd;font:16px system-ui,sans-serif}
main{width:min(420px,calc(100% - 32px));padding:32px 26px;background:#291a10;border:2px solid #a6793e;border-radius:8px;text-align:center;box-shadow:0 20px 55px #0009}
h1{margin:0 0 8px;color:#e2b95f;font:700 30px Georgia,serif}p{line-height:1.5}#button{display:flex;justify-content:center;margin-top:24px}#status{min-height:24px;color:#f0c17b}
</style></head><body><main><h1>Perdidos</h1><p>Continue com sua conta Google. Depois, volte ao jogo.</p>
<div id="g_id_onload" data-client_id="{{.ClientID}}" data-callback="onGoogleCredential" data-auto_prompt="false"></div>
<div id="button" class="g_id_signin" data-type="standard" data-size="large" data-theme="filled_blue" data-text="continue_with" data-shape="rectangular" data-logo_alignment="left"></div>
<p id="status" role="status">Aguardando autenticação Google…</p></main>
<script>
const flowID={{.FlowID}};
async function onGoogleCredential(response){
 const status=document.getElementById("status");
 status.textContent="Validando sua conta…";
 try{
  const result=await fetch("/api/google/complete",{method:"POST",headers:{"Content-Type":"application/json","ngrok-skip-browser-warning":"1"},body:JSON.stringify({flow_id:flowID,credential:response.credential}),cache:"no-store"});
  const data=await result.json();
  if(result.ok) {
      status.textContent="Conta confirmada. Redirecionando para o jogo...";
      setTimeout(function(){
          window.location.href="intent://auth#Intent;scheme=perdidos;package=org.godotengine.perdidos;end";
          window.close();
      }, 500);
  } else {
      status.textContent=data.message||"Não foi possível validar sua conta.";
  }
 }catch(_){status.textContent="Falha de conexão. Feche esta aba e tente de novo.";}
}
</script></body></html>`))

func (s *Server) googleEnabled() bool {
	base, err := url.Parse(s.cfg.PublicBaseURL)
	return strings.TrimSpace(s.cfg.GoogleClientID) != "" && err == nil && base.Scheme == "https" && base.Host != ""
}

func (s *Server) handleGoogleConfig(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, map[string]bool{"enabled": s.googleEnabled()})
}

func (s *Server) handleGoogleStart(w http.ResponseWriter, r *http.Request) {
	if !s.googleEnabled() {
		writeError(w, http.StatusServiceUnavailable, "google_disabled", "Login Google ainda não está configurado no servidor.")
		return
	}
	if !s.allow(w, s.googleStarts, "ip:"+clientIP(r)) {
		return
	}
	var raw [32]byte
	if _, err := rand.Read(raw[:]); err != nil {
		s.internal(w, "google_flow_random", err)
		return
	}
	flowID := base64.RawURLEncoding.EncodeToString(raw[:])
	now := s.now()
	s.googleMu.Lock()
	for id, flow := range s.googleFlows {
		if now.Sub(flow.createdAt) > googleFlowTTL {
			delete(s.googleFlows, id)
		}
	}
	if len(s.googleFlows) >= 4096 {
		s.googleMu.Unlock()
		writeError(w, http.StatusServiceUnavailable, "google_busy", "Muitas tentativas de login. Tente novamente em instantes.")
		return
	}
	s.googleFlows[flowID] = &googleFlow{createdAt: now}
	s.googleMu.Unlock()

	loginURL := strings.TrimRight(s.cfg.PublicBaseURL, "/") + "/auth/google?flow=" + url.QueryEscape(flowID)
	writeJSON(w, http.StatusCreated, googleStartResponse{FlowID: flowID, LoginURL: loginURL})
}

func (s *Server) handleGooglePage(w http.ResponseWriter, r *http.Request) {
	flowID := r.URL.Query().Get("flow")
	if !s.googleFlowPending(flowID) || !s.googleEnabled() {
		http.Error(w, "Este pedido de login expirou. Volte ao app e tente de novo.", http.StatusGone)
		return
	}
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	w.Header().Set("Cache-Control", "no-store")
	w.Header().Set("Referrer-Policy", "no-referrer")
	w.Header().Set("X-Content-Type-Options", "nosniff")
	w.Header().Set("X-Frame-Options", "DENY")
	_ = googleLoginPage.Execute(w, struct{ ClientID, FlowID string }{s.cfg.GoogleClientID, flowID})
}

func (s *Server) handleGoogleComplete(w http.ResponseWriter, r *http.Request) {
	if !s.googleEnabled() || !s.allow(w, s.googleVerify, "ip:"+clientIP(r)) {
		if !s.googleEnabled() {
			writeError(w, http.StatusServiceUnavailable, "google_disabled", "Login Google ainda não está configurado no servidor.")
		}
		return
	}
	r.Body = http.MaxBytesReader(w, r.Body, maxGoogleTokenBytes+1024)
	var req googleCredentialRequest
	dec := json.NewDecoder(r.Body)
	dec.DisallowUnknownFields()
	if err := dec.Decode(&req); err != nil || req.FlowID == "" || req.Credential == "" || len(req.Credential) > maxGoogleTokenBytes {
		writeError(w, http.StatusBadRequest, "google_bad_request", "Pedido de login Google inválido.")
		return
	}
	s.googleMu.Lock()
	flow := s.googleFlows[req.FlowID]
	if flow == nil || s.now().Sub(flow.createdAt) > googleFlowTTL || flow.session != nil || flow.errCode != "" || flow.working {
		s.googleMu.Unlock()
		writeError(w, http.StatusGone, "google_flow_expired", "Este pedido de login expirou. Volte ao app e tente de novo.")
		return
	}
	flow.working = true
	s.googleMu.Unlock()

	ctx, cancel := context.WithTimeout(r.Context(), 8*time.Second)
	identity, err := s.verifyGoogleCredential(ctx, req.Credential)
	cancel()
	if err == nil {
		var acc Account
		acc, err = s.accountForGoogleIdentity(r.Context(), identity)
		if err == nil {
			_ = s.store.TouchLogin(r.Context(), acc.ID)
			var session tokenResponse
			session, err = s.makeToken(acc)
			if err == nil {
				s.googleMu.Lock()
				flow.session = &session
				flow.working = false
				s.googleMu.Unlock()
				s.log.Info("google_login_ok", "account_id", acc.ID, "email", maskEmail(acc.Email), "ip", clientIP(r))
				writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
				return
			}
		}
	}
	s.googleMu.Lock()
	flow.working = false
	flow.errCode = "google_invalid"
	flow.errText = "Não foi possível validar sua conta Google. Volte ao app e tente novamente."
	s.googleMu.Unlock()
	s.log.Info("google_login_failed", "ip", clientIP(r))
	writeError(w, http.StatusUnauthorized, "google_invalid", "Não foi possível validar sua conta Google. Volte ao app e tente novamente.")
}

func (s *Server) handleGooglePoll(w http.ResponseWriter, r *http.Request) {
	if !s.allow(w, s.googlePolls, "ip:"+clientIP(r)) {
		return
	}
	flowID := r.URL.Query().Get("flow")
	s.googleMu.Lock()
	flow := s.googleFlows[flowID]
	if flow == nil || s.now().Sub(flow.createdAt) > googleFlowTTL {
		delete(s.googleFlows, flowID)
		s.googleMu.Unlock()
		writeError(w, http.StatusGone, "google_flow_expired", "Este pedido de login expirou. Volte ao app e tente de novo.")
		return
	}
	if flow.working || flow.session == nil && flow.errCode == "" {
		s.googleMu.Unlock()
		writeJSON(w, http.StatusAccepted, map[string]bool{"pending": true})
		return
	}
	delete(s.googleFlows, flowID)
	result, code, message := flow.session, flow.errCode, flow.errText
	s.googleMu.Unlock()
	if code != "" {
		writeError(w, http.StatusUnauthorized, code, message)
		return
	}
	writeJSON(w, http.StatusOK, result)
}

func (s *Server) googleFlowPending(flowID string) bool {
	s.googleMu.Lock()
	defer s.googleMu.Unlock()
	flow := s.googleFlows[flowID]
	return flow != nil && s.now().Sub(flow.createdAt) <= googleFlowTTL && flow.session == nil && flow.errCode == ""
}

func (s *Server) verifyGoogleCredential(ctx context.Context, credential string) (googleIdentity, error) {
	if len(credential) == 0 || len(credential) > maxGoogleTokenBytes {
		return googleIdentity{}, errors.New("invalid token size")
	}
	endpoint := s.cfg.GoogleTokenInfoURL
	if endpoint == "" {
		endpoint = googleTokenInfoURL
	}
	u, err := url.Parse(endpoint)
	if err != nil || u.Scheme != "https" || u.Host == "" {
		return googleIdentity{}, errors.New("invalid token verifier endpoint")
	}
	q := u.Query()
	q.Set("id_token", credential)
	u.RawQuery = q.Encode()
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, u.String(), nil)
	if err != nil {
		return googleIdentity{}, err
	}
	resp, err := s.googleHTTP.Do(req)
	if err != nil {
		return googleIdentity{}, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return googleIdentity{}, errors.New("Google rejected ID token")
	}
	var info googleTokenInfo
	if err := json.NewDecoder(io.LimitReader(resp.Body, 16*1024)).Decode(&info); err != nil {
		return googleIdentity{}, err
	}
	var verified bool
	if len(info.EmailVerified) > 0 {
		if json.Unmarshal(info.EmailVerified, &verified) != nil {
			var text string
			_ = json.Unmarshal(info.EmailVerified, &text)
			verified = text == "true"
		}
	}
	var expires int64
	if json.Unmarshal(info.Expires, &expires) != nil {
		var text string
		_ = json.Unmarshal(info.Expires, &text)
		expires, _ = strconv.ParseInt(text, 10, 64)
	}
	if expires <= s.now().Unix() || info.Audience != s.cfg.GoogleClientID ||
		(info.Issuer != "accounts.google.com" && info.Issuer != "https://accounts.google.com") ||
		!verified || info.Subject == "" {
		return googleIdentity{}, errors.New("Google ID token claims did not match")
	}
	email, err := normalizeEmail(info.Email)
	if err != nil {
		return googleIdentity{}, errors.New("Google account has no verified email")
	}
	return googleIdentity{Subject: info.Subject, Email: email}, nil
}

func (s *Server) accountForGoogleIdentity(ctx context.Context, identity googleIdentity) (Account, error) {
	acc, err := s.store.FindByEmail(ctx, identity.Email)
	if err == nil {
		return acc, nil
	}
	if err != errNotFound {
		return Account{}, err
	}
	var random [32]byte
	if _, err := rand.Read(random[:]); err != nil {
		return Account{}, err
	}
	hash, err := s.hash(ctx, base64.RawURLEncoding.EncodeToString(random[:]))
	if err != nil {
		return Account{}, err
	}
	acc, err = s.store.CreateAccount(ctx, identity.Email, hash)
	if err == errEmailTaken {
		return s.store.FindByEmail(ctx, identity.Email)
	}
	if err == nil {
		s.log.Info("google_account_created", "account_id", acc.ID, "email", maskEmail(acc.Email))
	}
	return acc, err
}

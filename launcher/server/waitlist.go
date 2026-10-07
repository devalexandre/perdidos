package main

import (
	"context"
	"encoding/json"
	"io"
	"net/http"
	"net/mail"
	"strings"
	"time"
	"unicode"
	"unicode/utf8"
)

type WaitlistConfig struct {
	Store  WaitlistStore
	Origin string
}

func (s *Server) handleWaitlist(w http.ResponseWriter, r *http.Request) {
	origin := r.Header.Get("Origin")
	sameOrigin := origin == "https://"+r.Host || origin == "http://"+r.Host
	if origin != "" && !sameOrigin && !isAllowedOrigin(origin, s.cfg.Waitlist.Origin) {
		writeError(w, http.StatusForbidden, "origin_denied", "Origem não permitida.")
		return
	}
	if origin != "" {
		w.Header().Set("Access-Control-Allow-Origin", origin)
		w.Header().Set("Vary", "Origin")
	}
	if r.Method == http.MethodOptions {
		w.Header().Set("Access-Control-Allow-Methods", "POST, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, ngrok-skip-browser-warning")
		w.Header().Set("Access-Control-Max-Age", "600")
		w.WriteHeader(http.StatusNoContent)
		return
	}
	if allowed, _ := s.waitlistLimit.Allow(clientIP(r)); !allowed {
		w.Header().Set("Retry-After", "3600")
		writeError(w, http.StatusTooManyRequests, "rate_limited", "Muitas tentativas. Aguarde antes de tentar novamente.")
		return
	}
	if s.cfg.Waitlist.Store == nil {
		writeError(w, http.StatusServiceUnavailable, "unavailable", "A lista de espera está temporariamente indisponível. Tente novamente mais tarde.")
		return
	}
	if r.Header.Get("Content-Type") != "application/json" {
		writeError(w, http.StatusUnsupportedMediaType, "content_type", "Envie os dados do formulário.")
		return
	}
	var input struct {
		Email    string `json:"email"`
		Name     string `json:"name"`
		Platform string `json:"platform"`
		Consent  bool   `json:"consent"`
		Website  string `json:"website"` // honeypot
	}
	decoder := json.NewDecoder(http.MaxBytesReader(w, r.Body, maxBodyBytes))
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(&input); err != nil || decoder.Decode(new(any)) != io.EOF {
		writeError(w, http.StatusBadRequest, "invalid_request", "Confira os dados e tente novamente.")
		return
	}
	if input.Website != "" {
		writeJSON(w, http.StatusAccepted, map[string]bool{"ok": true})
		return
	}
	email := strings.ToLower(strings.TrimSpace(input.Email))
	parsed, err := mail.ParseAddress(email)
	if err != nil || parsed.Address != email || len(email) > maxEmailLen || strings.ContainsAny(email, "\r\n") || !strings.Contains(email, ".") {
		writeError(w, http.StatusBadRequest, "invalid_email", "Digite um e-mail válido.")
		return
	}
	name := strings.TrimSpace(input.Name)
	if utf8.RuneCountInString(name) > 80 || strings.IndexFunc(name, unicode.IsControl) >= 0 {
		writeError(w, http.StatusBadRequest, "invalid_name", "O nome deve ter até 80 caracteres.")
		return
	}
	if !input.Consent {
		writeError(w, http.StatusBadRequest, "consent_required", "Confirme que deseja receber novidades sobre Perdidos.")
		return
	}
	if input.Platform != "windows" && input.Platform != "linux" && input.Platform != "android" && input.Platform != "indeciso" {
		writeError(w, http.StatusBadRequest, "invalid_platform", "Escolha uma plataforma.")
		return
	}
	ctx, cancel := context.WithTimeout(r.Context(), 10*time.Second)
	defer cancel()
	_, err = s.cfg.Waitlist.Store.Subscribe(ctx, WaitlistEntry{Email: email, Name: name, Platform: input.Platform})
	if err != nil {
		s.log.Warn("waitlist_save_failed") // never log credentials or subscriber data
		writeError(w, http.StatusServiceUnavailable, "save_failed", "Não conseguimos salvar sua inscrição. Tente novamente em instantes.")
		return
	}
	// Same reply for duplicates; no e-mail-address enumeration.
	writeJSON(w, http.StatusAccepted, map[string]any{"ok": true, "message": "Inscrição recebida! Você está na lista de espera de Perdidos."})
}

func isAllowedOrigin(origin, allowed string) bool {
	if allowed == "" || allowed == "*" || origin == allowed {
		return true
	}
	for _, item := range strings.Split(allowed, ",") {
		if strings.TrimSpace(item) == origin {
			return true
		}
	}
	return false
}

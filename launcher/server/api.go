package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"math"
	"net"
	"net/http"
	"net/http/httputil"
	"net/mail"
	"net/url"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"sync"
	"time"
	"unicode/utf8"
)

const (
	minPasswordLen = 8
	maxPasswordLen = 128
	maxEmailLen    = 254
	maxBodyBytes   = 4 << 10
)

// Config of the API + gatekeeper.
type Config struct {
	Waitlist           WaitlistConfig
	Secret             []byte
	TokenTTL           time.Duration
	LatestPath         string   // latest.json served at /api/latest ("" or missing file = 404)
	GameURL            *url.URL // Godot WebSocket server (everything that is not /api goes there)
	GoogleClientID     string
	PublicBaseURL      string
	GoogleTokenInfoURL string
	GoogleHTTPClient   *http.Client
	AdminUserDataDir   string
	AdminServerLog     string
	AdminAuthLog       string
	SiteDir            string // static site served at / when the game proxy is disabled ("" = off)
}

// Server holds the HTTP handlers.
type Server struct {
	cfg   Config
	store Store
	log   *slog.Logger
	now   func() time.Time

	waitlistLimit *RateLimiter
	ipLimit       *RateLimiter // any auth call, per IP
	registerLimit *RateLimiter // account creation, per IP
	emailFail     *RateLimiter // failed logins, per e-mail
	hashSem       chan struct{}
	googleMu      sync.Mutex
	googleFlows   map[string]*googleFlow
	googleStarts  *RateLimiter
	googlePolls   *RateLimiter
	googleVerify  *RateLimiter
	googleHTTP    *http.Client
	admin         *AdminServer
}

func NewServer(cfg Config, store Store, log *slog.Logger) *Server {
	googleHTTP := cfg.GoogleHTTPClient
	if googleHTTP == nil {
		googleHTTP = &http.Client{Timeout: 8 * time.Second}
	}
	admin := NewAdminServer(AdminConfig{
		UserDataDir: cfg.AdminUserDataDir,
		ServerLog:   cfg.AdminServerLog,
		AuthLog:     cfg.AdminAuthLog,
		Secret:      cfg.Secret,
	}, store, log)
	return &Server{
		cfg: cfg, store: store, log: log, now: time.Now,
		waitlistLimit: NewRateLimiter(5, time.Hour),
		ipLimit:       NewRateLimiter(30, time.Minute),
		registerLimit: NewRateLimiter(5, time.Hour),
		emailFail:     NewRateLimiter(8, 15*time.Minute),
		hashSem:       make(chan struct{}, 4), // argon2id uses 64 MiB per hash
		googleFlows:   map[string]*googleFlow{},
		googleStarts:  NewRateLimiter(10, time.Minute),
		googlePolls:   NewRateLimiter(120, time.Minute),
		googleVerify:  NewRateLimiter(20, time.Minute),
		googleHTTP:    googleHTTP,
		admin:         admin,
	}
}

// Handler routes /api/* to the API and everything else to the game (WebSocket reverse proxy).
func (s *Server) Handler() http.Handler {
	mux := http.NewServeMux()
	if s.admin != nil {
		s.admin.RegisterRoutes(mux)
	}
	mux.HandleFunc("POST /api/waitlist", s.handleWaitlist)
	mux.HandleFunc("OPTIONS /api/waitlist", s.handleWaitlist)
	mux.HandleFunc("POST /api/register", s.handleRegister)
	mux.HandleFunc("POST /api/login", s.handleLogin)
	mux.HandleFunc("GET /api/google/config", s.handleGoogleConfig)
	mux.HandleFunc("POST /api/google/start", s.handleGoogleStart)
	mux.HandleFunc("GET /api/google/poll", s.handleGooglePoll)
	mux.HandleFunc("POST /api/google/complete", s.handleGoogleComplete)
	mux.HandleFunc("GET /auth/google", s.handleGooglePage)
	mux.HandleFunc("GET /api/latest", s.handleLatest)
	mux.HandleFunc("GET /api/theme/{name}", s.handleTheme)
	mux.HandleFunc("GET /api/health", s.handleHealth)
	mux.HandleFunc("/api/", func(w http.ResponseWriter, r *http.Request) {
		writeError(w, http.StatusNotFound, "not_found", "Rota não encontrada.")
	})
	if s.cfg.GameURL != nil {
		mux.Handle("/", s.gameProxy())
	} else if s.cfg.SiteDir != "" {
		mux.Handle("/", http.FileServer(http.Dir(s.cfg.SiteDir)))
	}
	return mux
}

func (s *Server) gameProxy() http.Handler {
	p := httputil.NewSingleHostReverseProxy(s.cfg.GameURL)
	p.ErrorHandler = func(w http.ResponseWriter, r *http.Request, err error) {
		s.log.Warn("game_proxy_error", "err", err.Error(), "ip", clientIP(r))
		http.Error(w, "Servidor do jogo fora do ar.", http.StatusBadGateway)
	}
	return p
}

type credentials struct {
	Email    string `json:"email"`
	Password string `json:"password"`
}

type tokenResponse struct {
	Token     string `json:"token"`
	AccountID int64  `json:"account_id"`
	Email     string `json:"email"`
	ExpiresAt int64  `json:"expires_at"`
}

func (s *Server) handleRegister(w http.ResponseWriter, r *http.Request) {
	ip := clientIP(r)
	if !s.allow(w, s.ipLimit, "ip:"+ip) {
		s.log.Warn("register_rate_limited", "ip", ip)
		return
	}
	c, ok := readCredentials(w, r)
	if !ok {
		return
	}
	email, err := normalizeEmail(c.Email)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid_email", "E-mail inválido.")
		return
	}
	if msg := passwordProblem(c.Password); msg != "" {
		writeError(w, http.StatusBadRequest, "weak_password", msg)
		return
	}
	// Only well-formed sign-ups count toward the per-IP account creation limit.
	if !s.allow(w, s.registerLimit, "ip:"+ip) {
		s.log.Warn("register_rate_limited", "ip", ip)
		return
	}
	hash, err := s.hash(r.Context(), c.Password)
	if err != nil {
		s.internal(w, "hash", err)
		return
	}
	acc, err := s.store.CreateAccount(r.Context(), email, hash)
	if errors.Is(err, errEmailTaken) {
		s.log.Info("register_email_taken", "email", maskEmail(email), "ip", ip)
		writeError(w, http.StatusConflict, "email_taken", "Este e-mail já tem conta. Use \"Entrar\".")
		return
	}
	if err != nil {
		s.internal(w, "create_account", err)
		return
	}
	s.log.Info("register_ok", "account_id", acc.ID, "email", maskEmail(email), "ip", ip)
	s.issueToken(w, http.StatusCreated, acc)
}

func (s *Server) handleLogin(w http.ResponseWriter, r *http.Request) {
	ip := clientIP(r)
	if !s.allow(w, s.ipLimit, "ip:"+ip) {
		s.log.Warn("login_rate_limited", "ip", ip)
		return
	}
	c, ok := readCredentials(w, r)
	if !ok {
		return
	}
	email, err := normalizeEmail(c.Email)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid_email", "E-mail inválido.")
		return
	}
	if blocked, wait := s.emailFail.Blocked("email:" + email); blocked {
		s.log.Warn("login_email_locked", "email", maskEmail(email), "ip", ip)
		tooMany(w, wait)
		return
	}
	acc, err := s.store.FindByEmail(r.Context(), email)
	if err != nil && !errors.Is(err, errNotFound) {
		s.internal(w, "find_account", err)
		return
	}
	hash := acc.PasswordHash
	if errors.Is(err, errNotFound) {
		hash = dummyHash // same cost either way: no e-mail enumeration by timing
	}
	good, verr := s.verify(r.Context(), c.Password, hash)
	if verr != nil && !errors.Is(err, errNotFound) {
		s.internal(w, "verify", verr)
		return
	}
	if errors.Is(err, errNotFound) || !good {
		s.emailFail.Allow("email:" + email)
		s.log.Info("login_failed", "email", maskEmail(email), "ip", ip)
		writeError(w, http.StatusUnauthorized, "bad_credentials", "E-mail ou senha incorretos.")
		return
	}
	s.emailFail.Reset("email:" + email)
	_ = s.store.TouchLogin(r.Context(), acc.ID)
	s.log.Info("login_ok", "account_id", acc.ID, "ip", ip)
	s.issueToken(w, http.StatusOK, acc)
}

func (s *Server) issueToken(w http.ResponseWriter, status int, acc Account) {
	response, err := s.makeToken(acc)
	if err != nil {
		s.internal(w, "sign", err)
		return
	}
	writeJSON(w, status, response)
}

func (s *Server) makeToken(acc Account) (tokenResponse, error) {
	now := s.now()
	exp := now.Add(s.cfg.TokenTTL)
	tok, err := SignJWT(s.cfg.Secret, Claims{
		Sub: "account:" + strconv.FormatInt(acc.ID, 10), AccountID: acc.ID, Email: acc.Email,
		Iat: now.Unix(), Exp: exp.Unix(), Iss: jwtIssuer,
	})
	if err != nil {
		return tokenResponse{}, err
	}
	return tokenResponse{Token: tok, AccountID: acc.ID, Email: acc.Email, ExpiresAt: exp.Unix()}, nil
}

func (s *Server) handleLatest(w http.ResponseWriter, r *http.Request) {
	if s.cfg.LatestPath == "" {
		writeError(w, http.StatusNotFound, "no_release", "Nenhuma versão publicada.")
		return
	}
	data, err := os.ReadFile(s.cfg.LatestPath)
	if err != nil {
		writeError(w, http.StatusNotFound, "no_release", "Nenhuma versão publicada.")
		return
	}
	var probe map[string]any
	if json.Unmarshal(data, &probe) != nil {
		s.log.Error("latest_json_invalid", "path", s.cfg.LatestPath)
		writeError(w, http.StatusInternalServerError, "bad_release", "O latest.json do servidor está inválido.")
		return
	}
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Cache-Control", "no-store")
	w.Write(data)
}

// reThemeImage: only the files release.sh writes (theme-<id>.<ext>); no path separators, no "..".
var reThemeImage = regexp.MustCompile(`^theme-[a-z0-9][a-z0-9_-]{0,31}\.(jpg|jpeg|png|webp)$`)

// handleTheme serves the launcher theme image from the release folder (next to latest.json),
// the plan B when the Drive is down.
func (s *Server) handleTheme(w http.ResponseWriter, r *http.Request) {
	name := r.PathValue("name")
	if s.cfg.LatestPath == "" || !reThemeImage.MatchString(name) {
		writeError(w, http.StatusNotFound, "not_found", "Tema não encontrado.")
		return
	}
	f, err := os.Open(filepath.Join(filepath.Dir(s.cfg.LatestPath), name))
	if err != nil {
		writeError(w, http.StatusNotFound, "not_found", "Tema não encontrado.")
		return
	}
	defer f.Close()
	st, err := f.Stat()
	if err != nil || !st.Mode().IsRegular() {
		writeError(w, http.StatusNotFound, "not_found", "Tema não encontrado.")
		return
	}
	w.Header().Set("Cache-Control", "public, max-age=300")
	w.Header().Set("X-Content-Type-Options", "nosniff")
	http.ServeContent(w, r, name, st.ModTime(), f)
}

func (s *Server) handleHealth(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, map[string]any{"ok": true, "time": s.now().Unix()})
}

// ---------------------------------------------------------------- helpers

func (s *Server) allow(w http.ResponseWriter, rl *RateLimiter, key string) bool {
	ok, wait := rl.Allow(key)
	if !ok {
		tooMany(w, wait)
	}
	return ok
}

func tooMany(w http.ResponseWriter, wait time.Duration) {
	secs := int(math.Ceil(wait.Seconds()))
	if secs < 1 {
		secs = 1
	}
	w.Header().Set("Retry-After", strconv.Itoa(secs))
	mins := (secs + 59) / 60
	writeError(w, http.StatusTooManyRequests, "rate_limited",
		fmt.Sprintf("Muitas tentativas. Tente de novo em %d min.", mins))
}

func (s *Server) hash(ctx context.Context, pw string) (string, error) {
	select {
	case s.hashSem <- struct{}{}:
		defer func() { <-s.hashSem }()
	case <-ctx.Done():
		return "", ctx.Err()
	}
	return HashPassword(pw)
}

func (s *Server) verify(ctx context.Context, pw, hash string) (bool, error) {
	select {
	case s.hashSem <- struct{}{}:
		defer func() { <-s.hashSem }()
	case <-ctx.Done():
		return false, ctx.Err()
	}
	return VerifyPassword(pw, hash)
}

var dummyHash = func() string {
	h, err := HashPassword("perdidos-dummy-password")
	if err != nil {
		panic(err)
	}
	return h
}()

func (s *Server) internal(w http.ResponseWriter, op string, err error) {
	s.log.Error("internal_error", "op", op, "err", err.Error())
	writeError(w, http.StatusInternalServerError, "internal", "Erro no servidor. Tente de novo.")
}

func readCredentials(w http.ResponseWriter, r *http.Request) (credentials, bool) {
	var c credentials
	r.Body = http.MaxBytesReader(w, r.Body, maxBodyBytes)
	dec := json.NewDecoder(r.Body)
	dec.DisallowUnknownFields()
	if err := dec.Decode(&c); err != nil {
		writeError(w, http.StatusBadRequest, "bad_request", "Pedido inválido.")
		return c, false
	}
	return c, true
}

func normalizeEmail(raw string) (string, error) {
	e := strings.ToLower(strings.TrimSpace(raw))
	if e == "" || len(e) > maxEmailLen || strings.ContainsAny(e, " \t\r\n<>\"'") {
		return "", errors.New("invalid")
	}
	addr, err := mail.ParseAddress(e)
	if err != nil || addr.Address != e {
		return "", errors.New("invalid")
	}
	at := strings.LastIndexByte(e, '@')
	local, domain := e[:at], e[at+1:]
	if local == "" || len(local) > 64 || !strings.Contains(domain, ".") ||
		strings.HasPrefix(domain, ".") || strings.HasSuffix(domain, ".") || strings.Contains(domain, "..") {
		return "", errors.New("invalid")
	}
	return e, nil
}

func passwordProblem(pw string) string {
	n := utf8.RuneCountInString(pw)
	if n < minPasswordLen {
		return fmt.Sprintf("A senha precisa ter pelo menos %d caracteres.", minPasswordLen)
	}
	if len(pw) > maxPasswordLen {
		return fmt.Sprintf("A senha pode ter no máximo %d caracteres.", maxPasswordLen)
	}
	if strings.TrimSpace(pw) == "" {
		return "A senha não pode ser só espaços."
	}
	return ""
}

// maskEmail keeps logs useful without storing full addresses: "an***@gmail.com".
func maskEmail(e string) string {
	at := strings.LastIndexByte(e, '@')
	if at <= 0 {
		return "***"
	}
	keep := 2
	if at < keep {
		keep = at
	}
	return e[:keep] + "***" + e[at:]
}

// clientIP: behind the ngrok tunnel (loopback peer) the real address is in X-Forwarded-For.
func clientIP(r *http.Request) string {
	host, _, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil {
		host = r.RemoteAddr
	}
	if ip := net.ParseIP(host); ip != nil && ip.IsLoopback() {
		if xff := r.Header.Get("X-Forwarded-For"); xff != "" {
			first := strings.TrimSpace(strings.Split(xff, ",")[0])
			if net.ParseIP(first) != nil {
				return first
			}
		}
	}
	return host
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.Header().Set("Cache-Control", "no-store")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}

func writeError(w http.ResponseWriter, status int, code, msg string) {
	writeJSON(w, status, map[string]string{"error": code, "message": msg})
}

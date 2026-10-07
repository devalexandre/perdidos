// Package account talks to the accounts API (launcher/server) and keeps the session on disk.
package account

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"strings"
	"time"
)

// Session is what the launcher keeps after login (session.json, mode 0600).
type Session struct {
	Token     string `json:"token"`
	AccountID int64  `json:"account_id"`
	Email     string `json:"email"`
	ExpiresAt int64  `json:"expires_at"`
}

// Valid: not expired and with some margin left to start the game.
func (s Session) Valid(now time.Time) bool {
	return s.Token != "" && now.Add(5*time.Minute).Unix() < s.ExpiresAt
}

// UserError carries a message ready to show (pt-BR).
type UserError struct {
	Code    string
	Message string
}

func (e *UserError) Error() string { return e.Message }

// Client calls /api/register and /api/login.
type Client struct {
	Base string
	HTTP *http.Client
}

type GoogleFlow struct {
	ID       string `json:"flow_id"`
	LoginURL string `json:"login_url"`
}

func (c *Client) Register(ctx context.Context, email, password string) (Session, error) {
	return c.post(ctx, "/api/register", email, password)
}

func (c *Client) Login(ctx context.Context, email, password string) (Session, error) {
	return c.post(ctx, "/api/login", email, password)
}

func (c *Client) StartGoogleLogin(ctx context.Context) (GoogleFlow, error) {
	var flow GoogleFlow
	if strings.TrimSpace(c.Base) == "" {
		return flow, &UserError{"no_api", "O endereço do servidor de contas não está configurado."}
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, strings.TrimRight(c.Base, "/")+"/api/google/start", strings.NewReader("{}"))
	if err != nil {
		return flow, err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("ngrok-skip-browser-warning", "1")
	resp, err := c.httpClient().Do(req)
	if err != nil {
		return flow, &UserError{"offline", "Não foi possível falar com o servidor de contas. Tente novamente."}
	}
	defer resp.Body.Close()
	if resp.StatusCode >= 400 {
		var out struct {
			Error   string `json:"error"`
			Message string `json:"message"`
		}
		_ = json.NewDecoder(resp.Body).Decode(&out)
		if out.Message != "" {
			return flow, &UserError{out.Error, out.Message}
		}
		return flow, &UserError{"google_unavailable", "Login Google indisponível no servidor."}
	}
	if err := json.NewDecoder(resp.Body).Decode(&flow); err != nil || flow.ID == "" || flow.LoginURL == "" {
		return GoogleFlow{}, &UserError{"bad_response", "Resposta inesperada do servidor de contas."}
	}
	return flow, nil
}

func (c *Client) PollGoogleLogin(ctx context.Context, flowID string) (Session, bool, error) {
	var session Session
	if strings.TrimSpace(c.Base) == "" {
		return session, false, &UserError{"no_api", "O endereço do servidor de contas não está configurado."}
	}
	u := strings.TrimRight(c.Base, "/") + "/api/google/poll?flow=" + url.QueryEscape(flowID)
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, u, nil)
	if err != nil {
		return session, false, err
	}
	req.Header.Set("ngrok-skip-browser-warning", "1")
	resp, err := c.httpClient().Do(req)
	if err != nil {
		return session, false, &UserError{"offline", "Não foi possível falar com o servidor de contas. Tente novamente."}
	}
	defer resp.Body.Close()
	if resp.StatusCode == http.StatusAccepted {
		return session, false, nil
	}
	if resp.StatusCode >= 400 {
		var out struct {
			Error   string `json:"error"`
			Message string `json:"message"`
		}
		_ = json.NewDecoder(resp.Body).Decode(&out)
		if out.Message != "" {
			return session, false, &UserError{out.Error, out.Message}
		}
		return session, false, &UserError{"google_failed", "Não foi possível autenticar com Google."}
	}
	if err := json.NewDecoder(resp.Body).Decode(&session); err != nil || session.Token == "" {
		return Session{}, false, &UserError{"bad_response", "Resposta inesperada do servidor de contas."}
	}
	return session, true, nil
}

func (c *Client) httpClient() *http.Client {
	if c.HTTP != nil {
		return c.HTTP
	}
	return &http.Client{Timeout: 20 * time.Second}
}

func (c *Client) post(ctx context.Context, path, email, password string) (Session, error) {
	if strings.TrimSpace(c.Base) == "" {
		return Session{}, &UserError{"no_api", "O endereço do servidor de contas não está configurado."}
	}
	body, _ := json.Marshal(map[string]string{"email": email, "password": password})
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, strings.TrimRight(c.Base, "/")+path, bytes.NewReader(body))
	if err != nil {
		return Session{}, err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("ngrok-skip-browser-warning", "1")
	resp, err := c.httpClient().Do(req)
	if err != nil {
		return Session{}, &UserError{"offline",
			"Não foi possível falar com o servidor de contas. Confira sua internet; se estiver tudo certo, o servidor pode estar desligado agora."}
	}
	defer resp.Body.Close()
	var out struct {
		Session
		Error   string `json:"error"`
		Message string `json:"message"`
	}
	decodeErr := json.NewDecoder(resp.Body).Decode(&out)
	if resp.StatusCode >= 400 {
		if out.Message != "" {
			return Session{}, &UserError{out.Error, out.Message}
		}
		if resp.StatusCode == http.StatusBadGateway || resp.StatusCode == http.StatusServiceUnavailable ||
			resp.StatusCode == http.StatusNotFound {
			return Session{}, &UserError{"offline", "O servidor de contas está fora do ar. Tente mais tarde."}
		}
		return Session{}, &UserError{"http", fmt.Sprintf("O servidor de contas respondeu com erro (%d).", resp.StatusCode)}
	}
	if decodeErr != nil || out.Token == "" {
		return Session{}, &UserError{"bad_response", "Resposta inesperada do servidor de contas."}
	}
	return out.Session, nil
}

// SaveSession writes session.json readable only by the user.
func SaveSession(path string, s Session) error {
	data, _ := json.Marshal(s)
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		return err
	}
	tmp := path + ".tmp"
	if err := os.WriteFile(tmp, data, 0o600); err != nil {
		return err
	}
	return os.Rename(tmp, path)
}

func LoadSession(path string) (Session, error) {
	var s Session
	data, err := os.ReadFile(path)
	if err != nil {
		return s, err
	}
	if err := json.Unmarshal(data, &s); err != nil {
		return s, errors.New("session.json inválido")
	}
	return s, nil
}

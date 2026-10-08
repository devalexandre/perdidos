package main

import (
	"context"
	"encoding/base64"
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"net/mail"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"sync"
	"time"
	"unicode/utf8"

	"github.com/wailsapp/wails/v3/pkg/application"

	"perdidos/launcher/internal/account"
	"perdidos/launcher/internal/drive"
	"perdidos/launcher/internal/settings"
	"perdidos/launcher/internal/update"
)

// LauncherVersion is the launcher's own version (shown in the footer).
var LauncherVersion = "0.1.0"

const (
	minPasswordLen  = 8
	sessionFileName = "session.json"
	evProgress      = "update:progress"
	evFinished      = "update:finished"
	evGameExited    = "game:exited"
	evTheme         = "theme:changed"
)

// LauncherService is bound to the frontend (Call.ByName("main.LauncherService.<Method>")).
type LauncherService struct {
	app  *application.App
	win  *application.WebviewWindow
	root string
	log  *slog.Logger

	mu       sync.Mutex
	settings settings.Settings
	session  account.Session
	source   *update.Source
	latest   *update.Manifest
	updating bool
	cancel   context.CancelFunc
	playing  bool

	themeBusy bool // a theme download is running (only one at a time)
}

// State is the snapshot the UI renders.
type State struct {
	LoggedIn        bool   `json:"loggedIn"`
	Email           string `json:"email"`
	SavedEmail      string `json:"savedEmail"`
	RememberEmail   bool   `json:"rememberEmail"`
	Installed       string `json:"installed"`
	InstallDir      string `json:"installDir"`
	Platform        string `json:"platform"`
	LauncherVersion string `json:"launcherVersion"`
	Updating        bool   `json:"updating"`
	Playing         bool   `json:"playing"`
}

// Result is returned by actions: Error is a message ready to show (pt-BR).
type Result struct {
	OK    bool   `json:"ok"`
	Error string `json:"error,omitempty"`
	Field string `json:"field,omitempty"` // email | password | confirm (for highlighting)
	State State  `json:"state"`
}

// UpdateInfo compares the installed version with the published one.
type UpdateInfo struct {
	// not_installed | update_available | up_to_date | no_release | offline | no_build
	Status    string `json:"status"`
	Installed string `json:"installed"`
	Latest    string `json:"latest"`
	Notes     string `json:"notes"`
	Size      int64  `json:"size"`
	Origin    string `json:"origin"`
	Message   string `json:"message"`
}

// ThemeView is the cached launcher theme (GetTheme and the theme:changed event).
// Image is a data URL ("" = no cached theme: the screen keeps the built-in background).
type ThemeView struct {
	ID      string `json:"id"`
	Arc     string `json:"arc"`
	Title   string `json:"title"`
	Tagline string `json:"tagline"`
	Image   string `json:"image"`
}

// Finished is sent with the update:finished event.
type Finished struct {
	OK        bool   `json:"ok"`
	Message   string `json:"message"`
	Installed string `json:"installed"`
}

func NewLauncherService(root string, log *slog.Logger) *LauncherService {
	s := &LauncherService{root: root, log: log, settings: settings.Load(root)}
	if sess, err := account.LoadSession(filepath.Join(root, sessionFileName)); err == nil && sess.Valid(time.Now()) {
		s.session = sess
	}
	httpc := &http.Client{Timeout: 0} // downloads are long; per-request deadlines come from contexts
	s.source = &update.Source{
		HTTP: &http.Client{Timeout: 30 * time.Second}, Drive: drive.New(httpc),
		FolderID: s.settings.DriveFolder(), APIBase: s.settings.API(),
	}
	update.CleanLeftovers(root)
	return s
}

func (s *LauncherService) attach(app *application.App, win *application.WebviewWindow) {
	s.app, s.win = app, win
}

// ---------------------------------------------------------------- state / account

func (s *LauncherService) GetState() State {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.stateLocked()
}

func (s *LauncherService) stateLocked() State {
	st := State{
		LoggedIn: s.session.Valid(time.Now()), Email: s.session.Email,
		RememberEmail: s.settings.RememberEmail, InstallDir: s.root, Platform: update.Platform(),
		LauncherVersion: LauncherVersion, Updating: s.updating, Playing: s.playing,
	}
	if s.settings.RememberEmail {
		st.SavedEmail = s.settings.Email
	}
	if in, ok := update.ReadInstalled(s.root); ok {
		st.Installed = in.Version
	}
	return st
}

func (s *LauncherService) Login(email, password string, remember bool) Result {
	email = strings.ToLower(strings.TrimSpace(email))
	if msg := checkEmail(email); msg != "" {
		return s.fail(msg, "email")
	}
	if password == "" {
		return s.fail("Digite sua senha.", "password")
	}
	return s.authenticate(false, email, password, remember)
}

func (s *LauncherService) Register(email, password, confirm string, remember bool) Result {
	email = strings.ToLower(strings.TrimSpace(email))
	if msg := checkEmail(email); msg != "" {
		return s.fail(msg, "email")
	}
	if utf8.RuneCountInString(password) < minPasswordLen {
		return s.fail(fmt.Sprintf("A senha precisa ter pelo menos %d caracteres.", minPasswordLen), "password")
	}
	if password != confirm {
		return s.fail("As senhas não são iguais.", "confirm")
	}
	return s.authenticate(true, email, password, remember)
}

func (s *LauncherService) LoginWithGoogle() Result {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Minute)
	defer cancel()
	s.mu.Lock()
	client := &account.Client{Base: s.settings.API()}
	s.mu.Unlock()
	flow, err := client.StartGoogleLogin(ctx)
	if err != nil {
		return s.googleLoginError(err)
	}
	if err := openExternalURL(flow.LoginURL); err != nil {
		s.log.Error("google_browser_open_failed", "err", err.Error())
		return s.fail("Não foi possível abrir o navegador para entrar com Google.", "")
	}
	ticker := time.NewTicker(750 * time.Millisecond)
	defer ticker.Stop()
	for {
		session, complete, err := client.PollGoogleLogin(ctx, flow.ID)
		if err != nil {
			return s.googleLoginError(err)
		}
		if complete {
			s.mu.Lock()
			s.session = session
			s.settings.RememberEmail = true
			s.settings.Email = session.Email
			_ = settings.Save(s.root, s.settings)
			if err := account.SaveSession(filepath.Join(s.root, sessionFileName), session); err != nil {
				s.log.Warn("google_session_save_failed", "err", err.Error())
			}
			state := s.stateLocked()
			s.mu.Unlock()
			return Result{OK: true, State: state}
		}
		select {
		case <-ctx.Done():
			return s.fail("O login Google expirou. Tente novamente.", "")
		case <-ticker.C:
		}
	}
}

func (s *LauncherService) googleLoginError(err error) Result {
	var userErr *account.UserError
	if errors.As(err, &userErr) {
		return s.fail(userErr.Message, "")
	}
	s.log.Error("google_login_failed", "err", err.Error())
	return s.fail("Não foi possível entrar com Google agora. Tente novamente.", "")
}

func openExternalURL(target string) error {
	var cmd *exec.Cmd
	switch runtime.GOOS {
	case "windows":
		cmd = exec.Command("rundll32.exe", "url.dll,FileProtocolHandler", target)
	case "darwin":
		cmd = exec.Command("open", target)
	default:
		cmd = exec.Command("xdg-open", target)
	}
	if err := cmd.Start(); err != nil {
		return err
	}
	go func() { _ = cmd.Wait() }()
	return nil
}

func (s *LauncherService) authenticate(register bool, email, password string, remember bool) Result {
	ctx, cancel := context.WithTimeout(context.Background(), 25*time.Second)
	defer cancel()
	s.mu.Lock()
	client := &account.Client{Base: s.settings.API()}
	s.mu.Unlock()
	var sess account.Session
	var err error
	if register {
		sess, err = client.Register(ctx, email, password)
	} else {
		sess, err = client.Login(ctx, email, password)
	}
	if err != nil {
		var ue *account.UserError
		if errors.As(err, &ue) {
			field := ""
			switch ue.Code {
			case "invalid_email", "email_taken":
				field = "email"
			case "weak_password", "bad_credentials":
				field = "password"
			}
			return s.fail(ue.Message, field)
		}
		s.log.Error("auth_failed", "err", err.Error())
		return s.fail("Não foi possível entrar agora. Tente de novo.", "")
	}
	s.mu.Lock()
	s.session = sess
	s.settings.RememberEmail = remember
	if remember {
		s.settings.Email = email
	} else {
		s.settings.Email = ""
	}
	_ = settings.Save(s.root, s.settings)
	if err := account.SaveSession(filepath.Join(s.root, sessionFileName), sess); err != nil {
		s.log.Warn("session_save_failed", "err", err.Error())
	}
	st := s.stateLocked()
	s.mu.Unlock()
	return Result{OK: true, State: st}
}

func (s *LauncherService) Logout() State {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.session = account.Session{}
	os.Remove(filepath.Join(s.root, sessionFileName))
	return s.stateLocked()
}

func (s *LauncherService) fail(msg, field string) Result {
	return Result{OK: false, Error: msg, Field: field, State: s.GetState()}
}

func checkEmail(email string) string {
	if email == "" {
		return "Digite seu e-mail."
	}
	addr, err := mail.ParseAddress(email)
	at := strings.LastIndexByte(email, '@')
	if err != nil || addr.Address != email || at <= 0 || !strings.Contains(email[at:], ".") || len(email) > 254 {
		return "Esse e-mail não parece válido."
	}
	return ""
}

// ---------------------------------------------------------------- updates

func (s *LauncherService) CheckUpdate() UpdateInfo {
	info := UpdateInfo{}
	if in, ok := update.ReadInstalled(s.root); ok {
		info.Installed = in.Version
	}
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	m, origin, err := s.source.Latest(ctx)
	switch {
	case errors.Is(err, update.ErrNoRelease):
		info.Status = "no_release"
		info.Message = "Nenhuma versão publicada ainda."
		return info
	case err != nil:
		s.log.Warn("check_update_failed", "err", err.Error())
		info.Status = "offline"
		info.Message = "Não foi possível verificar atualizações (sem internet ou Drive fora do ar)."
		return info
	}
	s.mu.Lock()
	s.latest = &m
	s.mu.Unlock()
	if m.ThemeErr != nil {
		s.log.Warn("theme_invalid", "err", m.ThemeErr.Error())
	}
	if m.Theme != nil {
		go s.syncTheme(*m.Theme)
	}
	info.Latest, info.Notes, info.Origin = m.Version, m.Notes, origin
	f, ok := m.For(update.Platform())
	if !ok {
		info.Status = "no_build"
		info.Message = "A versão " + m.Version + " ainda não tem pacote para " + platformName() + "."
		return info
	}
	info.Size = f.Size
	switch {
	case info.Installed == "":
		info.Status = "not_installed"
	case update.CompareVersions(m.Version, info.Installed) > 0:
		info.Status = "update_available"
	default:
		info.Status = "up_to_date"
	}
	return info
}

// StartUpdate downloads and installs the latest version in the background, emitting
// update:progress and finally update:finished.
func (s *LauncherService) StartUpdate() Result {
	s.mu.Lock()
	if s.updating {
		s.mu.Unlock()
		return Result{OK: true, State: s.GetState()}
	}
	m := s.latest
	s.mu.Unlock()
	if m == nil {
		if info := s.CheckUpdate(); info.Status != "not_installed" && info.Status != "update_available" {
			return s.fail(info.Message, "")
		}
		s.mu.Lock()
		m = s.latest
		s.mu.Unlock()
	}
	f, ok := m.For(update.Platform())
	if !ok {
		return s.fail("Esta versão não tem pacote para "+platformName()+".", "")
	}
	ctx, cancel := context.WithCancel(context.Background())
	s.mu.Lock()
	s.updating, s.cancel = true, cancel
	s.mu.Unlock()
	go s.runUpdate(ctx, *m, f)
	return Result{OK: true, State: s.GetState()}
}

func (s *LauncherService) CancelUpdate() {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.cancel != nil {
		s.cancel()
	}
}

func (s *LauncherService) runUpdate(ctx context.Context, m update.Manifest, f update.FileInfo) {
	report := func(p update.Progress) { s.emit(evProgress, p) }
	finish := func(fin Finished) {
		s.mu.Lock()
		s.updating, s.cancel = false, nil
		s.mu.Unlock()
		s.emit(evFinished, fin)
	}
	dir := filepath.Join(s.root, update.DownloadsDir)
	if err := os.MkdirAll(dir, 0o755); err != nil {
		finish(Finished{Message: "Não foi possível criar a pasta de downloads: " + err.Error()})
		return
	}
	dest := filepath.Join(dir, f.Name)
	var err error
	for try := 0; try < 2; try++ { // a corrupted file is downloaded once more from scratch
		if _, statErr := os.Stat(dest); statErr != nil {
			var open update.Opener
			open, err = s.source.Opener(ctx, update.Platform(), f)
			if err == nil {
				err = update.Download(ctx, open, dest, f.Size, report)
			}
			if err != nil {
				break
			}
		}
		report(update.Progress{Phase: "verify", ETA: -1})
		if err = update.VerifySHA256(dest, f.SHA256); !errors.Is(err, update.ErrChecksum) {
			break
		}
		s.log.Warn("checksum_mismatch", "file", f.Name, "try", try+1)
	}
	if err != nil {
		msg := "Falha na atualização: " + err.Error()
		switch {
		case errors.Is(err, context.Canceled):
			msg = "Atualização cancelada. Na próxima vez ela continua de onde parou."
		case errors.Is(err, update.ErrChecksum):
			msg = "O arquivo baixado veio corrompido (SHA-256 não confere). Tente de novo mais tarde."
		}
		s.log.Warn("update_failed", "err", err.Error())
		finish(Finished{Message: msg})
		return
	}
	in, err := update.Install(s.root, dest, m.Version, f.Exe, m.Server, report)
	if err != nil {
		finish(Finished{Message: "Falha ao instalar: " + err.Error()})
		return
	}
	os.Remove(dest)
	finish(Finished{OK: true, Installed: in.Version, Message: "Perdidos " + in.Version + " instalado."})
}

func (s *LauncherService) emit(name string, data any) {
	if s.app != nil {
		s.app.Event.Emit(name, data)
	}
}

// ---------------------------------------------------------------- theme

// GetTheme returns the cached theme of the current arc (empty when none was downloaded yet).
func (s *LauncherService) GetTheme() ThemeView {
	c, ok := update.ReadCurrentTheme(s.root)
	if !ok {
		return ThemeView{}
	}
	mime := update.ThemeMIME(c.File)
	data, err := os.ReadFile(c.ImagePath(s.root))
	if err != nil || mime == "" || len(data) == 0 || len(data) > update.MaxThemeImage {
		return ThemeView{}
	}
	return ThemeView{ID: c.ID, Arc: c.Arc, Title: c.Title, Tagline: c.Tagline,
		Image: "data:" + mime + ";base64," + base64.StdEncoding.EncodeToString(data)}
}

// syncTheme downloads the manifest's theme in the background (after CheckUpdate) and emits
// theme:changed when a new one is ready. Errors only go to the log: the theme never blocks the game.
func (s *LauncherService) syncTheme(t update.Theme) {
	if update.ThemeCached(s.root, t) {
		return
	}
	s.mu.Lock()
	if s.themeBusy {
		s.mu.Unlock()
		return
	}
	s.themeBusy = true
	s.mu.Unlock()
	defer func() {
		s.mu.Lock()
		s.themeBusy = false
		s.mu.Unlock()
	}()
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Minute)
	defer cancel()
	open, err := s.source.ThemeOpener(ctx, t.Background)
	if err == nil {
		_, err = update.FetchTheme(ctx, s.root, t, open)
	}
	if err != nil {
		s.log.Warn("theme_download_failed", "theme", t.ID, "file", t.Background.Name, "err", err.Error())
		return
	}
	s.log.Info("theme_updated", "theme", t.ID, "file", t.Background.Name)
	s.emit(evTheme, s.GetTheme())
}

// ---------------------------------------------------------------- play

// Play opens the game with the session token and the manifest's server; the launcher minimises.
func (s *LauncherService) Play() Result {
	s.mu.Lock()
	sess := s.session
	playing, updating := s.playing, s.updating
	s.mu.Unlock()
	if updating {
		return s.fail("Espere a atualização terminar.", "")
	}
	if playing {
		return s.fail("O jogo já está aberto.", "")
	}
	if !sess.Valid(time.Now()) {
		s.Logout()
		return s.fail("Sua sessão expirou. Entre de novo.", "session")
	}
	in, ok := update.ReadInstalled(s.root)
	if !ok {
		return s.fail("O jogo ainda não está instalado. Clique em Instalar.", "")
	}
	args := []string{"--", "--token=" + sess.Token}
	if strings.TrimSpace(in.Server) != "" {
		args = append(args, "--host="+strings.TrimSpace(in.Server))
	}
	cmd := exec.Command(in.ExePath(s.root), args...)
	cmd.Dir = filepath.Dir(in.ExePath(s.root))
	if err := cmd.Start(); err != nil {
		return s.fail("Não foi possível abrir o jogo: "+err.Error(), "")
	}
	s.log.Info("game_started", "version", in.Version, "pid", cmd.Process.Pid)
	s.mu.Lock()
	s.playing = true
	s.mu.Unlock()
	if s.win != nil {
		s.win.Minimise()
	}
	go func() {
		err := cmd.Wait()
		s.mu.Lock()
		s.playing = false
		s.mu.Unlock()
		code := 0
		if err != nil {
			code = -1
			if ee, ok := err.(*exec.ExitError); ok {
				code = ee.ExitCode()
			}
		}
		s.log.Info("game_exited", "code", code)
		if s.win != nil {
			s.win.UnMinimise()
			s.win.Show()
		}
		s.emit(evGameExited, code)
	}()
	return Result{OK: true, State: s.GetState()}
}

func platformName() string {
	if update.Platform() == "windows" {
		return "Windows"
	}
	return "Linux"
}

// Command perdidos-auth is the accounts API + gatekeeper of Perdidos.
//
//	:8080  POST /api/register, POST /api/login  -> JWT HS256 (account_id, email, exp)
//	       GET  /api/latest  (latest.json for the launcher), GET /api/health
//	       everything else   -> reverse proxy (WebSocket) to the Godot server (127.0.0.1:7777)
//
// The JWT secret comes from $PERDIDOS_JWT_SECRET or ~/.config/perdidos/secrets.env (created with
// a random value and mode 0600 when missing). It is never printed.
//
//	perdidos-auth [flags]          serve
//	perdidos-auth ensure-secret    only create the secrets file if missing (used by the Makefile)
package main

import (
	"context"
	"errors"
	"flag"
	"fmt"
	"log/slog"
	"net/http"
	"net/url"
	"os"
	"os/signal"
	"syscall"
	"time"
)

func main() {
	if len(os.Args) > 1 && os.Args[1] == "ensure-secret" {
		fs := flag.NewFlagSet("ensure-secret", flag.ExitOnError)
		secrets := fs.String("secrets", DefaultSecretsPath(), "secrets.env path")
		_ = fs.Parse(os.Args[2:])
		_, created, err := LoadOrCreateSecret(*secrets)
		if err != nil {
			fmt.Fprintln(os.Stderr, "erro:", err)
			os.Exit(1)
		}
		if created {
			fmt.Println(">> segredo do JWT criado em", *secrets, "(chmod 600)")
		}
		return
	}

	if len(os.Args) > 1 && os.Args[1] == "set-password" {
		fs := flag.NewFlagSet("set-password", flag.ExitOnError)
		email := fs.String("email", "", "account email")
		password := fs.String("password", "", "account password")
		dbPath := fs.String("db", ".run/accounts.db", "SQLite database file")
		_ = fs.Parse(os.Args[2:])
		if *email == "" || *password == "" {
			fmt.Fprintln(os.Stderr, "uso: perdidos-auth set-password -email=... -password=... [-db=...]")
			os.Exit(1)
		}
		hash, err := HashPassword(*password)
		if err != nil {
			fmt.Fprintln(os.Stderr, "erro ao gerar hash:", err)
			os.Exit(1)
		}
		store, err := OpenSQLite(*dbPath)
		if err != nil {
			fmt.Fprintln(os.Stderr, "erro ao abrir banco:", err)
			os.Exit(1)
		}
		defer store.Close()
		err = store.SetPassword(context.Background(), *email, hash)
		if err != nil {
			fmt.Fprintln(os.Stderr, "erro ao atualizar senha:", err)
			os.Exit(1)
		}
		fmt.Printf(">> Senha de %s atualizada com sucesso!\n", *email)
		return
	}

	waitlistEnv := flag.String("waitlist-env", ".run/waitlist.env", "private waitlist PostgreSQL configuration")
	addr := flag.String("addr", ":8080", "listen address (API + gatekeeper)")
	game := flag.String("game", "127.0.0.1:7777", "Godot WebSocket server (host:port); empty disables the proxy")
	dbPath := flag.String("db", ".run/accounts.db", "SQLite database file")
	latest := flag.String("latest", "build/release/latest.json", "latest.json served at /api/latest")
	secrets := flag.String("secrets", DefaultSecretsPath(), "secrets.env with "+SecretKey)
	ttl := flag.Duration("token-ttl", 12*time.Hour, "session token validity")
	googleClientID := flag.String("google-client-id", os.Getenv("PERDIDOS_GOOGLE_CLIENT_ID"), "Google Web client ID")
	publicURL := flag.String("public-url", os.Getenv("PERDIDOS_PUBLIC_URL"), "public HTTPS URL for Google sign-in page")
	adminData := flag.String("admin-user-data", "", "Godot user data directory used by the admin panel")
	serverLog := flag.String("server-log", ".run/server.log", "Godot server log shown in the admin panel")
	authLog := flag.String("auth-log", ".run/auth.log", "API log shown in the admin panel")
	flag.Parse()

	log := slog.New(slog.NewTextHandler(os.Stdout, &slog.HandlerOptions{Level: slog.LevelInfo}))
	secret, created, err := LoadOrCreateSecret(*secrets)
	if err != nil {
		log.Error("secret_load_failed", "path", *secrets, "err", err.Error())
		os.Exit(1)
	}
	if created {
		log.Info("secret_created", "path", *secrets)
	}
	store, err := OpenSQLite(*dbPath)
	if err != nil {
		log.Error("db_open_failed", "path", *dbPath, "err", err.Error())
		os.Exit(1)
	}
	defer store.Close()

	cfg := Config{Secret: []byte(secret), TokenTTL: *ttl, LatestPath: *latest,
		GoogleClientID: *googleClientID, PublicBaseURL: *publicURL,
		AdminUserDataDir: *adminData, AdminServerLog: *serverLog, AdminAuthLog: *authLog}
	waitlistEnvCfg, err := LoadWaitlistEnvironment(*waitlistEnv)
	if err != nil {
		log.Error("waitlist_config_failed")
		os.Exit(1)
	}
	if waitlistEnvCfg.DatabaseURL != "" {
		initCtx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
		waitlistStore, openErr := OpenWaitlist(initCtx, waitlistEnvCfg.DatabaseURL)
		cancel()
		if openErr != nil {
			log.Error("waitlist_database_failed")
			os.Exit(1)
		}
		defer waitlistStore.Close()
		cfg.Waitlist = WaitlistConfig{Store: waitlistStore, Origin: waitlistEnvCfg.Origin}
		log.Info("waitlist_ready")
	}
	if *game != "" {
		cfg.GameURL = &url.URL{Scheme: "http", Host: *game}
	}
	api := NewServer(cfg, store, log)
	srv := &http.Server{
		Addr:              *addr,
		Handler:           api.Handler(),
		ReadHeaderTimeout: 10 * time.Second,
	}
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()
	go func() {
		<-ctx.Done()
		shut, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		_ = srv.Shutdown(shut)
	}()
	log.Info("auth_started", "addr", *addr, "game", *game, "db", *dbPath, "latest", *latest)
	if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
		log.Error("listen_failed", "err", err.Error())
		os.Exit(1)
	}
}

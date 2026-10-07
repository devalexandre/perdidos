package main

import (
	"context"
	"errors"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// Waitlist data is kept in PostgreSQL independently of the existing account store.
type WaitlistEntry struct {
	ID       int64
	Email    string
	Name     string
	Platform string
}
type WaitlistStore interface {
	Subscribe(context.Context, WaitlistEntry) (bool, error)
	Close()
}
type postgresWaitlist struct{ pool *pgxpool.Pool }

// Only creates the new table; it does not migrate or change accounts/game data.
const waitlistSchema = `CREATE TABLE IF NOT EXISTS public.lista_de_espera (
 id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 email TEXT NOT NULL,
 nome TEXT NOT NULL DEFAULT '',
 plataforma TEXT NOT NULL CHECK (plataforma IN ('windows','linux','android','indeciso')),
 criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
 consentimento_em TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE UNIQUE INDEX IF NOT EXISTS lista_de_espera_email_unico ON public.lista_de_espera (lower(email));`

func OpenWaitlist(ctx context.Context, connectionURL string) (WaitlistStore, error) {
	cfg, err := pgxpool.ParseConfig(connectionURL)
	if err != nil {
		return nil, errors.New("invalid PostgreSQL configuration")
	}
	cfg.MaxConns = 4
	cfg.MinConns = 0
	cfg.ConnConfig.ConnectTimeout = 10 * time.Second
	// Neon pooler supports the extended protocol; avoid connection-local prepared statements.
	cfg.ConnConfig.DefaultQueryExecMode = pgx.QueryExecModeExec
	pool, err := pgxpool.NewWithConfig(ctx, cfg)
	if err != nil {
		return nil, errors.New("could not open PostgreSQL pool")
	}
	if _, err = pool.Exec(ctx, waitlistSchema); err != nil {
		pool.Close()
		return nil, errors.New("could not initialize waitlist table in PostgreSQL")
	}
	return &postgresWaitlist{pool: pool}, nil
}
func (s *postgresWaitlist) Subscribe(ctx context.Context, entry WaitlistEntry) (bool, error) {
	result, err := s.pool.Exec(ctx, `INSERT INTO public.lista_de_espera (email,nome,plataforma) VALUES ($1,$2,$3) ON CONFLICT (lower(email)) DO NOTHING`, entry.Email, entry.Name, entry.Platform)
	return err == nil && result.RowsAffected() == 1, err
}
func (s *postgresWaitlist) Close() { s.pool.Close() }

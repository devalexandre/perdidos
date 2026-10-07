package main

import (
	"context"
	"database/sql"
	"errors"
	"os"
	"path/filepath"
	"strings"
	"time"

	_ "modernc.org/sqlite" // pure-Go SQLite driver (no CGO)
)

// Account is a row of the accounts table (same columns as infra/db/schema.sql, minus flags).
type Account struct {
	ID           int64
	Email        string
	PasswordHash string
	CreatedAt    time.Time
}

var errEmailTaken = errors.New("email already registered")
var errNotFound = errors.New("account not found")

// Store keeps accounts. SQLite now; the interface keeps a Postgres store (infra/db) possible later.
type Store interface {
	CreateAccount(ctx context.Context, email, passwordHash string) (Account, error)
	FindByEmail(ctx context.Context, email string) (Account, error)
	SetPassword(ctx context.Context, email, passwordHash string) error
	CountAccounts(ctx context.Context) (int, error)
	TouchLogin(ctx context.Context, id int64) error
	Close() error
}

type sqliteStore struct{ db *sql.DB }

const sqliteSchema = `
CREATE TABLE IF NOT EXISTS accounts (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    email         TEXT    NOT NULL UNIQUE COLLATE NOCASE,
    password_hash TEXT    NOT NULL CHECK (password_hash LIKE '$argon2%'),
    created_at    INTEGER NOT NULL,
    last_login_at INTEGER
);`

// OpenSQLite opens (and creates) the accounts database file.
func OpenSQLite(path string) (Store, error) {
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		return nil, err
	}
	db, err := sql.Open("sqlite", "file:"+path+"?_pragma=busy_timeout(5000)&_pragma=journal_mode(WAL)")
	if err != nil {
		return nil, err
	}
	db.SetMaxOpenConns(1) // SQLite: one writer; the API is tiny.
	if _, err := db.Exec(sqliteSchema); err != nil {
		db.Close()
		return nil, err
	}
	_ = os.Chmod(path, 0o600)
	return &sqliteStore{db: db}, nil
}

func (s *sqliteStore) CreateAccount(ctx context.Context, email, hash string) (Account, error) {
	now := time.Now().UTC()
	res, err := s.db.ExecContext(ctx,
		`INSERT INTO accounts (email, password_hash, created_at) VALUES (?, ?, ?)`, email, hash, now.Unix())
	if err != nil {
		if strings.Contains(strings.ToLower(err.Error()), "unique") {
			return Account{}, errEmailTaken
		}
		return Account{}, err
	}
	id, err := res.LastInsertId()
	if err != nil {
		return Account{}, err
	}
	return Account{ID: id, Email: email, PasswordHash: hash, CreatedAt: now}, nil
}

func (s *sqliteStore) FindByEmail(ctx context.Context, email string) (Account, error) {
	var a Account
	var created int64
	err := s.db.QueryRowContext(ctx,
		`SELECT id, email, password_hash, created_at FROM accounts WHERE email = ?`, email).
		Scan(&a.ID, &a.Email, &a.PasswordHash, &created)
	if errors.Is(err, sql.ErrNoRows) {
		return a, errNotFound
	}
	a.CreatedAt = time.Unix(created, 0).UTC()
	return a, err
}

func (s *sqliteStore) SetPassword(ctx context.Context, email, hash string) error {
	res, err := s.db.ExecContext(ctx, `UPDATE accounts SET password_hash = ? WHERE email = ? COLLATE NOCASE`, hash, email)
	if err != nil {
		return err
	}
	n, _ := res.RowsAffected()
	if n == 0 {
		return errNotFound
	}
	return nil
}

func (s *sqliteStore) CountAccounts(ctx context.Context) (int, error) {
	var count int
	err := s.db.QueryRowContext(ctx, `SELECT COUNT(*) FROM accounts`).Scan(&count)
	return count, err
}

func (s *sqliteStore) TouchLogin(ctx context.Context, id int64) error {
	_, err := s.db.ExecContext(ctx, `UPDATE accounts SET last_login_at = ? WHERE id = ?`, time.Now().Unix(), id)
	return err
}

func (s *sqliteStore) Close() error { return s.db.Close() }

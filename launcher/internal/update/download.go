package update

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"io"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"
)

// Progress is reported during download/verify/install.
type Progress struct {
	Phase   string  `json:"phase"` // "download", "verify", "extract", "done"
	Done    int64   `json:"done"`
	Total   int64   `json:"total"`
	Speed   float64 `json:"speed"` // bytes/s (smoothed)
	ETA     float64 `json:"eta"`   // seconds (-1 unknown)
	Attempt int     `json:"attempt"`
	Message string  `json:"message,omitempty"`
}

// Opener opens the remote file at a byte offset (Range). 206 = resumed, 200 = from the start.
type Opener func(offset int64) (*http.Response, error)

// Retry policy (network drops, Drive hiccups). Variables so tests can shorten them.
var (
	MaxAttempts  = 6
	RetryBackoff = []time.Duration{time.Second, 2 * time.Second, 4 * time.Second, 8 * time.Second, 15 * time.Second}
	ReportEvery  = 250 * time.Millisecond
)

// ErrChecksum: the downloaded file does not match latest.json.
var ErrChecksum = errors.New("checksum mismatch")

// Download fetches into dest, resuming from dest+".part" and retrying on errors.
// The .part is renamed to dest only once complete.
func Download(ctx context.Context, open Opener, dest string, size int64, report func(Progress)) error {
	part := dest + ".part"
	var offset int64
	if st, err := os.Stat(part); err == nil {
		offset = st.Size()
	}
	if size > 0 && offset > size {
		os.Remove(part)
		offset = 0
	}
	var lastErr error
	for attempt := 1; attempt <= MaxAttempts; attempt++ {
		if err := ctx.Err(); err != nil {
			return err
		}
		done, err := downloadOnce(ctx, open, part, offset, size, attempt, report)
		if err == nil {
			return os.Rename(part, dest)
		}
		lastErr = err
		offset = done
		if ctx.Err() != nil {
			return ctx.Err()
		}
		if attempt == MaxAttempts {
			break
		}
		wait := RetryBackoff[min(attempt-1, len(RetryBackoff)-1)]
		report(Progress{Phase: "download", Done: offset, Total: size, ETA: -1, Attempt: attempt + 1,
			Message: fmt.Sprintf("Conexão falhou (%v). Tentando de novo em %ds…", shortErr(err), int(wait.Seconds()))})
		select {
		case <-ctx.Done():
			return ctx.Err()
		case <-time.After(wait):
		}
	}
	return fmt.Errorf("download falhou depois de %d tentativas: %w", MaxAttempts, lastErr)
}

// downloadOnce returns how many bytes the .part has afterwards.
func downloadOnce(ctx context.Context, open Opener, part string, offset, size int64, attempt int,
	report func(Progress)) (int64, error) {
	resp, err := open(offset)
	if err != nil {
		return offset, err
	}
	defer resp.Body.Close()
	flags := os.O_CREATE | os.O_WRONLY
	switch {
	case offset > 0 && resp.StatusCode == http.StatusPartialContent:
		if start := contentRangeStart(resp.Header.Get("Content-Range")); start >= 0 && start != offset {
			return offset, fmt.Errorf("servidor retomou do byte %d, esperado %d", start, offset)
		}
		flags |= os.O_APPEND
	case resp.StatusCode == http.StatusOK:
		offset = 0 // server ignored Range: start over
		flags |= os.O_TRUNC
	case resp.StatusCode == http.StatusRequestedRangeNotSatisfiable && size > 0 && offset == size:
		return offset, nil
	default:
		return offset, fmt.Errorf("HTTP %d", resp.StatusCode)
	}
	total := size
	if total <= 0 && resp.ContentLength > 0 {
		total = offset + resp.ContentLength
	}
	f, err := os.OpenFile(part, flags, 0o644)
	if err != nil {
		return offset, err
	}
	defer f.Close()

	buf := make([]byte, 256<<10)
	done := offset
	var speed float64
	lastT, lastB := time.Now(), done
	report(Progress{Phase: "download", Done: done, Total: total, ETA: -1, Attempt: attempt})
	for {
		n, rerr := resp.Body.Read(buf)
		if n > 0 {
			if _, werr := f.Write(buf[:n]); werr != nil {
				return done, werr
			}
			done += int64(n)
		}
		if now := time.Now(); now.Sub(lastT) >= ReportEvery || rerr == io.EOF {
			inst := float64(done-lastB) / now.Sub(lastT).Seconds()
			if speed == 0 {
				speed = inst
			} else {
				speed = 0.7*speed + 0.3*inst
			}
			eta := -1.0
			if speed > 0 && total > 0 {
				eta = float64(total-done) / speed
			}
			report(Progress{Phase: "download", Done: done, Total: total, Speed: speed, ETA: eta, Attempt: attempt})
			lastT, lastB = now, done
		}
		if rerr == io.EOF {
			break
		}
		if rerr != nil {
			return done, rerr
		}
		if ctx.Err() != nil {
			return done, ctx.Err()
		}
	}
	if total > 0 && done != total {
		return done, fmt.Errorf("arquivo incompleto (%d de %d bytes)", done, total)
	}
	return done, f.Sync()
}

func contentRangeStart(h string) int64 {
	// "bytes 1000-1999/2000"
	h = strings.TrimPrefix(strings.TrimSpace(h), "bytes ")
	dash := strings.IndexByte(h, '-')
	if dash <= 0 {
		return -1
	}
	v, err := strconv.ParseInt(h[:dash], 10, 64)
	if err != nil {
		return -1
	}
	return v
}

func shortErr(err error) string {
	s := err.Error()
	if len(s) > 80 {
		s = s[:80] + "…"
	}
	return s
}

// FileSHA256 hashes a file.
func FileSHA256(path string) (string, error) {
	f, err := os.Open(path)
	if err != nil {
		return "", err
	}
	defer f.Close()
	h := sha256.New()
	if _, err := io.Copy(h, f); err != nil {
		return "", err
	}
	return hex.EncodeToString(h.Sum(nil)), nil
}

// VerifySHA256 checks path against want; a mismatching file is deleted (so the next try starts clean).
func VerifySHA256(path, want string) error {
	got, err := FileSHA256(path)
	if err != nil {
		return err
	}
	if !strings.EqualFold(got, want) {
		os.Remove(path)
		return fmt.Errorf("%w: esperado %s…, veio %s…", ErrChecksum, want[:12], got[:12])
	}
	return nil
}

package main

import (
	"sync"
	"time"
)

// RateLimiter is a fixed-window counter per key ("ip:1.2.3.4", "email:a@b.c").
// In memory: good enough for one API process; restarts reset the counters.
type RateLimiter struct {
	mu     sync.Mutex
	limit  int
	window time.Duration
	hits   map[string]*window
	now    func() time.Time
}

type window struct {
	start time.Time
	count int
}

func NewRateLimiter(limit int, per time.Duration) *RateLimiter {
	return &RateLimiter{limit: limit, window: per, hits: map[string]*window{}, now: time.Now}
}

// Allow counts one hit for key and reports whether it is within the limit, plus the wait
// until the window resets when it is not.
func (r *RateLimiter) Allow(key string) (bool, time.Duration) {
	r.mu.Lock()
	defer r.mu.Unlock()
	now := r.now()
	w := r.hits[key]
	if w == nil || now.Sub(w.start) >= r.window {
		w = &window{start: now}
		r.hits[key] = w
	}
	if w.count >= r.limit {
		return false, w.start.Add(r.window).Sub(now)
	}
	w.count++
	if len(r.hits) > 50000 { // cheap cleanup so a flood of keys can't grow forever
		for k, v := range r.hits {
			if now.Sub(v.start) >= r.window {
				delete(r.hits, k)
			}
		}
	}
	return true, 0
}

// Blocked reports whether key is already over the limit without counting a hit.
func (r *RateLimiter) Blocked(key string) (bool, time.Duration) {
	r.mu.Lock()
	defer r.mu.Unlock()
	now := r.now()
	w := r.hits[key]
	if w == nil || now.Sub(w.start) >= r.window || w.count < r.limit {
		return false, 0
	}
	return true, w.start.Add(r.window).Sub(now)
}

// Reset forgets a key (e.g. failed-login counter after a successful login).
func (r *RateLimiter) Reset(key string) {
	r.mu.Lock()
	delete(r.hits, key)
	r.mu.Unlock()
}

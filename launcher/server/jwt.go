package main

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"errors"
	"strings"
	"time"
)

// Claims carried by the session token. The Godot server checks the HMAC, exp and account_id.
type Claims struct {
	Sub       string `json:"sub"`
	AccountID int64  `json:"account_id"`
	Email     string `json:"email"`
	Iat       int64  `json:"iat"`
	Exp       int64  `json:"exp"`
	Iss       string `json:"iss"`
}

const jwtIssuer = "perdidos-auth"

var (
	errTokenMalformed = errors.New("malformed token")
	errTokenSignature = errors.New("bad signature")
	errTokenExpired   = errors.New("token expired")
)

var jwtHeader = base64.RawURLEncoding.EncodeToString([]byte(`{"alg":"HS256","typ":"JWT"}`))

// SignJWT builds an HS256 JWT.
func SignJWT(secret []byte, c Claims) (string, error) {
	payload, err := json.Marshal(c)
	if err != nil {
		return "", err
	}
	signing := jwtHeader + "." + base64.RawURLEncoding.EncodeToString(payload)
	mac := hmac.New(sha256.New, secret)
	mac.Write([]byte(signing))
	return signing + "." + base64.RawURLEncoding.EncodeToString(mac.Sum(nil)), nil
}

// VerifyJWT checks signature (HS256 only) and expiry.
func VerifyJWT(secret []byte, token string, now time.Time) (Claims, error) {
	var c Claims
	parts := strings.Split(token, ".")
	if len(parts) != 3 {
		return c, errTokenMalformed
	}
	hdr, err := base64.RawURLEncoding.DecodeString(parts[0])
	if err != nil {
		return c, errTokenMalformed
	}
	var h struct {
		Alg string `json:"alg"`
	}
	if json.Unmarshal(hdr, &h) != nil || h.Alg != "HS256" {
		return c, errTokenMalformed
	}
	sig, err := base64.RawURLEncoding.DecodeString(parts[2])
	if err != nil {
		return c, errTokenMalformed
	}
	mac := hmac.New(sha256.New, secret)
	mac.Write([]byte(parts[0] + "." + parts[1]))
	if !hmac.Equal(sig, mac.Sum(nil)) {
		return c, errTokenSignature
	}
	payload, err := base64.RawURLEncoding.DecodeString(parts[1])
	if err != nil || json.Unmarshal(payload, &c) != nil {
		return c, errTokenMalformed
	}
	if now.Unix() >= c.Exp {
		return c, errTokenExpired
	}
	return c, nil
}

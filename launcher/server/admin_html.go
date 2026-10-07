package main

import (
	_ "embed"
	"net/http"
)

//go:embed admin.html
var adminHTML []byte

func (as *AdminServer) handleAdminPage(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write(adminHTML)
}

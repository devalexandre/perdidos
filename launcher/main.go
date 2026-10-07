// Perdidos launcher (Wails v3): account login/sign-up, keeps the game up to date from a public
// Google Drive folder (fallback: the accounts API /api/latest) and opens it with the session token.
package main

import (
	"embed"
	"io"
	"log"
	"log/slog"
	"os"
	"path/filepath"

	"github.com/wailsapp/wails/v3/pkg/application"

	"perdidos/launcher/internal/settings"
)

//go:embed all:frontend/dist
var assets embed.FS

func main() {
	root := settings.Root()
	if err := os.MkdirAll(root, 0o755); err != nil {
		log.Fatal(err)
	}
	logFile, err := os.OpenFile(filepath.Join(root, "launcher.log"), os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0o600)
	var out io.Writer = os.Stderr
	if err == nil {
		defer logFile.Close()
		out = io.MultiWriter(os.Stderr, logFile)
	}
	logger := slog.New(slog.NewTextHandler(out, nil))

	svc := NewLauncherService(root, logger)
	app := application.New(application.Options{
		Name:        "Perdidos",
		Description: "Launcher do Perdidos",
		Services:    []application.Service{application.NewService(svc)},
		Assets:      application.AssetOptions{Handler: application.AssetFileServerFS(assets)},
		SingleInstance: &application.SingleInstanceOptions{
			UniqueID: "dev.perdidos.launcher",
		},
		Mac: application.MacOptions{ApplicationShouldTerminateAfterLastWindowClosed: true},
	})
	win := app.Window.NewWithOptions(application.WebviewWindowOptions{
		Title:            "Perdidos",
		Width:            980,
		Height:           660,
		DisableResize:    true,
		BackgroundColour: application.NewRGB(14, 28, 25),
		URL:              "/",
	})
	svc.attach(app, win)
	if err := app.Run(); err != nil {
		log.Fatal(err)
	}
}

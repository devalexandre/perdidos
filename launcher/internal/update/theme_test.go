package update

import (
	"context"
	"fmt"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"sync/atomic"
	"testing"
)

const baseManifest = `{"version":"0.2.0","files":{"linux":{"name":"Perdidos-0.2.0-linux.zip","sha256":"%s","size":10}}%s}`

func themeJSON(id, tagline, name, sum string, size int64) string {
	return fmt.Sprintf(`,"theme":{"id":%q,"tagline":%q,"background":{"name":%q,"sha256":%q,"size":%d}}`,
		id, tagline, name, sum, size)
}

func TestManifestTheme(t *testing.T) {
	zipSHA := strings.Repeat("a", 64)
	imgSHA := strings.Repeat("B", 64)

	// valid
	m, err := ParseManifest([]byte(fmt.Sprintf(baseManifest, zipSHA,
		themeJSON("arco1", " Aqui as lendas são reais. ", "theme-arco1.jpg", imgSHA, 1234))))
	if err != nil || m.Theme == nil || m.ThemeErr != nil {
		t.Fatalf("válido: %v %+v %v", err, m.Theme, m.ThemeErr)
	}
	if m.Theme.ID != "arco1" || m.Theme.Tagline != "Aqui as lendas são reais." || m.Theme.Background.SHA256 != strings.ToLower(imgSHA) {
		t.Fatalf("tema: %+v", m.Theme)
	}

	// absent: old latest.json still valid
	m, err = ParseManifest([]byte(fmt.Sprintf(baseManifest, zipSHA, "")))
	if err != nil || m.Theme != nil || m.ThemeErr != nil {
		t.Fatalf("sem tema: %v %+v %v", err, m.Theme, m.ThemeErr)
	}

	// invalid: theme dropped, rest of the manifest kept
	bad := map[string]string{
		"id maiúsculo":    themeJSON("Arco1", "", "theme-arco1.jpg", imgSHA, 10),
		"id vazio":        themeJSON("", "", "theme-arco1.jpg", imgSHA, 10),
		"id longo":        themeJSON(strings.Repeat("a", 33), "", "theme-arco1.jpg", imgSHA, 10),
		"frase longa":     themeJSON("arco1", strings.Repeat("é", 141), "theme-arco1.jpg", imgSHA, 10),
		"traversal":       themeJSON("arco1", "", "../../evil.jpg", imgSHA, 10),
		"barra invertida": themeJSON("arco1", "", `..\evil.jpg`, imgSHA, 10),
		"subpasta":        themeJSON("arco1", "", "a/b.jpg", imgSHA, 10),
		"pontos":          themeJSON("arco1", "", "theme..jpg", imgSHA, 10),
		"extensão":        themeJSON("arco1", "", "theme-arco1.exe", imgSHA, 10),
		"svg":             themeJSON("arco1", "", "theme-arco1.svg", imgSHA, 10),
		"sha":             themeJSON("arco1", "", "theme-arco1.jpg", "xyz", 10),
		"sem tamanho":     themeJSON("arco1", "", "theme-arco1.jpg", imgSHA, 0),
		"grande demais":   themeJSON("arco1", "", "theme-arco1.jpg", imgSHA, MaxThemeImage+1),
		"url":             `,"theme":{"id":"arco1","background":{"name":"t.png","sha256":"` + imgSHA + `","size":5,"url":"file:///etc/passwd"}}`,
	}
	for name, th := range bad {
		m, err := ParseManifest([]byte(fmt.Sprintf(baseManifest, zipSHA, th)))
		if err != nil {
			t.Errorf("%s: o tema inválido não pode quebrar o manifesto: %v", name, err)
			continue
		}
		if m.Theme != nil || m.ThemeErr == nil {
			t.Errorf("%s: tema deveria ser ignorado (%+v)", name, m.Theme)
		}
		if _, ok := m.For("linux"); !ok {
			t.Errorf("%s: perdeu os arquivos do jogo", name)
		}
	}
	// a 140-char tagline is still accepted
	m, _ = ParseManifest([]byte(fmt.Sprintf(baseManifest, zipSHA,
		themeJSON("arco_2-b", strings.Repeat("é", 140), "theme-arco_2-b.webp", imgSHA, 10))))
	if m.Theme == nil {
		t.Fatalf("frase de 140: %v", m.ThemeErr)
	}
}

func TestManifestThemeArcTitle(t *testing.T) {
	zipSHA := strings.Repeat("a", 64)
	imgSHA := strings.Repeat("b", 64)
	seal := func(arc, title string) string {
		return fmt.Sprintf(`,"theme":{"id":"arco1","arc":%q,"title":%q,"background":{"name":"theme-arco1.jpg","sha256":%q,"size":10}}`,
			arc, title, imgSHA)
	}
	// valid
	m, err := ParseManifest([]byte(fmt.Sprintf(baseManifest, zipSHA, seal(" Arco I ", "A Terra do Sabiá"))))
	if err != nil || m.Theme == nil || m.Theme.Arc != "Arco I" || m.Theme.Title != "A Terra do Sabiá" {
		t.Fatalf("válido: %v %+v %v", err, m.Theme, m.ThemeErr)
	}
	// absent: optional
	m, _ = ParseManifest([]byte(fmt.Sprintf(baseManifest, zipSHA, themeJSON("arco1", "", "theme-arco1.jpg", imgSHA, 10))))
	if m.Theme == nil || m.Theme.Arc != "" || m.Theme.Title != "" {
		t.Fatalf("ausente: %+v %v", m.Theme, m.ThemeErr)
	}
	// limits: 20 / 60 accepted, 21 / 61 rejected; markup and control chars rejected
	if m, _ = ParseManifest([]byte(fmt.Sprintf(baseManifest, zipSHA, seal(strings.Repeat("á", 20), strings.Repeat("é", 60))))); m.Theme == nil {
		t.Fatalf("no limite: %v", m.ThemeErr)
	}
	for name, th := range map[string]string{
		"arco longo":   seal(strings.Repeat("á", 21), "x"),
		"título longo": seal("Arco I", strings.Repeat("é", 61)),
		"html":         seal("Arco I", "<b>Sabiá</b>"),
		"controle":     seal("Arco\nI", "x"),
	} {
		m, err := ParseManifest([]byte(fmt.Sprintf(baseManifest, zipSHA, th)))
		if err != nil || m.Theme != nil || m.ThemeErr == nil {
			t.Errorf("%s: deveria ignorar só o tema (%v %+v)", name, err, m.Theme)
		}
	}
}

func themeServer(t *testing.T, files map[string][]byte, hits *int32) *httptest.Server {
	t.Helper()
	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		atomic.AddInt32(hits, 1)
		name := strings.TrimPrefix(r.URL.Path, "/api/theme/")
		data, ok := files[name]
		if !ok {
			http.NotFound(w, r)
			return
		}
		w.Write(data)
	}))
	t.Cleanup(ts.Close)
	return ts
}

func mkTheme(id string, img []byte) Theme {
	return Theme{ID: id, Arc: "Arco I", Title: "Título " + id, Tagline: "Frase do " + id,
		Background: FileInfo{Name: "theme-" + id + ".jpg", SHA256: sha(img), Size: int64(len(img))}}
}

func fetch(t *testing.T, src *Source, root string, th Theme) (CachedTheme, error) {
	t.Helper()
	ctx := context.Background()
	open, err := src.ThemeOpener(ctx, th.Background)
	if err != nil {
		return CachedTheme{}, err
	}
	return FetchTheme(ctx, root, th, open)
}

func TestThemeCacheDownloadAndPrune(t *testing.T) {
	imgs := map[string][]byte{}
	for _, id := range []string{"arco1", "arco2", "arco3"} {
		imgs["theme-"+id+".jpg"] = []byte("imagem-" + id + strings.Repeat("x", 1000))
	}
	var hits int32
	ts := themeServer(t, imgs, &hits)
	src := &Source{APIBase: ts.URL} // no Drive: plan B /api/theme/<name>
	root := t.TempDir()

	if _, ok := ReadCurrentTheme(root); ok {
		t.Fatal("cache vazio deveria vir sem tema")
	}
	th1 := mkTheme("arco1", imgs["theme-arco1.jpg"])
	c, err := fetch(t, src, root, th1)
	if err != nil {
		t.Fatal(err)
	}
	got, _ := os.ReadFile(c.ImagePath(root))
	if string(got) != string(imgs["theme-arco1.jpg"]) || c.Tagline != "Frase do arco1" || c.Arc != "Arco I" || c.Title != "Título arco1" {
		t.Fatalf("imagem/frase erradas: %+v", c)
	}
	if !ThemeCached(root, th1) {
		t.Fatal("arco1 deveria estar em cache")
	}
	if cur, ok := ReadCurrentTheme(root); !ok || cur.ID != "arco1" || cur.Title != "Título arco1" {
		t.Fatalf("current.json: %+v", cur)
	}
	// only the seal changed: not cached anymore, but the image is reused
	th1b := th1
	th1b.Title = "Outro título"
	if ThemeCached(root, th1b) {
		t.Fatal("mudança de título deveria atualizar o current.json")
	}

	// same image again: no new download
	before := atomic.LoadInt32(&hits)
	if _, err := FetchTheme(context.Background(), root, th1, func(int64) (*http.Response, error) {
		t.Fatal("não devia baixar de novo")
		return nil, nil
	}); err != nil {
		t.Fatal(err)
	}
	if atomic.LoadInt32(&hits) != before {
		t.Fatal("baixou de novo")
	}

	// arco2 then arco3: only the current and the previous stay
	if _, err := fetch(t, src, root, mkTheme("arco2", imgs["theme-arco2.jpg"])); err != nil {
		t.Fatal(err)
	}
	if _, err := fetch(t, src, root, mkTheme("arco3", imgs["theme-arco3.jpg"])); err != nil {
		t.Fatal(err)
	}
	entries, _ := os.ReadDir(filepath.Join(root, ThemeDir))
	var dirs []string
	for _, e := range entries {
		if e.IsDir() {
			dirs = append(dirs, e.Name())
		}
	}
	if strings.Join(dirs, ",") != "arco2,arco3" {
		t.Fatalf("deveria manter só arco2 e arco3: %v", dirs)
	}
	if cur, _ := ReadCurrentTheme(root); cur.ID != "arco3" {
		t.Fatalf("tema atual: %+v", cur)
	}
}

func TestThemeCacheRejectsBadSHA(t *testing.T) {
	img := []byte("imagem-verdadeira")
	var hits int32
	ts := themeServer(t, map[string][]byte{"theme-arco1.jpg": []byte("imagem-adulterada")}, &hits)
	root := t.TempDir()
	th := mkTheme("arco1", img)
	th.Background.Size = int64(len("imagem-adulterada"))
	_, err := fetch(t, &Source{APIBase: ts.URL}, root, th)
	if err == nil || !strings.Contains(err.Error(), "checksum") {
		t.Fatalf("esperava checksum mismatch, veio %v", err)
	}
	if _, ok := ReadCurrentTheme(root); ok {
		t.Fatal("tema com sha errado não pode virar o atual")
	}
	if _, err := os.Stat(filepath.Join(root, ThemeDir, "arco1", "theme-arco1.jpg")); err == nil {
		t.Fatal("imagem corrompida ficou no cache")
	}
}

func TestThemeCacheKeepsOldOnFailure(t *testing.T) {
	imgs := map[string][]byte{"theme-arco1.jpg": []byte("um")}
	var hits int32
	ts := themeServer(t, imgs, &hits)
	src := &Source{APIBase: ts.URL}
	root := t.TempDir()
	if _, err := fetch(t, src, root, mkTheme("arco1", imgs["theme-arco1.jpg"])); err != nil {
		t.Fatal(err)
	}
	old := MaxAttempts
	MaxAttempts = 1
	defer func() { MaxAttempts = old }()
	// arco2 is not on the server (404): the current theme stays arco1
	if _, err := fetch(t, src, root, mkTheme("arco2", []byte("dois"))); err == nil {
		t.Fatal("esperava erro de download")
	}
	if cur, ok := ReadCurrentTheme(root); !ok || cur.ID != "arco1" {
		t.Fatalf("perdeu o tema anterior: %+v", cur)
	}
}

func TestThemeOpenerPrefersURL(t *testing.T) {
	img := []byte("pela-url")
	var hits int32
	ts := themeServer(t, map[string][]byte{"/direto/theme-x.png": img}, &hits)
	th := Theme{ID: "x", Background: FileInfo{Name: "theme-x.png", SHA256: sha(img), Size: int64(len(img)),
		URL: ts.URL + "/direto/theme-x.png"}}
	root := t.TempDir()
	c, err := fetch(t, &Source{APIBase: "http://127.0.0.1:1"}, root, th)
	if err != nil {
		t.Fatal(err)
	}
	if ThemeMIME(c.File) != "image/png" {
		t.Fatalf("mime: %q", ThemeMIME(c.File))
	}
}

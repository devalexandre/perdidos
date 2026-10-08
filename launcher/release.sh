#!/usr/bin/env bash
# Empacota uma versão do jogo para distribuição (chamado por `make release VERSION=x.y.z`).
# Entrada: build/windows/, build/linux/ e build/android/ já exportados. Saída em build/release/:
#   zips desktop, APK Android, imagem do tema do launcher, latest.json e COMO-PUBLICAR.txt
#
# Tema do launcher (fundo + frase do arco, vai no "theme" do latest.json). Opcional:
#   THEME_ID=arco2                       usa launcher/themes/arco2/ (padrão: o último de launcher/themes/, em sort -V)
#   THEME_IMAGE=arte.jpg THEME_ID=arco2  usa outra imagem (.jpg/.jpeg/.png/.webp, até 8 MB)
#   THEME_TAGLINE="..."                  troca a frase (padrão: a do theme.json; até 140 caracteres)
#   THEME_ARC="Arco II" THEME_TITLE="..." trocam o selo do arco (padrão: os do theme.json; até 20 e 60)
#   THEME_ID=-                           publica sem tema (o launcher mantém o que já tem em cache)
set -euo pipefail
: "${VERSION:?}" "${BUILD:?}"
NOTES="${NOTES:-}"
SERVER_URL="${SERVER_URL:-}"
DRIVE_URL="${DRIVE_URL:-}"
OUT="$BUILD/release"
mkdir -p "$OUT"
rm -f "$OUT"/Perdidos-*.zip "$OUT"/Perdidos-*.apk "$OUT"/theme-* "$OUT/latest.json"

THEMES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/themes"
THEME_ID="${THEME_ID:-}"
THEME_IMAGE="${THEME_IMAGE:-}"
THEME_TAGLINE="${THEME_TAGLINE:-}"
THEME_TITLE="${THEME_TITLE:-}"
THEME_ARC="${THEME_ARC:-}"
THEME_JSON=""
if [[ "$THEME_ID" == "-" ]]; then
	THEME_ID="" THEME_IMAGE=""
elif [[ -n "$THEME_IMAGE" ]]; then
	[[ -f "$THEME_IMAGE" ]] || { echo "THEME_IMAGE não existe: $THEME_IMAGE"; exit 1; }
	[[ -n "$THEME_ID" ]] || { echo "com THEME_IMAGE, informe também THEME_ID (ex.: arco2)"; exit 1; }
else
	if [[ -z "$THEME_ID" && -d "$THEMES_DIR" ]]; then
		THEME_ID="$(find "$THEMES_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort -V | tail -n1)"
	fi
	if [[ -n "$THEME_ID" ]]; then
		[[ -d "$THEMES_DIR/$THEME_ID" ]] || { echo "tema não encontrado: $THEMES_DIR/$THEME_ID"; exit 1; }
		for ext in jpg jpeg png webp; do
			if [[ -f "$THEMES_DIR/$THEME_ID/background.$ext" ]]; then THEME_IMAGE="$THEMES_DIR/$THEME_ID/background.$ext"; break; fi
		done
		[[ -n "$THEME_IMAGE" ]] || { echo "faltou $THEMES_DIR/$THEME_ID/background.jpg (ou .png/.webp)"; exit 1; }
		[[ -f "$THEMES_DIR/$THEME_ID/theme.json" ]] && THEME_JSON="$THEMES_DIR/$THEME_ID/theme.json"
	fi
fi

declare -A EXE=([windows]=Perdidos.exe [linux]=Perdidos.x86_64)
for plat in windows linux; do
	src="$BUILD/$plat"
	[[ -f "$src/${EXE[$plat]}" ]] || { echo "faltou $src/${EXE[$plat]} (rode make build-$plat)"; exit 1; }
	echo "$VERSION" > "$src/version.txt"
	zip_name="Perdidos-$VERSION-$plat.zip"
	(cd "$src" && zip -q -r -X "$OUT/$zip_name" .)
	echo ">> $zip_name ($(du -h "$OUT/$zip_name" | cut -f1))"
done

android_apk="$BUILD/android/Perdidos.apk"
[[ -f "$android_apk" ]] || { echo "faltou $android_apk (rode make build-apk)"; exit 1; }
android_name="Perdidos-$VERSION-android.apk"
cp "$android_apk" "$OUT/$android_name"
echo ">> $android_name ($(du -h "$OUT/$android_name" | cut -f1))"

python3 - "$OUT" "$VERSION" "$NOTES" "$SERVER_URL" "$android_name" \
	"$THEME_ID" "$THEME_IMAGE" "$THEME_TAGLINE" "$THEME_JSON" "$THEME_TITLE" "$THEME_ARC" <<'PY'
import hashlib, json, os, re, shutil, sys, datetime
out, version, notes, server, android_name = sys.argv[1:6]
theme_id, theme_image, theme_tagline, theme_json, theme_title, theme_arc = sys.argv[6:12]
files = {}
for plat, exe in (("windows", "Perdidos.exe"), ("linux", "Perdidos.x86_64")):
    name = f"Perdidos-{version}-{plat}.zip"
    path = os.path.join(out, name)
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    files[plat] = {"name": name, "sha256": h.hexdigest(), "size": os.path.getsize(path), "exe": exe}
path = os.path.join(out, android_name)
h = hashlib.sha256()
with open(path, "rb") as f:
    for chunk in iter(lambda: f.read(1 << 20), b""):
        h.update(chunk)
files["android"] = {"name": android_name, "sha256": h.hexdigest(), "size": os.path.getsize(path)}
manifest = {
    "version": version,
    "files": files,
    "notes": notes or f"Versão {version}.",
    "published": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
}
if server:
    manifest["server"] = server
if theme_image:
    # Same rules as the launcher (internal/update/theme.go): an invalid theme would be ignored there.
    tagline = theme_tagline
    if theme_json:
        with open(theme_json, encoding="utf-8") as f:
            meta = json.load(f)
        if meta.get("id") and meta["id"] != theme_id:
            sys.exit(f"{theme_json}: id {meta['id']!r} não bate com a pasta {theme_id!r}")
        tagline = tagline or meta.get("tagline", "")
        theme_title = theme_title or meta.get("title", "")
        theme_arc = theme_arc or meta.get("arc", "")
    tagline = tagline.strip()
    title = theme_title.strip()
    arc = theme_arc.strip()
    if len(arc) > 20:
        sys.exit(f"o arco do tema tem {len(arc)} caracteres (máximo 20)")
    if len(title) > 60:
        sys.exit(f"o título do tema tem {len(title)} caracteres (máximo 60)")
    if re.search(r"[<>\x00-\x1f\x7f]", arc + title + tagline):
        sys.exit("arco/título/frase do tema: só texto simples (sem <, > nem caracteres de controle)")
    if not re.fullmatch(r"[a-z0-9][a-z0-9_-]{0,31}", theme_id):
        sys.exit(f"THEME_ID inválido {theme_id!r} (minúsculas, números, _ e -; até 32)")
    if len(tagline) > 140:
        sys.exit(f"a frase do tema tem {len(tagline)} caracteres (máximo 140)")
    ext = os.path.splitext(theme_image)[1].lower()
    if ext not in (".jpg", ".jpeg", ".png", ".webp"):
        sys.exit(f"imagem do tema precisa ser .jpg, .jpeg, .png ou .webp: {theme_image}")
    size = os.path.getsize(theme_image)
    if not 0 < size <= 8 << 20:
        sys.exit(f"imagem do tema com {size} bytes (máximo 8 MB)")
    name = f"theme-{theme_id}{ext}"
    shutil.copyfile(theme_image, os.path.join(out, name))
    with open(os.path.join(out, name), "rb") as f:
        digest = hashlib.sha256(f.read()).hexdigest()
    manifest["theme"] = {"id": theme_id, "tagline": tagline,
                         "background": {"name": name, "sha256": digest, "size": size}}
    if arc:
        manifest["theme"]["arc"] = arc
    if title:
        manifest["theme"]["title"] = title
with open(os.path.join(out, "latest.json"), "w", encoding="utf-8") as f:
    json.dump(manifest, f, ensure_ascii=False, indent=2)
    f.write("\n")
PY

theme_name="$(cd "$OUT" && ls theme-* 2>/dev/null | head -n1 || true)"
if [[ -n "$theme_name" ]]; then
	theme_line="  - $theme_name   (fundo do launcher do tema \"$THEME_ID\")"
	theme_step="Suba também a imagem do tema ($theme_name), na raiz ou na subpasta \"theme\"."
else
	theme_line="  (sem tema do launcher nesta versão)"
	theme_step="(Nesta versão não há imagem de tema para subir.)"
fi

cat > "$OUT/COMO-PUBLICAR.txt" <<EOF
Perdidos $VERSION — como publicar no Google Drive
=================================================

Arquivos desta versão (pasta build/release/):
  - Perdidos-$VERSION-windows.zip
  - Perdidos-$VERSION-linux.zip
  - $android_name
$theme_line
  - latest.json

Pasta pública do Drive: ${DRIVE_URL:-(a configurada no launcher)}

1. Abra a pasta no navegador (logado na conta dona da pasta).
2. Suba os DOIS zips e o APK Android antes do latest.json (Novo > Upload de arquivo).
    Os zips podem ficar na raiz da pasta ou nas subpastas "windows" e "linux".
   $theme_step
   Se já existe uma imagem com o mesmo nome, use "Gerenciar versões" (não deixe duas).
3. Espere o upload terminar (a barra do Drive some).
4. Só então suba o latest.json NA RAIZ da pasta.
   - Se já existe um latest.json: clique com o botão direito > "Gerenciar versões" >
     "Enviar nova versão" (mantém o mesmo arquivo) — ou apague o antigo e suba o novo.
     Não deixe dois latest.json na pasta.
5. Confira: abra https://drive.google.com/embeddedfolderview?id=<ID-da-pasta> numa aba anônima;
    todos os arquivos acima devem aparecer com o nome exato.
6. Abra o launcher: ele mostra "Nova versão $VERSION disponível" e o botão Atualizar.
7. Versões antigas (zips) podem ser apagadas do Drive depois que todos atualizarem.

A pasta precisa estar como "Qualquer pessoa com o link: Leitor".
Também copiamos o latest.json para a API (make serve-ngrok serve build/release/latest.json
em /api/latest e a imagem do tema em /api/theme/<nome>) — é o plano B do launcher quando o
Drive falha.
EOF

echo ">> pronto: $OUT/latest.json"
echo
cat "$OUT/latest.json"
echo
cat "$OUT/COMO-PUBLICAR.txt"

#!/usr/bin/env bash
# Empacota uma versão do jogo para distribuição (chamado por `make release VERSION=x.y.z`).
# Entrada: build/windows/, build/linux/ e build/android/ já exportados. Saída em build/release/:
#   zips desktop, APK Android, latest.json e COMO-PUBLICAR.txt
set -euo pipefail
: "${VERSION:?}" "${BUILD:?}"
NOTES="${NOTES:-}"
SERVER_URL="${SERVER_URL:-}"
DRIVE_URL="${DRIVE_URL:-}"
OUT="$BUILD/release"
mkdir -p "$OUT"
rm -f "$OUT"/Perdidos-*.zip "$OUT"/Perdidos-*.apk "$OUT/latest.json"

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

python3 - "$OUT" "$VERSION" "$NOTES" "$SERVER_URL" "$android_name" <<'PY'
import hashlib, json, os, sys, datetime
out, version, notes, server, android_name = sys.argv[1:6]
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
with open(os.path.join(out, "latest.json"), "w", encoding="utf-8") as f:
    json.dump(manifest, f, ensure_ascii=False, indent=2)
    f.write("\n")
PY

cat > "$OUT/COMO-PUBLICAR.txt" <<EOF
Perdidos $VERSION — como publicar no Google Drive
=================================================

Arquivos desta versão (pasta build/release/):
  - Perdidos-$VERSION-windows.zip
  - Perdidos-$VERSION-linux.zip
    - $android_name
  - latest.json

Pasta pública do Drive: ${DRIVE_URL:-(a configurada no launcher)}

1. Abra a pasta no navegador (logado na conta dona da pasta).
2. Suba os DOIS zips e o APK Android antes do latest.json (Novo > Upload de arquivo).
    Os zips podem ficar na raiz da pasta ou nas subpastas "windows" e "linux".
3. Espere o upload terminar (a barra do Drive some).
4. Só então suba o latest.json NA RAIZ da pasta.
   - Se já existe um latest.json: clique com o botão direito > "Gerenciar versões" >
     "Enviar nova versão" (mantém o mesmo arquivo) — ou apague o antigo e suba o novo.
     Não deixe dois latest.json na pasta.
5. Confira: abra https://drive.google.com/embeddedfolderview?id=<ID-da-pasta> numa aba anônima;
    os quatro arquivos devem aparecer com o nome exato.
6. Abra o launcher: ele mostra "Nova versão $VERSION disponível" e o botão Atualizar.
7. Versões antigas (zips) podem ser apagadas do Drive depois que todos atualizarem.

A pasta precisa estar como "Qualquer pessoa com o link: Leitor".
Também copiamos o latest.json para a API (make serve-ngrok serve build/release/latest.json
em /api/latest) — é o plano B do launcher quando o Drive falha.
EOF

echo ">> pronto: $OUT/latest.json"
echo
cat "$OUT/latest.json"
echo
cat "$OUT/COMO-PUBLICAR.txt"

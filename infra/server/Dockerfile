# Servidor dedicado do Projeto Isekai (headless, autoritativo).
# Roda o projeto com o binário oficial da Godot em modo headless. Quando os templates de export
# estiverem no CI, trocar por uma imagem só com o executável gerado por `make build-server`.
FROM debian:bookworm-slim

ARG GODOT_VERSION=4.7.2
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl unzip libfontconfig1 \
 && curl -fsSL -o /tmp/godot.zip \
      "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip" \
 && unzip -q /tmp/godot.zip -d /tmp \
 && mv "/tmp/Godot_v${GODOT_VERSION}-stable_linux.x86_64" /usr/local/bin/godot \
 && rm -rf /tmp/godot.zip /var/lib/apt/lists/* \
 && useradd --create-home --uid 10001 game \
 && mkdir -p /data/saves /srv/game && chown game:game /data/saves /srv/game

WORKDIR /srv/game
COPY --chown=game:game game/ ./
USER game
# Importa os recursos na construção da imagem (a subida do container fica rápida).
RUN godot --headless --path /srv/game --import \
 && test -f /srv/game/.godot/global_script_class_cache.cfg

EXPOSE 7777/udp
ENV GAME_PORT=7777
CMD ["sh", "-c", "exec godot --headless --path /srv/game -- --server --port=${GAME_PORT} --save-dir=/data/saves/"]

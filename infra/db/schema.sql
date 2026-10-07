-- =============================================================================
-- Projeto Isekai — esquema do banco (PostgreSQL 16+)
-- Fonte: GDD §15.5 (tabelas mínimas) + decisões do marco "Passeio no Porto do Despertar"
-- (espaços cosméticos, flags de "só uma vez", aparência replicada).
--
-- Uso em produção (banco vazio):
--   psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f infra/db/schema.sql
-- No docker-compose ele roda sozinho na primeira subida do postgres
-- (montado em /docker-entrypoint-initdb.d).
-- Mudanças futuras: novos arquivos em infra/db/migrations/NNNN_descricao.sql,
-- registrados em schema_migrations. Nunca editar este arquivo depois de aplicado em produção.
-- =============================================================================

BEGIN;

CREATE EXTENSION IF NOT EXISTS citext;

CREATE TABLE schema_migrations (
    version     text PRIMARY KEY,
    applied_at  timestamptz NOT NULL DEFAULT now()
);

-- -----------------------------------------------------------------------------
-- Contas (GDD §15.6). Senha só como hash argon2; o servidor de jogo nunca vê a senha.
-- -----------------------------------------------------------------------------
CREATE TABLE accounts (
    id              bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    email           citext      NOT NULL UNIQUE,
    password_hash   text        NOT NULL CHECK (password_hash LIKE '$argon2%'),
    created_at      timestamptz NOT NULL DEFAULT now(),
    last_login_at   timestamptz,
    flags           jsonb       NOT NULL DEFAULT '{}'::jsonb   -- ex.: {"banned": true, "tester": true}
);

-- -----------------------------------------------------------------------------
-- Personagens (GDD §6). Nome único no servidor, sem diferenciar maiúsculas.
-- -----------------------------------------------------------------------------
CREATE TABLE characters (
    id              bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    account_id      bigint      NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    name            citext      NOT NULL UNIQUE CHECK (char_length(name) BETWEEN 3 AND 16),
    body_type       text        NOT NULL CHECK (body_type IN ('male', 'female')),
    -- tom de pele, cabelo (estilo/cor), olhos, variação da roupa inicial (GDD §6.1)
    appearance      jsonb       NOT NULL DEFAULT '{}'::jsonb,
    level           smallint    NOT NULL DEFAULT 1 CHECK (level BETWEEN 1 AND 25),
    xp              bigint      NOT NULL DEFAULT 0 CHECK (xp >= 0),
    -- {"str":5,"dex":5,"vit":5,"int":5,"spi":5}
    attributes      jsonb       NOT NULL DEFAULT '{"str":5,"dex":5,"vit":5,"int":5,"spi":5}'::jsonb,
    free_points     smallint    NOT NULL DEFAULT 0 CHECK (free_points >= 0),
    hp              integer     NOT NULL CHECK (hp >= 0),
    mp              integer     NOT NULL CHECK (mp >= 0),
    map_id          text        NOT NULL DEFAULT 'city_awakening',
    pos_x           real        NOT NULL DEFAULT 0,
    pos_y           real        NOT NULL DEFAULT 0,
    pos_z           real        NOT NULL DEFAULT 0,
    facing_yaw      real        NOT NULL DEFAULT 0,
    stars           bigint      NOT NULL DEFAULT 100 CHECK (stars >= 0),   -- moeda (GDD §10.5)
    once_flags      text[]      NOT NULL DEFAULT '{}',                     -- ex.: give:curious_child:ipe_flower_crown
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now(),
    deleted_at      timestamptz
);
CREATE INDEX characters_account_idx ON characters (account_id) WHERE deleted_at IS NULL;

-- -----------------------------------------------------------------------------
-- Skills e barra de atalhos (GDD §8)
-- -----------------------------------------------------------------------------
CREATE TABLE character_skills (
    character_id    bigint   NOT NULL REFERENCES characters(id) ON DELETE CASCADE,
    skill_id        text     NOT NULL,
    level           smallint NOT NULL DEFAULT 1 CHECK (level BETWEEN 1 AND 10),
    xp              integer  NOT NULL DEFAULT 0 CHECK (xp >= 0),
    learned_at      timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (character_id, skill_id)
);

CREATE TABLE character_hotbar (
    character_id    bigint   NOT NULL REFERENCES characters(id) ON DELETE CASCADE,
    slot            smallint NOT NULL CHECK (slot BETWEEN 0 AND 7),
    skill_id        text     NOT NULL,
    PRIMARY KEY (character_id, slot),
    FOREIGN KEY (character_id, skill_id) REFERENCES character_skills(character_id, skill_id) ON DELETE CASCADE
);

-- -----------------------------------------------------------------------------
-- Túmulos — Marca da Alma (GDD §12). Não pertencem à instância.
-- -----------------------------------------------------------------------------
CREATE TABLE graves (
    id                  bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    owner_character_id  bigint      NOT NULL REFERENCES characters(id) ON DELETE CASCADE,
    map_id              text        NOT NULL,
    pos_x               real        NOT NULL,
    pos_y               real        NOT NULL,
    pos_z               real        NOT NULL,
    killer_character_id bigint      REFERENCES characters(id) ON DELETE SET NULL,  -- só no PVP
    created_at          timestamptz NOT NULL DEFAULT now(),
    expires_at          timestamptz NOT NULL DEFAULT now() + interval '3 hours'
);
CREATE INDEX graves_owner_map_idx ON graves (owner_character_id, map_id);
CREATE INDEX graves_expires_idx   ON graves (expires_at);   -- job de limpeza

-- -----------------------------------------------------------------------------
-- Itens (GDD §11). Cada linha é uma pilha; o local define o dono e o espaço.
-- -----------------------------------------------------------------------------
CREATE TYPE item_location AS ENUM ('inventory', 'equipped', 'storage', 'grave');

CREATE TABLE items (
    id                  bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    item_def_id         text          NOT NULL,                 -- id do ItemDef (data/items/<id>.tres)
    quantity            smallint      NOT NULL DEFAULT 1 CHECK (quantity BETWEEN 1 AND 99),
    rarity              smallint      NOT NULL DEFAULT 0 CHECK (rarity BETWEEN 0 AND 3),  -- comum..épico
    extra_attributes    jsonb         NOT NULL DEFAULT '{}'::jsonb,
    location            item_location NOT NULL,
    character_id        bigint        REFERENCES characters(id) ON DELETE CASCADE,
    storage_account_id  bigint        REFERENCES accounts(id) ON DELETE CASCADE,
    slot_index          smallint,                               -- inventory (0..39) / storage (0..59)
    equip_slot          text,                                   -- equipped
    protected           boolean       NOT NULL DEFAULT false,   -- GDD §12.4 (infraestrutura)
    created_at          timestamptz   NOT NULL DEFAULT now(),
    CONSTRAINT items_owner_by_location CHECK (
        (location = 'inventory' AND character_id IS NOT NULL AND storage_account_id IS NULL
            AND slot_index BETWEEN 0 AND 39 AND equip_slot IS NULL)
     OR (location = 'equipped'  AND character_id IS NOT NULL AND storage_account_id IS NULL
            AND slot_index IS NULL AND equip_slot IN ('weapon','offhand','head','body','feet',
                'accessory_1','accessory_2','cosmetic_head','cosmetic_body','cosmetic_weapon'))
     OR (location = 'storage'   AND storage_account_id IS NOT NULL AND character_id IS NULL
            AND slot_index BETWEEN 0 AND 59 AND equip_slot IS NULL)
     OR (location = 'grave'     AND character_id IS NULL AND storage_account_id IS NULL
            AND slot_index IS NULL AND equip_slot IS NULL)
    )
);
CREATE UNIQUE INDEX items_inventory_slot_uq ON items (character_id, slot_index) WHERE location = 'inventory';
CREATE UNIQUE INDEX items_equip_slot_uq     ON items (character_id, equip_slot) WHERE location = 'equipped';
CREATE UNIQUE INDEX items_storage_slot_uq   ON items (storage_account_id, slot_index) WHERE location = 'storage';

CREATE TABLE grave_items (
    grave_id    bigint NOT NULL REFERENCES graves(id) ON DELETE CASCADE,
    item_id     bigint NOT NULL UNIQUE REFERENCES items(id) ON DELETE CASCADE,
    PRIMARY KEY (grave_id, item_id)
);

-- -----------------------------------------------------------------------------
-- Quests (GDD §9)
-- -----------------------------------------------------------------------------
CREATE TABLE quests_progress (
    character_id    bigint   NOT NULL REFERENCES characters(id) ON DELETE CASCADE,
    quest_id        text     NOT NULL,
    step            smallint NOT NULL DEFAULT 0,
    progress        jsonb    NOT NULL DEFAULT '{}'::jsonb,
    started_at      timestamptz NOT NULL DEFAULT now(),
    completed_at    timestamptz,
    PRIMARY KEY (character_id, quest_id)
);

-- -----------------------------------------------------------------------------
-- Social (GDD §13)
-- -----------------------------------------------------------------------------
CREATE TABLE friends (
    character_id        bigint NOT NULL REFERENCES characters(id) ON DELETE CASCADE,
    friend_character_id bigint NOT NULL REFERENCES characters(id) ON DELETE CASCADE,
    created_at          timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (character_id, friend_character_id),
    CHECK (character_id <> friend_character_id)
);

CREATE TABLE blocks (
    character_id         bigint NOT NULL REFERENCES characters(id) ON DELETE CASCADE,
    blocked_character_id bigint NOT NULL REFERENCES characters(id) ON DELETE CASCADE,
    created_at           timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (character_id, blocked_character_id),
    CHECK (character_id <> blocked_character_id)
);

-- -----------------------------------------------------------------------------
-- Métricas do playtest (GDD §3.3)
-- -----------------------------------------------------------------------------
CREATE TABLE metrics_events (
    id              bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    character_id    bigint REFERENCES characters(id) ON DELETE SET NULL,
    type            text   NOT NULL,          -- ex.: session_start, death, grave_recovered, quest_done
    platform        text,                     -- pc / android
    data            jsonb  NOT NULL DEFAULT '{}'::jsonb,
    created_at      timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX metrics_events_type_time_idx ON metrics_events (type, created_at);

-- updated_at automático em characters
CREATE FUNCTION touch_updated_at() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    NEW.updated_at := now();
    RETURN NEW;
END $$;
CREATE TRIGGER characters_touch BEFORE UPDATE ON characters
    FOR EACH ROW EXECUTE FUNCTION touch_updated_at();

INSERT INTO schema_migrations (version) VALUES ('0001_initial');

COMMIT;

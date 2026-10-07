-- Lista de espera do site Perdidos. Aplicação idempotente.
CREATE TABLE IF NOT EXISTS public.lista_de_espera (
 id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 email TEXT NOT NULL,
 nome TEXT NOT NULL DEFAULT '',
 plataforma TEXT NOT NULL CHECK (plataforma IN ('windows','linux','android','indeciso')),
 criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
 consentimento_em TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE UNIQUE INDEX IF NOT EXISTS lista_de_espera_email_unico ON public.lista_de_espera (lower(email));

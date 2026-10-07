import { Call, Events } from "@wailsio/runtime";

// ------------------------------------------------------------------ backend (service.go)
interface State {
  loggedIn: boolean;
  email: string;
  savedEmail: string;
  rememberEmail: boolean;
  installed: string;
  installDir: string;
  platform: string;
  launcherVersion: string;
  updating: boolean;
  playing: boolean;
}
interface Result { ok: boolean; error?: string; field?: string; state: State; }
interface UpdateInfo {
  status: "not_installed" | "update_available" | "up_to_date" | "no_release" | "offline" | "no_build";
  installed: string;
  latest: string;
  notes: string;
  size: number;
  origin: string;
  message: string;
}
interface Progress { phase: string; done: number; total: number; speed: number; eta: number; attempt: number; message?: string; }
interface Finished { ok: boolean; message: string; installed: string; }

const call = <T>(method: string, ...args: unknown[]): Promise<T> =>
  Call.ByName(`main.LauncherService.${method}`, ...args) as Promise<T>;

// ------------------------------------------------------------------ DOM
const $ = <T extends HTMLElement>(id: string) => document.getElementById(id) as T;
const authPanel = $("auth");
const homePanel = $("home");
const form = $<HTMLFormElement>("auth-form");
const emailIn = $<HTMLInputElement>("email");
const passIn = $<HTMLInputElement>("password");
const confirmIn = $<HTMLInputElement>("confirm");
const rememberIn = $<HTMLInputElement>("remember");
const authError = $("auth-error");
const authSubmit = $<HTMLButtonElement>("auth-submit");
const googleLogin = $<HTMLButtonElement>("google-login");
const mainBtn = $<HTMLButtonElement>("main-btn");
const cancelBtn = $<HTMLButtonElement>("cancel-btn");
const refreshBtn = $<HTMLButtonElement>("refresh-btn");
const statusEl = $("status");
const progressEl = $("progress");
const fill = $("fill");
const pLeft = $("p-left");
const pRight = $("p-right");
const news = $("news");
const notes = $("notes");
const launcherMusic = $<HTMLAudioElement>("launcher-music");
const musicToggle = $<HTMLButtonElement>("music-toggle");

let mode: "login" | "register" = "login";
let state: State;
let info: UpdateInfo | null = null;
let busy = false;
let musicEnabled = localStorage.getItem("perdidosLauncherMusic") !== "off";

function updateMusicControl() {
  musicToggle.classList.toggle("is-playing", musicEnabled && !launcherMusic.paused);
  musicToggle.setAttribute("aria-label", musicEnabled ? "Desativar música" : "Ativar música");
  musicToggle.title = musicEnabled ? "Desativar música" : "Ativar música";
}

async function startLauncherMusic() {
  if (!musicEnabled) return;
  try {
    await launcherMusic.play();
  } catch {
    const resume = () => {
      if (musicEnabled) void launcherMusic.play().then(updateMusicControl).catch(() => {});
    };
    document.addEventListener("pointerdown", resume, { once: true });
    document.addEventListener("keydown", resume, { once: true });
  }
  updateMusicControl();
}

musicToggle.addEventListener("click", () => {
  musicEnabled = !musicEnabled;
  localStorage.setItem("perdidosLauncherMusic", musicEnabled ? "on" : "off");
  if (musicEnabled) void startLauncherMusic();
  else launcherMusic.pause();
  updateMusicControl();
});

launcherMusic.addEventListener("play", updateMusicControl);
launcherMusic.addEventListener("pause", updateMusicControl);
updateMusicControl();
void startLauncherMusic();

// ------------------------------------------------------------------ formatting (pt-BR)
const nf1 = new Intl.NumberFormat("pt-BR", { maximumFractionDigits: 1, minimumFractionDigits: 1 });
function bytes(n: number): string {
  if (n >= 1024 ** 3) return `${nf1.format(n / 1024 ** 3)}\u00a0GB`;
  if (n >= 1024 ** 2) return `${nf1.format(n / 1024 ** 2)}\u00a0MB`;
  if (n >= 1024) return `${Math.round(n / 1024)} KB`;
  return `${n} B`;
}
function duration(s: number): string {
  if (!isFinite(s) || s < 0) return "calculando…";
  s = Math.round(s);
  if (s < 60) return `${s} s`;
  const m = Math.floor(s / 60);
  if (m < 60) return `${m} min ${String(s % 60).padStart(2, "0")} s`;
  return `${Math.floor(m / 60)} h ${String(m % 60).padStart(2, "0")} min`;
}

// ------------------------------------------------------------------ auth screen
function setMode(m: typeof mode) {
  mode = m;
  authPanel.classList.toggle("register", m === "register");
  document.querySelectorAll<HTMLButtonElement>(".tab").forEach((t) => {
    const on = t.dataset.mode === m;
    t.classList.toggle("active", on);
    t.setAttribute("aria-selected", String(on));
  });
  authSubmit.textContent = m === "login" ? "Entrar" : "Criar conta";
  passIn.autocomplete = m === "login" ? "current-password" : "new-password";
  showAuthError("");
}

function showAuthError(msg: string, field = "") {
  authError.textContent = msg;
  for (const [name, el] of [["email", emailIn], ["password", passIn], ["confirm", confirmIn]] as const) {
    el.classList.toggle("invalid", field === name);
  }
  if (field === "email") emailIn.focus();
  else if (field === "password") passIn.focus();
  else if (field === "confirm") confirmIn.focus();
}

function localCheck(): [string, string] | null {
  const email = emailIn.value.trim();
  if (!email) return ["Digite seu e-mail.", "email"];
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) return ["Esse e-mail não parece válido.", "email"];
  if (!passIn.value) return ["Digite sua senha.", "password"];
  if (mode === "register") {
    if ([...passIn.value].length < 8) return ["A senha precisa ter pelo menos 8 caracteres.", "password"];
    if (passIn.value !== confirmIn.value) return ["As senhas não são iguais.", "confirm"];
  }
  return null;
}

form.addEventListener("submit", async (ev) => {
  ev.preventDefault();
  if (busy) return;
  const bad = localCheck();
  if (bad) return showAuthError(...bad);
  busy = true;
  authSubmit.disabled = true;
  authSubmit.textContent = mode === "login" ? "Entrando…" : "Criando conta…";
  try {
    const r = mode === "login"
      ? await call<Result>("Login", emailIn.value, passIn.value, rememberIn.checked)
      : await call<Result>("Register", emailIn.value, passIn.value, confirmIn.value, rememberIn.checked);
    if (!r.ok) {
      showAuthError(r.error ?? "Algo deu errado.", r.field ?? "");
      return;
    }
    passIn.value = confirmIn.value = "";
    state = r.state;
    showHome();
  } catch (e) {
    showAuthError("Erro inesperado: " + String(e));
  } finally {
    busy = false;
    authSubmit.disabled = false;
    authSubmit.textContent = mode === "login" ? "Entrar" : "Criar conta";
  }
});

googleLogin.addEventListener("click", async () => {
  if (busy) return;
  busy = true;
  googleLogin.disabled = true;
  authSubmit.disabled = true;
  googleLogin.querySelector("span:last-child")!.textContent = "Aguardando Google…";
  try {
    const r = await call<Result>("LoginWithGoogle");
    if (!r.ok) {
      showAuthError(r.error ?? "Não foi possível entrar com Google.");
      return;
    }
    state = r.state;
    showHome();
  } catch (e) {
    showAuthError("Não foi possível entrar com Google: " + String(e));
  } finally {
    busy = false;
    googleLogin.disabled = false;
    authSubmit.disabled = false;
    googleLogin.querySelector("span:last-child")!.textContent = "Usar conta Google";
    authSubmit.textContent = mode === "login" ? "Entrar" : "Criar conta";
  }
});

document.querySelectorAll<HTMLButtonElement>(".tab").forEach((t) =>
  t.addEventListener("click", () => setMode(t.dataset.mode as typeof mode)));

function showAuth(msg = "") {
  homePanel.hidden = true;
  authPanel.hidden = false;
  renderNews();
  rememberIn.checked = state.rememberEmail;
  emailIn.value = state.savedEmail || emailIn.value;
  setMode(mode);
  if (msg) showAuthError(msg);
  (emailIn.value ? passIn : emailIn).focus();
}

// ------------------------------------------------------------------ home screen
function setStatus(text: string, kind: "" | "warn" | "ok" = "") {
  statusEl.textContent = text;
  statusEl.className = "status" + (kind ? " " + kind : "");
}

function setMainButton(label: string, enabled: boolean, update = false) {
  mainBtn.textContent = label;
  mainBtn.disabled = !enabled;
  mainBtn.classList.toggle("update", update);
}

function renderNews() {
  const text = info?.notes.trim() ?? "";
  news.hidden = false;
  notes.textContent = text || (info ? "Nenhuma nota de atualização publicada." : "Consultando novidades…");
}

async function loadPublicNews() {
  try {
    info = await call<UpdateInfo>("CheckUpdate");
  } catch {
    info = null;
  }
  renderNews();
}

async function showHome() {
  authPanel.hidden = true;
  homePanel.hidden = false;
  $("who-email").textContent = state.email;
  $("v-installed").textContent = state.installed || "—";
  if (state.updating) return showUpdating();
  await checkUpdate();
}

async function checkUpdate() {
  progressEl.hidden = true;
  cancelBtn.hidden = true;
  setStatus("Verificando atualizações…");
  setMainButton("Jogar", false);
  refreshBtn.disabled = true;
  try {
    info = await call<UpdateInfo>("CheckUpdate");
  } finally {
    refreshBtn.disabled = false;
  }
  renderInfo();
}

function renderInfo() {
  if (!info) return;
  const inst = info.installed || state.installed;
  $("v-installed").textContent = inst || "—";
  const latest = $("v-latest");
  latest.textContent = info.latest || "—";
  latest.classList.toggle("new", info.status === "update_available" || info.status === "not_installed");
  renderNews();
  const size = info.size ? ` (${bytes(info.size)})` : "";
  switch (info.status) {
    case "up_to_date":
      setStatus("Tudo pronto. Boa aventura!", "ok");
      setMainButton("Jogar", true);
      break;
    case "update_available":
      setStatus(`Nova versão ${info.latest} disponível${size}.`);
      setMainButton("Atualizar", true, true);
      break;
    case "not_installed":
      setStatus(`O jogo ainda não está instalado. Versão ${info.latest}${size}.`);
      setMainButton("Instalar", true, true);
      break;
    case "no_release":
      setStatus(inst ? "Nenhuma versão publicada no momento; você pode jogar a instalada." : "Nenhuma versão publicada ainda.", inst ? "" : "warn");
      setMainButton("Jogar", !!inst);
      break;
    case "no_build":
    case "offline":
      setStatus(info.message + (inst ? " Você pode jogar a versão instalada." : ""), "warn");
      setMainButton("Jogar", !!inst);
      break;
  }
}

function showUpdating() {
  progressEl.hidden = false;
  cancelBtn.hidden = false;
  refreshBtn.disabled = true;
  setMainButton("Atualizando…", false, true);
  fill.classList.add("indeterminate");
  setStatus("Preparando o download…");
  pLeft.textContent = "";
  pRight.textContent = "";
}

mainBtn.addEventListener("click", async () => {
  if (!info && !state.installed) return;
  const label = mainBtn.textContent;
  if (label === "Atualizar" || label === "Instalar") {
    showUpdating();
    const r = await call<Result>("StartUpdate");
    if (!r.ok) {
      setStatus(r.error ?? "Falha ao iniciar a atualização.", "warn");
      progressEl.hidden = true;
      cancelBtn.hidden = true;
      refreshBtn.disabled = false;
      renderInfo();
    }
    return;
  }
  setMainButton("Abrindo…", false);
  const r = await call<Result>("Play");
  if (!r.ok) {
    if (r.field === "session") {
      state = r.state;
      return showAuth(r.error);
    }
    setStatus(r.error ?? "Não foi possível abrir o jogo.", "warn");
    renderInfo();
    setStatus(r.error ?? "", "warn");
    return;
  }
  setStatus("O jogo está aberto. Este launcher volta quando você fechar o jogo.", "ok");
  setMainButton("Jogando…", false);
});

cancelBtn.addEventListener("click", () => call("CancelUpdate"));
refreshBtn.addEventListener("click", () => checkUpdate());

$("logout").addEventListener("click", async () => {
  state = await call<State>("Logout");
  info = null;
  showAuth();
  await loadPublicNews();
});

// ------------------------------------------------------------------ events from Go
const unwrap = <T>(ev: { data: unknown }): T =>
  (Array.isArray(ev.data) && ev.data.length === 1 ? ev.data[0] : ev.data) as T;

Events.On("update:progress", (ev) => {
  const p = unwrap<Progress>(ev);
  progressEl.hidden = false;
  const pct = p.total > 0 ? Math.min(100, (p.done / p.total) * 100) : 0;
  fill.classList.toggle("indeterminate", p.total <= 0 || p.phase === "verify");
  fill.style.width = `${pct.toFixed(1)}%`;
  if (p.phase === "download") {
    setStatus(p.message ?? (p.attempt > 1 ? `Baixando (tentativa ${p.attempt})…` : "Baixando atualização…"), p.message ? "warn" : "");
    pLeft.textContent = p.total > 0 ? `${bytes(p.done)} de ${bytes(p.total)} · ${Math.floor(pct)}%` : bytes(p.done);
    pRight.textContent = p.speed > 0 ? `${bytes(p.speed)}/s · falta ${duration(p.eta)}` : "";
  } else if (p.phase === "verify") {
    setStatus("Conferindo o arquivo (SHA-256)…");
    pLeft.textContent = "";
    pRight.textContent = "";
  } else if (p.phase === "extract") {
    setStatus("Instalando…");
    pLeft.textContent = `${Math.floor(pct)}%`;
    pRight.textContent = "";
  }
});

Events.On("update:finished", async (ev) => {
  const f = unwrap<Finished>(ev);
  fill.classList.remove("indeterminate");
  cancelBtn.hidden = true;
  refreshBtn.disabled = false;
  if (f.ok) {
    state = await call<State>("GetState");
    progressEl.hidden = true;
    if (info) {
      info.installed = f.installed;
      info.status = "up_to_date";
    }
    renderInfo();
    setStatus(f.message + " Tudo pronto. Boa aventura!", "ok");
  } else {
    progressEl.hidden = true;
    renderInfo();
    setStatus(f.message, "warn");
  }
});

Events.On("game:exited", async () => {
  state = await call<State>("GetState");
  if (!state.loggedIn) return showAuth("Sua sessão expirou. Entre de novo.");
  await checkUpdate();
});

// ------------------------------------------------------------------ start
(async () => {
  state = await call<State>("GetState");
  $("foot-version").textContent = `Launcher ${state.launcherVersion} · ${state.platform === "windows" ? "Windows" : "Linux"}`;
  $("foot-dir").textContent = `Instalado em ${state.installDir}`;
  if (state.loggedIn) await showHome();
  else {
    showAuth();
    await loadPublicNews();
  }
})();

"""Bria image edit + background removal (key from $BK or ~/.zshrc BRIA_API_KEy; never printed)."""
import base64, json, os, re, time, urllib.error, urllib.request

EDIT_URL = "https://engine.prod.bria-api.com/v2/image/edit"
RMBG_URL = "https://engine.prod.bria-api.com/v2/image/edit/remove_background"


def _key() -> str:
    k = os.environ.get("BK", "")
    if k:
        return k
    txt = open(os.path.expanduser("~/.zshrc"), encoding="utf-8", errors="ignore").read()
    m = re.search(r"BRIA_API_KEy=[\"']?([^\"'\s]+)", txt)
    if not m:
        raise RuntimeError("Bria key not found (BK or BRIA_API_KEy in ~/.zshrc)")
    return m.group(1)


def _post(url, body):
    r = urllib.request.Request(url, data=json.dumps(body).encode(),
                               headers={"api_token": _key(), "Content-Type": "application/json"})
    try:
        return json.load(urllib.request.urlopen(r, timeout=120))
    except urllib.error.HTTPError as e:
        raise RuntimeError(f"HTTP {e.code}: {e.read()[:300]!r}")


def _poll(u):
    for _ in range(200):
        d = json.load(urllib.request.urlopen(urllib.request.Request(u, headers={"api_token": _key()}), timeout=60))
        if d["status"] == "COMPLETED":
            return d["result"]["image_url"]
        if d["status"] == "FAILED":
            raise RuntimeError(str(d)[:300])
        time.sleep(2)
    raise RuntimeError("timeout")


def _b64(p):
    return "data:image/png;base64," + base64.b64encode(open(p, "rb").read()).decode()


def _retry(fn):
    for t in range(6):
        try:
            return fn()
        except Exception as e:  # noqa: BLE001
            if t == 5 or not any(k in str(e) for k in ("429", "timed out", "HTTP 5", "Remote", "timeout", "reset")):
                raise
            time.sleep(6 * (t + 1))


def edit(src, instruction, out, seed=None):
    """Edits src (png path) following the instruction; writes out. Skips when out exists."""
    if os.path.exists(out):
        return out

    def go():
        body = {"images": [_b64(src)], "instruction": instruction}
        if seed is not None:
            body["seed"] = seed
        d = _post(EDIT_URL, body)
        url = d.get("result", {}).get("image_url") or _poll(d["status_url"])
        urllib.request.urlretrieve(url, out + ".part")
        os.replace(out + ".part", out)
        return out
    return _retry(go)


def rmbg(src, out):
    if os.path.exists(out):
        return out

    def go():
        d = _post(RMBG_URL, {"image": _b64(src)})
        url = d.get("result", {}).get("image_url") or _poll(d["status_url"])
        urllib.request.urlretrieve(url, out + ".part")
        os.replace(out + ".part", out)
        return out
    return _retry(go)

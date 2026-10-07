import os, sys, json, time, urllib.request, concurrent.futures as cf
KEY = os.environ["BK"]
SEED = int(os.environ.get("SEED", "1000"))
def post(url, body):
    r = urllib.request.Request(url, data=json.dumps(body).encode(), headers={"api_token": KEY, "Content-Type": "application/json"})
    return json.load(urllib.request.urlopen(r, timeout=60))
def poll(u):
    for _ in range(90):
        d = json.load(urllib.request.urlopen(urllib.request.Request(u, headers={"api_token": KEY}), timeout=60))
        if d["status"] == "COMPLETED": return d["result"]["image_url"]
        if d["status"] == "FAILED": raise Exception(d)
        time.sleep(2)
def gen(i, prompt):
    d = post("https://engine.prod.bria-api.com/v2/image/generate", dict({"prompt": prompt, "aspect_ratio": AR, "seed": SEED + i}, **({"negative_prompt": NEG} if NEG else {})))
    url = d.get("result", {}).get("image_url") or poll(d["status_url"])
    urllib.request.urlretrieve(url, f"{sys.argv[1]}_{i}.png"); return i
if __name__=='__main__':
    prompt = open(sys.argv[2]).read().strip()
    NEG = open(os.environ["NEG"]).read().strip() if os.environ.get("NEG") else ""
    n = int(sys.argv[3]) if len(sys.argv) > 3 else 4
    AR = sys.argv[4] if len(sys.argv) > 4 else "1:1"
    
    with cf.ThreadPoolExecutor(4) as ex:
        for f in cf.as_completed([ex.submit(gen, i, prompt) for i in range(n)]):
            try: print("ok", f.result())
            except Exception as e: print("err", e)

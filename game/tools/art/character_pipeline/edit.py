import os, sys, json, time, base64, urllib.request, concurrent.futures as cf
from gen import post, poll
def edit(src, instruction, out, seed=None):
    b64 = "data:image/png;base64," + base64.b64encode(open(src,'rb').read()).decode()
    body = {"images": [b64], "instruction": instruction}
    if seed is not None: body["seed"] = seed
    d = post("https://engine.prod.bria-api.com/v2/image/edit", body)
    url = d.get("result", {}).get("image_url") or poll(d["status_url"])
    urllib.request.urlretrieve(url, out); return out
if __name__ == "__main__":
    jobs = json.load(open(sys.argv[1]))  # [[src, instruction, out], ...]
    with cf.ThreadPoolExecutor(6) as ex:
        for f in cf.as_completed([ex.submit(edit, *j) for j in jobs]):
            try: print("ok", f.result())
            except Exception as e: print("err", e)

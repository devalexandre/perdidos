import sys, json, base64, urllib.request, concurrent.futures as cf, os
from gen import post, poll
def rmbg(src, out):
    if os.path.exists(out): return out
    b64="data:image/png;base64,"+base64.b64encode(open(src,'rb').read()).decode()
    d=post("https://engine.prod.bria-api.com/v2/image/edit/remove_background", {"image": b64})
    url=d.get("result",{}).get("image_url") or poll(d["status_url"])
    urllib.request.urlretrieve(url,out); return out
if __name__=="__main__":
    srcs=sys.argv[1:]
    with cf.ThreadPoolExecutor(6) as ex:
        for f in cf.as_completed([ex.submit(rmbg,s,'rb_'+s) for s in srcs]):
            try: print('ok',f.result())
            except Exception as e: print('err',e)

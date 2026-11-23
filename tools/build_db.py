#!/usr/bin/env python3
"""식약처 낱알식별 API 전체 수집 → pills.sqlite 생성.

사용법:
  DATA_GO_KR_KEY=... python3 tools/build_db.py            # API에서 전체 수집
  python3 tools/build_db.py --from-json tools/cache/all.json   # 캐시된 응답 사용
키는 환경 변수로만 받는다 (커밋 금지).
"""
import argparse, json, os, re, sqlite3, sys, time, urllib.parse, urllib.request

ENDPOINT = "https://apis.data.go.kr/1471000/MdcinGrnIdntfcInfoService03/getMdcinGrnIdntfcInfoList03"
PAGE = 500
DEFAULT_OUT = os.path.join(os.path.dirname(__file__), "..", "MediLens", "Data", "Resources", "pills.sqlite")
NOISE = re.compile(r"분할선|마크|\s+")

SCHEMA = """
CREATE TABLE pill (
  item_seq TEXT PRIMARY KEY, name TEXT NOT NULL, eng_name TEXT, company TEXT, chart TEXT,
  shape TEXT, color1 TEXT, color2 TEXT, form TEXT,
  print_front TEXT, print_back TEXT, imprint_front_norm TEXT, imprint_back_norm TEXT,
  line_front TEXT, line_back TEXT,
  len_long REAL, len_short REAL, thick REAL,
  image_url TEXT, img_regist_ts TEXT, change_date TEXT,
  class_name TEXT, etc_otc TEXT, ambiguous INTEGER DEFAULT 0
);
CREATE TABLE pill_color (item_seq TEXT NOT NULL, color TEXT NOT NULL);
CREATE INDEX idx_pill_shape ON pill(shape);
CREATE INDEX idx_pill_color ON pill_color(color, item_seq);
CREATE INDEX idx_pill_img_ts ON pill(img_regist_ts);
CREATE VIRTUAL TABLE pill_imprint_fts USING fts5(
  imprint_front_norm, imprint_back_norm, content='pill', content_rowid='rowid');
CREATE TABLE sync_meta (key TEXT PRIMARY KEY, value TEXT);
"""

def fetch_all(key):
    out, page = [], 1
    while True:
        url = ENDPOINT + "?" + urllib.parse.urlencode(
            {"serviceKey": key, "type": "json", "pageNo": page, "numOfRows": PAGE})
        for attempt in range(6):
            try:
                body = json.load(urllib.request.urlopen(url, timeout=90))["body"]
                break
            except Exception as e:  # 네트워크 끊김 재시도
                print(f"retry page={page} attempt={attempt}: {type(e).__name__}", file=sys.stderr)
                time.sleep(2 * (attempt + 1))
        else:
            sys.exit(f"failed to fetch page {page}")
        items = body.get("items", [])
        out += items
        print(f"page {page}: {len(out)}/{body['totalCount']}", file=sys.stderr)
        if not items or len(out) >= body["totalCount"]:
            return out
        page += 1
        time.sleep(0.3)

def norm_imprint(s):
    return NOISE.sub("", s).upper() if s else None

def num(s):
    try: return float(s)
    except (TypeError, ValueError): return None

def split_colors(*vals):
    seen = []
    for v in vals:
        for c in (v or "").split(","):
            c = c.strip()
            if c and c not in seen: seen.append(c)
    return seen

def build(items, out_path):
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    if os.path.exists(out_path): os.remove(out_path)
    db = sqlite3.connect(out_path)
    db.executescript(SCHEMA)
    for i in items:  # 중복 ITEM_SEQ는 마지막 값으로 덮어쓴다
        db.execute("""INSERT OR REPLACE INTO pill (item_seq,name,eng_name,company,chart,shape,color1,color2,form,
            print_front,print_back,imprint_front_norm,imprint_back_norm,line_front,line_back,
            len_long,len_short,thick,image_url,img_regist_ts,change_date,class_name,etc_otc)
            VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)""",
            (i["ITEM_SEQ"], i["ITEM_NAME"], i.get("ITEM_ENG_NAME"), i.get("ENTP_NAME"), i.get("CHART"),
             i.get("DRUG_SHAPE"), i.get("COLOR_CLASS1"), i.get("COLOR_CLASS2"), i.get("FORM_CODE_NAME"),
             i.get("PRINT_FRONT"), i.get("PRINT_BACK"),
             norm_imprint(i.get("PRINT_FRONT")), norm_imprint(i.get("PRINT_BACK")),
             i.get("LINE_FRONT"), i.get("LINE_BACK"),
             num(i.get("LENG_LONG")), num(i.get("LENG_SHORT")), num(i.get("THICK")),
             i.get("ITEM_IMAGE"), i.get("IMG_REGIST_TS"), i.get("CHANGE_DATE"),
             i.get("CLASS_NAME"), i.get("ETC_OTC_NAME")))
        db.execute("DELETE FROM pill_color WHERE item_seq=?", (i["ITEM_SEQ"],))
        for c in split_colors(i.get("COLOR_CLASS1"), i.get("COLOR_CLASS2")):
            db.execute("INSERT INTO pill_color VALUES (?,?)", (i["ITEM_SEQ"], c))
    db.execute("INSERT INTO pill_imprint_fts(rowid,imprint_front_norm,imprint_back_norm) "
               "SELECT rowid,imprint_front_norm,imprint_back_norm FROM pill")
    last = db.execute("SELECT MAX(img_regist_ts) FROM pill").fetchone()[0]
    db.execute("INSERT INTO sync_meta VALUES ('last_synced_date', ?)", (last,))
    db.commit()
    n = db.execute("SELECT COUNT(*) FROM pill").fetchone()[0]
    db.execute("VACUUM"); db.close()
    print(f"wrote {out_path}: {n} pills, last_synced_date={last}, {os.path.getsize(out_path)/1e6:.1f}MB")

if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--from-json"); ap.add_argument("--out", default=DEFAULT_OUT)
    ap.add_argument("--save-json", help="수집한 원본 응답을 캐시 파일로 저장")
    a = ap.parse_args()
    if a.from_json:
        items = json.load(open(a.from_json))
    else:
        key = os.environ.get("DATA_GO_KR_KEY") or sys.exit("DATA_GO_KR_KEY 환경 변수가 필요합니다")
        items = fetch_all(key)
    if a.save_json:
        os.makedirs(os.path.dirname(a.save_json) or ".", exist_ok=True)
        json.dump(items, open(a.save_json, "w"), ensure_ascii=False)
    build(items, os.path.abspath(a.out))

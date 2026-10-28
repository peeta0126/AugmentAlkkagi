#!/usr/bin/env python3
"""팀 현황판과 변경 기록. 표준 라이브러리만 쓴다.

  python .github/team/team.py web                웹 화면을 켠다 (브라우저가 열린다)
  python .github/team/team.py board              현황판을 글로 찍는다
  python .github/team/team.py board --publish    고정 이슈(라벨 현황)에 올린다
  python .github/team/team.py changes A B        A..B 에서 바뀐 기능을 찍는다
  python .github/team/team.py changes A B --publish   변경 기록 이슈에 댓글로 남긴다
  python .github/team/team.py features           지금 있는 기능 목록
  python .github/team/team.py setup              라벨을 만든다(여러 번 돌려도 된다)

사람이 따로 적지 않아도 되도록, 변경 기록은 커밋 메시지가 아니라 파일 내용을 읽어서 만든다.
"""
import http.server, json, os, re, secrets, subprocess, sys, threading, time, urllib.parse, webbrowser
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timedelta, timezone

KST = timezone(timedelta(hours=9))
RARITY = ["일반", "희귀", "영웅", "전설"]
KIND = ["패시브", "발사", "필드", "액티브", "조건부"]
LABELS = {  # 이름: (색, 뜻)
    "진행중": ("1d76db", "지금 하고 있다"),
    "막힘": ("d93f0b", "다른 사람이나 결정이 필요하다"),
    "기능": ("0e8a16", "새로 만들 것"),
    "버그": ("b60205", "잘못 동작하는 것"),
    "우선-높음": ("fbca04", "먼저 해야 한다"),
    "우선-낮음": ("c5def5", "여유 있을 때 한다"),
    "현황": ("5319e7", "자동으로 갱신되는 글. 직접 고치지 않는다"),
}
BOARD_TITLE = "📋 현황판 (자동 갱신 — 직접 고치지 마세요)"
LOG_TITLE = "🆕 변경 기록 (자동 — 무엇이 바뀌었는지 여기서 본다)"
# 앞에서부터 맞는 첫 영역을 쓴다
AREAS = [
    ("resources/augments/", "증강"), ("scripts/augments/", "증강"),
    ("scripts/ui/", "화면"), ("scenes/ui/", "화면"),
    ("scripts/network/", "온라인"),
    ("scripts/physics/", "물리·밸런스"), ("resources/balance/", "물리·밸런스"),
    ("assets/audio/", "소리"),
    ("scripts/effects/", "효과"), ("scenes/effects/", "효과"), ("assets/", "효과"),
    ("scripts/", "규칙"), ("scenes/", "화면"),
    ("tests/", "테스트"), ("docs/", "문서"),
]
IGNORE = (".uid", ".import")


def run(*args, check=True):
    p = subprocess.run(args, capture_output=True, text=True, encoding="utf-8")
    if check and p.returncode:
        sys.exit(f"실패: {' '.join(args)}\n{p.stderr.strip()}")
    return p.stdout


def git(*a, check=True):
    return run("git", *a, check=check)


def gh_json(*a):
    return json.loads(run("gh", *a) or "[]")


def area_of(path):
    for prefix, name in AREAS:
        if path.startswith(prefix):
            return name
    return None


def tracked(path):
    return not path.endswith(IGNORE)


# ---------- 증강 읽기 ----------
def parse_tres(text):
    d = {}
    for m in re.finditer(r'^(\w+) = (.+)$', text, re.M):
        v = m.group(2).strip()
        d[m.group(1)] = v[1:-1] if v.startswith('"') and v.endswith('"') else v
    return d


def augments_at(ref):
    out = {}
    for path in git("ls-tree", "-r", "--name-only", ref, "resources/augments/", check=False).split():
        if not path.endswith(".tres"):
            continue
        d = parse_tres(git("show", f"{ref}:{path}"))
        if "display_name" not in d:
            continue
        out[path] = {
            "이름": d["display_name"],
            "설명": d.get("description", ""),
            "등급": RARITY[int(d["rarity"])] if d.get("rarity", "0").isdigit() else "?",
            "유형": KIND[int(d["kind"])] if d.get("kind", "0").isdigit() else "?",
            "횟수": d.get("max_uses", "0"),
            "쿨다운": d.get("cooldown_turns", "0"),
            "지속": d.get("duration_turns", "0"),
        }
    return out


def aug_line(a):
    extra = []
    if a["횟수"] not in ("0", "-1"):
        extra.append(f"{a['횟수']}회")
    if a["쿨다운"] != "0":
        extra.append(f"쿨다운 {a['쿨다운']}턴")
    if a["지속"] != "0":
        extra.append(f"{a['지속']}턴 지속")
    tail = f" ({', '.join(extra)})" if extra else ""
    return f"**{a['이름']}** — {a['등급']}·{a['유형']}{tail}\n  - {a['설명']}"


def purpose_of(ref, path):
    """새 파일이 무슨 파일인지 사람이 알아볼 한 줄. 첫 ## 주석, 없으면 class_name."""
    if not path.endswith(".gd"):
        return ""
    text = git("show", f"{ref}:{path}", check=False)
    for line in text.splitlines()[:12]:
        s = line.strip()
        if s.startswith("##"):
            return s.lstrip("# ").strip()
    m = re.search(r'^class_name (\w+)', text, re.M)
    return f"클래스 {m.group(1)}" if m else ""


# ---------- 변경 기록 ----------
def changes(base, head):
    if set(base) == {"0"}:  # 첫 push: 직전 기록이 없다
        base = git("rev-list", "--max-parents=0", head).split()[0]
    old, new = augments_at(base), augments_at(head)
    out = []

    added = [new[k] for k in new if k not in old]
    removed = [old[k] for k in old if k not in new]
    changed = []
    for k in new:
        if k in old and new[k] != old[k]:
            diffs = [f"{f}: {old[k][f]} → {new[k][f]}" for f in new[k] if new[k][f] != old[k][f]]
            changed.append((new[k]["이름"], diffs))
    aug_lines = [f"- 🆕 새 증강 {aug_line(a)}" for a in added]
    aug_lines += [f"- ❌ 사라진 증강 **{a['이름']}**" for a in removed]
    aug_lines += [f"- ✏️ **{n}** 바뀜: " + " / ".join(d) for n, d in changed]

    status = {}
    for line in git("diff", "--name-status", "-M", f"{base}..{head}").splitlines():
        parts = line.split("\t")
        code, path = parts[0][0], parts[-1]
        if tracked(path) and not path.startswith("resources/augments/"):
            status[path] = code
    by_area = {}
    for path, code in status.items():
        area = area_of(path)
        if area:
            by_area.setdefault(area, []).append((code, path))
    for area in sorted(set(by_area) | ({"증강"} if aug_lines else set()), key=lambda x: x != "증강"):
        items = by_area.get(area, [])
        out.append(f"### {area}")
        if area == "증강":
            out += aug_lines
        for code, path in sorted(items, key=lambda x: (x[0] != "A", x[1])):
            mark = {"A": "🆕 새 파일", "D": "❌ 지워짐", "M": "✏️ 고침", "R": "✏️ 옮김"}.get(code, "✏️")
            note = purpose_of(head, path) if code == "A" else ""
            out.append(f"- {mark} `{path}`" + (f" — {note}" if note else ""))

    log = git("log", "--no-merges", "--format=%an\t%s", f"{base}..{head}").splitlines()
    if log:
        out.append("### 올라온 커밋")
        out += [f"- {l.replace(chr(9), ' — ', 1)}" for l in log[:30]]
        if len(log) > 30:
            out.append(f"- … 외 {len(log) - 30}개")
    if not out:
        return None

    def short(r):
        return git("rev-parse", "--short", r).strip()

    head_line = f"**{datetime.now(KST):%m-%d %H:%M}** · `{short(base)}`..`{short(head)}`"
    return head_line + "\n\n" + "\n".join(out)


def features(ref="HEAD"):
    out = ["## 지금 있는 증강"]
    for a in augments_at(ref).values():
        out.append(f"- {aug_line(a)}")
    return "\n".join(out)


# ---------- 현황판 ----------
def annotate(issues, open_prs):
    """이슈마다 상태(todo/doing/blocked/done)와 우선순위를 붙인다. 2주 지난 완료는 뺀다."""
    pr_text = " ".join(f"{p['title']} {p.get('body') or ''} {p['headRefName']}" for p in open_prs)
    linked = {int(n) for n in re.findall(r'#(\d+)', pr_text)}
    cut = datetime.now(timezone.utc) - timedelta(days=14)
    out = []
    for i in issues:
        names = {l["name"] for l in i["labels"]}
        if "현황" in names:
            continue
        if i["state"] == "CLOSED":
            when = datetime.fromisoformat(i["closedAt"].replace("Z", "+00:00"))
            if when < cut:
                continue
            status = "done"
        elif "막힘" in names:
            status = "blocked"
        elif "진행중" in names or i["number"] in linked:
            status = "doing"
        else:
            status = "todo"
        prio = 1 if "우선-높음" in names else -1 if "우선-낮음" in names else 0
        out.append({**i, "status": status, "prio": prio, "labels": sorted(names),
                    "people": [a["login"] for a in i["assignees"]]})
    return out


def board_text():
    issues = gh_json("issue", "list", "--state", "all", "--limit", "300", "--json",
                     "number,title,state,labels,assignees,closedAt,url")
    prs = gh_json("pr", "list", "--state", "open", "--json", "number,title,body,headRefName")
    items = annotate(issues, prs)

    def who(i):
        return ", ".join("@" + p for p in i["people"]) or "담당 없음"

    def pick(status):
        return sorted((i for i in items if i["status"] == status), key=lambda i: (-i["prio"], who(i), i["number"]))

    def lines(rows):
        if not rows:
            return ["- (없음)"]
        return [f"- [ ] #{i['number']} {'**급함** ' if i['prio'] > 0 else ''}{i['title']} — {who(i)}" for i in rows]

    doing, todo, blocked = pick("doing"), pick("todo"), pick("blocked")
    done = sorted(pick("done"), key=lambda i: i["closedAt"], reverse=True)
    out = [f"갱신 {datetime.now(KST):%Y-%m-%d %H:%M} (한국 시간)", ""]
    out += [f"## 🔵 진행 중 ({len(doing)})"] + lines(doing) + [""]
    out += [f"## ⏳ 할 일 ({len(todo)})"] + lines(todo) + [""]
    out += [f"## 🟥 막힘 ({len(blocked)})"] + lines(blocked) + [""]
    out += [f"## ✅ 최근 2주 끝난 일 ({len(done)})"]
    out += [f"- [x] #{i['number']} {i['title']} — {who(i)}" for i in done] or ["- (없음)"]
    out += ["", "## 사람별", ""]
    people = {}
    for tag, rows in (("진행 중", doing), ("할 일", todo), ("막힘", blocked)):
        for i in rows:
            for w in who(i).split(", "):
                people.setdefault(w, {}).setdefault(tag, []).append(i["number"])
    for w, d in sorted(people.items()):
        out.append(f"- **{w}** — " + " · ".join(f"{t} " + ", ".join(f"#{n}" for n in ns) for t, ns in d.items()))
    if not people:
        out.append("- (열린 일이 없습니다)")
    out += ["", "_이슈에 `진행중` 라벨을 붙이거나, PR 본문에 `#번호`를 쓰면 진행 중으로 올라갑니다. 우선순위는 `우선-높음` 라벨._"]
    return "\n".join(out)


# ---------- 웹 화면 ----------
HERE = os.path.dirname(os.path.abspath(__file__))
_cache = {"t": 0.0, "data": None}
_lock = threading.Lock()


def load_data(force=False):
    with _lock:
        if not force and _cache["data"] and time.time() - _cache["t"] < 15:
            return _cache["data"]
        jobs = {
            "issues": lambda: gh_json("issue", "list", "--state", "all", "--limit", "300", "--json",
                                      "number,title,state,labels,assignees,closedAt,createdAt,updatedAt,url,body"),
            "prs": lambda: gh_json("pr", "list", "--state", "all", "--limit", "50", "--json",
                                   "number,title,state,author,mergedAt,createdAt,url,body,headRefName,isDraft"),
            "commits": lambda: json.loads(run("gh", "api", "repos/{owner}/{repo}/commits?per_page=60")),
            "me": lambda: run("gh", "api", "user", "--jq", ".login").strip(),
        }
        with ThreadPoolExecutor(4) as ex:
            res = {k: ex.submit(f).result() for k, f in jobs.items()}
        items = annotate(res["issues"], [p for p in res["prs"] if p["state"] == "OPEN"])
        for it in items:
            it["body"] = (it.get("body") or "")[:600]
        log = []
        for i in res["issues"]:
            if i["title"] == LOG_TITLE:
                log = gh_json("issue", "view", str(i["number"]), "--json", "comments")["comments"][-15:]
                log = [{"date": c["createdAt"], "body": c["body"]} for c in reversed(log)]
        prs = [{"number": p["number"], "title": p["title"], "state": p["state"], "url": p["url"],
                "author": (p.get("author") or {}).get("login", ""), "mergedAt": p["mergedAt"],
                "createdAt": p["createdAt"], "draft": p["isDraft"]} for p in res["prs"]]
        commits = [{"login": (c.get("author") or {}).get("login") or c["commit"]["author"]["name"],
                    "msg": c["commit"]["message"].splitlines()[0], "date": c["commit"]["author"]["date"],
                    "url": c["html_url"]} for c in res["commits"]]
        repo_url = res["issues"][0]["url"].rsplit("/issues", 1)[0] if res["issues"] else ""
        data = {"me": res["me"], "repo": repo_url, "issues": items, "prs": prs, "commits": commits, "log": log}
        _cache.update(t=time.time(), data=data)
        return data


def do_action(number, action, me):
    cur = gh_json("issue", "view", str(number), "--json", "labels,assignees,state")
    has = {l["name"] for l in cur["labels"]}
    add, rem, extra = [], [], []
    if action == "start":
        add, rem = ["진행중"], ["막힘"]
        if not cur["assignees"]:
            extra = ["--add-assignee", "@me"]
    elif action == "block":
        add, rem = ["막힘"], ["진행중"]
    elif action == "unblock":
        rem = ["막힘"]
    elif action == "take":
        extra = ["--add-assignee", "@me"]
    elif action == "drop":
        extra = ["--remove-assignee", "@me"]
    elif action == "prio_high":
        add, rem = ["우선-높음"], ["우선-낮음"]
    elif action == "prio_low":
        add, rem = ["우선-낮음"], ["우선-높음"]
    elif action == "prio_normal":
        rem = ["우선-높음", "우선-낮음"]
    elif action == "done":
        rem = ["진행중", "막힘"]
    elif action != "reopen":
        raise ValueError(f"모르는 동작: {action}")
    args = ["gh", "issue", "edit", str(number)] + extra
    for n in add:
        if n not in has:
            args += ["--add-label", n]
    for n in rem:
        if n in has:
            args += ["--remove-label", n]
    if len(args) > 4:
        run(*args)
    if action == "done":
        run("gh", "issue", "close", str(number))
    elif action == "reopen":
        run("gh", "issue", "reopen", str(number))


def new_issue(d):
    title = (d.get("title") or "").strip()
    if not title:
        raise ValueError("제목을 적어 주세요")
    body = f"### 이러면 끝입니다\n\n{(d.get('done') or '(적지 않음)').strip()}\n"
    args = ["gh", "issue", "create", "--title", title, "--body", body, "--label", "기능"]
    if d.get("assignee"):
        args += ["--assignee", d["assignee"]]
    if d.get("prio") == "high":
        args += ["--label", "우선-높음"]
    elif d.get("prio") == "low":
        args += ["--label", "우선-낮음"]
    return run(*args).strip()


class Handler(http.server.BaseHTTPRequestHandler):
    token = ""
    port = 0

    def log_message(self, *a):
        pass

    def _ok_host(self):
        return self.headers.get("Host", "") in (f"127.0.0.1:{self.port}", f"localhost:{self.port}")

    def _send(self, code, body, ctype="application/json; charset=utf-8"):
        raw = body if isinstance(body, bytes) else body.encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(raw)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(raw)

    def _json(self, code, obj):
        self._send(code, json.dumps(obj, ensure_ascii=False))

    def do_GET(self):
        if not self._ok_host():
            return self._json(403, {"error": "허용되지 않은 주소"})
        path = urllib.parse.urlparse(self.path)
        if path.path == "/":
            html = open(os.path.join(HERE, "web.html"), encoding="utf-8").read().replace("__TOKEN__", self.token)
            return self._send(200, html, "text/html; charset=utf-8")
        if path.path == "/api/data":
            try:
                force = "force=1" in path.query
                return self._json(200, load_data(force))
            except (SystemExit, Exception) as e:
                return self._json(500, {"error": str(getattr(e, "code", None) or e)})
        self._json(404, {"error": "없는 주소"})

    def do_POST(self):
        if not self._ok_host() or self.headers.get("X-Token") != self.token:
            return self._json(403, {"error": "허용되지 않은 요청"})
        try:
            d = json.loads(self.rfile.read(int(self.headers.get("Content-Length", 0))) or b"{}")
            if self.path == "/api/action":
                do_action(int(d["number"]), d["action"], d.get("me"))
            elif self.path == "/api/new":
                d["url"] = new_issue(d)
            else:
                return self._json(404, {"error": "없는 주소"})
            load_data(True)
            self._json(200, {"ok": True, "url": d.get("url")})
        except (SystemExit, Exception) as e:
            self._json(500, {"error": str(getattr(e, "code", None) or e)})


def serve(open_browser=True):
    os.chdir(git("rev-parse", "--show-toplevel").strip())
    run("gh", "auth", "status")
    threading.Thread(target=lambda: _quiet(setup_labels), daemon=True).start()
    Handler.token = secrets.token_urlsafe(16)
    for port in range(8765, 8776):
        try:
            srv = http.server.ThreadingHTTPServer(("127.0.0.1", port), Handler)
            break
        except OSError:
            continue
    else:
        sys.exit("8765~8775 포트가 모두 사용 중입니다")
    Handler.port = port
    url = f"http://127.0.0.1:{port}/"
    print(f"작업판: {url}   (끄려면 Ctrl+C)")
    if open_browser:
        webbrowser.open(url)
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        print("끝")


def _quiet(fn):
    try:
        fn()
    except BaseException:
        pass


# ---------- 올리기 ----------
def setup_labels():
    for name, (color, desc) in LABELS.items():
        run("gh", "label", "create", name, "--color", color, "--description", desc, "--force")


def pinned_issue(title):
    for i in gh_json("issue", "list", "--label", "현황", "--state", "open", "--json", "number,title"):
        if i["title"] == title:
            return i["number"]
    url = run("gh", "issue", "create", "--title", title, "--label", "현황", "--body", "(곧 채워집니다)").strip()
    return int(url.rsplit("/", 1)[1])


def publish_board(text):
    n = pinned_issue(BOARD_TITLE)
    run("gh", "issue", "edit", str(n), "--body", text)
    print(f"현황판 #{n} 갱신")


def publish_changes(text):
    n = pinned_issue(LOG_TITLE)
    run("gh", "issue", "comment", str(n), "--body", text[:60000])
    print(f"변경 기록 #{n} 에 댓글")


def main():
    a = sys.argv[1:]
    if not a:
        sys.exit(__doc__)
    pub = "--publish" in a
    a = [x for x in a if x != "--publish"]
    cmd = a[0]
    if cmd == "board":
        t = board_text()
        publish_board(t) if pub else print(t)
    elif cmd == "changes":
        t = changes(a[1], a[2] if len(a) > 2 else "HEAD")
        if t is None:
            print("바뀐 기능이 없습니다.")
        else:
            publish_changes(t) if pub else print(t)
    elif cmd == "web":
        serve("--no-open" not in a)
    elif cmd == "features":
        print(features())
    elif cmd == "setup":
        setup_labels()
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    main()

#!/usr/bin/env python3
"""팀 현황판과 변경 기록. 표준 라이브러리만 쓴다.

  python .github/team/team.py board              현황판을 화면에 찍는다
  python .github/team/team.py board --publish    고정 이슈(라벨 현황)에 올린다
  python .github/team/team.py changes A B        A..B 에서 바뀐 기능을 찍는다
  python .github/team/team.py changes A B --publish   변경 기록 이슈에 댓글로 남긴다
  python .github/team/team.py features           지금 있는 기능 목록
  python .github/team/team.py setup              라벨을 만든다(여러 번 돌려도 된다)

사람이 따로 적지 않아도 되도록, 변경 기록은 커밋 메시지가 아니라 파일 내용을 읽어서 만든다.
"""
import json, re, subprocess, sys
from datetime import datetime, timedelta, timezone

KST = timezone(timedelta(hours=9))
RARITY = ["일반", "희귀", "영웅", "전설"]
KIND = ["패시브", "발사", "필드", "액티브", "조건부"]
LABELS = {  # 이름: (색, 뜻)
    "진행중": ("1d76db", "지금 하고 있다"),
    "막힘": ("d93f0b", "다른 사람이나 결정이 필요하다"),
    "기능": ("0e8a16", "새로 만들 것"),
    "버그": ("b60205", "잘못 동작하는 것"),
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
def board_text():
    issues = gh_json("issue", "list", "--state", "all", "--limit", "300", "--json",
                     "number,title,state,labels,assignees,closedAt,url")
    prs = gh_json("pr", "list", "--state", "open", "--json", "number,title,body,headRefName")
    pr_text = " ".join(f"{p['title']} {p.get('body') or ''} {p['headRefName']}" for p in prs)
    linked = {int(n) for n in re.findall(r'#(\d+)', pr_text)}

    def labels(i):
        return {l["name"] for l in i["labels"]}

    def who(i):
        return ", ".join("@" + a["login"] for a in i["assignees"]) or "담당 없음"

    cut = datetime.now(timezone.utc) - timedelta(days=14)
    doing, todo, blocked, done = [], [], [], []
    for i in issues:
        if "현황" in labels(i):
            continue
        if i["state"] == "CLOSED":
            when = datetime.fromisoformat(i["closedAt"].replace("Z", "+00:00"))
            if when >= cut:
                done.append((when, i))
        elif "막힘" in labels(i):
            blocked.append(i)
        elif "진행중" in labels(i) or i["number"] in linked:
            doing.append(i)
        else:
            todo.append(i)

    def lines(items):
        if not items:
            return ["- (없음)"]
        rows = sorted(items, key=lambda i: (who(i), i["number"]))
        return [f"- [ ] #{i['number']} {i['title']} — {who(i)}" for i in rows]

    out = [f"갱신 {datetime.now(KST):%Y-%m-%d %H:%M} (한국 시간)", ""]
    out += [f"## 🔵 진행 중 ({len(doing)})"] + lines(doing) + [""]
    out += [f"## ⏳ 할 일 ({len(todo)})"] + lines(todo) + [""]
    out += [f"## 🟥 막힘 ({len(blocked)})"] + lines(blocked) + [""]
    out += [f"## ✅ 최근 2주 끝난 일 ({len(done)})"]
    out += [f"- [x] #{i['number']} {i['title']} — {who(i)}"
            for _, i in sorted(done, key=lambda x: x[0], reverse=True)] or ["- (없음)"]
    out += ["", "## 사람별", ""]
    people = {}
    for tag, items in (("진행 중", doing), ("할 일", todo), ("막힘", blocked)):
        for i in items:
            for w in who(i).split(", "):
                people.setdefault(w, {}).setdefault(tag, []).append(i["number"])
    for w, d in sorted(people.items()):
        out.append(f"- **{w}** — " + " · ".join(f"{t} " + ", ".join(f"#{n}" for n in ns) for t, ns in d.items()))
    if not people:
        out.append("- (열린 일이 없습니다)")
    out += ["", "_이슈에 `진행중` 라벨을 붙이거나, PR 본문에 `#번호`를 쓰면 진행 중으로 올라갑니다._"]
    return "\n".join(out)


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
    elif cmd == "features":
        print(features())
    elif cmd == "setup":
        setup_labels()
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    main()

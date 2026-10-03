import argparse, datetime, gzip, html, ipaddress, json, os, re, sys, urllib.error, urllib.parse, urllib.request
from concurrent.futures import ThreadPoolExecutor

UA = "CioWeb3Apk/3.5 (public-profile-lookup)"
ALLOW_LOCAL = os.environ.get("CIO_ALLOW_LOCAL") == "1"
MAX_BYTES = 2_000_000


def base(name, default):
    return os.environ.get("CIO_" + name, default).rstrip("/")


class NotFound(Exception): pass
class Limited(Exception): pass
class NeedKey(Exception): pass
class Failed(Exception): pass


# ---------------------------------------------------------------- helpers
CTRL = re.compile(r"[\x00-\x1f\x7f-\x9f\u200b-\u200f\u202a-\u202e\u2066-\u2069]")
TAG = re.compile(r"<[^>]*>")


def clean(v, n=140):
    """Text from a remote service -> safe single line (no terminal escapes)."""
    if v is None:
        return "-"
    s = re.sub(r"</p>\s*<p>|<br\s*/?>", " ", str(v), flags=re.I)
    s = html.unescape(TAG.sub("", s))
    s = re.sub(r"\s+", " ", CTRL.sub(" ", s)).strip()
    if not s:
        return "-"
    return s if len(s) <= n else s[: n - 1] + "…"


def num(v):
    try:
        return f"{int(v):,}"
    except (TypeError, ValueError):
        return "-"


def date(v):
    try:
        if isinstance(v, (int, float)):
            if v > 1e11:
                v /= 1000.0
            return datetime.datetime.fromtimestamp(v, datetime.timezone.utc).strftime("%Y-%m-%d")
        s = str(v)
        if re.match(r"\d{4}-\d{2}-\d{2}", s):
            return s[:10]
        return clean(s, 30)
    except (OverflowError, OSError, ValueError):
        return "-"


def safe_host(host):
    """Refuse localhost / private IP literals (unless CIO_ALLOW_LOCAL=1 for tests)."""
    h = host.split(":")[0].lower()
    if not re.fullmatch(r"[a-z0-9]([a-z0-9.-]{0,251}[a-z0-9])?", h):
        return False
    if ALLOW_LOCAL:
        return True
    if h == "localhost" or h.endswith((".local", ".internal", ".lan")):
        return False
    try:
        ip = ipaddress.ip_address(h)
        return not (ip.is_private or ip.is_loopback or ip.is_link_local or ip.is_reserved)
    except ValueError:
        return True


def call(url, headers=None, notfound=(404, 410), limited=(403, 429)):
    h = {"User-Agent": UA, "Accept": "application/json", "Accept-Encoding": "gzip"}
    h.update(headers or {})
    try:
        with urllib.request.urlopen(urllib.request.Request(url, headers=h), timeout=15) as r:
            raw = r.read(MAX_BYTES + 1)
            if len(raw) > MAX_BYTES:
                raise Failed("response too large")
            if r.headers.get("Content-Encoding", "").lower() == "gzip":
                raw = gzip.decompress(raw)
            return json.loads(raw.decode("utf-8", "replace"))
    except urllib.error.HTTPError as e:
        if e.code in notfound:
            raise NotFound()
        if e.code in limited:
            raise Limited()
        raise Failed(f"HTTP {e.code}")
    except (urllib.error.URLError, TimeoutError, OSError):
        raise Failed("network error")
    except (ValueError, json.JSONDecodeError):
        raise Failed("unexpected response")


def q(s):
    return urllib.parse.quote(s, safe="")


# ---------------------------------------------------------------- platforms
def github(u):
    hdr = {"Accept": "application/vnd.github+json"}
    if os.environ.get("GITHUB_TOKEN"):
        hdr["Authorization"] = "Bearer " + os.environ["GITHUB_TOKEN"]
    d = call(f"{base('GITHUB_API', 'https://api.github.com')}/users/{q(u)}", hdr)
    return [("Name", clean(d.get("name"), 60)), ("Type", clean(d.get("type"), 20)), ("Bio", clean(d.get("bio"))),
            ("Followers", num(d.get("followers"))), ("Following", num(d.get("following"))),
            ("Repos", num(d.get("public_repos"))), ("Joined", date(d.get("created_at"))),
            ("URL", clean(d.get("html_url"), 200))]


def gitlab(u):
    d = call(f"{base('GITLAB', 'https://gitlab.com')}/api/v4/users?username={q(u)}")
    hit = next((x for x in d if str(x.get("username", "")).lower() == u.lower()), None) if isinstance(d, list) else None
    if not hit:
        raise NotFound()
    return [("Name", clean(hit.get("name"), 60)), ("State", clean(hit.get("state"), 20)),
            ("URL", clean(hit.get("web_url"), 200))]


def bluesky(u):
    handle = u if "." in u else u + ".bsky.social"
    d = call(f"{base('BSKY', 'https://public.api.bsky.app')}/xrpc/app.bsky.actor.getProfile?actor={q(handle)}",
             notfound=(400, 404))
    return [("Name", clean(d.get("displayName"), 60)), ("Bio", clean(d.get("description"))),
            ("Followers", num(d.get("followersCount"))), ("Following", num(d.get("followsCount"))),
            ("Posts", num(d.get("postsCount"))), ("Joined", date(d.get("createdAt"))),
            ("URL", "https://bsky.app/profile/" + clean(d.get("handle", handle), 100))]


def mastodon(u):
    user, _, inst = u.lstrip("@").partition("@")
    inst = inst or os.environ.get("CIO_MASTODON_DEFAULT", "mastodon.social")
    if not safe_host(inst):
        raise Failed("instance not allowed")
    scheme = os.environ.get("CIO_MASTODON_SCHEME", "https")
    d = call(f"{scheme}://{inst}/api/v1/accounts/lookup?acct={q(user)}")
    return [("Name", clean(d.get("display_name"), 60)), ("Bio", clean(d.get("note"))),
            ("Followers", num(d.get("followers_count"))), ("Following", num(d.get("following_count"))),
            ("Posts", num(d.get("statuses_count"))), ("Joined", date(d.get("created_at"))),
            ("URL", clean(d.get("url"), 200))]


def reddit(u):
    d = call(f"{base('REDDIT', 'https://www.reddit.com')}/user/{q(u)}/about.json")
    d = d.get("data", {}) if isinstance(d, dict) else {}
    if not d.get("name"):
        raise NotFound()
    rows = [("Name", clean(d.get("name"), 60))]
    if d.get("is_suspended"):
        rows.append(("Status", "suspended"))
    rows += [("Karma", num(d.get("total_karma", (d.get("link_karma") or 0) + (d.get("comment_karma") or 0)))),
             ("Joined", date(d.get("created_utc"))),
             ("Bio", clean((d.get("subreddit") or {}).get("public_description"))),
             ("URL", "https://www.reddit.com/user/" + clean(d.get("name"), 60))]
    return rows


def hackernews(u):
    d = call(f"{base('HN', 'https://hacker-news.firebaseio.com')}/v0/user/{q(u)}.json")
    if not d:
        raise NotFound()
    return [("Karma", num(d.get("karma"))), ("Joined", date(d.get("created"))), ("About", clean(d.get("about"))),
            ("Submissions", num(len(d.get("submitted", [])))),
            ("URL", "https://news.ycombinator.com/user?id=" + q(clean(d.get("id"), 40)))]


def stackoverflow(u):
    d = call(f"{base('SE', 'https://api.stackexchange.com')}/2.3/users?inname={q(u)}&site=stackoverflow&pagesize=30")
    hit = next((x for x in d.get("items", []) if str(x.get("display_name", "")).lower() == u.lower()), None)
    if not hit:
        raise NotFound()
    b = hit.get("badge_counts") or {}
    return [("Name", clean(hit.get("display_name"), 60)), ("Reputation", num(hit.get("reputation"))),
            ("Badges", f"{b.get('gold', 0)} gold / {b.get('silver', 0)} silver / {b.get('bronze', 0)} bronze"),
            ("Joined", date(hit.get("creation_date"))), ("URL", clean(hit.get("link"), 200))]


def lichess(u):
    d = call(f"{base('LICHESS', 'https://lichess.org')}/api/user/{q(u)}")
    if d.get("disabled") or d.get("closed"):
        raise NotFound()
    return [("Name", clean(d.get("username"), 40)), ("Bio", clean((d.get("profile") or {}).get("bio"))),
            ("Games", num((d.get("count") or {}).get("all"))), ("Followers", num(d.get("nbFollowers"))),
            ("Joined", date(d.get("createdAt"))), ("URL", clean(d.get("url") or "https://lichess.org/@/" + u, 200))]


def chesscom(u):
    d = call(f"{base('CHESS', 'https://api.chess.com')}/pub/player/{q(u.lower())}")
    return [("Name", clean(d.get("name") or d.get("username"), 60)), ("Status", clean(d.get("status"), 20)),
            ("Followers", num(d.get("followers"))), ("Joined", date(d.get("joined"))),
            ("URL", clean(d.get("url"), 200))]


def devto(u):
    d = call(f"{base('DEVTO', 'https://dev.to')}/api/users/by_username?url={q(u)}")
    return [("Name", clean(d.get("name"), 60)), ("Bio", clean(d.get("summary"))), ("Joined", date(d.get("joined_at"))),
            ("URL", "https://dev.to/" + clean(d.get("username"), 60))]


def youtube(u):
    key = os.environ.get("YT_API_KEY")
    if not key:
        raise NeedKey()
    handle = u if u.startswith("@") else "@" + u
    d = call(f"{base('YT', 'https://www.googleapis.com')}/youtube/v3/channels?part=snippet,statistics&forHandle={q(handle)}&key={q(key)}",
             limited=(403, 429), notfound=(404,))
    items = d.get("items") or []
    if not items:
        raise NotFound()
    it = items[0]; sn = it.get("snippet", {}); st = it.get("statistics", {})
    subs = "hidden" if st.get("hiddenSubscriberCount") else num(st.get("subscriberCount"))
    return [("Name", clean(sn.get("title"), 60)), ("Bio", clean(sn.get("description"))), ("Subscribers", subs),
            ("Videos", num(st.get("videoCount"))), ("Views", num(st.get("viewCount"))),
            ("Joined", date(sn.get("publishedAt"))),
            ("URL", "https://www.youtube.com/" + clean(sn.get("customUrl") or handle, 80))]


PLATFORMS = [("github", "GitHub", github), ("gitlab", "GitLab", gitlab), ("bluesky", "Bluesky", bluesky),
             ("mastodon", "Mastodon", mastodon), ("reddit", "Reddit", reddit), ("hackernews", "Hacker News", hackernews),
             ("stackoverflow", "Stack Overflow", stackoverflow), ("lichess", "Lichess", lichess),
             ("chesscom", "Chess.com", chesscom), ("devto", "DEV", devto), ("youtube", "YouTube (API key)", youtube)]
UNSUPPORTED = "Instagram, TikTok, X/Twitter, Facebook, Threads, Telegram, Snapchat"


def run_one(entry, user):
    key, label, fn = entry
    try:
        return key, label, "found", fn(user)
    except NotFound:
        return key, label, "notfound", None
    except Limited:
        return key, label, "limited", None
    except NeedKey:
        return key, label, "needkey", None
    except Failed as e:
        return key, label, "error", str(e)
    except Exception as e:  # never crash the whole report
        return key, label, "error", type(e).__name__


def main():
    ap = argparse.ArgumentParser(add_help=False)
    ap.add_argument("user", nargs="?")
    ap.add_argument("--only", default="")
    ap.add_argument("--list", action="store_true")
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--plain", action="store_true")
    ap.add_argument("--color", type=int, default=45)
    ap.add_argument("--save", default="")
    a = ap.parse_args()

    if a.list:
        for k, label, _ in PLATFORMS:
            print(f"{k:14s} {label}")
        print("\nNot supported (no public official API for arbitrary profiles): " + UNSUPPORTED)
        return 0
    if not a.user:
        print("usage: social.py USERNAME [--only a,b] [--json] [--plain] [--save FILE]", file=sys.stderr)
        return 2
    user = a.user.lstrip("@")
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]{0,63}(@[A-Za-z0-9.:-]{1,100})?", user):
        print("invalid username (letters, digits, . _ - ; optional @instance)", file=sys.stderr)
        return 2
    only = [x.strip().lower() for x in a.only.split(",") if x.strip()]
    chosen = [p for p in PLATFORMS if not only or p[0] in only]
    unknown = [x for x in only if x not in [p[0] for p in PLATFORMS]]
    if unknown:
        print("unknown platform(s): " + ", ".join(unknown) + "  (see --list)", file=sys.stderr)
        return 2

    with ThreadPoolExecutor(max_workers=6) as ex:
        results = list(ex.map(lambda p: run_one(p, user), chosen))

    if a.json:
        out = {k: {"status": s, "data": dict(d) if s == "found" else (d if s == "error" else None)} for k, _, s, d in results}
        print(json.dumps({"user": user, "results": out}, ensure_ascii=False, indent=2))
        return 0 if any(r[2] == "found" for r in results) else 1

    col = (not a.plain) and not a.save
    def c(code, t): return f"\x1b[{code}m{t}\x1b[0m" if col else t
    acc = lambda t: (f"\x1b[38;5;{a.color}m{t}\x1b[0m" if col else t)
    lines = []
    lines.append(acc("Social lookup") + c("2", f" · @{user} · public/official APIs only"))
    lines.append(c("2", "─" * 46))
    found = 0
    for key, label, st, data in results:
        if st == "found":
            found += 1
            lines.append(c("32", " ✔ ") + c("1", label))
            for k, v in data:
                lines.append(f"     {c('2', k.ljust(12))} {v}")
        elif st == "notfound":
            lines.append(c("2", f" ✘ {label.ljust(22)} not found"))
        elif st == "limited":
            lines.append(c("33", f" ! {label.ljust(22)} blocked / rate-limited (try later)"))
        elif st == "needkey":
            lines.append(c("2", f" – {label.ljust(22)} needs a free API key: cioweb3apk keys set youtube KEY"))
        else:
            lines.append(c("33", f" ! {label.ljust(22)} error: {data}"))
    lines.append(c("2", "─" * 46))
    lines.append(f" Found on {found} of {len(results)} platforms")
    if not only:
        lines.append(c("2", f" Not covered (no public official API for arbitrary profiles, never scraped): {UNSUPPORTED}"))
    text = "\n".join(lines)
    print(text)
    if a.save:
        try:
            with open(a.save, "w", encoding="utf-8") as f:
                f.write(text + "\n")
            print(f"saved: {a.save}")
        except OSError as e:
            print(f"cannot save: {e}", file=sys.stderr)
    return 0 if found else 1


if __name__ == "__main__":
    try:
        sys.exit(main())
    except BrokenPipeError:
        sys.exit(0)

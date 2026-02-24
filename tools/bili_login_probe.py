#!/usr/bin/env python3
"""Quick tester for Bilibili web login APIs.

Examples:
  python3 tools/bili_login_probe.py qr-generate
  python3 tools/bili_login_probe.py qr-poll --qrcode-key <key>
  python3 tools/bili_login_probe.py password --username u --password p --token t --challenge c --validate v --seccode s
  python3 tools/bili_login_probe.py sms --cid 86 --tel 13800000000 --code 123456 --captcha-key xxx
"""

from __future__ import annotations

import argparse
import json
import ssl
import urllib.parse
import urllib.error
import urllib.request
from http.cookies import SimpleCookie

HEADERS = {
    "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)",
    "Referer": "https://www.bilibili.com",
}


def request(url: str, method: str = "GET", body: dict[str, str] | None = None) -> tuple[dict, dict[str, str]]:
    data = None
    headers = dict(HEADERS)
    if body is not None:
        data = urllib.parse.urlencode(body).encode("utf-8")
        headers["Content-Type"] = "application/x-www-form-urlencoded"

    req = urllib.request.Request(url=url, data=data, headers=headers, method=method)
    try:
        return _do_request(req, ssl.create_default_context())
    except urllib.error.URLError as err:
        reason = getattr(err, "reason", None)
        if isinstance(reason, ssl.SSLCertVerificationError):
            print("warning: cert verify failed, fallback to insecure SSL context")
            return _do_request(req, ssl._create_unverified_context())
        raise


def _do_request(req: urllib.request.Request, ctx: ssl.SSLContext) -> tuple[dict, dict[str, str]]:
    with urllib.request.urlopen(req, context=ctx, timeout=20) as resp:
        raw = resp.read().decode("utf-8", errors="replace")
        payload = json.loads(raw)
        cookies = extract_cookies(resp.headers)
        return payload, cookies


def extract_cookies(headers) -> dict[str, str]:
    result: dict[str, str] = {}
    for line in headers.get_all("Set-Cookie", []):
        c = SimpleCookie()
        c.load(line)
        for k, morsel in c.items():
            result[k] = morsel.value
    return result


def print_result(payload: dict, cookies: dict[str, str]) -> None:
    print(json.dumps(payload, ensure_ascii=False, indent=2))
    if cookies:
        wanted = {k: cookies.get(k, "") for k in ["SESSDATA", "bili_jct", "DedeUserID", "buvid3", "buvid4"] if k in cookies}
        print("cookies:")
        print(json.dumps(wanted, ensure_ascii=False, indent=2))


def main() -> None:
    parser = argparse.ArgumentParser(description="Bilibili login endpoint probe")
    sub = parser.add_subparsers(dest="cmd", required=True)

    sub.add_parser("qr-generate")

    qr_poll = sub.add_parser("qr-poll")
    qr_poll.add_argument("--qrcode-key", required=True)

    pwd = sub.add_parser("password")
    pwd.add_argument("--username", required=True)
    pwd.add_argument("--password", required=True)
    pwd.add_argument("--token", required=True)
    pwd.add_argument("--challenge", required=True)
    pwd.add_argument("--validate", required=True)
    pwd.add_argument("--seccode", required=True)

    sms = sub.add_parser("sms")
    sms.add_argument("--cid", default="86")
    sms.add_argument("--tel", required=True)
    sms.add_argument("--code", required=True)
    sms.add_argument("--captcha-key", required=True)

    args = parser.parse_args()

    if args.cmd == "qr-generate":
        payload, cookies = request("https://passport.bilibili.com/x/passport-login/web/qrcode/generate")
    elif args.cmd == "qr-poll":
        q = urllib.parse.urlencode({"qrcode_key": args.qrcode_key})
        payload, cookies = request(f"https://passport.bilibili.com/x/passport-login/web/qrcode/poll?{q}")
    elif args.cmd == "password":
        payload, cookies = request(
            "https://passport.bilibili.com/x/passport-login/web/login",
            method="POST",
            body={
                "username": args.username,
                "password": args.password,
                "keep": "true",
                "token": args.token,
                "challenge": args.challenge,
                "validate": args.validate,
                "seccode": args.seccode,
            },
        )
    else:
        payload, cookies = request(
            "https://passport.bilibili.com/x/passport-login/web/login/sms",
            method="POST",
            body={
                "cid": args.cid,
                "tel": args.tel,
                "code": args.code,
                "source": "main_web",
                "captcha_key": args.captcha_key,
            },
        )

    print_result(payload, cookies)


if __name__ == "__main__":
    main()

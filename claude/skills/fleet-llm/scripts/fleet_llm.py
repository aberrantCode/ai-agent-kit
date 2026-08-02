#!/usr/bin/env python3
"""fleet_llm — a stdlib-only CLI for the operator's self-hosted Open WebUI / ollama fleet.

Talks to an Open WebUI instance (which fronts ollama) over the LAN: list models,
chat, embeddings, pull/remove models, and a raw passthrough for arbitrary endpoints.

Config resolution order (first hit wins per key):
  1. ~/.claude/fleet-llm.env         (KEY=VALUE lines; written by `setup`)
  2. environment variables           (FLEET_LLM_BASE_URL, FLEET_LLM_API_KEY, ...)
  3. error, pointing the user at `setup`

Keys: FLEET_LLM_BASE_URL, FLEET_LLM_API_KEY, FLEET_LLM_DEFAULT_MODEL (default qwen3.5:9b).

Design notes:
  - Open WebUI on :3000 is the ONLY reachable surface. ollama's native :11434 is
    compose-net-only and unreachable from the LAN. Always go through :3000.
  - OpenAI-compatible endpoints live under /openai/v1; the native ollama proxy
    (pull/delete/tags) lives under /ollama/api.
  - qwen3.5:latest is a "thinking" variant that returns EMPTY content — the default
    model is the explicit tag qwen3.5:9b. `chat` warns when content comes back empty.

No third-party deps: stdlib urllib/json only, so this runs on a bare Python 3
anywhere (Windows, git-bash, Linux).
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import urllib.error
import urllib.request
from pathlib import Path

CONFIG_PATH = Path.home() / ".claude" / "fleet-llm.env"
DEFAULT_MODEL = "qwen3.5:9b"
DEFAULT_EMBED_MODEL = "nomic-embed-text"
HTTP_TIMEOUT = 120  # seconds; generous for chat completions on a GPU box

CONFIG_KEYS = ("FLEET_LLM_BASE_URL", "FLEET_LLM_API_KEY", "FLEET_LLM_DEFAULT_MODEL")

# The AC_OPBTA SOPS seed (operator convenience only — see `setup --from-ac-devops-sops`).
SOPS_SSH_HOST = "ubuntu@192.168.30.15"
SOPS_REMOTE_CMD = (
    "sops -d ~/repos/AC_OPBTA/secrets/repo-radar.enc.yml | "
    "python3 -c 'import sys,yaml;print(yaml.safe_load(sys.stdin)[\"openai_api_key\"])'"
)


# --------------------------------------------------------------------------- #
# Errors / output helpers
# --------------------------------------------------------------------------- #

class FleetError(Exception):
    """User-facing error; message is printed to stderr and the process exits 1."""


def eprint(*args: object) -> None:
    print(*args, file=sys.stderr)


def _redact(value: str) -> str:
    """Never echo a full token. Show only enough to confirm which key is set."""
    if not value:
        return "(empty)"
    if len(value) <= 8:
        return "*" * len(value)
    return f"{value[:4]}...{value[-2:]} ({len(value)} chars)"


# --------------------------------------------------------------------------- #
# Config
# --------------------------------------------------------------------------- #

def parse_env_file(path: Path) -> dict[str, str]:
    """Parse a KEY=VALUE file. Ignores blanks and #-comments; strips simple quotes."""
    values: dict[str, str] = {}
    if not path.is_file():
        return values
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if "=" not in line:
            continue
        key, _, val = line.partition("=")
        key = key.strip()
        val = val.strip().strip('"').strip("'")
        if key:
            values[key] = val
    return values


def load_config() -> dict[str, str]:
    """Resolve config: file values first, then env-var fallback per missing key."""
    cfg = parse_env_file(CONFIG_PATH)
    for key in CONFIG_KEYS:
        if not cfg.get(key):
            env_val = os.environ.get(key)
            if env_val:
                cfg[key] = env_val
    return cfg


def require_config() -> tuple[str, str, str]:
    """Return (base_url, api_key, default_model) or raise a helpful FleetError."""
    cfg = load_config()
    base_url = (cfg.get("FLEET_LLM_BASE_URL") or "").rstrip("/")
    api_key = cfg.get("FLEET_LLM_API_KEY") or ""
    default_model = cfg.get("FLEET_LLM_DEFAULT_MODEL") or DEFAULT_MODEL
    missing = [k for k, v in (("FLEET_LLM_BASE_URL", base_url), ("FLEET_LLM_API_KEY", api_key)) if not v]
    if missing:
        raise FleetError(
            f"Missing config: {', '.join(missing)}.\n"
            f"Run `fleet_llm.py setup --base-url <url> --api-key <key>` "
            f"(writes {CONFIG_PATH}), or set the env vars."
        )
    return base_url, api_key, default_model


# --------------------------------------------------------------------------- #
# HTTP
# --------------------------------------------------------------------------- #

def _request(
    method: str,
    base_url: str,
    api_key: str,
    path: str,
    body: dict | None = None,
    stream: bool = False,
    timeout: int = HTTP_TIMEOUT,
):
    """Issue an HTTP request against the fleet. Returns the open response when
    `stream=True` (caller iterates lines), else the parsed JSON dict.

    Raises FleetError on non-2xx (with status + body head) and on network errors.
    """
    url = f"{base_url}{path}"
    data = json.dumps(body).encode("utf-8") if body is not None else None
    headers = {"Authorization": f"Bearer {api_key}", "Accept": "application/json"}
    if data is not None:
        headers["Content-Type"] = "application/json"
    req = urllib.request.Request(url, data=data, headers=headers, method=method.upper())
    try:
        resp = urllib.request.urlopen(req, timeout=timeout)  # noqa: S310 (LAN, operator-owned)
    except urllib.error.HTTPError as exc:
        detail = ""
        try:
            detail = exc.read().decode("utf-8", "replace")[:500]
        except Exception:  # noqa: BLE001
            pass
        raise FleetError(f"HTTP {exc.code} {exc.reason} for {method.upper()} {path}\n{detail}") from exc
    except urllib.error.URLError as exc:
        raise FleetError(
            f"Cannot reach fleet at {base_url} ({exc.reason}).\n"
            f"The host is LAN-only (VLAN30). Confirm you're on-network and the base URL is correct."
        ) from exc
    if stream:
        return resp
    raw = resp.read().decode("utf-8", "replace")
    if not raw:
        return {}
    try:
        return json.loads(raw)
    except json.JSONDecodeError as exc:
        raise FleetError(f"Non-JSON response from {path}: {raw[:500]}") from exc


# --------------------------------------------------------------------------- #
# Subcommands
# --------------------------------------------------------------------------- #

def cmd_setup(args: argparse.Namespace) -> int:
    existing = parse_env_file(CONFIG_PATH)
    base_url = args.base_url or existing.get("FLEET_LLM_BASE_URL") or ""
    api_key = args.api_key or existing.get("FLEET_LLM_API_KEY") or ""
    default_model = args.default_model or existing.get("FLEET_LLM_DEFAULT_MODEL") or DEFAULT_MODEL

    if args.from_ac_devops_sops:
        eprint("Fetching fleet token from AC_OPBTA SOPS via ssh…")
        api_key = fetch_token_from_sops()

    # Interactive fill only for a genuine TTY and only for still-missing values.
    if sys.stdin.isatty():
        if not base_url:
            base_url = input("Base URL [http://192.168.30.53:3000]: ").strip() or "http://192.168.30.53:3000"
        if not api_key:
            api_key = input("API key (service-account bearer token): ").strip()

    if not base_url or not api_key:
        raise FleetError(
            "setup needs both a base URL and an API key. Provide --base-url/--api-key, "
            "use --from-ac-devops-sops, or run interactively."
        )

    lines = [
        "# fleet-llm config — written by `fleet_llm.py setup`. Single-user; do not commit.",
        f"FLEET_LLM_BASE_URL={base_url.rstrip('/')}",
        f"FLEET_LLM_API_KEY={api_key}",
        f"FLEET_LLM_DEFAULT_MODEL={default_model}",
        "",
    ]
    CONFIG_PATH.parent.mkdir(parents=True, exist_ok=True)
    CONFIG_PATH.write_text("\n".join(lines), encoding="utf-8")
    try:
        os.chmod(CONFIG_PATH, 0o600)
    except OSError:
        pass  # best-effort on Windows filesystems

    print(f"Wrote {CONFIG_PATH}")
    print(f"  base_url      = {base_url.rstrip('/')}")
    print(f"  api_key       = {_redact(api_key)}")
    print(f"  default_model = {default_model}")
    return 0


def fetch_token_from_sops() -> str:
    """Operator-only convenience: decrypt the fleet token from AC_OPBTA SOPS on ac-devops."""
    try:
        out = subprocess.run(
            ["ssh", SOPS_SSH_HOST, SOPS_REMOTE_CMD],
            capture_output=True, text=True, timeout=60,
        )
    except FileNotFoundError as exc:
        raise FleetError("ssh not found on PATH; cannot use --from-ac-devops-sops.") from exc
    except subprocess.TimeoutExpired as exc:
        raise FleetError("ssh to ac-devops timed out; are you on the LAN?") from exc
    if out.returncode != 0:
        raise FleetError(f"SOPS fetch failed (exit {out.returncode}): {out.stderr.strip()[:300]}")
    token = out.stdout.strip()
    if not token:
        raise FleetError("SOPS fetch returned an empty token.")
    return token


def cmd_models(args: argparse.Namespace) -> int:
    base_url, api_key, _ = require_config()
    data = _request("GET", base_url, api_key, "/openai/v1/models")
    if args.json:
        print(json.dumps(data, indent=2))
        return 0
    models = data.get("data", []) if isinstance(data, dict) else []
    if not models:
        eprint("No models returned.")
        return 0
    for m in sorted(models, key=lambda x: str(x.get("id", ""))):
        print(m.get("id", ""))
    return 0


def _read_prompt(prompt_arg: str) -> str:
    if prompt_arg == "-" or prompt_arg is None:
        return sys.stdin.read()
    return prompt_arg


def cmd_chat(args: argparse.Namespace) -> int:
    base_url, api_key, default_model = require_config()
    model = args.model or default_model
    prompt = _read_prompt(args.prompt)
    if not prompt.strip():
        raise FleetError("Empty prompt. Pass text or pipe it via `-`.")

    messages = []
    if args.system:
        messages.append({"role": "system", "content": args.system})
    messages.append({"role": "user", "content": prompt})

    body: dict = {"model": model, "messages": messages, "stream": False}
    if args.temperature is not None:
        body["temperature"] = args.temperature
    if args.max_tokens is not None:
        body["max_tokens"] = args.max_tokens

    data = _request("POST", base_url, api_key, "/openai/v1/chat/completions", body=body)
    if args.json:
        print(json.dumps(data, indent=2))
        return 0

    content = ""
    try:
        content = data["choices"][0]["message"]["content"]
    except (KeyError, IndexError, TypeError):
        raise FleetError(f"Unexpected chat response shape:\n{json.dumps(data, indent=2)[:800]}")

    if not content.strip():
        eprint(
            f"WARNING: model '{model}' returned empty content. "
            f"Some 'thinking' variants (e.g. qwen3.5:latest) do this — try an explicit tag like {DEFAULT_MODEL}."
        )
        return 1
    print(content)
    return 0


def cmd_embed(args: argparse.Namespace) -> int:
    base_url, api_key, _ = require_config()
    text = _read_prompt(args.text)
    if not text.strip():
        raise FleetError("Empty input for embed.")
    body = {"model": args.model, "input": text}
    data = _request("POST", base_url, api_key, "/openai/v1/embeddings", body=body)
    if args.json:
        print(json.dumps(data, indent=2))
        return 0
    try:
        vector = data["data"][0]["embedding"]
    except (KeyError, IndexError, TypeError):
        raise FleetError(f"Unexpected embeddings response:\n{json.dumps(data, indent=2)[:800]}")
    head = ", ".join(f"{v:.4f}" for v in vector[:8])
    print(f"dim={len(vector)}  head=[{head}, ...]")
    return 0


def cmd_pull(args: argparse.Namespace) -> int:
    base_url, api_key, _ = require_config()
    body = {"name": args.model}
    resp = _request("POST", base_url, api_key, "/ollama/api/pull", body=body, stream=True, timeout=3600)
    last_status = ""
    success = False
    try:
        for raw_line in resp:
            line = raw_line.decode("utf-8", "replace").strip()
            if not line:
                continue
            try:
                event = json.loads(line)
            except json.JSONDecodeError:
                continue
            status = event.get("status", "")
            if event.get("error"):
                raise FleetError(f"pull failed: {event['error']}")
            if status and status != last_status:
                # Progress lines can be noisy (per-layer digests); collapse repeats.
                total = event.get("total")
                completed = event.get("completed")
                if total and completed:
                    pct = 100.0 * completed / total
                    eprint(f"  {status}  {pct:5.1f}%")
                else:
                    eprint(f"  {status}")
                last_status = status
            if status == "success":
                success = True
    finally:
        resp.close()
    if success:
        print(f"pulled {args.model}")
        return 0
    eprint(f"pull ended without an explicit success status (last: {last_status!r}).")
    return 1


def cmd_rm(args: argparse.Namespace) -> int:
    base_url, api_key, _ = require_config()
    if not args.yes and sys.stdin.isatty():
        ans = input(f"Delete model '{args.model}' from the fleet? [y/N]: ").strip().lower()
        if ans not in ("y", "yes"):
            eprint("Aborted.")
            return 1
    _request("DELETE", base_url, api_key, "/ollama/api/delete", body={"name": args.model})
    print(f"removed {args.model}")
    return 0


def cmd_raw(args: argparse.Namespace) -> int:
    base_url, api_key, _ = require_config()
    path = args.path if args.path.startswith("/") else "/" + args.path
    body = None
    if args.data is not None:
        payload = _read_prompt(args.data)
        try:
            body = json.loads(payload)
        except json.JSONDecodeError as exc:
            raise FleetError(f"--data is not valid JSON: {exc}")
    data = _request(args.method, base_url, api_key, path, body=body)
    print(json.dumps(data, indent=2))
    return 0


# --------------------------------------------------------------------------- #
# Argument parsing
# --------------------------------------------------------------------------- #

def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        prog="fleet_llm.py",
        description="Talk to the self-hosted Open WebUI / ollama fleet (LAN-only, VLAN30).",
    )
    sub = p.add_subparsers(dest="command", required=True)

    sp = sub.add_parser("setup", help="Write ~/.claude/fleet-llm.env config.")
    sp.add_argument("--base-url", help="Fleet base URL, e.g. http://192.168.30.53:3000")
    sp.add_argument("--api-key", help="Service-account bearer token.")
    sp.add_argument("--default-model", help=f"Default chat model (default {DEFAULT_MODEL}).")
    sp.add_argument("--from-ac-devops-sops", action="store_true",
                    help="Operator convenience: fetch the token from AC_OPBTA SOPS via ssh.")
    sp.set_defaults(func=cmd_setup)

    mp = sub.add_parser("models", help="List available model ids.")
    mp.add_argument("--json", action="store_true", help="Print raw JSON.")
    mp.set_defaults(func=cmd_models)

    cp = sub.add_parser("chat", help="Send a prompt and print the assistant reply.")
    cp.add_argument("prompt", nargs="?", default="-", help="Prompt text, or '-' / omit to read stdin.")
    cp.add_argument("--model", help="Override the default chat model.")
    cp.add_argument("--system", help="Optional system prompt.")
    cp.add_argument("--temperature", type=float, help="Sampling temperature.")
    cp.add_argument("--max-tokens", type=int, help="Max tokens in the reply.")
    cp.add_argument("--json", action="store_true", help="Print the full JSON response.")
    cp.set_defaults(func=cmd_chat)

    ep = sub.add_parser("embed", help="Return an embedding vector for text.")
    ep.add_argument("text", nargs="?", default="-", help="Text, or '-' / omit to read stdin.")
    ep.add_argument("--model", default=DEFAULT_EMBED_MODEL, help=f"Embedding model (default {DEFAULT_EMBED_MODEL}).")
    ep.add_argument("--json", action="store_true", help="Print raw JSON.")
    ep.set_defaults(func=cmd_embed)

    pp = sub.add_parser("pull", help="Pull a model onto the fleet (streams progress).")
    pp.add_argument("model", help="Model tag, e.g. llama3.1:8b")
    pp.set_defaults(func=cmd_pull)

    rp = sub.add_parser("rm", help="Delete a model from the fleet.")
    rp.add_argument("model", help="Model tag to delete.")
    rp.add_argument("-y", "--yes", action="store_true", help="Skip the confirmation prompt.")
    rp.set_defaults(func=cmd_rm)

    rawp = sub.add_parser("raw", help="Raw passthrough to any fleet endpoint.")
    rawp.add_argument("method", help="HTTP method, e.g. GET, POST, DELETE.")
    rawp.add_argument("path", help="Endpoint path, e.g. /openai/v1/models or /ollama/api/tags")
    rawp.add_argument("--data", help="JSON request body (or '-' to read from stdin).")
    rawp.set_defaults(func=cmd_raw)

    return p


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    try:
        return args.func(args)
    except FleetError as exc:
        eprint(f"error: {exc}")
        return 1
    except KeyboardInterrupt:
        eprint("interrupted")
        return 130


if __name__ == "__main__":
    sys.exit(main())

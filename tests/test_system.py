#!/usr/bin/env python3
"""Does this Codespaces + agents + Pages + Key Vault setup actually work?

Run:
  python3 tests/test_system.py -v
  python3 tests/test_system.py --json
  GROK_LIVE=1 python3 tests/test_system.py -v   # needs grok login

Never prints secret values.
"""
from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import unittest
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
VAULT = os.environ.get("AZURE_KEY_VAULT", "dp-kv-deliverypilot")
PAGES = "https://rifaterdemsahin.github.io/codespaces-ai-agents"
REPO = "https://github.com/rifaterdemsahin/codespaces-ai-agents"
INSTALL_GROK = "https://x.ai/cli/install.sh"
INSTALL_AGY = "https://antigravity.google/cli/install.sh"

REQUIRED_FILES = [
    ".devcontainer/devcontainer.json",
    ".devcontainer/post-create.sh",
    ".gitignore",
    ".env.example",
    "index.html",
    "iphone.html",
    "test.html",
    "after-green.html",
    "agy-worked.html",
    "grok-worked.html",
    "codespace-url.html",
    "iphone-ssh.html",
    "termius.html",
    "termius-setup.html",
    "iphone-free.html",
    "copy.js",
    "test.js",
    "nav.js",
    "styles.css",
    "README.md",
    "SUBSCRIPTION.md",
    "AGENTS.md",
    "scripts/kv-env.sh",
    "scripts/system-test.sh",
    "scripts/smoke-test.sh",
    ".github/workflows/pages.yml",
    ".github/workflows/ci.yml",
    "tests/test_system.py",
]


def _read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")


def _headers() -> dict[str, str]:
    return {"User-Agent": "codespaces-ai-agents-tests"}


def _http_head(url: str, timeout: int = 20) -> int:
    req = urllib.request.Request(url, method="HEAD", headers=_headers())
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return resp.status
    except urllib.error.HTTPError as exc:
        return exc.code
    except Exception:
        status, _ = _http_get(url, timeout=timeout)
        return status


def _http_get(url: str, timeout: int = 20) -> tuple[int, str]:
    req = urllib.request.Request(url, method="GET", headers=_headers())
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            body = resp.read().decode("utf-8", errors="replace")
            return resp.status, body
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace") if exc.fp else ""
        return exc.code, body


def _run(cmd: list[str], timeout: int = 60) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        cmd,
        cwd=ROOT,
        text=True,
        capture_output=True,
        timeout=timeout,
        check=False,
    )


def _az_logged_in() -> bool:
    if not shutil.which("az"):
        return False
    return _run(["az", "account", "show"], timeout=30).returncode == 0


class TestRepoFiles(unittest.TestCase):
    """Tracked files the Codespace and Pages site need."""

    def test_required_files_exist(self) -> None:
        missing = [rel for rel in REQUIRED_FILES if not (ROOT / rel).is_file()]
        self.assertEqual(missing, [], f"missing {missing}")

    def test_devcontainer_json(self) -> None:
        data = json.loads(_read(".devcontainer/devcontainer.json"))
        self.assertEqual(data.get("postCreateCommand"), "bash .devcontainer/post-create.sh")
        feats = json.dumps(data.get("features", {}))
        self.assertIn("azure-cli", feats)
        self.assertIn("sshd", feats)
        cpus = data.get("hostRequirements", {}).get("cpus")
        self.assertEqual(cpus, 2)

    def test_gitignore_covers_env(self) -> None:
        text = _read(".gitignore")
        self.assertRegex(text, r"(?m)^\.env$")

    def test_pages_workflow_publishes_test_page(self) -> None:
        text = _read(".github/workflows/pages.yml")
        self.assertIn("test.html", text)
        self.assertIn("after-green.html", text)
        self.assertIn("agy-worked.html", text)
        self.assertIn("grok-worked.html", text)
        self.assertIn("codespace-url.html", text)
        self.assertIn("iphone-ssh.html", text)
        self.assertIn("termius.html", text)
        self.assertIn("termius-setup.html", text)
        self.assertIn("iphone-free.html", text)
        self.assertIn("copy.js", text)
        self.assertIn("nav.js", text)
        self.assertIn("test.js", text)
        self.assertIn("report.json", text)

    def test_shell_scripts_parse(self) -> None:
        for rel in (
            ".devcontainer/post-create.sh",
            "scripts/kv-env.sh",
            "scripts/system-test.sh",
            "scripts/smoke-test.sh",
        ):
            proc = _run(["bash", "-n", str(ROOT / rel)])
            self.assertEqual(proc.returncode, 0, proc.stderr)


class TestPagesContent(unittest.TestCase):
    """Static HTML that GitHub Pages serves."""

    def test_index_explains_setup(self) -> None:
        html = _read("index.html")
        self.assertIn("Codespaces that run AI agents", html)
        self.assertIn("dp-kv-deliverypilot", html)
        self.assertIn("test.html", html)
        self.assertIn("nav.js", html)
        self.assertIn("after-green.html", html)

    def test_iphone_page(self) -> None:
        html = _read("iphone.html")
        self.assertIn("iPhone 14 Pro Max", html)
        self.assertIn("Request Desktop Website", html)
        self.assertIn("grok login --device-auth", html)
        self.assertIn("nav.js", html)

    def test_test_page(self) -> None:
        html = _read("test.html")
        self.assertIn("test.js", html)
        self.assertIn("system-test.sh", html)
        self.assertIn("nav.js", html)

    def test_after_green_page(self) -> None:
        html = _read("after-green.html")
        self.assertIn("After you press the green button", html)
        self.assertIn("github.dev", html)
        self.assertIn("system-test.sh", html)
        self.assertIn("nav.js", html)

    def test_shared_nav_lists_all_pages(self) -> None:
        js = _read("nav.js")
        for name in (
            "after-green.html",
            "agy-worked.html",
            "grok-worked.html",
            "codespace-url.html",
            "iphone-ssh.html",
            "termius.html",
            "termius-setup.html",
            "iphone-free.html",
            "index.html",
            "iphone.html",
            "test.html",
        ):
            self.assertIn(name, js)

    def test_agy_worked_page(self) -> None:
        html = _read("agy-worked.html")
        self.assertIn("What you should see when agy works", html)
        self.assertIn("Antigravity CLI 1.1.16", html)
        self.assertIn("Google AI Pro", html)
        self.assertIn("nav.js", html)

    def test_grok_worked_page(self) -> None:
        html = _read("grok-worked.html")
        self.assertIn("when grok is authorised", html)
        self.assertIn("grok login --device-auth", html)
        self.assertIn("READY", html)
        self.assertIn("nav.js", html)

    def test_codespace_url_page(self) -> None:
        html = _read("codespace-url.html")
        self.assertIn("zany-train-p9wx45qrxq3rr5p.github.dev", html)
        self.assertIn("iphone-ssh.html", html)
        self.assertIn("nav.js", html)

    def test_iphone_ssh_page(self) -> None:
        html = _read("iphone-ssh.html")
        self.assertIn("gh codespace ssh", html)
        self.assertIn("Termius", html)
        self.assertIn("nav.js", html)

    def test_termius_page(self) -> None:
        html = _read("termius.html")
        self.assertIn("How Termius reaches that Codespace", html)
        self.assertIn("two hops", html)
        self.assertIn("gh codespace ssh", html)
        self.assertIn("nav.js", html)

    def test_termius_setup_page(self) -> None:
        html = _read("termius-setup.html")
        self.assertIn("tap copy", html)
        self.assertIn("data-copy", html)
        self.assertIn("copy.js", html)
        self.assertIn("zany-train-p9wx45qrxq3rr5p", html)
        self.assertIn("nav.js", html)

    def test_iphone_free_page(self) -> None:
        html = _read("iphone-free.html")
        self.assertIn("skip Blink", html)
        self.assertIn("Termius", html)
        self.assertIn("data-copy", html)
        self.assertIn("copy.js", html)
        self.assertIn("nav.js", html)


class TestNoSecretsCommitted(unittest.TestCase):
    def test_no_obvious_api_key_literals(self) -> None:
        proc = _run(
            [
                "git",
                "grep",
                "-I",
                "-E",
                r"xai-[A-Za-z0-9]{20,}|sk-ant-|sk-or-",
                "--",
                ":!scripts/smoke-test.sh",
                ":!tests/test_system.py",
            ]
        )
        if proc.returncode == 0:
            self.fail("possible API key pattern in tracked files")
        if proc.returncode != 1:
            self.fail(f"git grep failed ({proc.returncode}): {proc.stderr.strip()}")


class TestInstallers(unittest.TestCase):
    def test_grok_installer_url(self) -> None:
        self.assertEqual(_http_head(INSTALL_GROK), 200)

    def test_agy_installer_url(self) -> None:
        self.assertEqual(_http_head(INSTALL_AGY), 200)


class TestLivePages(unittest.TestCase):
    """Public GitHub Pages — may lag one deploy behind this commit."""

    def test_pages_index_http(self) -> None:
        status, body = _http_get(f"{PAGES}/")
        self.assertEqual(status, 200)
        self.assertIn("Codespaces that run AI agents", body)

    def test_pages_iphone_http(self) -> None:
        status, body = _http_get(f"{PAGES}/iphone.html")
        self.assertEqual(status, 200)
        self.assertIn("iPhone 14 Pro Max", body)

    def test_pages_test_html_http(self) -> None:
        status, body = _http_get(f"{PAGES}/test.html")
        if status == 404:
            self.skipTest("test.html not on Pages yet (first deploy)")
        self.assertEqual(status, 200)
        self.assertIn("Is this system working", body)

    def test_pages_after_green_http(self) -> None:
        status, body = _http_get(f"{PAGES}/after-green.html")
        if status == 404:
            self.skipTest("after-green.html not on Pages yet (first deploy)")
        self.assertEqual(status, 200)
        self.assertIn("After you press the green button", body)

    def test_pages_agy_worked_http(self) -> None:
        status, body = _http_get(f"{PAGES}/agy-worked.html")
        if status == 404:
            self.skipTest("agy-worked.html not on Pages yet (first deploy)")
        self.assertEqual(status, 200)
        self.assertIn("What you should see when agy works", body)

    def test_pages_grok_worked_http(self) -> None:
        status, body = _http_get(f"{PAGES}/grok-worked.html")
        if status == 404:
            self.skipTest("grok-worked.html not on Pages yet (first deploy)")
        self.assertEqual(status, 200)
        self.assertIn("when grok is authorised", body)

    def test_pages_codespace_url_http(self) -> None:
        status, body = _http_get(f"{PAGES}/codespace-url.html")
        if status == 404:
            self.skipTest("codespace-url.html not on Pages yet (first deploy)")
        self.assertEqual(status, 200)
        self.assertIn("zany-train-p9wx45qrxq3rr5p.github.dev", body)

    def test_pages_iphone_ssh_http(self) -> None:
        status, body = _http_get(f"{PAGES}/iphone-ssh.html")
        if status == 404:
            self.skipTest("iphone-ssh.html not on Pages yet (first deploy)")
        self.assertEqual(status, 200)
        self.assertIn("gh codespace ssh", body)

    def test_pages_termius_http(self) -> None:
        status, body = _http_get(f"{PAGES}/termius.html")
        if status == 404:
            self.skipTest("termius.html not on Pages yet (first deploy)")
        self.assertEqual(status, 200)
        self.assertIn("How Termius reaches that Codespace", body)

    def test_pages_termius_setup_http(self) -> None:
        status, body = _http_get(f"{PAGES}/termius-setup.html")
        if status == 404:
            self.skipTest("termius-setup.html not on Pages yet (first deploy)")
        self.assertEqual(status, 200)
        self.assertIn("tap copy", body)

    def test_pages_iphone_free_http(self) -> None:
        status, body = _http_get(f"{PAGES}/iphone-free.html")
        if status == 404:
            self.skipTest("iphone-free.html not on Pages yet (first deploy)")
        self.assertEqual(status, 200)
        self.assertIn("skip Blink", body)


class TestGithubRepo(unittest.TestCase):
    def test_public_repo_api(self) -> None:
        status, body = _http_get("https://api.github.com/repos/rifaterdemsahin/codespaces-ai-agents")
        self.assertEqual(status, 200)
        data = json.loads(body)
        self.assertEqual(data.get("full_name"), "rifaterdemsahin/codespaces-ai-agents")
        self.assertFalse(data.get("private"))


class TestCliPresence(unittest.TestCase):
    """Installed tools — SKIP on CI / a laptop that is not the Codespace."""

    def test_grok_on_path(self) -> None:
        if not shutil.which("grok"):
            self.skipTest("grok not installed on this machine")
        proc = _run(["grok", "--version"], timeout=30)
        self.assertEqual(proc.returncode, 0, proc.stderr or proc.stdout)

    def test_agy_on_path(self) -> None:
        if not shutil.which("agy"):
            self.skipTest("agy not installed on this machine")
        proc = _run(["agy", "--version"], timeout=30)
        self.assertEqual(proc.returncode, 0, proc.stderr or proc.stdout)

    def test_az_on_path(self) -> None:
        if not shutil.which("az"):
            self.skipTest("az not installed on this machine")
        proc = _run(["az", "version", "--query", '"azure-cli"', "-o", "tsv"], timeout=30)
        self.assertEqual(proc.returncode, 0, proc.stderr)


class TestAzureKeyVault(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        if not _az_logged_in():
            raise unittest.SkipTest("az not logged in")

    def test_vault_exists(self) -> None:
        proc = _run(["az", "keyvault", "show", "--name", VAULT, "--query", "name", "-o", "tsv"])
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertEqual(proc.stdout.strip(), VAULT)

    def test_agent_secrets_present(self) -> None:
        names = [
            "xai-api-key",
            "ANTHROPIC-API-KEY",
            "OPENAI-API-KEY",
            "GEMINI-API-KEY-PRIMARY",
        ]
        missing = []
        for name in names:
            proc = _run(
                [
                    "az",
                    "keyvault",
                    "secret",
                    "show",
                    "--vault-name",
                    VAULT,
                    "--name",
                    name,
                    "--query",
                    "length(value)",
                    "-o",
                    "tsv",
                ]
            )
            if proc.returncode != 0 or not proc.stdout.strip().isdigit():
                missing.append(name)
        self.assertEqual(missing, [], f"vault secrets missing or empty: {missing}")


class TestGrokLive(unittest.TestCase):
    """Real model call. Opt-in: GROK_LIVE=1 after `grok login --device-auth`."""

    def test_grok_prompt_ready(self) -> None:
        if os.environ.get("GROK_LIVE") != "1":
            self.skipTest("set GROK_LIVE=1 after grok login")
        if not shutil.which("grok"):
            self.skipTest("grok not installed")
        proc = _run(
            ["grok", "-p", "Reply with READY and nothing else"],
            timeout=180,
        )
        self.assertEqual(proc.returncode, 0, "grok -p failed (not logged in?)")
        text = (proc.stdout or "") + (proc.stderr or "")
        self.assertIn("READY", text, "grok did not reply READY (login or quota?)")


class JsonTestResult(unittest.TextTestResult):
    def __init__(self, *args, **kwargs) -> None:
        super().__init__(*args, **kwargs)
        self.records: list[dict[str, str]] = []

    def addSuccess(self, test: unittest.TestCase) -> None:
        super().addSuccess(test)
        self.records.append(self._row(test, "PASS", ""))

    def addSkip(self, test: unittest.TestCase, reason: str) -> None:
        super().addSkip(test, reason)
        self.records.append(self._row(test, "SKIP", reason))

    def addFailure(self, test: unittest.TestCase, err) -> None:
        super().addFailure(test, err)
        self.records.append(self._row(test, "FAIL", self._exc(err)))

    def addError(self, test: unittest.TestCase, err) -> None:
        super().addError(test, err)
        self.records.append(self._row(test, "FAIL", self._exc(err)))

    @staticmethod
    def _row(test: unittest.TestCase, status: str, detail: str) -> dict[str, str]:
        return {
            "id": test.id(),
            "name": test.shortDescription() or str(test),
            "status": status,
            "detail": detail[:400],
        }

    @staticmethod
    def _exc(err) -> str:
        return str(err[1]).replace("\n", " ")[:400]


def _report(records: list[dict[str, str]]) -> dict:
    summary = {"pass": 0, "fail": 0, "skip": 0}
    for row in records:
        key = {"PASS": "pass", "FAIL": "fail", "SKIP": "skip"}.get(row["status"], "fail")
        summary[key] += 1
    return {
        "generated_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "host": os.environ.get("GITHUB_ACTIONS") and "github-actions" or os.uname().nodename,
        "repo": REPO,
        "pages": PAGES,
        "ok": summary["fail"] == 0,
        "summary": summary,
        "checks": records,
    }


def main(argv: list[str] | None = None) -> int:
    argv = list(sys.argv if argv is None else argv)
    want_json = "--json" in argv
    if want_json:
        argv.remove("--json")
    if "--live" in argv:
        argv.remove("--live")
        os.environ["GROK_LIVE"] = "1"

    os.chdir(ROOT)
    loader = unittest.TestLoader()
    suite = loader.loadTestsFromModule(sys.modules[__name__])

    if want_json:
        runner = unittest.TextTestRunner(
            stream=open(os.devnull, "w"),
            verbosity=0,
            resultclass=JsonTestResult,
        )
        result = runner.run(suite)
        json.dump(_report(result.records), sys.stdout, indent=2)
        sys.stdout.write("\n")
        return 0 if result.wasSuccessful() else 1

    runner = unittest.TextTestRunner(verbosity=2)
    # unittest.main would re-parse argv; drive it ourselves so --json/--live work
    sys.argv = [argv[0], *argv[1:]]
    result = runner.run(suite)
    return 0 if result.wasSuccessful() else 1


if __name__ == "__main__":
    raise SystemExit(main())

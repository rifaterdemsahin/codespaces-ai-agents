/* Browser checks for the GitHub Pages test board. No secrets. */
(function () {
  const PAGES = "https://rifaterdemsahin.github.io/codespaces-ai-agents";
  const API = "https://api.github.com/repos/rifaterdemsahin/codespaces-ai-agents";

  const board = document.getElementById("board");
  const summaryEl = document.getElementById("summary");
  const ciEl = document.getElementById("ci-report");
  const runBtn = document.getElementById("run");

  function badge(status) {
    const span = document.createElement("span");
    span.className = "badge badge-" + status.toLowerCase();
    span.textContent = status;
    return span;
  }

  function row(name, status, detail) {
    const tr = document.createElement("tr");
    const tdN = document.createElement("td");
    tdN.textContent = name;
    const tdS = document.createElement("td");
    tdS.appendChild(badge(status));
    const tdD = document.createElement("td");
    tdD.textContent = detail || "";
    tr.appendChild(tdN);
    tr.appendChild(tdS);
    tr.appendChild(tdD);
    return tr;
  }

  async function check(name, fn) {
    try {
      const detail = await fn();
      return { name, status: "PASS", detail: detail || "" };
    } catch (err) {
      if (err && err.skip) {
        return { name, status: "SKIP", detail: String(err.message || err) };
      }
      return { name, status: "FAIL", detail: String(err.message || err) };
    }
  }

  async function fetchText(url) {
    const res = await fetch(url, { cache: "no-store" });
    if (!res.ok) throw new Error(url + " → HTTP " + res.status);
    return res.text();
  }

  async function fetchJson(url) {
    const res = await fetch(url, { cache: "no-store" });
    if (!res.ok) throw new Error(url + " → HTTP " + res.status);
    return res.json();
  }

  function mustInclude(body, snippet, label) {
    if (!body.includes(snippet)) throw new Error(label + " missing “" + snippet + "”");
    return (body.length || 0) + " chars";
  }

  async function browserChecks() {
    return Promise.all([
      check("index.html loads", async () => {
        const t = await fetchText("./index.html");
        return mustInclude(t, "Codespaces that run AI agents", "index");
      }),
      check("iphone.html loads", async () => {
        const t = await fetchText("./iphone.html");
        return mustInclude(t, "iPhone 14 Pro Max", "iphone");
      }),
      check("test.html loads", async () => {
        const t = await fetchText("./test.html");
        return mustInclude(t, "system-test.sh", "test page");
      }),
      check("after-green.html loads", async () => {
        const t = await fetchText("./after-green.html");
        return mustInclude(t, "After you press the green button", "after-green");
      }),
      check("nav.js shared menu", async () => {
        const t = await fetchText("./nav.js");
        return mustInclude(t, "After green button", "nav");
      }),
      check("agy-worked.html loads", async () => {
        const t = await fetchText("./agy-worked.html");
        return mustInclude(t, "What you should see when agy works", "agy-worked");
      }),
      check("grok-worked.html loads", async () => {
        const t = await fetchText("./grok-worked.html");
        return mustInclude(t, "when grok is authorised", "grok-worked");
      }),
      check("codespace-url.html loads", async () => {
        const t = await fetchText("./codespace-url.html");
        return mustInclude(t, "zany-train-p9wx45qrxq3rr5p.github.dev", "codespace-url");
      }),
      check("iphone-ssh.html loads", async () => {
        const t = await fetchText("./iphone-ssh.html");
        return mustInclude(t, "gh codespace ssh", "iphone-ssh");
      }),
      check("termius.html loads", async () => {
        const t = await fetchText("./termius.html");
        return mustInclude(t, "How Termius reaches that Codespace", "termius");
      }),
      check("termius-setup.html loads", async () => {
        const t = await fetchText("./termius-setup.html");
        return mustInclude(t, "tap copy", "termius-setup");
      }),
      check("copy.js loads", async () => {
        const t = await fetchText("./copy.js");
        return mustInclude(t, "data-copy", "copy.js");
      }),
      check("iphone-free.html loads", async () => {
        const t = await fetchText("./iphone-free.html");
        return mustInclude(t, "skip Blink", "iphone-free");
      }),
      check("vps.html loads", async () => {
        const t = await fetchText("./vps.html");
        return mustInclude(t, "Fly.io", "vps");
      }),
      check("cheapest-vps.html loads", async () => {
        const t = await fetchText("./cheapest-vps.html");
        return mustInclude(t, "Cheapest VPS you can reach from the UK", "cheapest-vps");
      }),
      check("azure-idle.html loads", async () => {
        const t = await fetchText("./azure-idle.html");
        return mustInclude(t, "destroy when idle", "azure-idle");
      }),
      check("why.html loads", async () => {
        const t = await fetchText("./why.html");
        return mustInclude(t, "when you are mobile", "why");
      }),
      check("azure-vm-errors.html loads", async () => {
        const t = await fetchText("./azure-vm-errors.html");
        return mustInclude(t, "QuotaExceeded", "azure-vm-errors");
      }),
      check("termius-azure.html loads", async () => {
        const t = await fetchText("./termius-azure.html");
        return mustInclude(t, "azureuser", "termius-azure");
      }),
      check("styles.css loads", async () => {
        const t = await fetchText("./styles.css");
        return mustInclude(t, "--accent", "css");
      }),
      check("test.js loads", async () => {
        const t = await fetchText("./test.js");
        return mustInclude(t, "browserChecks", "test.js");
      }),
      check("GitHub repo is public", async () => {
        const data = await fetchJson(API);
        if (data.full_name !== "rifaterdemsahin/codespaces-ai-agents") {
          throw new Error("unexpected repo " + data.full_name);
        }
        if (data.private) throw new Error("repo is private — Pages may 404");
        return "default branch " + (data.default_branch || "?");
      }),
      check("GitHub Actions has a green run", async () => {
        const data = await fetchJson(API + "/actions/runs?per_page=8");
        const runs = data.workflow_runs || [];
        if (!runs.length) throw new Error("no workflow runs");
        const ok = runs.find((r) => r.conclusion === "success");
        if (!ok) throw new Error("no successful run in last " + runs.length);
        return ok.name + " · " + ok.conclusion + " · " + ok.head_sha.slice(0, 7);
      }),
      check("live Pages origin responds", async () => {
        const t = await fetchText(PAGES + "/");
        return mustInclude(t, "Codespaces that run AI agents", "live index");
      }),
      check("live test.html on GitHub Pages", async () => {
        const res = await fetch(PAGES + "/test.html", { cache: "no-store" });
        if (res.status === 404) {
          const err = new Error("not on CDN yet — wait for Pages deploy");
          err.skip = true;
          throw err;
        }
        if (!res.ok) throw new Error("HTTP " + res.status);
        const t = await res.text();
        return mustInclude(t, "Is this system working", "live test page");
      }),
    ]);
  }

  function render(results, title) {
    const pass = results.filter((r) => r.status === "PASS").length;
    const fail = results.filter((r) => r.status === "FAIL").length;
    const skip = results.filter((r) => r.status === "SKIP").length;
    summaryEl.innerHTML = "";
    const h = document.createElement("p");
    h.className = fail ? "summary fail" : "summary pass";
    h.textContent = title + ": " + pass + " pass · " + fail + " fail · " + skip + " skip";
    summaryEl.appendChild(h);

    board.innerHTML = "";
    const table = document.createElement("table");
    const thead = document.createElement("thead");
    thead.innerHTML = "<tr><th>Check</th><th>Status</th><th>Detail</th></tr>";
    table.appendChild(thead);
    const tbody = document.createElement("tbody");
    results.forEach((r) => tbody.appendChild(row(r.name, r.status, r.detail)));
    table.appendChild(tbody);
    board.appendChild(table);
    return fail === 0;
  }

  async function loadCiReport() {
    ciEl.textContent = "Loading last CI report…";
    try {
      const report = await fetchJson("./report.json");
      const s = report.summary || {};
      const lines = [];
      lines.push(
        (report.ok ? "PASS" : "FAIL") +
          " · generated " +
          (report.generated_at || "?") +
          " on " +
          (report.host || "?")
      );
      lines.push(
        (s.pass || 0) + " pass · " + (s.fail || 0) + " fail · " + (s.skip || 0) + " skip"
      );
      const table = document.createElement("table");
      const tbody = document.createElement("tbody");
      (report.checks || []).forEach((c) => {
        tbody.appendChild(row(c.id || c.name, c.status, c.detail));
      });
      table.appendChild(tbody);
      ciEl.innerHTML = "";
      const p = document.createElement("p");
      p.className = report.ok ? "summary pass" : "summary fail";
      p.textContent = lines.join(" — ");
      ciEl.appendChild(p);
      ciEl.appendChild(table);
    } catch (err) {
      ciEl.textContent =
        "No report.json yet (this file is written during the Pages deploy). " +
        String(err.message || err);
    }
  }

  async function run() {
    runBtn.disabled = true;
    summaryEl.textContent = "Running browser checks…";
    const results = await browserChecks();
    render(results, "Browser");
    runBtn.disabled = false;
  }

  runBtn.addEventListener("click", run);
  loadCiReport();
  run();
})();

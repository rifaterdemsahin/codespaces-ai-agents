/* Shared top menu for every GitHub Pages screen. */
(function () {
  const ITEMS = [
    { href: "after-green.html", emoji: "🟢", label: "After green button" },
    { href: "agy-worked.html", emoji: "✨", label: "agy worked" },
    { href: "grok-worked.html", emoji: "🤖", label: "grok authorised" },
    { href: "index.html", emoji: "🏠", label: "Setup log" },
    { href: "codespace-url.html", emoji: "🔗", label: "Codespace URL" },
    { href: "iphone-free.html", emoji: "🆓", label: "Free iPhone" },
    { href: "termius-setup.html", emoji: "📋", label: "Termius setup" },
    { href: "termius.html", emoji: "📱", label: "Termius hops" },
    { href: "iphone-ssh.html", emoji: "📡", label: "iPhone SSH" },
    { href: "iphone.html", emoji: "📱", label: "iPhone Safari" },
    { href: "test.html", emoji: "✅", label: "System test" },
  ];

  const mount = document.getElementById("topnav");
  if (!mount) return;

  const file = (location.pathname.split("/").pop() || "index.html").toLowerCase();
  const current = file === "" || file === "/" ? "index.html" : file;

  const bar = document.createElement("div");
  bar.className = "bar";

  const brand = document.createElement("a");
  brand.className = "brand";
  brand.href = "index.html";
  brand.textContent = "⚡ AI agents";
  bar.appendChild(brand);

  ITEMS.forEach(function (item) {
    const a = document.createElement("a");
    a.href = item.href;
    a.innerHTML = "<span class=\"e\">" + item.emoji + "</span> " + item.label;
    if (item.href === current) a.setAttribute("aria-current", "page");
    bar.appendChild(a);
  });

  mount.appendChild(bar);
  mount.setAttribute("aria-label", "Site");
})();

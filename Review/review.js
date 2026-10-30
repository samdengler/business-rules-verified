// The site's bar: the site name and links between the parts of the site, added
// to the header of every page of the review document.  The page's <base> is the document root, so "../" is
// the site root, where the progress page is.
document.addEventListener("DOMContentLoaded", () => {
  const header = document.querySelector("header");
  if (!header || header.querySelector(".site-nav")) return;
  const nav = document.createElement("nav");
  nav.className = "site-nav";
  nav.setAttribute("aria-label", "Site");
  const links = [
    ["../", "Progress"],
    ["./", "Review document", true],
    ["../graph/", "Dependency graph"],
    ["https://github.com/samdengler/airline-order-verified", "GitHub"],
  ];
  for (const [href, text, current] of links) {
    const a = document.createElement("a");
    a.href = href;
    a.textContent = text;
    if (current) a.setAttribute("aria-current", "page");
    nav.appendChild(a);
  }
  // The site name, as on the progress page and the blueprint (scripts/site_nav.py).
  const brand = document.createElement("a");
  brand.className = "brand";
  brand.href = "../";
  brand.innerHTML = '<svg class="mark" viewBox="0 0 24 24" aria-hidden="true"><path transform="rotate(-30 12 12)" '
    + 'fill="currentColor" d="M21.6 12c0-.85-.7-1.45-1.55-1.45H14.3L9.4 3.2H7.6l2.35 7.35H5.5L3.75 8.1H2.4l1.05 3.9-1.05 3.9h1.35l1.75-2.45h4.45L7.6 20.8h1.8l4.9-7.35h5.75c.85 0 1.55-.6 1.55-1.45z"/></svg>Airline Order';
  // The same plane as the browser tab's icon (FAVICON in scripts/site_nav.py).
  const icon = document.createElement("link");
  icon.rel = "icon";
  icon.href = "data:image/svg+xml," + encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">'
    + '<path transform="rotate(-30 12 12)" fill="#2a78d6" d="M21.6 12c0-.85-.7-1.45-1.55-1.45H14.3L9.4 3.2H7.6l2.35 7.35H5.5L3.75 8.1H2.4l1.05 3.9-1.05 3.9h1.35l1.75-2.45h4.45L7.6 20.8h1.8l4.9-7.35h5.75c.85 0 1.55-.6 1.55-1.45z"/></svg>');
  document.head.appendChild(icon);
  // Inside the title area: Verso's search box overlaps anything placed after it.
  const wrapper = header.querySelector(".header-title-wrapper") || header;
  wrapper.append(brand, nav);
});

// Try-it panels on the requirement pages.  They call the Rust rules compiled to
// WebAssembly (try/rules.wasm at the site root, built by scripts/build-wasm.sh).
document.addEventListener("DOMContentLoaded", async () => {
  const panels = document.querySelectorAll(".try-it");
  if (!panels.length) return;
  let rules;
  try {
    const response = await fetch(new URL("../try/rules.wasm", document.baseURI));
    const { instance } = await WebAssembly.instantiate(await response.arrayBuffer());
    rules = instance.exports;
  } catch (e) {
    for (const panel of panels)
      panel.querySelector(".try-result").textContent = "The rule could not be loaded in this browser.";
    return;
  }
  const states = ["ready", "delivered", "cancelled", "refunded"];
  const cents = (input) => {
    const n = Math.round(parseFloat(input.value) * 100);
    return Number.isFinite(n) && n >= 0 ? n : null;
  };
  const usd = (n) => (n / 100).toFixed(2) + " USD";
  const updates = {
    step(panel, result) {
      const s = Number(panel.querySelector("[name=state]").value);
      const e = Number(panel.querySelector("[name=event]").value);
      const next = rules.step_index(s, e);
      result.className = "try-result " + (next >= 0 ? "ok" : "no");
      result.textContent = next >= 0
        ? `Allowed. The service moves from ${states[s]} to ${states[next]}.`
        : `Refused. A ${states[s]} service cannot take this event, so its state stays ${states[s]}.`;
    },
    refund(panel, result) {
      const paid = cents(panel.querySelector("[name=paid]"));
      const refunds = [1, 2].map((i) => ({
        amount: cents(panel.querySelector(`[name=r${i}]`)),
        payment: Number(panel.querySelector(`[name=p${i}]`).value),
      }));
      if (paid === null || refunds.some((r) => r.amount === null)) {
        result.className = "try-result";
        result.textContent = "Enter amounts of zero or more.";
        return;
      }
      const accepted = refunds.map((r) =>
        rules.accept_refund_flag(1n, BigInt(paid), BigInt(r.payment), BigInt(r.amount)) === 1);
      const total = refunds.reduce((sum, r, i) => sum + (accepted[i] ? r.amount : 0), 0);
      const lines = refunds.map((r, i) => `Refund ${i + 1}: ${accepted[i] ? "accepted" : "rejected"}.`);
      lines.push(`Accepted refunds return ${usd(total)} against a payment of ${usd(paid)}.`);
      if (total > paid) lines.push("That is more than was paid: the open question for this rule.");
      result.className = "try-result " + (total > paid ? "no" : "ok");
      result.textContent = lines.join(" ");
    },
  };
  for (const panel of panels) {
    const result = panel.querySelector(".try-result");
    const update = () => updates[panel.dataset.try](panel, result);
    panel.addEventListener("input", update);
    panel.addEventListener("change", update);
    update();
  }
});

// Perdidos — protótipo do site. Sem dependências.
(function () {
  "use strict";

  // Menu fixo (celular)
  var nav = document.querySelector(".nav");
  var toggle = document.querySelector(".nav-toggle");
  if (toggle) {
    toggle.addEventListener("click", function () {
      var open = nav.classList.toggle("open");
      toggle.setAttribute("aria-expanded", open ? "true" : "false");
    });
    nav.querySelectorAll(".nav-links a").forEach(function (a) {
      a.addEventListener("click", function () {
        nav.classList.remove("open");
        toggle.setAttribute("aria-expanded", "false");
      });
    });
  }

  // Tema claro/escuro (o escuro é o padrão; a escolha fica salva no navegador)
  var root = document.documentElement;
  var themeMeta = document.querySelector('meta[name="theme-color"]');
  function applyTheme(theme) {
    root.dataset.theme = theme;
    document.querySelectorAll(".theme-toggle").forEach(function (b) {
      b.setAttribute("aria-pressed", theme === "dark" ? "true" : "false");
    });
    if (themeMeta) themeMeta.setAttribute("content", theme === "dark" ? "#0f1f1b" : "#183e34");
  }
  applyTheme(root.dataset.theme === "light" ? "light" : "dark");
  document.querySelectorAll(".theme-toggle").forEach(function (b) {
    b.addEventListener("click", function () {
      var next = root.dataset.theme === "dark" ? "light" : "dark";
      applyTheme(next);
      try { localStorage.setItem("perdidos-theme", next); } catch (e) {}
    });
  });

  // Pétalas da tela de título (leves; desligadas com "reduzir movimento")
  var petals = document.querySelector(".petals");
  var reduce = window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  if (petals && !reduce) {
    var n = window.innerWidth < 600 ? 9 : 16;
    for (var i = 0; i < n; i++) {
      var p = document.createElement("span");
      p.className = "petal";
      p.style.left = (Math.random() * 95).toFixed(1) + "%";
      p.style.animationDuration = (11 + Math.random() * 10).toFixed(1) + "s";
      p.style.animationDelay = (-Math.random() * 20).toFixed(1) + "s";
      p.style.setProperty("--dx", (60 + Math.random() * 220).toFixed(0) + "px");
      var s = Math.random() < 0.3 ? 2 : 3;
      p.style.width = p.style.height = (3 * s) + "px";
      p.style.backgroundSize = (3 * s) + "px " + (3 * s) + "px";
      petals.appendChild(p);
    }
  }

  // Seu Viajante: nacionalidade e corpo
  var stage = document.querySelector("[data-stage]");
  if (stage) {
    var figM = stage.querySelector("[data-fig='m']");
    var figF = stage.querySelector("[data-fig='f']");
    var title = stage.querySelector("[data-nat-name]");
    var hook = stage.querySelector("[data-nat-hook]");
    var sw = stage.querySelector("[data-nat-swatches]");
    var natButtons = document.querySelectorAll(".nat-btn");
    var bodyButtons = document.querySelectorAll("[data-body]");
    var state = { nat: "sabia", body: "both" };

    function render() {
      var btn = document.querySelector(".nat-btn[data-nat='" + state.nat + "']");
      figM.src = "img/chars/" + state.nat + "_m_se.png";
      figF.src = "img/chars/" + state.nat + "_f_se.png";
      figM.hidden = state.body === "f";
      figF.hidden = state.body === "m";
      title.textContent = btn.dataset.name;
      hook.textContent = btn.dataset.hook;
      sw.innerHTML = "<i style='background:" + btn.dataset.c1 + "'></i><i style='background:" + btn.dataset.c2 + "'></i>";
      natButtons.forEach(function (b) { b.setAttribute("aria-pressed", b === btn ? "true" : "false"); });
      bodyButtons.forEach(function (b) { b.setAttribute("aria-pressed", b.dataset.body === state.body ? "true" : "false"); });
    }
    natButtons.forEach(function (b) {
      b.addEventListener("click", function () { state.nat = b.dataset.nat; render(); });
    });
    bodyButtons.forEach(function (b) {
      b.addEventListener("click", function () { state.body = b.dataset.body; render(); });
    });
    render();
  }

  // Bestiário: filtro por região
  var chips = document.querySelectorAll(".chip[data-filter]");
  var mons = document.querySelectorAll(".mon[data-region]");
  chips.forEach(function (c) {
    c.addEventListener("click", function () {
      var f = c.dataset.filter;
      chips.forEach(function (o) { o.setAttribute("aria-pressed", o === c ? "true" : "false"); });
      mons.forEach(function (m) { m.hidden = !(f === "all" || m.dataset.region === f); });
    });
  });
  // começa na aba marcada (Terra do Sabiá)
  var firstChip = document.querySelector('.chip[data-filter][aria-pressed="true"]');
  if (firstChip) firstChip.click();

  // Abas genéricas: [data-tabgroup] com filhos [data-tab="Nome"]
  document.querySelectorAll("[data-tabgroup]").forEach(function (group, gi) {
    var panes = Array.prototype.slice.call(group.children).filter(function (c) { return c.hasAttribute("data-tab"); });
    if (panes.length < 2) return;
    var bar = document.createElement("div");
    bar.className = "skilltabs";
    bar.setAttribute("role", "tablist");
    if (group.getAttribute("aria-label")) bar.setAttribute("aria-label", group.getAttribute("aria-label"));
    var buttons = panes.map(function (pane, i) {
      var id = "tabpane-" + gi + "-" + i;
      pane.id = pane.id || id;
      pane.setAttribute("role", "tabpanel");
      var b = document.createElement("button");
      b.type = "button";
      b.setAttribute("role", "tab");
      b.setAttribute("aria-controls", pane.id);
      b.textContent = pane.getAttribute("data-tab");
      var c = getComputedStyle(pane).getPropertyValue("--tab-c");
      if (c) b.style.setProperty("--tab-c", c);
      bar.appendChild(b);
      return b;
    });
    function show(i) {
      panes.forEach(function (p, j) { p.hidden = j !== i; });
      buttons.forEach(function (b, j) { b.setAttribute("aria-selected", j === i ? "true" : "false"); b.tabIndex = j === i ? 0 : -1; });
    }
    buttons.forEach(function (b, i) {
      b.addEventListener("click", function () { show(i); if (b.scrollIntoView) b.scrollIntoView({ block: "nearest", inline: "nearest" }); });
      b.addEventListener("keydown", function (e) {
        var n = e.key === "ArrowRight" ? 1 : e.key === "ArrowLeft" ? -1 : 0;
        if (!n) return;
        var k = (i + n + buttons.length) % buttons.length;
        show(k); buttons[k].focus();
      });
    });
    group.parentNode.insertBefore(bar, group);
    group.classList.add("tabbed-group");
    show(0);
  });

  // Visualizador das capturas
  var viewer = document.querySelector(".viewer");
  if (viewer && typeof viewer.showModal === "function") {
    var vImg = viewer.querySelector("img");
    var vCap = viewer.querySelector("p");
    document.querySelectorAll(".shot button, .fx button").forEach(function (b) {
      b.addEventListener("click", function () {
        var img = b.querySelector("img");
        vImg.src = img.src;
        vImg.alt = img.alt;
        var cap = b.parentElement.querySelector("figcaption");
        vCap.textContent = cap ? cap.textContent : "";
        viewer.showModal();
      });
    });
    viewer.addEventListener("click", function (e) { if (e.target === viewer) viewer.close(); });
    viewer.querySelector(".close").addEventListener("click", function () { viewer.close(); });
  }

  // Árvores de skills em abas, uma por título
  document.querySelectorAll(".trees[data-tabs]").forEach(function (trees) {
    var panels = Array.prototype.slice.call(trees.querySelectorAll(".skilltree"));
    if (!panels.length) return;
    var bar = document.createElement("div");
    bar.className = "skilltabs";
    bar.setAttribute("role", "tablist");
    bar.setAttribute("aria-label", "Títulos");
    var buttons = panels.map(function (panel, i) {
      var id = "skilltree-" + i;
      panel.id = id;
      panel.setAttribute("role", "tabpanel");
      var b = document.createElement("button");
      b.type = "button";
      b.setAttribute("role", "tab");
      b.setAttribute("aria-controls", id);
      b.textContent = panel.querySelector("h4").textContent;
      var school = ["blade", "arcane", "bow", "support", "tank", "hybrid", "traveler"].filter(function (c) {
        return panel.classList.contains(c);
      })[0];
      if (school) b.style.setProperty("--tab-c", getComputedStyle(panel).getPropertyValue("--tab-c"));
      bar.appendChild(b);
      return b;
    });
    function show(i) {
      panels.forEach(function (p, j) { p.hidden = j !== i; });
      buttons.forEach(function (b, j) {
        b.setAttribute("aria-selected", j === i ? "true" : "false");
        b.tabIndex = j === i ? 0 : -1;
      });
    }
    buttons.forEach(function (b, i) {
      b.addEventListener("click", function () {
        show(i);
        if (b.scrollIntoView) b.scrollIntoView({ block: "nearest", inline: "nearest" });
      });
      b.addEventListener("keydown", function (e) {
        var n = e.key === "ArrowRight" ? 1 : e.key === "ArrowLeft" ? -1 : 0;
        if (!n) return;
        var k = (i + n + buttons.length) % buttons.length;
        show(k);
        buttons[k].focus();
      });
    });
    trees.parentNode.insertBefore(bar, trees);
    trees.classList.add("tabbed");
    show(0);
  });

  // Lista de espera (protótipo: não envia nada)
  var signup = document.querySelector(".signup");
  if (signup) {
    signup.querySelector("form").addEventListener("submit", function (e) {
      e.preventDefault();
      signup.classList.add("sent");
      signup.querySelector(".thanks").focus();
    });
  }
})();

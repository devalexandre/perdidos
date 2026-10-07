(function () {
  'use strict';
  const nav = document.querySelector('.nav');
  const toggle = document.querySelector('.nav-toggle');
  document.addEventListener('keydown', function (event) {
    if (event.key === 'Escape' && nav.classList.contains('open')) {
      nav.classList.remove('open');
      toggle.setAttribute('aria-expanded', 'false');
      toggle.focus();
    }
  });
  document.addEventListener('click', function (event) {
    if (!nav.contains(event.target)) {
      nav.classList.remove('open');
      toggle.setAttribute('aria-expanded', 'false');
    }
  });
  const tabs = Array.from(document.querySelectorAll('.paths [role=tab]'));
  function selectTab(index, focus) {
    tabs.forEach(function (tab, current) {
      const selected = current === index;
      tab.setAttribute('aria-selected', String(selected));
      tab.tabIndex = selected ? 0 : -1;
      document.getElementById(tab.getAttribute('aria-controls')).hidden = !selected;
    });
    if (focus) tabs[index].focus();
  }
  tabs.forEach(function (tab, index) {
    tab.addEventListener('click', function () { selectTab(index, false); });
    tab.addEventListener('keydown', function (event) {
      let target;
      if (event.key === 'ArrowRight') target = (index + 1) % tabs.length;
      if (event.key === 'ArrowLeft') target = (index - 1 + tabs.length) % tabs.length;
      if (event.key === 'Home') target = 0;
      if (event.key === 'End') target = tabs.length - 1;
      if (target !== undefined) {
        event.preventDefault();
        selectTab(target, true);
      }
    });
  });
  const anchors = Array.from(document.querySelectorAll('.nav-links a[href^="#"]'));
  if ('IntersectionObserver' in window) {
    const observer = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (!entry.isIntersecting) return;
        anchors.forEach(function (anchor) {
          if (anchor.hash === '#' + entry.target.id) anchor.setAttribute('aria-current', 'location');
          else anchor.removeAttribute('aria-current');
        });
      });
    }, {rootMargin: '-15% 0px -55% 0px'});
    anchors.forEach(function (anchor) {
      const section = document.querySelector(anchor.hash);
      if (section) observer.observe(section);
    });
  }
  const form = document.getElementById('waitlist-form');
  if (form) {
    const status = document.getElementById('waitlist-status');
    const button = form.querySelector('button[type="submit"]');
    form.addEventListener('submit', async function (event) {
      event.preventDefault();
      if (!form.reportValidity() || button.disabled) return;
      const data = new FormData(form);
      const controller = new AbortController();
      const timeout = setTimeout(function () { controller.abort(); }, 15000);
      button.disabled = true;
      form.setAttribute('aria-busy', 'true');
      status.dataset.error = 'false';
      status.textContent = 'Enviando sua inscrição…';
      try {
        const response = await fetch(form.dataset.endpoint, {
          method: 'POST',
          headers: {'Content-Type': 'application/json', 'ngrok-skip-browser-warning': '1'},
          body: JSON.stringify({email: data.get('email').trim(), name: data.get('name').trim(), platform: data.get('platform'), consent: data.get('consent') === 'on', website: data.get('website') || ''}),
          signal: controller.signal
        });
        const result = await response.json();
        if (!response.ok || result.ok !== true) throw new Error(result.message || 'Não conseguimos salvar sua inscrição. Tente novamente em instantes.');
        form.reset();
        status.textContent = 'Inscrição recebida! Você está na lista de espera de Perdidos. Até a próxima viagem.';
      } catch (error) {
        status.dataset.error = 'true';
        status.textContent = error.name === 'AbortError' || error instanceof TypeError || error instanceof SyntaxError
          ? 'Não conseguimos conectar à lista de espera. Confira sua conexão ou tente novamente mais tarde.'
          : error.message;
      } finally {
        clearTimeout(timeout);
        button.disabled = false;
        form.removeAttribute('aria-busy');
        status.focus({preventScroll: true});
      }
    });
  }
})();

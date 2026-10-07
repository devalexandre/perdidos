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
})();

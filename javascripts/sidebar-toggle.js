(function () {
  // outerWidth >= availWidth when Windows maximizes (invisible resize border extends off-screen)
  function isMaximized() {
    return window.outerWidth >= screen.availWidth;
  }

  function injectToc(nav, toc) {
    if (nav.querySelector('#_toc-inject')) return;
    var tocInner = toc.querySelector('.md-sidebar__inner') || toc.querySelector('nav');
    if (!tocInner) return;
    var div = document.createElement('div');
    div.id = '_toc-inject';
    div.style.cssText = 'margin-top:1rem;padding-top:1rem;border-top:1px solid var(--md-default-fg-color--lightest)';
    div.innerHTML = '<div style="font-size:.7rem;font-weight:700;padding:0 .6rem;margin-bottom:.5rem;text-transform:uppercase;letter-spacing:.1em;color:var(--md-default-fg-color--light)">On this page</div>' + tocInner.innerHTML;
    var wrap = nav.querySelector('.md-sidebar__scrollwrap');
    if (wrap) wrap.appendChild(div);
  }

  function removeInjectedToc(nav) {
    if (!nav) return;
    var el = nav.querySelector('#_toc-inject');
    if (el) el.remove();
  }

  function applyState() {
    var max = isMaximized();
    var drawer = document.getElementById('__drawer');
    var drawerOpen = !max && !!drawer && drawer.checked;
    var nav = document.querySelector('.md-sidebar--primary');
    var toc = document.querySelector('.md-sidebar--secondary');

    document.body.classList.toggle('is-maximized', max);

    if (max) {
      if (nav) nav.style.setProperty('display', '', 'important');
      if (toc) toc.style.setProperty('display', '', 'important');
      removeInjectedToc(nav);
    } else if (drawerOpen) {
      // Let Material show nav drawer; inject TOC into it; hide standalone TOC sidebar.
      // Must be explicit block !important to beat the CSS fallback hide rule.
      if (nav) nav.style.setProperty('display', 'block', 'important');
      if (toc) toc.style.setProperty('display', 'none', 'important');
      if (nav && toc) injectToc(nav, toc);
    } else {
      if (nav) nav.style.setProperty('display', 'none', 'important');
      if (toc) toc.style.setProperty('display', 'none', 'important');
      removeInjectedToc(nav);
    }
  }

  function setup(sidebar, storageKey, collapseChar, expandChar) {
    var btn = document.createElement('button');
    btn.className = 'sidebar-toggle';
    btn.title = 'Toggle sidebar';

    var collapsed = localStorage.getItem(storageKey) === '1';
    if (collapsed) sidebar.classList.add('is-collapsed');
    btn.textContent = collapsed ? expandChar : collapseChar;

    btn.addEventListener('click', function () {
      var nowCollapsed = sidebar.classList.toggle('is-collapsed');
      localStorage.setItem(storageKey, nowCollapsed ? '1' : '0');
      btn.textContent = nowCollapsed ? expandChar : collapseChar;
    });

    sidebar.appendChild(btn);
  }

  document.addEventListener('DOMContentLoaded', function () {
    applyState();

    var nav = document.querySelector('.md-sidebar--primary');
    var toc = document.querySelector('.md-sidebar--secondary');
    if (nav) setup(nav, 'sidebar-nav-collapsed', '««', '»»');
    if (toc) setup(toc, 'sidebar-toc-collapsed', '»»', '««');

    var drawer = document.getElementById('__drawer');
    if (drawer) drawer.addEventListener('change', applyState);
  });

  window.addEventListener('load', function () { setTimeout(applyState, 100); });
  window.addEventListener('resize', applyState);
})();

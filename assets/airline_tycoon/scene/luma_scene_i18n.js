// Locale payloads are supplied by the Flutter host so these embedded scenes
// follow the language selected in Luma's settings.
(function () {
  'use strict';

  let language = 'en';
  let strings = Object.create(null);
  let sourceStrings = Object.create(null);
  const textOrigins = new WeakMap();
  const attributeOrigins = new WeakMap();
  const knownSourceByTranslation = Object.create(null);

  function value(key) {
    return strings[key] ?? '';
  }

  function format(key, values) {
    return value(key).replace(/\{([A-Za-z][A-Za-z0-9_]*)\}/g, (_, name) =>
      String(values?.[name] ?? ''));
  }

  function translate(source) {
    return sourceStrings[source] ?? sourceStrings[knownSourceByTranslation[source]] ?? source;
  }

  function apply(root) {
    const scope = root || document;
    const walker = document.createTreeWalker(scope, NodeFilter.SHOW_TEXT);
    while (walker.nextNode()) {
      const node = walker.currentNode;
      if (node.parentElement?.closest('script, style, textarea, input, [contenteditable="true"], [data-luma-user-content]')) continue;
      if (!node.nodeValue || !node.nodeValue.trim()) continue;
      const leading = node.nodeValue.match(/^\s*/)[0];
      const trailing = node.nodeValue.match(/\s*$/)[0];
      const text = node.nodeValue.slice(leading.length, node.nodeValue.length - trailing.length || undefined);
      let origin = textOrigins.get(node);
      if (!origin) origin = {source: knownSourceByTranslation[text] || text, rendered: null};
      else if (text !== origin.rendered) origin.source = knownSourceByTranslation[text] || text;
      const translatedText = sourceStrings[origin.source];
      const translated = translatedText === undefined ? text : translatedText;
      const output = `${leading}${translated}${trailing}`;
      origin.rendered = translated;
      textOrigins.set(node, origin);
      if (node.nodeValue !== output) node.nodeValue = output;
    }
    for (const node of scope.querySelectorAll('[data-luma-text]')) {
      const translated = value(node.dataset.lumaText);
      if (node.textContent !== translated) node.textContent = translated;
    }
    for (const node of scope.querySelectorAll('[data-luma-title]')) {
      const translated = value(node.dataset.lumaTitle);
      if (node.title !== translated) node.title = translated;
    }
    for (const node of scope.querySelectorAll('[data-luma-placeholder]')) {
      const translated = value(node.dataset.lumaPlaceholder);
      if (node.placeholder !== translated) node.placeholder = translated;
    }
    for (const node of scope.querySelectorAll('[data-luma-aria]')) {
      const translated = value(node.dataset.lumaAria);
      if (node.getAttribute('aria-label') !== translated) node.setAttribute('aria-label', translated);
    }
    for (const node of scope.querySelectorAll('[title], [placeholder], [aria-label]')) {
      if (node.closest('[data-luma-user-content]')) continue;
      for (const [attribute, dataKey] of [
        ['title', 'lumaOriginalTitle'],
        ['placeholder', 'lumaOriginalPlaceholder'],
        ['aria-label', 'lumaOriginalAria'],
      ]) {
        if (!node.hasAttribute(attribute)) continue;
        let origins = attributeOrigins.get(node);
        if (!origins) { origins = Object.create(null); attributeOrigins.set(node, origins); }
        const current = node.getAttribute(attribute);
        const origin = origins[attribute];
        const source = origin && current === origin.rendered
          ? origin.source
          : (knownSourceByTranslation[current] || current);
        if (sourceStrings[source] === undefined) {
          if (!origin) node.dataset[dataKey] = source;
          continue;
        }
        const translated = sourceStrings[source];
        origins[attribute] = {source, rendered: translated};
        node.dataset[dataKey] = source;
        if (current !== translated) node.setAttribute(attribute, translated);
      }
    }
  }

  function set(payload) {
    if (!payload || typeof payload !== 'object') return;
    language = typeof payload.language === 'string' ? payload.language : 'en';
    strings = payload.strings && typeof payload.strings === 'object'
      ? payload.strings
      : Object.create(null);
    sourceStrings = payload.sourceStrings && typeof payload.sourceStrings === 'object'
      ? payload.sourceStrings
      : Object.create(null);
    for (const [source, translated] of Object.entries(sourceStrings)) {
      knownSourceByTranslation[translated] = source;
    }
    document.documentElement.lang = language;
    document.documentElement.dataset.lumaLocale = language;
    document.documentElement.style.visibility = '';
    apply();
    window.dispatchEvent(new CustomEvent('luma-locale-changed', {
      detail: {language, strings},
    }));
  }

  window.LumaSceneI18n = {get language() { return language; }, value, format, translate, apply, set};
  if (document.documentElement.dataset.lumaHosted === 'true') {
    document.documentElement.style.visibility = 'hidden';
  }

  const observer = new MutationObserver((records) => {
    for (const record of records) {
      if (record.type === 'attributes' || record.type === 'characterData') {
        apply(record.target.parentElement || record.target);
      }
      for (const node of record.addedNodes || []) {
        if (node.nodeType === Node.ELEMENT_NODE) apply(node);
        else if (node.nodeType === Node.TEXT_NODE) {
          const parent = node.parentElement;
          if (parent) apply(parent);
        }
      }
    }
  });
  observer.observe(document.documentElement, {
    attributes: true,
    attributeFilter: ['title', 'placeholder', 'aria-label'],
    characterData: true,
    childList: true,
    subtree: true,
  });

  if (window.chrome && window.chrome.webview) {
    window.chrome.webview.addEventListener('message', (event) => {
      let message = event.data;
      if (typeof message === 'string') {
        try { message = JSON.parse(message); } catch (_) { return; }
      }
      if (message && message.type === 'luma-locale') set(message);
    });
  }
})();

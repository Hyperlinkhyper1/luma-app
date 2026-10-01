// The book review desk at the wandering trader's stall. Sitting down at it
// brings up the computer's screen: pick one of your books and send it to the
// reviewer (the model the operator picked in the admin dashboard). The
// answer comes back as a letter the next in-game day, with coins for a good
// book or tips for a better one. The app does the sending; this page draws
// the screen and files the answer with the post.
(() => {
  'use strict';
  const $ = id => document.getElementById(id);

  // A short fingerprint of a book's text, to tell whether it changed since
  // it was last reviewed.
  function hashText(s) {
    let h = 0x811c9dc5;
    for (let i = 0; i < s.length; i++) {
      h ^= s.charCodeAt(i);
      h = Math.imul(h, 0x01000193) >>> 0;
    }
    return h.toString(16).padStart(8, '0');
  }

  // `books()` lists the library as [{name, books: [{id, title, body, blank}]}];
  // `upload(book)` resolves to the reviewer's answer or throws with a message
  // fit to show.
  function create({gui, post, books, upload}) {
    let screen = null;

    function open() {
      return new Promise(resolve => {
        screen = {resolve, view: 'list', picked: null, message: ''};
        $('pc').hidden = false;
        refresh();
        setTimeout(() => $('pc-off').focus(), 30);
      });
    }

    function close() {
      if (!screen || screen.view === 'sending') return;
      const done = screen.resolve;
      screen = null;
      $('pc').hidden = true;
      done();
    }

    const minutes = s => Math.max(1, Math.ceil(s / 60));
    const line = (text, cls) => {
      const p = document.createElement('p');
      p.className = 'pc-line' + (cls ? ' ' + cls : '');
      p.textContent = text;
      return p;
    };

    function refresh() {
      if (!screen) return;
      $('pc-title').textContent = gui.t('pcTitle');
      $('pc-off').textContent = gui.t('pcLogOff');
      const body = $('pc-body');
      const send = $('pc-send');
      const waiting = post.pendingReview;
      if (screen.view === 'list' && waiting) screen.view = 'waiting';
      send.hidden = screen.view !== 'list';
      if (screen.view === 'sending') {
        body.replaceChildren(line(gui.t('pcSending'), 'big blink'));
      } else if (screen.view === 'sent') {
        const wait = post.pendingReview?.wait ?? 0;
        body.replaceChildren(line(gui.t('pcSent'), 'big ok'), line(gui.t('pcSentBody', minutes(wait))));
      } else if (screen.view === 'waiting') {
        const r = post.pendingReview;
        if (!r) { screen.view = 'list'; refresh(); return; }
        body.replaceChildren(line(gui.t('pcWaiting', r.letter.title || gui.t('untitled')), 'big'), line(gui.t('pcWaitingBody', minutes(r.wait))));
      } else {
        renderList(body, send);
      }
    }

    function renderList(body, send) {
      const rows = [line(gui.t('pcIntro'), 'dim')];
      if (screen.message) rows.push(line(screen.message, 'err'));
      const subjects = books().filter(s => s.books.some(b => !b.blank));
      if (!subjects.length) rows.push(line(gui.t('pcNoBooks'), 'big'));
      else rows.push(line(gui.t('pcPick')));
      const list = document.createElement('div');
      list.className = 'pc-list';
      list.setAttribute('role', 'listbox');
      for (const s of subjects) {
        list.append(line(s.name, 'pc-subject'));
        for (const b of s.books) {
          if (b.blank) continue;
          const row = document.createElement('button');
          row.type = 'button';
          row.className = 'pc-book' + (screen.picked === b.id ? ' on' : '');
          row.setAttribute('role', 'option');
          row.setAttribute('aria-selected', String(screen.picked === b.id));
          row.textContent = b.title || gui.t('untitled');
          if (post.wasReviewed(String(b.id), hashText(b.body))) row.classList.add('done');
          row.onclick = () => { screen.picked = b.id; screen.message = ''; refresh(); };
          list.append(row);
        }
      }
      if (subjects.length) rows.push(list);
      body.replaceChildren(...rows);
      const book = pickedBook();
      const same = book && post.wasReviewed(String(book.id), hashText(book.body));
      if (same) body.append(line(gui.t('pcSame'), 'err'));
      send.textContent = gui.t('pcSend');
      send.disabled = !book || same;
    }

    function pickedBook() {
      if (!screen || screen.picked == null) return null;
      for (const s of books()) for (const b of s.books) if (b.id === screen.picked && !b.blank) return b;
      return null;
    }

    async function sendPicked() {
      const book = pickedBook();
      if (!screen || !book || post.pendingReview) return;
      const hash = hashText(book.body);
      if (post.wasReviewed(String(book.id), hash)) return;
      screen.view = 'sending';
      refresh();
      try {
        const result = await upload(book);
        if (!screen) return;
        post.queueReview(String(book.id), hash, book.title || gui.t('untitled'), result);
        screen.view = 'sent';
      } catch (e) {
        if (!screen) return;
        screen.view = 'list';
        screen.message = `${gui.t('pcFailed')}: ${e?.message || e}`;
      }
      refresh();
      $('pc-off').focus();
    }

    $('pc-send').onclick = sendPicked;
    $('pc-off').onclick = close;
    $('pc').addEventListener('keydown', e => {
      if (e.key !== 'Escape') return;
      e.stopPropagation();
      close();
    });

    const desk = {open, close, refresh, hashText};
    Object.defineProperties(desk, {isOpen: {get: () => !!screen}});
    return desk;
  }

  window.LibraryDesk = {create, hashText};
})();

/**
 * window.Storage — a thin, defensive localStorage wrapper for Kaley's Puzzle.
 *
 * Every read tolerates missing or corrupt JSON and every write is wrapped in
 * try/catch, so a child poking at private-mode browsers or a full disk can
 * never crash the game. Nothing here touches the DOM or the puzzle engine.
 *
 * Namespaced keys:
 *   kaley.settings      → { muted, showTimer }
 *   kaley.tutorialSeen  → "1"
 *   kaley.collection    → string[] of animal keys
 *   kaley.resume        → ResumeState (see app.js / design.md)
 */
(function () {
  'use strict';

  var KEYS = {
    settings: 'kaley.settings',
    tutorial: 'kaley.tutorialSeen',
    collection: 'kaley.collection',
    resume: 'kaley.resume',
  };

  var DEFAULT_SETTINGS = { muted: false, showTimer: false };

  // ----- low-level helpers -------------------------------------------------

  function safeGet(key) {
    try {
      return window.localStorage.getItem(key);
    } catch (e) {
      return null;
    }
  }

  function safeSet(key, value) {
    try {
      window.localStorage.setItem(key, value);
      return true;
    } catch (e) {
      return false;
    }
  }

  function safeRemove(key) {
    try {
      window.localStorage.removeItem(key);
    } catch (e) {
      /* ignore */
    }
  }

  function readJSON(key, fallback) {
    var raw = safeGet(key);
    if (raw == null) return fallback;
    try {
      var parsed = JSON.parse(raw);
      return parsed == null ? fallback : parsed;
    } catch (e) {
      return fallback;
    }
  }

  function writeJSON(key, value) {
    try {
      return safeSet(key, JSON.stringify(value));
    } catch (e) {
      return false;
    }
  }

  // ----- settings ----------------------------------------------------------

  function getSettings() {
    var stored = readJSON(KEYS.settings, null);
    if (!stored || typeof stored !== 'object') {
      return { muted: DEFAULT_SETTINGS.muted, showTimer: DEFAULT_SETTINGS.showTimer };
    }
    return {
      muted: typeof stored.muted === 'boolean' ? stored.muted : DEFAULT_SETTINGS.muted,
      showTimer:
        typeof stored.showTimer === 'boolean' ? stored.showTimer : DEFAULT_SETTINGS.showTimer,
    };
  }

  function setSettings(partial) {
    var next = getSettings();
    if (partial && typeof partial === 'object') {
      if (typeof partial.muted === 'boolean') next.muted = partial.muted;
      if (typeof partial.showTimer === 'boolean') next.showTimer = partial.showTimer;
    }
    writeJSON(KEYS.settings, next);
    return next;
  }

  // ----- tutorial ----------------------------------------------------------

  function hasSeenTutorial() {
    return safeGet(KEYS.tutorial) === '1';
  }

  function markTutorialSeen() {
    safeSet(KEYS.tutorial, '1');
  }

  // ----- collection --------------------------------------------------------

  function getCollection() {
    var arr = readJSON(KEYS.collection, []);
    if (!Array.isArray(arr)) return [];
    // keep only unique strings
    var seen = {};
    var out = [];
    for (var i = 0; i < arr.length; i++) {
      var k = arr[i];
      if (typeof k === 'string' && !seen[k]) {
        seen[k] = true;
        out.push(k);
      }
    }
    return out;
  }

  function addToCollection(animalKey) {
    if (typeof animalKey !== 'string' || !animalKey) return getCollection();
    var current = getCollection();
    if (current.indexOf(animalKey) === -1) {
      current.push(animalKey);
      writeJSON(KEYS.collection, current);
    }
    return current;
  }

  // ----- resume ------------------------------------------------------------

  function saveResume(state) {
    if (!state || typeof state !== 'object') return;
    writeJSON(KEYS.resume, state);
  }

  function loadResume() {
    return readJSON(KEYS.resume, null);
  }

  function clearResume() {
    safeRemove(KEYS.resume);
  }

  window.Storage = {
    getSettings: getSettings,
    setSettings: setSettings,
    hasSeenTutorial: hasSeenTutorial,
    markTutorialSeen: markTutorialSeen,
    getCollection: getCollection,
    addToCollection: addToCollection,
    saveResume: saveResume,
    loadResume: loadResume,
    clearResume: clearResume,
  };
})();

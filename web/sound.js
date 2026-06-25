/**
 * window.Sound — synthesized sound effects + haptics for Kaley's Puzzle.
 *
 * All effects are generated with the Web Audio API (oscillators + gain
 * envelopes), so there are NO audio asset files to ship or load. Sounds are
 * deliberately short, soft and friendly for young children.
 *
 * Browsers require a user gesture before audio can start, so `init()` is
 * called lazily on the first tap/pointer-down. Every `play()` is a no-op
 * while muted or before `init()` succeeds, and any failure is swallowed so
 * audio problems can never break gameplay.
 */
(function () {
  'use strict';

  var ctx = null;
  var masterGain = null;
  var muted = false;
  var initialized = false;

  function readInitialMute() {
    try {
      if (window.Storage && typeof window.Storage.getSettings === 'function') {
        muted = !!window.Storage.getSettings().muted;
      }
    } catch (e) {
      muted = false;
    }
  }

  function init() {
    if (initialized && ctx) {
      // Resume if the context was suspended (e.g. autoplay policy).
      try {
        if (ctx.state === 'suspended') ctx.resume();
      } catch (e) {
        /* ignore */
      }
      return;
    }
    try {
      var AudioCtx = window.AudioContext || window.webkitAudioContext;
      if (!AudioCtx) return;
      ctx = new AudioCtx();
      masterGain = ctx.createGain();
      masterGain.gain.value = 0.25; // gentle overall volume
      masterGain.connect(ctx.destination);
      readInitialMute();
      initialized = true;
    } catch (e) {
      ctx = null;
      masterGain = null;
      initialized = false;
    }
  }

  function isMuted() {
    return muted;
  }

  function setMuted(value) {
    muted = !!value;
    try {
      if (window.Storage && typeof window.Storage.setSettings === 'function') {
        window.Storage.setSettings({ muted: muted });
      }
    } catch (e) {
      /* ignore */
    }
  }

  /**
   * Play a single tone with a quick attack and exponential decay.
   */
  function tone(opts) {
    if (!ctx || !masterGain) return;
    var now = ctx.currentTime;
    var start = now + (opts.delay || 0);
    var osc = ctx.createOscillator();
    var gain = ctx.createGain();
    osc.type = opts.type || 'sine';
    osc.frequency.setValueAtTime(opts.freq, start);
    if (opts.toFreq) {
      osc.frequency.exponentialRampToValueAtTime(opts.toFreq, start + opts.dur);
    }
    var peak = opts.gain == null ? 0.6 : opts.gain;
    gain.gain.setValueAtTime(0.0001, start);
    gain.gain.exponentialRampToValueAtTime(peak, start + 0.012);
    gain.gain.exponentialRampToValueAtTime(0.0001, start + opts.dur);
    osc.connect(gain);
    gain.connect(masterGain);
    osc.start(start);
    osc.stop(start + opts.dur + 0.02);
  }

  function playSnap() {
    // soft single "tock"
    tone({ type: 'sine', freq: 520, toFreq: 660, dur: 0.12, gain: 0.5 });
  }

  function playMerge() {
    // happy two-note rise
    tone({ type: 'triangle', freq: 523.25, dur: 0.12, gain: 0.5 });
    tone({ type: 'triangle', freq: 659.25, dur: 0.16, gain: 0.5, delay: 0.09 });
  }

  function playMilestone() {
    // bright three-note sparkle
    tone({ type: 'triangle', freq: 587.33, dur: 0.14, gain: 0.5 });
    tone({ type: 'triangle', freq: 783.99, dur: 0.14, gain: 0.5, delay: 0.1 });
    tone({ type: 'triangle', freq: 1046.5, dur: 0.2, gain: 0.5, delay: 0.2 });
  }

  function playWin() {
    // little victory fanfare (C-E-G-C)
    var seq = [523.25, 659.25, 783.99, 1046.5];
    for (var i = 0; i < seq.length; i++) {
      tone({ type: 'triangle', freq: seq[i], dur: 0.22, gain: 0.55, delay: i * 0.14 });
    }
  }

  function play(name) {
    if (muted || !initialized || !ctx) return;
    try {
      if (ctx.state === 'suspended') ctx.resume();
      switch (name) {
        case 'snap':
          playSnap();
          break;
        case 'merge':
          playMerge();
          break;
        case 'milestone':
          playMilestone();
          break;
        case 'win':
          playWin();
          break;
        default:
          break;
      }
    } catch (e) {
      /* ignore audio failures */
    }
  }

  function vibrate(ms) {
    if (muted) return;
    try {
      if (navigator && typeof navigator.vibrate === 'function') {
        navigator.vibrate(ms);
      }
    } catch (e) {
      /* ignore */
    }
  }

  // Pick up the persisted mute preference up front (safe even before init).
  readInitialMute();

  window.Sound = {
    init: init,
    isMuted: isMuted,
    setMuted: setMuted,
    play: play,
    vibrate: vibrate,
  };
})();

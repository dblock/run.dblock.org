// Running letters: after the reader has been idle for a while, every letter on
// screen crouches at the start line and sprints off the right edge, rightmost
// letters first and fastest, so the field scatters. Any click, mouse move, key
// press or touch brings them home: if every letter has run off the screen they
// all come back in from the far left, otherwise they all turn around and run
// back, slowing down to a stop at their original spot. Scrolling or resizing puts
// them back instantly. Letters bounce like runners the whole way.
//
// On activity pages letters run at a screen speed proportional to the run's
// average pace, so faster runs visibly race faster.
//
// The original text is never moved: visible text nodes are wrapped in hidden
// spans (which does not change layout) and replaced by a fixed overlay of
// per-letter clones that are animated with transforms.
(function () {
  'use strict';

  var script = document.currentScript;
  var params = new URLSearchParams(window.location.search);
  var idleSeconds = parseFloat(params.get('idle') || (script && script.dataset.idleSeconds) || '30');
  var paceSeconds = parseFloat(params.get('pace') || (script && script.dataset.paceSeconds) || '600');
  var maxLetters = 3000;
  var referencePace = 600; // 10:00/mi crosses the screen in crossSeconds
  var crossSeconds = 5;
  var skipTags = { SCRIPT: 1, STYLE: 1, NOSCRIPT: 1, TEXTAREA: 1, INPUT: 1, SELECT: 1, OPTION: 1, SVG: 1, CANVAS: 1, IFRAME: 1 };

  if (!(idleSeconds > 0)) return;
  if (!(paceSeconds > 0)) paceSeconds = referencePace;
  paceSeconds = Math.min(1200, Math.max(240, paceSeconds));
  if (window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches) return;

  var state = 'idle'; // idle | running | returning
  var idleTimer = null;
  var overlay = null;
  var letters = [];
  var hidden = [];
  var frame = null;

  function resetIdle() {
    clearTimeout(idleTimer);
    idleTimer = setTimeout(start, idleSeconds * 1000);
  }

  // Mobile Safari's innerHeight stops at its toolbars, but the page stays visible
  // under them, so letters there are on screen too. Off-screen letters below the
  // window on other browsers are harmless, as they're out of sight either way.
  function screenHeight() {
    return Math.max(window.innerHeight, (window.screen && window.screen.height) || 0);
  }

  function inViewport(rect) {
    return rect.width > 0 && rect.height > 0 && rect.bottom > 0 && rect.right > 0 &&
      rect.top < screenHeight() && rect.left < window.innerWidth;
  }

  // The area an element's content can be seen in: the viewport, narrowed by
  // every ancestor that clips its overflow, such as the collapsed mobile menu,
  // whose links still have on-screen rects while hidden.
  function clipRect(el) {
    var clip = { left: 0, top: 0, right: window.innerWidth, bottom: screenHeight() };
    for (; el && el !== document.body; el = el.parentElement) {
      var style = window.getComputedStyle(el);
      if (style.overflowX === 'visible' && style.overflowY === 'visible') continue;
      var r = el.getBoundingClientRect();
      if (style.overflowX !== 'visible') { clip.left = Math.max(clip.left, r.left); clip.right = Math.min(clip.right, r.right); }
      if (style.overflowY !== 'visible') { clip.top = Math.max(clip.top, r.top); clip.bottom = Math.min(clip.bottom, r.bottom); }
    }
    return clip;
  }

  function insideClip(rect, clip) {
    var x = rect.left + rect.width / 2;
    var y = rect.top + rect.height / 2;
    return x > clip.left && x < clip.right && y > clip.top && y < clip.bottom;
  }

  function visibleTextNodes() {
    var nodes = [];
    var walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT, {
      acceptNode: function (node) {
        if (!node.nodeValue.trim()) return NodeFilter.FILTER_REJECT;
        for (var el = node.parentElement; el && el !== document.body; el = el.parentElement) {
          if (skipTags[el.tagName.toUpperCase()] || el.isContentEditable) return NodeFilter.FILTER_REJECT;
        }
        var range = document.createRange();
        range.selectNodeContents(node);
        var rect = range.getBoundingClientRect();
        var clip = clipRect(node.parentElement);
        var shown = inViewport(rect) && rect.left < clip.right && rect.right > clip.left &&
          rect.top < clip.bottom && rect.bottom > clip.top;
        return shown ? NodeFilter.FILTER_ACCEPT : NodeFilter.FILTER_REJECT;
      }
    });
    while (walker.nextNode()) nodes.push(walker.currentNode);
    return nodes;
  }

  function start() {
    if (state !== 'idle') return;
    var nodes = visibleTextNodes();
    if (!nodes.length) return;

    overlay = document.createElement('div');
    overlay.setAttribute('aria-hidden', 'true');
    overlay.style.cssText = 'position:fixed;left:0;top:0;right:0;height:' + screenHeight() + 'px;pointer-events:none;z-index:2147483647;overflow:hidden;';
    letters = [];

    var baseSpeed = window.innerWidth / crossSeconds * (referencePace / paceSeconds);
    var range = document.createRange();
    nodes.forEach(function (node) {
      if (letters.length >= maxLetters) return;
      var style = window.getComputedStyle(node.parentElement);
      if (style.visibility === 'hidden' || parseFloat(style.opacity) === 0) return;
      var text = node.nodeValue;
      var clip = clipRect(node.parentElement);
      var found = [];
      for (var i = 0; i < text.length && letters.length + found.length < maxLetters; i++) {
        if (/\s/.test(text[i])) continue;
        range.setStart(node, i);
        range.setEnd(node, i + 1);
        var rect = range.getClientRects()[0];
        if (!rect || !inViewport(rect) || !insideClip(rect, clip)) continue;
        found.push({ ch: text[i], rect: rect });
      }
      if (!found.length) return;

      found.forEach(function (f) {
        var el = document.createElement('span');
        el.textContent = f.ch;
        // Site styles transition every span, which would smear the animation and
        // make letters coming back fly across the screen from the right.
        el.style.cssText = 'position:absolute;white-space:pre;will-change:transform;transform-origin:50% 100%;transition:none;' +
          'left:' + f.rect.left + 'px;top:' + f.rect.top + 'px;' +
          'font:' + style.font + ';color:' + style.color + ';font-feature-settings:' + style.fontFeatureSettings + ';' +
          // After the font shorthand, which resets line-height.
          'line-height:' + f.rect.height + 'px;text-transform:' + style.textTransform + ';';
        overlay.appendChild(el);
        // Letters further right start sooner and run faster, so the field
        // scatters from right to left like a race strung out behind its leaders.
        var ahead = Math.min(1, Math.max(0, (f.rect.left + f.rect.width) / window.innerWidth));
        letters.push({
          el: el, left: f.rect.left, w: f.rect.width, h: f.rect.height,
          x: 0, v: 0,
          top: baseSpeed * (0.6 + ahead * 0.8) * (0.9 + Math.random() * 0.2),
          reaction: 0.15 + (1 - ahead) * 0.6 + Math.random() * 0.1, // crouch, then react to the gun
          cadence: Math.PI * (2.6 + Math.random() * 0.6), // steps per second
          phase: Math.random() * Math.PI,
          back: null, gone: false
        });
      });

      var wrapper = document.createElement('span');
      wrapper.style.visibility = 'hidden';
      node.parentNode.insertBefore(wrapper, node);
      wrapper.appendChild(node);
      hidden.push(wrapper);
    });

    if (!letters.length) { cleanup(); return; }
    document.body.appendChild(overlay);
    state = 'running';
    animate();
  }

  // How far past the viewport edge a tilted, bouncing letter is out of sight.
  function margin(l) {
    return l.w + l.h;
  }

  var crouchSeconds = 0.15;

  function ease(t) {
    return t * t * (3 - 2 * t);
  }

  function render(l, crouch, gait, dir) {
    var effort = Math.min(1, l.v / l.top);
    // Runners bounce at a steady cadence the whole way, landing a little squashed.
    var stride = Math.abs(Math.sin(l.phase));
    var bob = -stride * l.h * 0.5 * gait;
    var land = (1 - stride) * 0.12 * gait;
    // Crouching dips and leans forward without changing the letter's size.
    var dip = crouch * l.h * 0.12;
    var lean = dir * (4 + 8 * effort) * gait + crouch * 5;
    var squash = 1 - land;
    l.el.style.transform = 'translate(' + l.x + 'px,' + (bob + dip) + 'px) rotate(' + lean + 'deg) scale(1,' + squash + ')';
  }

  function animate() {
    var last = performance.now();
    var elapsed = 0;

    function step(now) {
      var dt = Math.min(0.05, (now - last) / 1000);
      last = now;
      elapsed += dt;
      var moving = 0;

      letters.forEach(function (l) {
        var b = l.back;
        if (b) {
          if (!b.dir) { render(l, 0, 0, 1); return; }
          moving++;
          if (now < b.start) return;
          l.el.style.visibility = '';
          // Run home at full speed, braking over the last stretch.
          var remaining = Math.abs(l.x);
          var speed = remaining > b.brake ? b.speed : b.speed * Math.sqrt(remaining / b.brake);
          var move = Math.min(remaining, Math.max(speed, 20) * dt);
          l.x += b.dir * move;
          l.v = speed;
          l.phase += l.cadence * dt;
          if (Math.abs(l.x) < 0.5) {
            l.x = 0;
            l.back = { dir: 0 };
            moving--;
          }
          render(l, 0, Math.min(1, remaining / (l.h * 2)), b.dir);
          return;
        }
        // Letters off the screen keep running out of sight, so if the reader
        // comes back early they return spread out rather than in a clump.
        if (l.gone) { l.x += l.v * dt; return; }
        moving++;
        if (elapsed < l.reaction) {
          // Each letter crouches only just before it goes, so the page doesn't
          // all lean at once; letters waiting their turn stay upright.
          var wait = l.reaction - elapsed;
          if (wait < crouchSeconds) render(l, ease(1 - wait / crouchSeconds), 0, 1);
          return;
        }
        l.v = Math.min(l.top, l.v + l.top * 3 * dt);
        l.x += l.v * dt;
        l.phase += l.cadence * dt;
        // Once off the right edge a letter is gone until the reader comes back.
        if (l.left + l.x >= window.innerWidth + margin(l)) {
          l.gone = true;
          l.el.style.visibility = 'hidden';
          return;
        }
        // Rise out of the crouch into a full stride instead of jumping into it.
        var going = ease(Math.min(1, (elapsed - l.reaction) / 0.25));
        render(l, 1 - going, going, 1);
      });

      if (moving) frame = requestAnimationFrame(step);
      else {
        frame = null;
        // Start counting idle time again once every letter is back in place.
        if (state === 'returning') { cleanup(); resetIdle(); }
      }
    }

    if (frame) cancelAnimationFrame(frame);
    frame = requestAnimationFrame(step);
  }

  function returnHome(instant) {
    if (state === 'idle') return;
    if (instant) { cleanup(); return; }
    if (state === 'returning') return;
    state = 'returning';
    var now = performance.now();
    // Come back in from the far left only once every letter has left the
    // screen; until then every letter turns around and runs back.
    var allGone = letters.every(function (l) { return l.gone || l.left + l.x >= window.innerWidth; });
    letters.forEach(function (l) {
      if (allGone) {
        l.x = -(l.left + margin(l));
        l.back = { dir: 1, start: now + Math.random() * 400 };
      } else if (l.x > 0.5) {
        // Including letters already past the right edge, which come back from there.
        l.back = { dir: -1, start: now };
      } else {
        // Letters still crouching at the start line just stand up.
        l.x = 0;
        l.back = { dir: 0 };
        return;
      }
      var distance = Math.abs(l.x);
      // Don't keep the reader waiting: cross any distance in about two seconds.
      l.back.speed = Math.max(l.top, distance / 2);
      l.back.brake = Math.min(distance, Math.max(l.h * 4, window.innerWidth * 0.15));
    });
    animate();
  }

  function cleanup() {
    if (frame) cancelAnimationFrame(frame);
    frame = null;
    hidden.forEach(function (wrapper) {
      var parent = wrapper.parentNode;
      if (!parent) return;
      while (wrapper.firstChild) parent.insertBefore(wrapper.firstChild, wrapper);
      parent.removeChild(wrapper);
    });
    hidden = [];
    if (overlay && overlay.parentNode) overlay.parentNode.removeChild(overlay);
    overlay = null;
    letters = [];
    state = 'idle';
  }

  function onActivity(e) {
    // Scrolling or resizing moves the real text, so letters can't run back to stale positions.
    var instant = e.type === 'scroll' || e.type === 'resize';
    if (state !== 'idle') returnHome(instant);
    resetIdle();
  }

  ['mousemove', 'mousedown', 'keydown', 'touchstart', 'wheel', 'scroll', 'resize'].forEach(function (type) {
    window.addEventListener(type, onActivity, { passive: true });
  });
  document.addEventListener('visibilitychange', function () {
    if (document.hidden) clearTimeout(idleTimer); else resetIdle();
  });

  resetIdle();
})();

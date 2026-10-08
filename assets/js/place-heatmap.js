(function () {
  'use strict';

  var container = document.getElementById('place-heatmap');
  var status = document.getElementById('place-heatmap-status');
  if (!container || !status) {
    return;
  }

  function fail(message) {
    status.textContent = message;
    container.className += ' place-heatmap-error';
  }

  if (typeof window.L === 'undefined' || typeof window.L.heatLayer !== 'function') {
    fail('The heatmap could not be loaded. The place list remains available below.');
    return;
  }

  fetch(container.getAttribute('data-url'), { credentials: 'same-origin' })
    .then(function (response) {
      if (!response.ok) {
        throw new Error('Heatmap data request failed with status ' + response.status);
      }
      return response.json();
    })
    .then(function (data) {
      if (!data.cells || data.cells.length === 0) {
        fail('No heatmap data is available yet.');
        return;
      }

      var map = window.L.map(container, {
        scrollWheelZoom: false,
        worldCopyJump: true
      });
      window.L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {
        attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap contributors</a>',
        maxZoom: 19
      }).addTo(map);

      var denominator = Math.log(1 + data.maximum);
      var points = data.cells.map(function (cell) {
        return [cell[0], cell[1], Math.log(1 + cell[2]) / denominator];
      });
      window.L.heatLayer(points, {
        radius: 20,
        blur: 14,
        maxZoom: 12,
        minOpacity: 0.45,
        gradient: {
          0.15: '#5e00a1',
          0.4: '#d1007e',
          0.7: '#ff6b00',
          1: '#ffe600'
        }
      }).addTo(map);

      map.fitBounds(window.L.latLngBounds(points.map(function (point) {
        return [point[0], point[1]];
      })).pad(0.05));
      status.textContent = data.cells.length.toLocaleString() +
        ' cells generated from ' + data.activity_count.toLocaleString() + ' activities.';
    })
    .catch(function () {
      fail('The heatmap could not be loaded. The place list remains available below.');
    });
}());

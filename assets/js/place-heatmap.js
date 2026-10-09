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

  function fetchJson(url) {
    return fetch(url, { credentials: 'same-origin' }).then(function (response) {
      if (!response.ok) {
        throw new Error('Request failed with status ' + response.status);
      }
      return response.json();
    });
  }

  function longitudeToTileX(longitude, zoom) {
    return Math.floor(((longitude + 180) / 360) * Math.pow(2, zoom));
  }

  function latitudeToTileY(latitude, zoom) {
    var limited = Math.max(-85.05112878, Math.min(85.05112878, latitude));
    var radians = limited * Math.PI / 180;
    return Math.floor((1 - (Math.log(Math.tan(radians) + (1 / Math.cos(radians))) / Math.PI)) /
      2 * Math.pow(2, zoom));
  }

  function tileKeysForBounds(bounds, zoom, available) {
    var tiles = Math.pow(2, zoom);
    var west = longitudeToTileX(bounds.getWest(), zoom);
    var east = longitudeToTileX(bounds.getEast(), zoom);
    var north = Math.max(0, latitudeToTileY(bounds.getNorth(), zoom));
    var south = Math.min(tiles - 1, latitudeToTileY(bounds.getSouth(), zoom));
    var keys = [];

    for (var rawX = west; rawX <= east; rawX += 1) {
      var x = ((rawX % tiles) + tiles) % tiles;
      for (var y = north; y <= south; y += 1) {
        var key = x + '/' + y;
        if (available[key]) {
          keys.push(key);
        }
      }
    }
    return keys;
  }

  if (typeof window.L === 'undefined' || typeof window.L.heatLayer !== 'function') {
    fail('The heatmap could not be loaded. The place list remains available below.');
    return;
  }

  fetchJson(container.getAttribute('data-url'))
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
      var heatLayer = window.L.heatLayer(points, {
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
      });
      heatLayer.addTo(map);

      map.fitBounds(window.L.latLngBounds(points.map(function (point) {
        return [point[0], point[1]];
      })).pad(0.05));
      heatLayer._canvas.style.transition = 'opacity 180ms ease';

      var baseStatus = data.cells.length.toLocaleString() +
        ' cells generated from ' + data.activity_count.toLocaleString() + ' activities.';
      status.textContent = baseStatus + ' Zoom in for detailed routes.';

      fetchJson(container.getAttribute('data-routes-url') + '/manifest.json')
        .then(function (manifest) {
          var available = Object.create(null);
          var tileCache = Object.create(null);
          var detailedHeatLayer = null;
          var renderedSignature = null;
          var updateSequence = 0;

          manifest.tiles.forEach(function (key) {
            available[key] = true;
          });

          function detailedPoints(segments, zoom) {
            var maximumDetailZoom = map.getMaxZoom() - 5;
            var effectiveZoom = Math.min(zoom, maximumDetailZoom);
            var detailLevel = Math.max(0, effectiveZoom - manifest.detail_zoom);
            var samples = Math.pow(2, detailLevel);
            var maximum = Math.log(1 + manifest.maximum);
            var points = [];

            segments.forEach(function (segment) {
              var intensity = Math.log(1 + segment[4]) / maximum / samples / 4;
              for (var step = 1; step <= samples; step += 1) {
                var fraction = step / (samples + 1);
                points.push([
                  segment[0] + ((segment[2] - segment[0]) * fraction),
                  segment[1] + ((segment[3] - segment[1]) * fraction),
                  intensity
                ]);
              }
            });
            return {
              points: points,
              radius: 6 * Math.pow(2, zoom - effectiveZoom),
              samples: samples
            };
          }

          function loadTile(key) {
            if (tileCache[key]) {
              return tileCache[key].promise;
            }

            var entry = {};
            entry.promise = fetchJson(container.getAttribute('data-routes-url') + '/' +
              manifest.tile_zoom + '/' + key + '.json')
              .then(function (tileData) {
                entry.segments = tileData.segments;
                return entry;
              }).catch(function (error) {
                delete tileCache[key];
                throw error;
              });
            tileCache[key] = entry;
            return entry.promise;
          }

          function removeDetailedHeatmap() {
            if (detailedHeatLayer && map.hasLayer(detailedHeatLayer)) {
              map.removeLayer(detailedHeatLayer);
            }
            detailedHeatLayer = null;
            renderedSignature = null;
            heatLayer._canvas.style.opacity = '1';
          }

          function uniqueSegments(entries) {
            var segmentsByKey = Object.create(null);
            entries.forEach(function (entry) {
              entry.segments.forEach(function (segment) {
                var first = segment[0] + ',' + segment[1];
                var second = segment[2] + ',' + segment[3];
                var key = first < second ? first + '|' + second : second + '|' + first;
                if (!segmentsByKey[key] || segmentsByKey[key][4] < segment[4]) {
                  segmentsByKey[key] = segment;
                }
              });
            });
            return Object.keys(segmentsByKey).sort().map(function (key) {
              return segmentsByKey[key];
            });
          }

          function showDetailedHeatmap(entries, signature) {
            var segments = uniqueSegments(entries);
            var detailed = detailedPoints(segments, map.getZoom());
            removeDetailedHeatmap();
            heatLayer._canvas.style.opacity = '0.15';
            detailedHeatLayer = window.L.heatLayer(detailed.points, {
              radius: detailed.radius,
              blur: Math.max(4, Math.round(detailed.radius * 2 / 3)),
              maxZoom: manifest.detail_zoom,
              minOpacity: 0.25,
              max: 1,
              gradient: {
                0.15: '#5e00a1',
                0.4: '#d1007e',
                0.7: '#ff6b00',
                1: '#ffe600'
              }
            });
            detailedHeatLayer.addTo(map);
            renderedSignature = signature;
            return {
              pointCount: detailed.points.length,
              sampleCount: detailed.samples
            };
          }

          function updateDetailedRoutes() {
            updateSequence += 1;
            var sequence = updateSequence;
            if (map.getZoom() < manifest.detail_zoom) {
              removeDetailedHeatmap();
              status.textContent = baseStatus + ' Zoom in for detailed routes.';
              return;
            }

            var keys = tileKeysForBounds(map.getBounds(), manifest.tile_zoom, available);
            if (keys.length === 0) {
              removeDetailedHeatmap();
              status.textContent = baseStatus + ' No repeated routes are available in this view.';
              return;
            }

            var signature = map.getZoom() + ':' + keys.join(',');
            if (detailedHeatLayer && renderedSignature === signature) {
              return;
            }

            status.textContent = baseStatus + ' Loading detailed routes…';
            Promise.all(keys.map(loadTile)).then(function (entries) {
              if (sequence !== updateSequence || map.getZoom() < manifest.detail_zoom) {
                return;
              }

              var rendered = showDetailedHeatmap(entries, signature);
              status.textContent = baseStatus + ' Showing ' +
                rendered.pointCount.toLocaleString() + ' detailed heat points at ' +
                rendered.sampleCount.toLocaleString() + ' per route segment.';
            }).catch(function () {
              if (sequence === updateSequence) {
                removeDetailedHeatmap();
                status.textContent = baseStatus + ' Detailed routes could not be loaded.';
              }
            });
          }

          map.on('zoomend moveend', updateDetailedRoutes);
          updateDetailedRoutes();
        })
        .catch(function () {
          status.textContent = baseStatus + ' Detailed routes are unavailable.';
        });
    })
    .catch(function () {
      fail('The heatmap could not be loaded. The place list remains available below.');
    });
}());

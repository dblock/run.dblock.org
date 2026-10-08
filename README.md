[![cron](https://github.com/dblock/run.dblock.org/actions/workflows/strava.yml/badge.svg?branch=gh-pages)](https://github.com/dblock/run.dblock.org/actions/workflows/strava.yml)

This is my personal running blog, see it at [run.dblock.org](http://run.dblock.org).

It synchronizes runs from Strava to Github Pages. See [Rakefile](Rakefile) and [CRON](CRON.md) for details.

## Places

Places are configured under `places` in [`_data/places.yml`](_data/places.yml). Each canonical entry stores its generated `count`, optional `aliases` and OpenStreetMap `osm` identity, and `bounds`. Bounds contain `[latitude, longitude]` points: two opposite corners define a rectangle, while three or more vertices define a polygon. An array of polygons supports disconnected areas. Places may overlap, and a run receives every matching `p/<slug>` tag when its sampled route intersects those bounds. Routes are sampled at the start, every mile and the finish. Places without matching activities are removed. Identical boundaries are merged, and alternate names are retained as aliases. Active entries are written in descending run-count order.

Set `enabled: false` on a slug in `_data/places.yml` to suppress an unwanted place without losing the decision. Disabled places receive no tags or generated pages and are ignored by future discovery.

Run `rake places` to update place tags in existing posts and regenerate tag pages.

Run `rake places:discover` to add missing city and town boundaries from cached Strava segment location names via OpenStreetMap Nominatim, then update the posts. Places require at least one matching activity. It also adds an overlapping country boundary when more than one qualifying city or town exists in that country; countries represented by exactly one city are omitted. Discovery sends place names such as `Brooklyn, New York, United States`, never route coordinates. Incremental discovery derives candidates from activity files added or modified relative to Git `HEAD`, while cumulative run counts come from the full local cache. The Strava CI update runs discovery after fetching activities. `FULL=1` intentionally scans all historical candidates; `PLACE` searches the full cache for one slug, for example `PLACE=brooklyn rake places:discover`.

Run `rake places:heatmap` to regenerate the route-density data shown on the Places page. Routes are sampled every quarter mile and aggregated by unique activity into 500-meter cells. Cells with fewer than three activities are omitted; the generated JSON contains no activity IDs or raw route polylines.

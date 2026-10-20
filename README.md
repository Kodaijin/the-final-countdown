# The Final Countdown

A single-page countdown to a deadline you set, showing days, hours, minutes, seconds and
hundredths of a second, over a choice of five animated backgrounds. The last ten seconds take
over the screen, zero gets fireworks, and then a live tracker follows a flight you name: map,
altitude, speed, distance to go, an altitude chart and a second countdown to the landing. No build step — one static HTML
file served by nginx in a container, which also relays the public flight data.

```
site/index.html      the entire app - markup, CSS and JS in one file
site/config.js       deadline settings for serving site/ without Docker
site/airports.json   airport codes -> coordinates, for COUNTDOWN_ROUTE
docker/              nginx config (+ flight-data relay) and the entrypoint scripts
tools/               build-airports.py, which regenerates site/airports.json
.env.example         template for the COUNTDOWN_* variables compose reads
Dockerfile           nginx:alpine, copies site/ into the image
docker-compose.yml   one service, port 8080:80
```

## Run it

There is no built-in deadline — set one first, or nothing will start:

```sh
cp .env.example .env
$EDITOR .env          # set COUNTDOWN_TARGET
docker compose up -d --build
```

Then open <http://localhost:8080>.

Without compose, pass the deadline on the command line:

```sh
docker build -t final-countdown .
docker run -d -p 8080:80 --name final-countdown \
  -e COUNTDOWN_TARGET=2026-10-29T18:00:00 \
  -e COUNTDOWN_TZ=America/Los_Angeles \
  final-countdown
```

Stop it with `docker compose down` (or `docker rm -f final-countdown`).

To serve on the standard web port instead, change the mapping to `80:80` in
`docker-compose.yml`, or `-p 80:80` on the `docker run`.

## Changing the deadline

`COUNTDOWN_TARGET` in `.env` is the single source of truth. Edit it and rebuild:

```sh
docker compose up -d --build
```

```sh
COUNTDOWN_TARGET=2026-10-29T18:00:00   # required - when it ends
COUNTDOWN_TZ=America/Los_Angeles       # the zone that time is written in
COUNTDOWN_LABEL=                       # caption under the clock; blank = generated
COUNTDOWN_FLIGHT=                      # flight(s) to track after zero, e.g. AS 414, AS 488
COUNTDOWN_ROUTE=                       # their route, e.g. PIT-SEA-PDX (optional, recommended)
COUNTDOWN_BG=                          # default background; blank = synthwave (see Backgrounds)
```

`COUNTDOWN_TARGET` is read as wall-clock time in `COUNTDOWN_TZ`, so you write the time you
mean and daylight saving is worked out for you — the same `18:00` is UTC-7 on Oct 29 and
UTC-8 two weeks later. Leave `COUNTDOWN_TZ` blank to have the time read in each viewer's
own timezone instead. You can also give an absolute instant (`2026-10-30T01:00:00Z` or
`2026-10-29T18:00:00-07:00`), in which case the zone only affects how the caption reads.
Whatever the input, everyone counts down to the same moment.

The deadline is written into the page at container start by
`docker/30-countdown-config.sh`, so an `.env` edit needs a restart rather than a new image
— but pass `--build` regardless. Compose only
builds when the tagged image is *missing*, so a plain `docker compose up -d`
keeps serving whatever `final-countdown` image is already on the machine — after a `git
pull` that is the old app, silently, with none of your changes in it. `--build` is nearly
free when nothing changed (every layer is cached) and is the only way to be sure the
container matches the checkout.

Serving `site/` directly with no container? Fill in `site/config.js` by hand; it holds the
same settings and ships blank.

### Behind Cloudflare or any other CDN

The entrypoint writes the deadline *into* `index.html` rather than leaving it in a file the
page fetches. That matters in front of a cache: Cloudflare caches `.js` by default and does
not cache HTML, so a separate `config.js` can be served from the edge long after the origin
changed — a fresh page reading a months-old deadline. Inlined, there is one document to get
right, and the inline block also overrides `config.js` if a stale copy does arrive.

nginx sends `Cache-Control: no-store` for the page and `config.js`, which is enough to keep
Cloudflare from caching either going forward. A copy cached *before* that header existed
stays until evicted, so purge the cache once after deploying this
(Cloudflare dashboard → Caching → Configuration → Purge Everything).

To tell an edge-cached response from an origin one, compare them directly on the server:

```sh
curl -s http://localhost:8080/ | grep "target: '"      # what the origin serves
curl -s https://your-domain/ | grep "target: '"        # what the world sees
curl -sI https://your-domain/ | grep -i "cf-cache-status\|cache-control\|age"
```

### Nothing is hardcoded, and nothing is guessed

There is no fallback date anywhere. If the deadline is missing or unreadable you get told,
at whichever layer notices first:

| What is wrong | What happens |
| --- | --- |
| `COUNTDOWN_TARGET` empty or unset | `docker compose up` fails immediately and names the variable |
| Same, via `docker run` without `-e` | The container exits 1; `docker logs` shows how to fix it |
| Config missing entirely (no Docker, blank `config.js`) | The page replaces the digits with **NO DEADLINE SET** and the fix |
| A stale `config.js` from a CDN edge | Ignored - the deadline inlined in the page wins |
| Target that does not parse | The page shows the value it could not read and the expected format |
| `COUNTDOWN_TZ` not an IANA zone | The page names the bad zone |
| `COUNTDOWN_FLIGHT` / `COUNTDOWN_ROUTE` with stray characters | The container exits 1 and says which one |
| `COUNTDOWN_BG` not one of the five backgrounds | The container exits 1 and lists them |
| `COUNTDOWN_ROUTE` with an unknown airport code | The tracker names the code it could not find |

One consequence of the compose-level check: while `COUNTDOWN_TARGET` is unset, *every*
`docker compose` subcommand refuses to run, `down` and `ps` included. Set the variable, or
use `docker rm -f final-countdown` to tear down.

### Per-visit overrides on the URL

```
http://localhost:8080/?t=2026-12-25T00:00:00&tz=America/New_York
http://localhost:8080/?t=2027-01-01T00:00:00Z&label=Liftoff
```

`?t=` wins over the environment and stands alone: it does not inherit `COUNTDOWN_TZ` or
`COUNTDOWN_LABEL`, so add `?tz=` and `?label=` if you want them.

`?bg=globe` (or any background name) opens on that background, whatever the default.

`?flight=` and `?route=` do the same for the tracker. The flight carries over a `?t=`
(it is not tied to the deadline), so a past `?t=` is the quick way to try the tracker on a
plane that is in the air right now:

```
http://localhost:8080/?t=2020-01-01T00:00Z&flight=UA1947
http://localhost:8080/?t=2020-01-01T00:00Z&flight=OZ203&route=LAX-ICN
```

## After zero: live flight tracking

Set `COUNTDOWN_FLIGHT` and the clock hands over to a flight tracker when it reaches zero —
after four seconds of TIME'S UP if you watched it happen, straight away if you open the
page later. Before zero, a line under the caption says which flight will be tracked.

```sh
COUNTDOWN_FLIGHT=UA 1        # flight number, ADS-B callsign (UAL1) or tail number (N81110)
COUNTDOWN_ROUTE=SFO-SIN      # two IATA airport codes; optional but recommended
```

For a connection, list the flights in order and give the route one airport per stop:

```sh
COUNTDOWN_FLIGHT=AS 414, AS 488
COUNTDOWN_ROUTE=PIT-SEA-PDX  # or "PIT-SEA, SEA-PDX"
```

The tracker follows the first flight until it lands, shows *Layover* with what is next,
then picks up the second as soon as its transponder comes on. An itinerary strip shows
every leg (flown, in progress, still to come) and lets viewers click back to one; the map
draws the whole trip. A page opened mid-trip catches up on its own: the next leg is
checked every 15 seconds or so, and once it is airborne the earlier one counts as flown.

The tracker shows the plane on a map with its route and trail, plus altitude and climb
rate, ground speed, heading, distance to go, a progress bar and an estimated arrival time
(in `COUNTDOWN_TZ`), the aircraft type and registration, and a status: *Waiting for
signal*, *On the ground*, *Taxiing*, *In flight*, *Signal lost*, *Landed*, or an
*Emergency* squawk. It polls every 5 seconds (30 in a background tab) and keeps its trail
in the browser, so a reload mid-flight keeps the line drawn so far.

**Where the data comes from.** Positions are public ADS-B from
[adsb.fi](https://adsb.fi), falling back to [adsb.lol](https://adsb.lol); routes, when
`COUNTDOWN_ROUTE` is blank, from [adsbdb](https://www.adsbdb.com); map tiles from
OpenStreetMap; Leaflet from unpkg. None needs an API key. The feeds send no CORS headers,
so nginx relays three fixed lookups under `/api/` (see `docker/default.conf`) and caches
them for a few seconds — every viewer shares one upstream request per flight, which keeps
well inside adsb.fi's 1-request-a-second limit however many people are watching. Upstream
hosts are resolved per request (`docker/25-flight-resolver.sh` sets up the resolver), so a
DNS failure can only break the tracker, never stop the countdown from being served.

Serving `site/` without Docker gives you the countdown but no relay; the tracker then says
*No data relay*.

**Things worth knowing before the day:**

- *Flight numbers vs callsigns.* Planes broadcast an ICAO callsign (`UAL1`), not the
  flight number on your ticket (`UA 1`). The page converts the common airlines'
  two-letter codes, but regional flights sold under a mainline number usually fly under
  the operator's own callsign (a `UA 5xxx` is often `SKW…`), and some airlines use
  alphanumeric callsigns. If the tracker sits on *Waiting for signal* while the plane is
  plainly airborne, look the flight up on FlightAware and use the callsign it lists.
- *Set the route.* adsbdb's routes are crowd-sourced and often stale for domestic flights.
  The tracker refuses to use one that does not fit where the plane is — it crosses the route
  out and hides distance and arrival — but `COUNTDOWN_ROUTE` avoids the problem entirely.
- *Coverage gaps.* ADS-B comes from volunteer receivers on the ground, so planes vanish
  over oceans and remote areas. The tracker shows *Signal lost*, greys the plane out and
  keeps estimating distance and arrival from the last report until it reappears.
- *Arrival is an estimate*: great-circle distance at the current ground speed. It runs long
  during climb-out and settles down at cruise.
- *Tight connections.* Leg two is only recognised once its own transponder is on, so for
  the first minutes of a layover the page shows *Layover* rather than the next plane at
  the gate. That is normal.
- *Daily flight numbers.* A long-haul callsign can be on two planes at once (yesterday's
  still landing as today's leaves). The tracker prefers the one nearest the origin and then
  stays locked to that airframe.

`site/airports.json` is built from [OurAirports](https://ourairports.com/data/) (public
domain): every airport with an IATA code and scheduled service. Regenerate it with
`python3 tools/build-airports.py`.

## Notes

- The clock is driven by `requestAnimationFrame` against `Date.now()`, so the hundredths
  field stays smooth and never drifts, even if a tab is throttled and resumes.
- Digits use tabular figures in a fixed layout, so nothing shifts sideways as they change.
- Under 700px wide the clock wraps to two rows for phones.
- At zero the page stops ticking and shows "TIME'S UP" — then the flight tracker, if one
  is configured.
- The tab title is the time left (`2d 04:13:22 · The Final Countdown`), so it reads from
  any other tab.

## Backgrounds

`COUNTDOWN_BG` sets which one viewers see first:

| Name | What it is |
| --- | --- |
| `synthwave` (default) | Banded sun, glowing horizon and a perspective grid floor, all CSS |
| `hyperspace` | A starfield that stretches into light-speed streaks at the end, then drops out of warp |
| `globe` | Earth turning, with `COUNTDOWN_ROUTE` drawn on it; at zero it dives in on the first airport. Drag to spin it |
| `board` | A split-flap departures board with your flight(s) climbing it: *On time*, *Boarding* in the last hour, *Final call* in the last ten minutes, then the tracker's status |
| `aurora` | Northern lights over a mountain skyline, green and slow far out, magenta and fast at the end |

Viewers can switch with the menu in the bottom-right corner. Their pick is remembered in
their own browser, so a changed `COUNTDOWN_BG` only reaches people who never picked one (or
who pick the entry marked *default*). A `?bg=` link beats both.

Every background runs off the same `requestAnimationFrame` loop that drives the digits, and
reacts to the countdown the same four ways:

- **Beat** — a pulse on every whole second, in sync with the digits
  (`beat = (1 - frac) ** 4` off the same remaining-ms value).
- **Speed ramp** — ~18 px/s when the deadline is weeks away, accelerating continuously to
  ~900 px/s in the final seconds, interpolated on `log10(seconds remaining)` so there are no
  visible steps. Synthwave scrolls its grid at that speed; the others map it to warp speed,
  spin, flap rate or wave speed.
- **Palette** — the accent hue slides from cyan (186°) to hot magenta (320°) as time runs
  out, via a single `--accent-h` custom property that every layer derives from.
- **Progress** — how far along the wait is, 0 about 11 days out to 1 at zero, on the same
  log scale as the speed (about 20% a day out, 40% an hour out, 70% a minute out). Each
  background shows it as something you can read at a glance:
  - synthwave: the sun rises from a sliver on the horizon to clear of it, and the sky warms
  - hyperspace: the destination planet grows from a pinpoint at the vanishing point
  - globe: the night side turns until dawn reaches the first airport of the route at zero
  - board: your flight starts at the foot of the board and climbs a row at a time to the top
  - aurora: the storm builds from one faint band to four tall curtains, and the moon rises

  After zero, while a tracked flight is in the air, progress starts over against the
  landing: the sun eases back down at takeoff and comes up again on final approach.

They also follow the mouse (or the phone's tilt) with a little parallax, and answer a tap
anywhere on the background: a shooting star, a burst of sparks, a ping on the globe, a row
of the board flapping round, a ripple through the aurora.

The globe's land outlines come from [world-atlas](https://github.com/topojson/world-atlas)
(Natural Earth, public domain) on jsDelivr, fetched only when the globe is showing; without
them it still draws its grid and the route.

Tuning knobs live in the page script: `SPEED`, `HUE_CALM` / `HUE_HOT`, and synthwave's
`TILE` / `TILT` (which must stay in step with the `.grid` CSS). `prefers-reduced-motion`
freezes the motion, the parallax and the fireworks while keeping the palette shift.

## The big moments

- **Last ten seconds** — the clock gives way to one huge number, 10 to 1, each landing with
  a punch.
- **Zero** — a white flash, fireworks and confetti, and the background's own moment (the sun
  flares, the stars drop out of warp, the globe dives in, the board flaps every tile, the
  aurora blooms). Only for viewers who were watching; a page opened afterwards goes
  straight to the tracker.
- **Takeoff to landing** — while the tracked plane is in the air, big digits count down to
  its estimated landing, and the background ramps up again toward it. The final leg's
  landing gets confetti and an airport chime.

## Corner controls

They fade out after a few idle seconds and come back on any movement.

- **Background** menu, as above.
- **Sound** (off by default): a soft tick each second, a drone that rises through the last
  minute, and a synthesized fanfare at zero. Browsers only allow audio after a click or tap,
  so after a reload it starts on the first one.
- **Flight alerts** (with `COUNTDOWN_FLIGHT` set): browser notifications for zero, takeoff,
  each landing and any emergency squawk — they arrive with the tab in the background.
- **Keep screen on**, for a page left up on a TV or a spare laptop.
- **Full screen**.

Alerts and keep-screen-on are browser features that only work over https (or on
`localhost`), so they do not appear when the page is opened by a plain-http LAN address.
Behind Cloudflare they work. iPhones ask once for motion access the first time the page is
tapped; that only drives the tilt parallax.

The tracker also shows the nearest town with an airport under the plane (from
`site/airports.json`) and an altitude chart of the leg so far — hover it for readings.

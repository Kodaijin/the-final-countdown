# The Final Countdown

A single-page countdown to **Oct 29, 2026 at 6:00 PM Pacific**, showing days, hours,
minutes, seconds and hundredths of a second. No dependencies, no build step — one static
HTML file served by nginx in a container.

```
site/index.html      the entire app - markup, CSS and JS in one file
site/config.js       deadline settings; regenerated in the container from env vars
docker/              entrypoint script that writes config.js at container start
.env.example         template for the COUNTDOWN_* variables compose reads
Dockerfile           nginx:alpine, copies site/ into the image
docker-compose.yml   one service, port 8080:80
```

## Run it

```sh
docker compose up -d --build
```

Then open <http://localhost:8080>.

Without compose:

```sh
docker build -t final-countdown .
docker run -d -p 8080:80 --name final-countdown final-countdown
```

Stop it with `docker compose down` (or `docker rm -f final-countdown`).

To serve on the standard web port instead, change the mapping to `80:80` in
`docker-compose.yml`, or `-p 80:80` on the `docker run`.

## Changing the deadline

Copy `.env.example` to `.env`, edit it, and bring the stack back up:

```sh
cp .env.example .env
docker compose up -d --build
```

```sh
COUNTDOWN_TARGET=2026-10-29T18:00:00   # when it ends
COUNTDOWN_TZ=America/Los_Angeles       # the zone that time is written in
COUNTDOWN_LABEL=                       # caption under the clock; blank = generated
```

`COUNTDOWN_TARGET` is read as wall-clock time in `COUNTDOWN_TZ`, so you write the time you
mean and daylight saving is worked out for you — the same `18:00` is UTC-7 on Oct 29 and
UTC-8 two weeks later. Leave `COUNTDOWN_TZ` blank to have the time read in each viewer's
own timezone instead. You can also give an absolute instant (`2026-10-30T01:00:00Z` or
`2026-10-29T18:00:00-07:00`), in which case the zone only affects how the caption reads.
Whatever the input, everyone counts down to the same moment.

After an `.env` edit a plain `docker compose up -d` is enough — no rebuild. `config.js` is
written at container start by `docker/30-countdown-config.sh`.

Without compose, pass the same variables on the command line:

```sh
docker run -d -p 8080:80 --name final-countdown \
  -e COUNTDOWN_TARGET=2027-01-01T00:00:00 \
  -e COUNTDOWN_TZ=Europe/Berlin \
  final-countdown
```

Serving `site/` directly with no container? Edit `site/config.js`, which holds the same
three settings and ships with the defaults.

### Per-visit overrides on the URL

```
http://localhost:8080/?t=2026-12-25T00:00:00&tz=America/New_York
http://localhost:8080/?t=2027-01-01T00:00:00Z&label=Liftoff
```

`?t=` wins over the environment and stands alone: it does not inherit `COUNTDOWN_TZ` or
`COUNTDOWN_LABEL`, so add `?tz=` and `?label=` if you want them. A target that fails to
parse falls back to the built-in default rather than showing a broken clock.

## Notes

- The clock is driven by `requestAnimationFrame` against `Date.now()`, so the hundredths
  field stays smooth and never drifts, even if a tab is throttled and resumes.
- Digits use tabular figures in a fixed layout, so nothing shifts sideways as they change.
- Under 700px wide the clock wraps to two rows for phones.
- At zero the page stops ticking and shows "TIME'S UP".

## The background

A synthwave scene drawn entirely in CSS — stars, a banded sun clipped at the horizon, a
glowing horizon line and a perspective grid floor. It reacts to the countdown from the same
`requestAnimationFrame` loop that drives the digits:

- **Beat** — the horizon and the sun's bloom pulse on every whole second, in sync with the
  digits (`beat = (1 - frac) ** 4` off the same remaining-ms value).
- **Speed ramp** — the grid scrolls at ~18 px/s when the deadline is weeks away and
  accelerates continuously to ~900 px/s in the final seconds, interpolated on
  `log10(seconds remaining)` so there are no visible steps.
- **Palette** — the accent hue slides from cyan (186°) to hot magenta (320°) as time runs
  out, via a single `--accent-h` custom property that every layer derives from.

Tuning knobs live at the top of the script: `SPEED`, `HUE_CALM` / `HUE_HOT`, and `TILE` /
`TILT` (which must stay in step with the `.grid` CSS). Per frame the page writes one
transform and three opacity/transform values on four elements — no per-frame layout — and
`prefers-reduced-motion` freezes the grid and the beat while keeping the palette shift.

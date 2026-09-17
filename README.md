# The Final Countdown

A single-page countdown to a deadline you set, showing days, hours, minutes, seconds and
hundredths of a second. No dependencies, no build step — one static HTML file served by
nginx in a container.

```
site/index.html      the entire app - markup, CSS and JS in one file
site/config.js       deadline settings; regenerated in the container from env vars
docker/              nginx config and the entrypoint that writes config.js at start
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
```

`COUNTDOWN_TARGET` is read as wall-clock time in `COUNTDOWN_TZ`, so you write the time you
mean and daylight saving is worked out for you — the same `18:00` is UTC-7 on Oct 29 and
UTC-8 two weeks later. Leave `COUNTDOWN_TZ` blank to have the time read in each viewer's
own timezone instead. You can also give an absolute instant (`2026-10-30T01:00:00Z` or
`2026-10-29T18:00:00-07:00`), in which case the zone only affects how the caption reads.
Whatever the input, everyone counts down to the same moment.

`config.js` is written at container start by `docker/30-countdown-config.sh`, so an `.env`
edit needs a restart rather than a new image — but pass `--build` regardless. Compose only
builds when the tagged image is *missing*, so a plain `docker compose up -d`
keeps serving whatever `final-countdown` image is already on the machine — after a `git
pull` that is the old app, silently, with none of your changes in it. `--build` is nearly
free when nothing changed (every layer is cached) and is the only way to be sure the
container matches the checkout.

Serving `site/` directly with no container? Fill in `site/config.js` by hand; it holds the
same three settings and ships blank.

### Nothing is hardcoded, and nothing is guessed

There is no fallback date anywhere. If the deadline is missing or unreadable you get told,
at whichever layer notices first:

| What is wrong | What happens |
| --- | --- |
| `COUNTDOWN_TARGET` empty or unset | `docker compose up` fails immediately and names the variable |
| Same, via `docker run` without `-e` | The container exits 1; `docker logs` shows how to fix it |
| `config.js` blank, missing, or stale | The page replaces the digits with **NO DEADLINE SET** and the fix |
| Target that does not parse | The page shows the value it could not read and the expected format |
| `COUNTDOWN_TZ` not an IANA zone | The page names the bad zone |

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

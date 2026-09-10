# The Final Countdown

A single-page countdown to **Oct 29, 2026 at 6:00 PM Pacific**, showing days, hours,
minutes, seconds and hundredths of a second. No dependencies, no build step — one static
HTML file served by nginx in a container.

```
site/index.html      the entire app - markup, CSS and JS in one file
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

The target is stored as an absolute UTC instant, so everyone counts down to the same
moment no matter what timezone they're in. Edit this line near the top of the script in
`site/index.html` and rebuild:

```js
var TARGET = Date.parse('2026-10-30T01:00:00Z'); // = 6:00 PM Pacific (PDT), Oct 29 2026
```

Note that Oct 29 is still daylight time (UTC-7); after Nov 1 Pacific is UTC-8.

For a one-off without rebuilding, pass a target on the URL:

```
http://localhost:8080/?t=2027-01-01T00:00:00Z
```

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

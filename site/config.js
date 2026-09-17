// Deadline settings. Inside the container this file is regenerated on start from
// the COUNTDOWN_TARGET / COUNTDOWN_TZ / COUNTDOWN_LABEL environment variables
// (see docker/30-countdown-config.sh); edit it directly when serving site/ by hand.
window.COUNTDOWN = {
  target: '2026-10-29T18:00:00',   // wall-clock time in `tz`, or an absolute "...Z" / "...-07:00" instant
  tz: 'America/Los_Angeles',       // IANA zone; blank means the viewer's own timezone
  label: ''                        // caption under the clock; blank = generated from the target
};

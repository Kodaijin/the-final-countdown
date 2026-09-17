// Deadline settings. Inside the container this file is overwritten on every start
// from COUNTDOWN_TARGET / COUNTDOWN_TZ / COUNTDOWN_LABEL in .env, by
// docker/30-countdown-config.sh. There is no default deadline: a blank target
// makes the page say so instead of counting down to an arbitrary date.
// Serving site/ without Docker? Fill in target (and tz) here by hand.
window.COUNTDOWN = {
  target: '',   // e.g. '2026-10-29T18:00:00', or an absolute '2026-10-30T01:00:00Z'
  tz: '',       // e.g. 'America/Los_Angeles'; blank means the viewer's own timezone
  label: ''     // caption under the clock; blank = generated from the target
};

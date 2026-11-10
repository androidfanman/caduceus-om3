# Colour chart light box (parked 2026-11-09)

**Status: taken out of the Control Panel the same day it was built.** The owner tried it live and said "I don't like
this … yet. Let's scrap it", and asked for notes so it can be made again. The photos are the preview again, with the
colour frames first. The whole working version is kept on the branch **`feature/chart-lightbox`** (last commit
`0588953`): `webapp/src/lightbox.ts`, its wiring in `webapp/src/main.ts` and `style.css`, and
`webapp/tests/lightbox.test.ts`. To bring it back, start from that branch rather than from this page.

## The idea (owner)

A colour chart in the Control Panel whose light can be changed, to see a film in different light: the angle of the sun,
brightness, shadow / cloudy, a street lamp at night, fluorescent light; and the camera's white balance "like in camera so
we can see the film sims at different K values".

## What was built, in the order the owner asked for it

1. **A drawn chart** (no photo, no maker's chart; our own layout and colours). First 12 x 5 patches (greys, the wheel's
   12 colours at three strengths, skin, everyday colours); then 6 x 4; last an **upright card, 3 columns x 6 rows**: a
   wider column of six greys (white at the top), six strong colours (red, yellow, green, cyan, blue, magenta), and three
   skin tones, sky, leaves, brick; **black** card and grid (the darkest grey lifted to L* 16 so it shows).
2. **Light:** Sun, Open shade 7500 K, Cloudy 6500 K, Tungsten 2850 K, Street lamp (sodium, 2050 K, weak colours),
   Fluorescent 4100 K (green tint), LED 4000 K. Lamps fall off from the centre. Brightness −3..+3 EV in thirds.
3. **Sun as a time-of-day arc** (6 AM left, Noon top centre, 6 PM right, 15-minute steps, drag or arrow keys): height
   = 70° x sin, light 2500 K at the horizon to 5500 K at noon.
4. **Shadow tied to the time:** none at noon, up to 60 % of the chart at sunrise / sunset, on the right in the
   morning and the left in the afternoon; lit by blue skylight (9000 K, about two stops down). An on / off tick.
5. **Camera WB**, values confirmed by the owner from the camera: Auto, Sunny 5300, Shadow 7500, Cloudy 6000,
   Incandescent 3000, Fluorescent 4000, WB Flash 5500, and Custom with a **typed Kelvin** (2000–14000) plus a slider.
   Auto follows the light only between 2600 and 9500 K (a street lamp stays orange).
6. **Layout:** the chart was the default picture and the first thumbnail; for the chart only, Before and After were two
   pictures side by side (no dividing line); the light controls sat right under the chart, the photo thumbnails below.
7. **Before / After:** last change, Before = the chart in that light with the light's colour cancelled (the camera WB
   did not touch it), After = the camera WB setting + the film.

## How the picture was computed

Each patch has a linear RGB reflectance. The light's colour comes from its Kelvin (a fit of the black-body curve,
normalised so 6500 K is white) with a green / magenta tint; a "colour showing" factor pulls reflectances toward grey
for poor lamps. Pixel = reflectance x light x (1 / colour of the light the camera WB is set for) x exposure, then a
soft highlight clip and the sRGB curve. The film is applied on top by the normal preview (`renderLook`).

## Why it was parked, and what to solve first next time

- The owner's words during the session: the proportions and the panel layout kept needing fixes; "the before follows
  the after too much"; and it was not clear what the Camera WB box was for.
- The underlying knot (analysis): with Auto WB the camera cancels the light, so the sun's time of day and the lamp
  types change almost nothing but the shadow; they only show with a fixed WB. So Light and Camera WB are two controls
  for one visible effect, and Before / After had no obvious meaning for a drawn scene. A next version should decide
  first **what the two pictures are** (for example: left = the film in neutral light, right = the same film in the
  chosen light at the chosen camera WB) and probably offer fewer controls.
- It is a model, never measured against the camera; lamp light on a real OM-3 will differ.
- Not checked in Safari itself (no WebKit in the build environment); the owner's Safari showed the first layout wrong.

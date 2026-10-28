-- Omarchy Notch glass. Keep the bar and notch on the same blur path.
-- https://wiki.hypr.land/configuring/core/rules/layer-rules/
hl.config({ decoration = { blur = { enabled = true, size = 8, passes = 2 } } })
hl.layer_rule({ match = { namespace = "^omarchy-bar$" }, blur = true, xray = true })
hl.layer_rule({
  match = { namespace = "^mark-notch$" },
  blur = true,
  xray = true,
  ignore_alpha = 0.001,
  no_anim = true,
})

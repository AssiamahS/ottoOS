# OttoOS build notes

- Own take on "INK Lockscreen Calendar Note": the note block is drawn onto the
  photo you pick (INK paywalls the background), plus live lock/home widgets.
- No App Group on purpose: Otto notes are reminders in a Reminders list named
  "OttoOS", so the widget extension reads everything through EventKit (widgets
  regained EventKit access in iOS 16.1 b4; both Info.plists carry the usage
  strings). Adding a home-screen photo widget later needs
  `group.com.djsly.ottoos` created by hand in the developer portal first.
- Wallpaper auto-refresh = Shortcuts automation: Make OttoOS Wallpaper → Set
  Wallpaper (Lock Screen). Only works while the lock screen is a plain Photo
  wallpaper, not Photo Shuffle.
- ImageRenderer cannot draw materials, so the canvas uses an explicit dim + blur.
- CI-only builds (no local Xcode). `gh workflow run CI --ref main` after a push
  if the run doesn't start on its own.

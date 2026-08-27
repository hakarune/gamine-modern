# Contributing

Thanks for helping revive Gamine!

## Ground rules

- The game stays **one self-contained `index.html`** — no bundler, no runtime
  dependencies, no external asset fetches. If a change needs a build step,
  it's probably out of scope.
- Keep it usable by a two-year-old: large targets, no small UI, nothing that
  navigates away, no data collection.
- Behaviour ported from the original `gamine.c` is annotated with the name of
  the C function it came from. Keep that mapping intact when you touch it.

## Dev loop

```sh
npm start            # serve on :8080
# edit index.html, reload
npm run validate     # optional: html-validate
shellcheck build-deb.sh
./build-deb.sh        # optional: verify packaging still works
```

## Pull requests

- One logical change per PR; describe what a child sees differently.
- Note if you changed anything under the "ported from gamine.c" comments.
- By contributing you agree your work is licensed under GPL-3.0-or-later.

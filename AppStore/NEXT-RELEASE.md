# Next release: move the web addresses

On 2026-11-10 the code moved to **github.com/justpuzzles/justkakuro**. The old
repo **kkai/justkakuro** stays, only to serve the pages the live app and its App
Store listing point at. Don't delete it: that would take
kaikunze.de/justkakuro/ offline.

In the next release, once the app's page exists at justpuzzles.app/kakuro/
(see "Websites" in the workspace README):

- [ ] ASC version: Support URL and Marketing URL
      kaikunze.de/justkakuro/ → https://justpuzzles.app/kakuro/
- [ ] ASC App Information: Privacy Policy URL
      kaikunze.de/justkakuro/justkakuro-privacy.html → https://justpuzzles.app/kakuro/privacy/
- [ ] In-app links (Settings / About) that still say kaikunze.de/justkakuro/
- [ ] After that release is live: turn kkai/justkakuro's gh-pages into
      redirects to the new pages (old binaries keep their links), then
      archive kkai/justkakuro.

Local clones have two remotes: `origin` (justpuzzles, code) and `kaikunze`
(kkai, the old pages). Push code to `origin` only.

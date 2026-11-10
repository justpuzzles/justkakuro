# Next release: move the web addresses

On 2026-11-10 the code moved to **github.com/justpuzzles/**. The old repo
**kkai/** stays, only to serve the pages the live app and its App Store
listing point at. Don't delete it: that would take kaikunze.de// offline.

In the next release, once the app's page exists at justpuzzles.app//
(see "Websites" in the workspace README):

- [ ] ASC version: Support URL and Marketing URL
      kaikunze.de// → https://justpuzzles.app//
- [ ] ASC App Information: Privacy Policy URL
      kaikunze.de// → https://justpuzzles.app//privacy/
- [ ] In-app links (Settings / About) that still say kaikunze.de//
- [ ] After the release is live: turn kkai/'s gh-pages into redirects
      to the new pages (old binaries keep their links), then archive
      kkai/.

Local clones have two remotes:  (justpuzzles, code) and
 (kkai, the old pages). Push code to  only.

# Third-Party Licenses

This file attributes third-party assets vendored into the repository that are
**not** Go modules. `make verify-license` (`go-licenses`) classifies Go-module
licenses only and cannot see these assets. Each entry cites the vendored bytes
as a `<repo-relative-path>@<8-hex sha256 prefix>` pin and links its license
text as a co-located `*.LICENSE` file. `make verify-vendored-assets` (run inside
`verify-supply-chain`) scans the whole file: it recomputes every pin's hash and
asserts every cited `*.LICENSE` is present, failing on drift, a missing asset,
or a dropped license — regardless of which tree the asset lives in. To attribute
a new non-Go asset, add an entry in this format; the gate picks it up with no
script change.

First-party assets (`internal/dashboard/assets/css/output.css` and the
dashboard vanilla JS under `internal/dashboard/assets/js/`) are covered by the
repository [`LICENSE`](LICENSE) and are not listed here.

## Geist Font

- **Component:** Geist (Sans + Mono)
- **License:** OFL-1.1 (SIL Open Font License 1.1)
- **Copyright:** © 2023 Vercel, Inc.
- **Source:** <https://github.com/vercel/geist-font>
- **License text:** [`internal/dashboard/assets/fonts/Geist.LICENSE`](internal/dashboard/assets/fonts/Geist.LICENSE)
- **Vendored assets (sha-pinned):**
  - `internal/dashboard/assets/fonts/Geist-Sans.woff2@c086f231`
  - `internal/dashboard/assets/fonts/Geist-Mono.woff2@48154b18`

## Outfit Font

- **Component:** Outfit Variable
- **License:** OFL-1.1 (SIL Open Font License 1.1)
- **Copyright:** © 2021 Mathieu Triay and the Outfit Project Authors
- **Source:** <https://github.com/Outfitio/Outfit-Fonts>
- **License text:** [`internal/dashboard/assets/fonts/Outfit.LICENSE`](internal/dashboard/assets/fonts/Outfit.LICENSE)
- **Vendored assets (sha-pinned):**
  - `internal/dashboard/assets/fonts/Outfit-Variable.woff2@45447a2b`

## templUI v1.11.1

- **Component:** templUI v1.11.1
- **License:** MIT
- **Copyright:** © 2024 templUI contributors
- **Source:** <https://github.com/templui/templui>
- **License text:** [`internal/dashboard/components/templui/templui.LICENSE`](internal/dashboard/components/templui/templui.LICENSE)
- **Vendored assets (sha-pinned):**
  - `internal/dashboard/components/templui/utils/utils.go@ff049ad3` *(representative pin for the vendored templUI tree; utils.go is the stable hand-curated core — the full multi-file tree cannot be collapsed to a single sha)*

## 3d-force-graph v1.80.0

- **Component:** 3d-force-graph v1.80.0 (force-directed 3D graph; bundles three.js internally for its own renderer)
- **License:** MIT
- **Copyright:** © Vasco Asturiano
- **Source:** <https://github.com/vasturiano/3d-force-graph>
- **License text:** [`internal/dashboard/assets/vendor/3d-force-graph.LICENSE`](internal/dashboard/assets/vendor/3d-force-graph.LICENSE)
- **Vendored assets (sha-pinned):**
  - `internal/dashboard/assets/vendor/3d-force-graph.min.js@d96e738e`

## three.js r0.183.0 (UnrealBloom pass)

- **Component:** three.js r0.183.0 — ESM module + core half, plus the `UnrealBloomPass` post-processing pass and its shader deps, vendored to give the graph its bloom glow (the UMD `3d-force-graph` bundle's internal three cannot drive the pass; a shared ESM three instance is bridged onto `window.THREE` by the first-party `assets/js/three-bloom-bootstrap.js`).
- **License:** MIT
- **Copyright:** © 2010–2026 three.js authors
- **Source:** <https://github.com/mrdoob/three.js>
- **License text:** [`internal/dashboard/assets/vendor/three.LICENSE`](internal/dashboard/assets/vendor/three.LICENSE)
- **Provenance note:** `UnrealBloomPass.js`, `Pass.js`, and `LuminosityHighPassShader.js` are not byte-identical to upstream — their bare `from 'three'` (and `UnrealBloomPass.js`'s `../shaders/*`) import specifiers were rewritten to the co-located vendored files so the ESM resolves without an import map. The pins below are the committed (post-rewrite) hashes. `three.module.min.js`, `three.core.min.js`, and `CopyShader.js` ship byte-identical to upstream. Full upstream/pre-rewrite hashes are recorded in the lift source's `internal/web/static/vendor/README.md`.
- **Vendored assets (sha-pinned):**
  - `internal/dashboard/assets/vendor/three.module.min.js@e3ec4d5d`
  - `internal/dashboard/assets/vendor/three.core.min.js@c5f69a04`
  - `internal/dashboard/assets/vendor/UnrealBloomPass.js@87c6a167`
  - `internal/dashboard/assets/vendor/Pass.js@08c996de`
  - `internal/dashboard/assets/vendor/LuminosityHighPassShader.js@e69f66b4`
  - `internal/dashboard/assets/vendor/CopyShader.js@a33057d5`

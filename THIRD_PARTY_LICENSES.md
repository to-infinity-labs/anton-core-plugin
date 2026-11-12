# Third-Party Licenses

anton-core bundles the third-party works below. Their licence texts are in
[`licenses/`](licenses); everything else is under the project [`LICENSE`](LICENSE).

## Fonts and browser libraries (the dashboard)

| Component | Licence | Copyright | Source | Licence text |
|---|---|---|---|---|
| Geist (Sans + Mono) | OFL-1.1 | © 2023 Vercel, Inc. | <https://github.com/vercel/geist-font> | [`licenses/Geist.LICENSE`](licenses/Geist.LICENSE) |
| Outfit Variable | OFL-1.1 | © 2021 Mathieu Triay and the Outfit Project Authors | <https://github.com/Outfitio/Outfit-Fonts> | [`licenses/Outfit.LICENSE`](licenses/Outfit.LICENSE) |
| templUI v1.11.1 | MIT | © 2024 templUI contributors | <https://github.com/templui/templui> | [`licenses/templui.LICENSE`](licenses/templui.LICENSE) |
| d3-force-3d v3.0.6 and the packages its bundle inlines | MIT, ISC | © Vasco Asturiano; each inlined package's holder is in its licence text | <https://github.com/vasturiano/d3-force-3d> | [`licenses/d3-force-3d.deps.LICENSE`](licenses/d3-force-3d.deps.LICENSE) |
| three.js r0.183.0 | MIT | © 2010–2026 three.js authors | <https://github.com/mrdoob/three.js> | [`licenses/three.LICENSE`](licenses/three.LICENSE) |

## Go modules (the binary)

The licence and notice files of every Go module linked into the `anton-core`
binary are in [`licenses/go/`](licenses/go), one directory per module path.
The release's CycloneDX SBOM (`SBOM.cyclonedx.json`) lists each module and version.

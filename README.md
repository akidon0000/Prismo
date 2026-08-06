<h1 align="center">Prismo</h1>

<p align="center">
  <strong>See the shape of a PR before you read it.</strong>
</p>

<p align="center">
  A macOS app for reviewing pull requests in call order — not file-name order.<br/>
  Assigned reviews surface first. Open a PR and read the diff along the call graph.
</p>

<p align="center">
  <img alt="Platform" src="https://img.shields.io/badge/platform-macOS%2014%2B-1B1B1F?style=flat-square&logo=apple"/>
  <a href="https://github.com/akidon0000/Prismo/actions/workflows/ci.yml"><img alt="CI" src="https://github.com/akidon0000/Prismo/actions/workflows/ci.yml/badge.svg"/></a>
</p>

<p align="center">
  <a href="README.md"><strong>English</strong></a> ·
  <a href="README.ja.md">日本語</a>
</p>

---

## Features

Prismo is intentionally a two-feature MVP:

1. **Assigned-first inbox** — Open the app and see PRs waiting for *your* review, with everything else still reachable. ⌘R to refresh.
2. **Call-order review** — Changed symbols are ordered by how they call each other (callers before callees), grouped into file columns. Select a symbol to read its patch hunk in the in-app diff pane. ⌘J / ⌘K to walk the outline.

Supported languages: **Swift · Kotlin · Dart** (import + symbol-name reference heuristics).

Inspired by [rinkaku](https://github.com/hiro-o918/rinkaku)'s “see the shape before you read” idea, built as a native macOS window app in the spirit of [Tokfuel](https://github.com/Tokfuel/Tokfuel).

## Status

Working slice:

- **Inbox** via GitHub search (`review-requested` / `assignee` / `involves`), falling back to demo data when unauthenticated (clearly labeled)
- **Token** from Keychain (PAT), or `gh auth token` when empty — github.com, single account
- **Call-graph columns** from PR file patches (import + symbol-name reference heuristics for Swift · Kotlin · Dart)
- **In-app diff pane** — select a symbol to see its patch hunk
- **Keyboard** — ⌘R refresh, ⌘J/⌘K next/prev symbol

Still ahead: tree-sitter-grade symbol graphs, checkout + IDE jump, review notes, multi-account. (A pre-MVP build with those features lives on the `snapshot/pre-mvp` branch.)

## Install

- **DMG (after first release):** [Prismo-latest.dmg](https://github.com/akidon0000/Prismo/releases/latest/download/Prismo-latest.dmg)
- **Download page:** GitHub Pages (`Site/`, published by `.github/workflows/pages.yml`)

### From source

```bash
git clone git@github.com:akidon0000/Prismo.git
cd Prismo
bash scripts/setup.sh
swift assets/make-icon.swift   # optional
bash scripts/build.sh          # → /Applications/Prismo.app
```

Requirements: macOS 14+, Xcode with Swift 6 toolchain.

## Development

```bash
swift test
swift build -c release
bash scripts/ui-preview.sh /tmp/ui-preview   # DEBUG screenshots
bash scripts/screenshot.sh                   # README + Site hero PNG
(cd Site && swift run)                       # download page → Site/Build
```

Label a PR with `ui-preview 📸` to post rendered screens in the conversation.
Label a PR with `site-preview 🌐` to post a rendered download-page URL.

### Release

1. Run **Bump version** (Actions) → merge the PR (`versions/macos`)
2. **Release** builds a universal DMG and publishes a GitHub Release
3. Optional secrets for Developer ID + notarization: `DEVELOPER_ID_P12`, `DEVELOPER_ID_P12_PASSWORD`, `APP_STORE_CONNECT_*`

Sources live under [`Prismo/Sources/`](Prismo/Sources/). See [`AGENTS.md`](AGENTS.md).

## Contributors

<!-- readme: contributors -start -->
<table>
	<tbody>
		<tr>
            <td align="center">
                <a href="https://github.com/akidon0000">
                    <img src="https://avatars.githubusercontent.com/u/53287375?v=4&s=100" width="100;" alt="akidon0000"/>
                    <br />
                    <sub><b>akidon0000</b></sub>
                </a>
            </td>
		</tr>
	</tbody>
</table>
<!-- readme: contributors -end -->

## License

MIT © akidon0000

<h1 align="center">Prismo</h1>

<p align="center">
  <strong>読む前に、PR の形が見える。</strong>
</p>

<p align="center">
  ファイル名順ではなく、呼び出し順でプルリクエストをレビューする macOS アプリ。<br/>
  起動すると自分にアサインされたレビューが先に見え、PR を開くと呼び出し順に差分を読み進められる。
</p>

<p align="center">
  <img alt="Platform" src="https://img.shields.io/badge/platform-macOS%2014%2B-1B1B1F?style=flat-square&logo=apple"/>
  <a href="https://github.com/akidon0000/Prismo/actions/workflows/ci.yml"><img alt="CI" src="https://github.com/akidon0000/Prismo/actions/workflows/ci.yml/badge.svg"/></a>
</p>

<p align="center">
  <a href="README.md">English</a> ·
  <a href="README.ja.md"><strong>日本語</strong></a>
</p>

---

## 機能

Prismo は意図的に 2 機能だけの MVP:

1. **アサイン優先のインボックス** — 起動直後に「自分がレビューすべき PR」が先に見える。それ以外も一覧できる。⌘R で更新。
2. **呼び出し順レビュー** — 変更シンボルを呼び出し関係（呼び出し元 → 先）で並べ、ファイル列にまとめる。シンボルを選ぶと該当 patch hunk をアプリ内 diff で読める。⌘J / ⌘K で輪郭を辿る。

対応言語: **Swift · Kotlin · Dart**（import / シンボル名参照のヒューリスティック）。

思想は [rinkaku](https://github.com/hiro-o918/rinkaku) の「読む前に形を見る」に近く、構成は [Tokfuel](https://github.com/Tokfuel/Tokfuel) を参考にした SwiftPM ネイティブ macOS アプリ。

## 現状

動く範囲:

- **インボックス** — GitHub 検索（`review-requested` / `assignee` / `involves`）。未認証時はデモデータ（その旨を表示）
- **トークン** — Keychain の PAT、または空なら `gh auth token`。github.com の単一アカウント
- **呼び出し順ファイル列** — PR の patch から import / シンボル名参照を拾うヒューリスティック（Swift · Kotlin · Dart）
- **アプリ内 Diff** — シンボルを選ぶと該当 patch hunk を表示
- **キーボード** — ⌘R 更新、⌘J/⌘K 次/前シンボル

これから: tree-sitter 級のシンボルグラフ、Checkout + IDE ジャンプ、レビューメモ、マルチアカウント（削る前の実装は `snapshot/pre-mvp` ブランチにある）。

## インストール

- **DMG（初回リリース後）:** [Prismo-latest.dmg](https://github.com/akidon0000/Prismo/releases/latest/download/Prismo-latest.dmg)
- **ダウンロードページ:** GitHub Pages（`Site/`、`pages.yml` が公開）

### ソースから

```bash
git clone git@github.com:akidon0000/Prismo.git
cd Prismo
bash scripts/setup.sh
bash scripts/build.sh
```

## 開発

```bash
swift test
swift build -c release
bash scripts/ui-preview.sh /tmp/ui-preview
bash scripts/screenshot.sh
(cd Site && swift run)
```

PR に `ui-preview 📸` ラベルを付けると、実 UI のスクショがコメントに貼られる。
`site-preview 🌐` ラベルを付けると、ダウンロードページのプレビュー URL がコメントに貼られる。

### リリース

1. Actions の **Bump version** → PR をマージ（`versions/macos`）
2. **Release** がユニバーサル DMG を GitHub Releases へ出す
3. 署名・公証は任意 secrets（`DEVELOPER_ID_P12` など）

詳細は [`AGENTS.md`](AGENTS.md)。

## コントリビューター

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

## ライセンス

MIT © akidon0000

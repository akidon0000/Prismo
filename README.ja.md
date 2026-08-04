<h1 align="center">Prismo</h1>

<p align="center">
  <strong>読む前に、PR の形が見える。</strong>
</p>

<p align="center">
  ファイル名順ではなく、呼び出し順でプルリクエストをレビューする macOS アプリ。<br/>
  起動すると自分にアサインされたレビューが先に見え、PR を開くと呼び出しグラフに沿ったファイル列が並ぶ。<br/>
  必要ならブランチを checkout して Xcode / Android Studio で続けられる。
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

- **アサイン優先** — 起動直後に「自分がレビューすべき PR」が先に見える。それ以外も一覧できる。
- **呼び出し順のファイル列** — 変更シンボルを呼び出し関係（呼び出し元 → 先）で並べ、ファイル列にまとめる。アルファベット順ではない。
- **Checkout + IDE ジャンプ** — 該当ブランチを落として、Xcode / Android Studio で続きの操作ができる（実装予定）。
- **Swift · Kotlin · Dart** — モバイルスタックを最初の対応言語にする。

思想は [rinkaku](https://github.com/hiro-o918/rinkaku) の「読む前に形を見る」に近く、構成は [Tokfuel](https://github.com/Tokfuel/Tokfuel) を参考にした SwiftPM ネイティブ macOS アプリ。

## 現状

動く範囲:

- **インボックス** — GitHub 検索（`review-requested` / `assignee` / `involves`）。未認証時はデモデータ
- **トークン** — Keychain、または空なら `gh auth token`
- **呼び出し順ファイル列** — PR の patch から import / シンボル名参照を拾うヒューリスティック（Swift · Kotlin · Dart）
- **Checkout** — `refs/pull/N/head` を落として Xcode / Android Studio を開く（`~/ghq/...` があれば再利用）
- **アプリ内 Diff** — シンボルを選ぶと該当 patch hunk を表示
- **コードジャンプ** — Checkout 後に `file:line` を Xcode / Android Studio / VS Code で開く
- **レビューメモ** — シンボルにメモを付け、Markdown コピーまたは GitHub COMMENT レビューとして一括投稿（ローカル永続化）
- **Blast radius** — 選択シンボルの呼び出し元 / 先（1-hop）
- **キーボード** — ⌘R 更新、⌘J/⌘K 次/前シンボル、⌘⇧J Jump、⌘⇧N メモ
- **インボックス絞り込み** — 検索 + Swift/Kotlin/Dart

これから: tree-sitter 級のシンボルグラフ。

## インストール（ソースから）

```bash
git clone git@github.com:akidon0000/Prismo.git
cd Prismo
bash scripts/setup.sh
swift assets/make-icon.swift   # 任意
bash scripts/build.sh          # → /Applications/Prismo.app
```

要件: macOS 14 以上、Swift 6 ツールチェーン付き Xcode。

## 開発

```bash
swift test
swift build -c release
```

ソースは [`Prismo/Sources/`](Prismo/Sources/)。作業合意は [`AGENTS.md`](AGENTS.md)。

## ライセンス

MIT © akidon0000

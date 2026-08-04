# AGENTS.md（AI セッションの作業合意）

> 人間かエージェントかを問わず、すべてのセッションが最初に読む共有前提。

## これは何か

**Prismo** は、PR を「ファイル名順」ではなく「呼び出し順」でレビューするための
SwiftUI ネイティブ macOS ウィンドウアプリ。起動すると自分にアサインされたレビューが
先に見え、PR を開くと呼び出しグラフに沿ったファイル列が並ぶ。必要ならブランチを
checkout して Xcode / Android Studio で続けられる。対応言語は Swift / Kotlin / Dart。
ソースはすべて [`Prismo/Sources/`](Prismo/Sources/) にある。

思想の近い先行例: [rinkaku](https://github.com/hiro-o918/rinkaku)。
リポジトリ構成の参考: [Tokfuel](https://github.com/Tokfuel/Tokfuel)。

## グラウンドルール（違反禁止）

1. **レビュー対象コードを勝手に外に出さない**：PR の diff・ソース・トークンを、
   ユーザーが明示していない外部サービスへ送らない。GitHub API へのリクエストは
   ユーザー設定のトークン（または `gh auth token`）での認証に限る。
2. **トークンは慎重に**：GitHub PAT をログ・Analytics・コミットに載せない。
   保存先は Keychain（`KeychainStore`）のみ。
3. **新規パッケージ依存の禁止**：Swift 6 / SwiftUI / macOS 14+、標準 SDK のみ。
   例外はオーナー承認後に `Package.swift` とこの文書へ追記する。
4. **デモデータを本物と偽らない**：フィクスチャ表示中は UI 上でその旨を示す。
5. **許可ネットワーク**：`api.github.com`（インボックス / files / PR 詳細）と、
   ユーザー操作時の `git clone` / `git fetch`（GitHub）のみ。

## 検証ゲート

```bash
swift test               # Prismo/Tests（Swift Testing）
swift build -c release   # scripts/build.sh がパッケージする構成
```

CI（[`.github/workflows/ci.yml`](.github/workflows/ci.yml)）がすべての PR でテストと
リリースビルドを実行する。実行時に見える変更は `bash scripts/build.sh` で
`/Applications/Prismo.app` に入れて観察する。

## 作業言語

- 会話・コミットメッセージ・Issue: **日本語**
- README / ユーザー向け説明: 日英併記（`README.md` / `README.ja.md`）
- コード識別子・コメント: 英語でも日本語でも可（既存ファイルに合わせる）

## 規約

- ブランチ: `feat/…`, `fix/…`, `chore/…`
- `@MainActor` を UI / store に明示する
- `bash scripts/setup.sh` で `.githooks` を有効化する（`@sansan.com` メール拒否）

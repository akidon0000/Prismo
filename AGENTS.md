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
3. **新規パッケージ依存の禁止（アプリ本体）**：ルート `Package.swift` は Swift 6 /
   SwiftUI / macOS 14+、標準 SDK のみ。例外はオーナー承認後に追記する。
   **Site/** だけは Ignite（静的サイト）を許可済み。
4. **デモデータを本物と偽らない**：フィクスチャ表示中は UI 上でその旨を示す。
5. **許可ネットワーク**：`api.github.com`（インボックス / files / PR 詳細 /
   レビュー投稿）と、ユーザー操作時の `git clone` / `git fetch`（GitHub）のみ。
   レビュー投稿はユーザーが明示的に「Post to GitHub」したときだけ。
6. **UI 変更時は ui-preview 同期**：`ContentView` / `PRDetailView` / `SettingsView` を
   変えたら、同じ PR で `ScreenshotRenderer.allScreens()` と
   [`.github/workflows/ui-preview.yml`](.github/workflows/ui-preview.yml) の
   `ORDER` / `screen_title` も更新する。

## 検証ゲート

```bash
swift test               # Prismo/Tests（Swift Testing）
swift build -c release   # scripts/build.sh がパッケージする構成
bash scripts/ui-preview.sh /tmp/ui-preview   # DEBUG 画面キャプチャ
(cd Site && swift run)   # ダウンロードページ
```

CI（[`.github/workflows/ci.yml`](.github/workflows/ci.yml)）がアプリと Site をビルドする。
実行時確認は `bash scripts/build.sh`。

## リリース

1. Actions の **Bump version** で `versions/macos` を上げる PR を作る
2. マージすると **Release** が DMG を GitHub Releases に出す
   （任意 secrets: Developer ID / App Store Connect 公証）
3. ダウンロード固定 URL:
   `https://github.com/akidon0000/Prismo/releases/latest/download/Prismo-latest.dmg`
4. **Pages** は `Site/` 変更で GitHub Pages を更新する

## 作業言語

- 会話・コミットメッセージ・Issue: **日本語**
- README / ユーザー向け説明: 日英併記（`README.md` / `README.ja.md`）
- コード識別子・コメント: 英語でも日本語でも可（既存ファイルに合わせる）

## 規約

- ブランチ: `feat/…`, `fix/…`, `chore/…`
- `@MainActor` を UI / store に明示する
- `bash scripts/setup.sh` で `.githooks` を有効化する（`@sansan.com` メール拒否）

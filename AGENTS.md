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
5. **許可ネットワーク**：アクティブアカウントの GitHub API
   （`api.github.com` または設定された Enterprise ホストの `/api/v3`）と、
   ユーザー操作時の `git clone` / `git fetch`（同じホスト）のみ。
   レビュー投稿はユーザーが明示的に「Post to GitHub」したときだけ。
   アカウント切替は設定 / ツールバーの `acct:` メニュー（`gh` 複数アカウント・PAT）。
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

CI はパスで分かれている。[`ci.yml`](.github/workflows/ci.yml) がアプリ本体
（`Prismo/Sources` / `Prismo/Tests` / `Package.swift`）を触った PR・push でユニットテストと
リリースビルドを回し、[`site-ci.yml`](.github/workflows/site-ci.yml) が `Site/` を触ったときだけ
ダウンロードページのビルドを検証する。実行時確認は `bash scripts/build.sh`。

PR へのプレビューはラベルで出す。`ui-preview 📸` が実 UI のスクショを、`site-preview 🌐` が
ダウンロードページのレンダリング URL をコメントに貼る。

## ロードマップの回し方

機能は GitHub Issue として管理する。新機能は **Proposal**、バグは **Bug report** の
テンプレートを使う。このサイクルは [`.agents/skills/`](.agents/skills/) 配下のスキルが回す
（`.claude/skills` は Claude Code 互換のための symlink）。

- **`ideation`**：アイデアを GitHub Issue に仕立てる（起案のみ）。
- **`implementation`**：Issue 番号を起点に実装して出荷する（Issue 本文が仕様）。
- **`task-select`**：オープンな Issue を見渡し、次に実装する項目を選ぶ。

## リリース

1. Actions の **Bump version** で `versions/macos` を上げる PR を作る
2. マージすると **Release** が DMG を GitHub Releases に出す
   （任意 secrets: Developer ID / App Store Connect 公証）
3. ダウンロード固定 URL:
   `https://github.com/akidon0000/Prismo/releases/latest/download/Prismo-latest.dmg`
4. **Pages** は `Site/` 変更で GitHub Pages を更新する

## 作業言語

このリポジトリの基本言語は日本語。

- セッションでのやり取り、レビューコメント、AGENTS.md やスキルといった作業文書は日本語で書く。
  文章は [`japanese-tech-writing`](.agents/skills/japanese-tech-writing/SKILL.md) スキルの規範に
  従う（Issue と PR の本文の日本語は敬体、作業規範の文書は常体）。
- **GitHub Issue（新規）**：タイトルは `日本語 / English`。本文は日本語ブロック
  （背景 / 要件 / タスク / 実現可否）のあとに英語ブロック（Background / Requirements /
  Tasks / Feasibility）を置く。正本は日本語。実装方針や関連ファイル一覧は書かない。
  ラベルは**種別**と、当てはまるなら**領域**を必ず自動付与する。
  種別は機能 `enhancement 🚀`、バグ `bugs 🐞`、文書 `docs ✍️`、雑務 `chore 🏠`。
  領域はアプリ `product 🍎`、サイト `web 🌐`、CI / Actions / 配布 `ci ⚙️`
  （領域に当てはまらなければ種別のみ）。急ぐものだけ `high priority 🔥` を付ける。
  詳細は [`ideation`](.agents/skills/ideation/SKILL.md) と
  [`.github/ISSUE_TEMPLATE/proposal.md`](.github/ISSUE_TEMPLATE/proposal.md) を参照。
- **GitHub PR（新規）**：タイトルは `日本語 / English`。本文は背景 / 変化 / 判断 / 懸念
  （あれば）＋ Background / Changes / Decisions / Concerns。ファイルパスの列挙は diff に任せ、
  書かない。懸念が無ければその節は削除する。ラベルは Issue と同じく種別＋領域を付ける。
  詳細は [`.github/PULL_REQUEST_TEMPLATE.md`](.github/PULL_REQUEST_TEMPLATE.md) を参照。
- コミットメッセージも日本語で書く（形式は「規約」のとおり）。
- README と SECURITY は日英併記を続ける。ユーザーに見える変更では `README.md` と
  `README.ja.md` の両方を更新する。
- コード内のコメントは、周囲の既存コードに合わせる。

## 規約

- ブランチ: `feat/…`, `fix/…`, `chore/…`
- `@MainActor` を UI / store に明示する
- `bash scripts/setup.sh` で `.githooks` を有効化する（`@sansan.com` メール拒否）

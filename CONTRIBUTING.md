# Contributing to Prismo

貢献ありがとうございます。小さな PR を歓迎します。

## 開発環境

- macOS 14+
- Xcode（Swift 6 ツールチェーン）
- `gh`（任意。トークン未設定時のフォールバック）

```bash
bash scripts/setup.sh
bash scripts/build.sh   # → /Applications/Prismo.app
swift test
```

## 方針

- アプリ本体（`Prismo/Sources`）への新しい外部依存は、Issue で合意してから追加する
- GitHub トークンは Keychain のみ。PR コードを外部へ送らない
- UI を変える PR は `ScreenshotRenderer.allScreens()` と ui-preview の ORDER を更新する（`AGENTS.md` 参照）
- Issue → 実装 → PR → レビューの流れを推奨。関連 Issue を PR 本文でリンクする

## PR

`.github/pull_request_template.md` に沿って、目的・変更点・確認内容を書いてください。

ラベル `ui-preview 📸` を付けると、CI がスクリーンショットをコメントします。

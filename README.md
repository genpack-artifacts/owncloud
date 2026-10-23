# ownCloud artifact (genpack)

Gentoo ベースの不変 SquashFS イメージとして ownCloud 11（PHP 8.3）サーバーをビルドする genpack 成果物。
イメージ内の運用手順は同梱の `files/home/owncloud/AGENTS.md` を参照。

## 構成

- ownCloud 11.x + PHP 8.3（Portage `dev-lang/php`。サポート範囲は **8.3〜8.5**、`lib/base.php` と `composer.json` で強制）
- Web: apache（**event MPM**, threaded）+ **php-fpm**（mod_php ではなく `proxy_fcgi` 経由）
  - MPM はビルド時に `APACHE2_MPMS: event` と `threads` USE で決まり、実行時のスイッチでは変えられない。
  - php-fpm は apache と別プロセスなので MPM の ZTS 要否と pecl 拡張が独立（nextcloud の prefork 固定問題の回避）。
- `mod_http2` はビルド済みだが既定では未ロード（`APACHE2_OPTS` に `-D HTTP2` を足すと有効化可）
- DB: mysql / キャッシュ: APCu（local）・Redis（locking）/ mail: postfix
- SMB 外部ストレージ用の `smbclient` PHP 拡張だけ Portage に無いため `50-php.sh` が `pecl install`（buildtime に `dev-build/autoconf`）

## ビルド

| 版 | コマンド | 出力 |
|---|---|---|
| Server（既定・最小アプリ） | `genpack build` | `owncloud-x86_64.squashfs` |
| Complete（アプリ一式・多くは無効同梱） | `genpack --variant complete build` | `owncloud-complete-x86_64.squashfs` |

buildtime 依存: `app-misc/jq`（`60-owncloud.sh`）、`dev-build/autoconf`（`50-php.sh`）。

### Server / Complete の中身

- **Server 版**: core 結合アプリ **約 20**（`files` / `dav` / `encryption` / `files_sharing` …）。
  `activity` / `files_pdfviewer` / `files_texteditor` は **同梱されない**（Complete 側・個別 repo 由来で、Server tarball にはどのバージョンにも同梱歴が無い）。
- **Complete 版**: 上記 + 約 35（`activity`, `files_antivirus`, `files_pdfviewer`, `files_texteditor`, `user_ldap`, `richdocuments` …）。
  OS 依存として `app-antivirus/clamav` を追加（`clamav-daemon` / `clamav-freshclam` unit 同梱、**既定無効**。`files_antivirus` 用で clamcli=clamscan でも動作）。
- 同梱アプリは DB 登録が必要。初回起動の `occ upgrade`（`owncloud-init`）または `occ app:enable <id>` で有効化する。

## バージョン選定

GitHub Releases から **semver で最大の 11.x** を選ぶ。`releases/latest` は公開日順で、ownCloud が 10.x/11.x を並行保守しているため 10.16.x を返しうる（latest ≠ 最大）。
Server 版は `owncloud-<ver>.tar.bz2`、Complete 版は `owncloud-complete-<date>.tar.bz2`（`-qa` は対象外）。
`download.owncloud.com` は 10.16.3 で停止しており、11 系は GitHub Releases のみ配布。

## 運用の前提

- イメージは read-only（squashfs + overlay）。書き込みはデータパーティション側。OS 構成の変更は再ビルド。
- 起動時 `owncloud-init`（`apache2.service` の `ExecStartPre`）が `data/.ocdata` を見て `occ upgrade` / `maintenance:install` を自動実行。
- 管理は uid 1000 の `owncloud` ユーザーが `sudo occ`（`sudoers.d/owncloud` で `/usr/bin/occ` に限定）。手順は `AGENTS.md`。
- 想定配置は **TLS 終端 reverse proxy の後ろ**。`X-Forwarded-Proto` でスキームは自動検出、公開 FQDN を `trusted_domains 0` に登録する（AGENTS 参照）。

## 11 系での破壊的変更

- PHP 7 廃止（PHP 8.3 必須）。
- G2 コード署名へ移行。**G1 署名アプリは 2027-01-01 に検証打ち切り**（`occ integrity:sign-*` 削除）。
- group-admin(subadmin) が既定無効（`allow_subadmins` で明示有効化）。
- `occ db:convert-type`・caching router 削除。アップグレード元は 8.2.11 / 9.0.9 / 9.1 以降のみ。

## 初回起動ログの既知ノイズ（非致命的）

- `PCRE JIT will be disabled` … `owncloud-init` が走る apache2 ユニットに `MemoryDenyWriteExecute=true` が付いており PCRE JIT が実行可能メモリを取れないため。リクエスト処理（php-fpm）側では発生しない。
- `owncloud@localhost` の mysql ユーザ作成失敗 … `60-owncloud.sh` が先に DB ユーザを作っているため install 側が `mysql.user` を読めず出るが、インストール自体は成功する。

## 参照

- 詳細なビルド情報: イメージ内 `/.genpack/genpack.md`
- 運用手順: `files/home/owncloud/AGENTS.md`

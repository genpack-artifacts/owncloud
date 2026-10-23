# ownCloud artifact — 運用ガイド (owncloud ユーザー用)

## 前提: これは genpack のイメージであり「普通の Linux」ではない
このシステムは genpack がビルドしたイメージから起動しています。**まず `/.genpack/genpack.md` を読んでください**。これはこの成果物のビルド・構成・パッケージ構成を記述した前提ドキュメントです。通常の Linux と同じに振る舞うと想定外の挙動になります(下は read-only、構成はビルドで決まる)。

このアカウント(uid/gid 1000)は、その ownCloud インスタンスを運用するためのログイン用ユーザーです。
SSH 鍵でログインし、`occ` を使って管理します。

## occ の実行
`occ` は root 実行後に所有ユーザー(apache)へ特権を降格するラッパーです。このアカウントには
`sudoers.d/owncloud` 経由で `/usr/bin/occ` の NOPASSWD 実行が許可されています。

```sh
sudo occ status
sudo occ config:system:list 2>/dev/null || sudo occ config:system:get <key>
```

## 初回に必要な設定 (TLS 終端 reverse proxy の後ろに置く場合)
reverse proxy が `X-Forwarded-Proto: https` を送る限りスキームは自動検出されます(設定不要)。
必要なのは **公開ホスト名 1 個** の信頼指定だけです:

```sh
# 公開 FQDN を trusted_domains の index 0 に入れる(index 0 必須。欠くと非信頼 Host で 500 になる)
sudo occ config:system:set trusted_domains 0 --value=cloud.example.com
```

または proxy 経由時にだけ発効させる固定ホスト指定:

```sh
sudo occ config:system:set overwritehost --value=cloud.example.com
# (proxy が X-Forwarded-Proto を送らない場合のみ)
sudo occ config:system:set overwriteprotocol --value=https
```

既定では `localhost` / `owncloud` / `owncloud.local` が信頼済みです(localhost は常に許可)。

## 構成メモ
- Web: apache(event MPM) + php-fpm(8.3, proxy_fcgi)。DB: mysql。キャッシュ: APCu(local)/Redis(locking)。メール: postfix。
- データ: `/var/www/localhost/htdocs/data`。ログ: `/var/www/localhost/htdocs/data/owncloud.log`, `/var/log/apache2/`, `/var/log/php-fpm.log`。

### ログ参照の注意 (このアカウントでは直接読めない)
owncloud は sudo 無しでは次のログを**読めません**(owncloud は apache グループ非所属のため)。
- `/var/log/apache2/` … dir が `0750 apache:apache`（traverse 不可）
- `/var/log/php-fpm.log` … `0600 root:root`
- `data/owncloud.log` … `0640 apache:apache`（data dir が `0750 apache:apache`）

現状は `occ` 経由で管理し、システムログの直接閲覧は root 側の作業とします。
read-only squashfs+overlay のため **ACL/ファイル capability は現状イメージに焼けても実行時に効きません**
（genpack が mksquashfs の `-xattrs` と squashfs の `xattrs` マウントをサポートするまで保留）。
読む仕組みを入れる場合は sudo の経路を限定する形が安全:
- `sudoedit:/var/log/apache2/error_log` (対象ファイルを絞った安全な閲覧/編集)
- 専用の読み取り helper コマンドを用意し `Cmnd_Alias` で**完全一致**の経路のみ許可
  （sudoers の `*` ワイルドカードは引数注入に弱く非推奨。mode ビット＝グループ方式なら squashfs にも残る）

## 注意
- `sudo` は `/usr/bin/occ` のみに限定されています(他のコマンドは不可)。
- パッケージの追加やシステム更新は root 側(成果物の再ビルド / 管理者)の責任です。
- 詳細なビルド情報は `/.genpack/genpack.md`。

# PHP と ownCloud の現状メモ

最終更新: 2026-10-21

## ownCloud Classic の PHP 事情

### なぜ長らく PHP 7.4 のままだったのか

ownCloud Classic（10.x 系）は長年 PHP 7.4 のみをサポートし、PHP 8 対応を事実上放棄していた。
その背景には、ownCloud 社が PHP で動く Classic を「過去の産物」と位置づけ、Go で完全に書き直した
次世代製品 **oCIS（ownCloud Infinite Scale）** に開発リソースを集中させていたという経営判断がある。

### ownCloud の迷走

- **2023年11月**: 米 **Kiteworks** が ownCloud を買収。方針が不透明になる。
- **2025年1月**: oCIS のコア開発チーム（12名以上）が集団退職し、Heinlein Group の下で
  **OpenCloud GmbH** を設立。Kiteworks は「人材の盗用」として訴訟をちらつかせる。
- **2026年4月**: 残された Kiteworks が Classic ユーザーを切り捨てられず、
  **ownCloud 11.0.0 プレアルファ** として PHP 8.3 対応版を Docker Hub でリリース。
  タイトルが「PHP 8.3. Yes, for Classic. Yes, we heard you.」という苦渋の滲む内容。
- **2026年5月6日**: Kiteworks が **ownCloud OSPO(Open Source Program Office)** を発足。
  ガバナンス憲章・DCO・AI 利用ポリシーを公表。その後のリリース管理は Kiteworks 系 GitHub
  アカウント(kw-tmueller, kw-fscheuer)が担い、コミットには `Co-authored-by: Claude Opus 4.8/5` が
  散見される — AI 支援開発を公式方針として導入した。
- **2026年7月30日**: **ownCloud 11.0.0 正式リリース**。PHP 8.3 が最低要件になり、
  セキュリティ修正 11 件を含む。プレアルファから 3 ヶ月ほどで安定版に到達した。
- **2026年9月25日**: **ownCloud 11.0.1** セキュリティリリース(ImageMagick プレビュー強化 2 件と
  appconfig パストラバーサル RCE 修正)。同日 10.16.5、10月6日 10.16.6 も出ており **10.x 系も並行して
  活発に保守**されている。11.0.0 で問題化した tarball 同梱物の整理(#41824)も 11.0.1 で解決した。

PHP 8 対応が遅れたのはリソース不足というより「Classic は捨てる予定だったので投資しなかった」
が実態で、買収と人材流出でその計画が崩れた結果、今になって対応を余儀なくされた格好。

## ownCloud 11.0.0 で変わったこと

### PHP 8.3 必須

`lib/base.php` の冒頭でハードチェックが入っている。

```php
if (PHP_VERSION_ID < 80300) { /* This version of ownCloud requires at least PHP 8.3.0 */ }
if (PHP_VERSION_ID >= 80600) { /* 8.6 以降は未サポート */ }
```

`composer.json` も `"php": ">=8.3"` / `config.platform.php = "8.3"`。
つまりサポート範囲は **PHP 8.3 / 8.4 / 8.5**。

### 配布方法が GitHub Releases に移った

`https://download.owncloud.com/server/stable/` は **10.16.3 で更新が止まっており**、
11.0.0 の tarball は置かれていない(10.16.4〜10.16.6 も同サイトで確認できず、2026-10-21 再確認済み)。
11.0.0 のアセットは GitHub Releases のみ:

```
https://github.com/owncloud/core/releases/download/v11.0.0/owncloud-11.0.0.tar.bz2
```

`.asc` / `.md5` / `.sha256` のサイドカー付き。リリースには 4 種類のバリアントがある
（`owncloud-<ver>` / `owncloud-<ver>-qa` / `owncloud-complete-<date>` / 同 `-qa`）ので、
素の Server 版だけを拾う必要がある。`60-owncloud.sh` では genpack-progs の
`get-github-download-url` に正規表現 `owncloud-[0-9.]+\.tar\.bz2$` を渡して選別している。

### その他の非互換

- **G2 コード署名**に移行。G1 署名は廃止され、`occ integrity:sign-app` /
  `integrity:sign-core` が削除された。G1 署名アプリは **2026-12-31T23:59:59Z を以って検証失敗**
  (検証のサンセットがコードにハードコード済み)。Marketplace 等のサードパーティアプリは
  2027 年までに G2 再署名版への乗り換えが必要。
- `occ db:convert-type` が削除。caching router も削除。
- グループ管理者機能が既定で無効になり、`allow_subadmins` で明示的に有効化する形になった。
- アップグレード元としてサポートされるのは 8.2.11 / 9.0.9 / 9.1 以降。

## このアーティファクトでの PHP 調達方法

### 現状: Gentoo の dev-lang/php:8.3（2026年8月〜）

`dev-lang/php` の amd64 安定版が 8.3 系で、プロファイル既定の `PHP_TARGETS` も `php8-3` の
ため、`dev-php/pecl-apcu` / `dev-php/pecl-redis` もそのまま乗る。

**mod_php ではなく php-fpm** を選び、`70_php_fpm.conf` の
`SetHandler "proxy:unix:/run/php-fpm/www.sock|fcgi://localhost"` で proxy_fcgi 経由に
繋いでいる。理由は 2 つ:

1. 旧構成（Remi の php-fpm + proxy_fcgi の unix socket）と同形なので apache 側の
   変更が最小で済む。
2. PHP が apache とは別プロセスになるので、apache の MPM 選択と PHP の ZTS 要否が
   独立する。ZTS 版が Portage に無い pecl 拡張をそのまま使える。

姉妹アーティファクトの `nextcloud` は mod_php を選んだ結果、pecl-imagick が ZTS 非対応
なので prefork MPM に固定せざるを得なくなっている。

### MPM は event

上記 2. の恩恵で、apache は **event MPM**（threaded）にしてある。apache 自体は静的
ファイル配信と fcgi プロキシしかしないので、1 接続 1 プロセスの prefork には何の意味も
なかった。実測でアイドル時 7 プロセス / 62.1 MiB → 4 プロセス / 45.5 MiB。

MPM は**ビルド時に決まる**点に注意。`apache-2.eclass` の `setup_mpm()` が
`--with-mpm=` を渡して静的リンクするので、実行時のスイッチでは変えられない。

```
APACHE2_MPMS に event/worker/prefork のいずれかを指定 → それを使う
指定なし ┬ USE=threads あり → DEFAULT_MPM_THREADED = event
         └ USE=threads なし → prefork
```

PHP 7.4 時代は `APACHE2_MPMS` 未指定・`threads` 無しだったので prefork にフォールバック
していた。現在は `genpack.json5` で `threads` と `APACHE2_MPMS: event` を明示している
（threaded MPM は `REQUIRED_USE` で `threads` を要求する）。`dev-libs/apr` には
`threads` USE 自体が無いので、他に触る箇所はない。

### HTTP/2 は無効のまま

**mod_http2 はビルドされているが読み込まれていない**（PHP 7.4 時代から変わらず）。
`41_mod_http2.conf` は入っているものの、httpd.conf の `LoadModule http2_module` が
`<IfDefine HTTP2>` で囲まれており、`APACHE2_OPTS` に `-D HTTP2` が付いていないため。
`genpack/base` の `apache.sh` が足すのは `-D PROXY -D DAV` のみ。

`-D HTTP2` は mod_http2 をロードするかどうかを決めるだけで、MPM とは無関係。
ただし MPM が event になったので、有効にしたければ `-D HTTP2` を足すだけでよくなった
（prefork との併用は `apache-2.eclass` が
`apache2_mpms_prefork? ( !apache2_modules_http2 )` で禁じている組み合わせだった）。

SMB 外部ストレージ用の **smbclient 拡張だけは Portage に無い**ので、`50-php.sh` で
`pecl install` している（`nextcloud` と同じ手口。ビルド時に `dev-build/autoconf` が要る）。

### 旧方式: Remi リポジトリの RPM 展開（2026年8月に廃止）

11.0.0 移行前は `50-php74.sh` で以下の力技をやっていた。履歴の参考として残す。

1. **Remi リポジトリ**（EL9向け）から `php74-*` の RPM を `get-rpm-download-url` で最新版取得
2. 依存ライブラリを CentOS Stream 9 / EPEL / Fedora 39 アーカイブから個別取得
3. `rpm2targz` で展開し、`patchelf` で rpath を書き換えて Gentoo 環境で動かす

これに伴い `app-arch/rpm2targz` / `dev-util/patchelf` の buildtime_packages と、
RPM の共有ライブラリ依存を埋めるための `media-libs/libaom` などの明示指定も不要になった。

なお Remi（Remi Collet 氏）の PHP 7.4 バックポートは
[php-src-security](https://github.com/remicollet/php-src-security) の
`PHP-7.4-security-backports` ブランチで継続しているが「best effort、spare time ベース、
無保証」であり、そこから降りられたのは大きい。

### ownCloud Docker イメージが使っていた PHP 7.4 の正体

ownCloud の公式 Docker イメージ（`owncloud-docker/php`）は **Freexian** の商用 PHP LTS
サービス（`php.freexian.com`）を使用していた。Remi とは別物で、
ownCloud が Pro/Enterprise 契約を結んで顧客への再配布権を得ている形。
外部から自由に使えるものではなかったため、当時は Remi を使うのが妥当だった。

## このアーティファクトに関係するセキュリティ修正(2026-10-21 調査)

2026年4〜10月は公式 GHSA アドバイザリ(owncloud/security-advisories)の公開ラッシュの期間だったが、
その多くは「旧バージョンで修正済みで正式開示が後から行われた」ものか、このアーティファクトの素の構成
(11.0.0、php-imagick 無し、外部ストレージは SMB のみ)で該当しないものだった。
ここに記すのはこのインスタンスに関係するものだけで、他は
https://github.com/owncloud/security-advisories を参照。

### 11.0.0 がクリティカル級の修正はすべて内包している

- Critical 級 9.1 のもの(CVE-2025-27844 コードインジェクション、CVE-2026-58274 逆シリアル化、
  CVE-2025-53827 Updater の危険メソッド露出)はいずれも管理者権限前提で 10.15.1/10.15.2 で修正済み、
  11.0.0 に継承されている。
- CVE-2026-70644(認証ユーザー→サーバー上の任意ファイル読取, 7.7)は 10.16.1 で修正済み、継承。
- CVE-2026-23989(oCIS の公開リンクスコープ不備, 8.2)は Classic 構成なので無関係。

### 11.0.1 で塞がる、この構成に該当する未修正分

1. **ImageMagick プレビュー強化**(#41827/#41834): 不正な SVG/MVG が ImageMagick に素で届き、
   Web サーバ特権での任意ファイル読書/書込への経路になる。このアーティファクトは php-imagick を
   入れていないため現時点では攻撃面なし。preview 用に imagick を追加した瞬間に critical 化する。
2. **appconfig `public_`/`remote_` キーのパストラバーサル→RCE**(#41856、10.16 系では #41803):
   管理者権限前提。単一管理者のインスタンスでは実リスクは低い。
3. **依存更新**: guzzle 7.15.2→7.15.5(advisory 13 件クローズ、CVE-2026-69246 ホスト検証バイパス 7.2 含む)、
   phpseclib 3.0.55→3.0.57(CVE-2026-55599 SSRF は SFTP 外部ストレージ経由。SMB のみの本構成では非該当)。
4. **occ の `config:*:set` がシークレットを stdout に出さない**(#41779):
   ビルドスクリプトで occ 経由の鍵をセットする場合のログ漏洩衛生。

緊急パッチを要するクリティカルは現状無い。次期ビルドで 11.0.1 に追随するのが妥当(積み残し参照)。

## 積み残し

- **アーティファクトの 11.0.1 追随**: 11.0.1 はセキュリティ修正 3 件 + tarball のスリム化
  (アプリ 13 個が `.git/`・テスト・build 成果物ごと同梱されていた問題が解消、ClamAV での
  Eicar 誤検出も消える)を含む。バージョン正規表現 `owncloud-[0-9.]+\.tar\.bz2$` はそのまま有効。
  次期ビルドで 11.0.0 → 11.0.1 に上げる。
- **G1 署名サンセット(2026-12-31)**: Marketplace 由来等の G1 署名アプリは 2027 年以降
  `occ integrity:check-app` で失敗する。アプリ導入・更新は G2 再署名済みバージョンで行うこと。

- **igbinary / msgpack シリアライザ**: Remi 版では `php-pecl-igbinary` /
  `php-pecl-msgpack` を入れて redis のシリアライザに使えるようにしていたが、
  Portage に `dev-php/pecl-igbinary` / `dev-php/pecl-msgpack` が無いため落とした。
  `dev-php/pecl-redis` の既定シリアライザ（PHP 標準）で動作する。
- **PHP 8.4 / 8.5 への追随**: ownCloud 11 は 8.5 まで許容するが、Portage の 8.4 / 8.5 は
  まだ `~amd64`。安定化されたら `PHP_TARGETS` ごと上げるか検討する。
- **初回起動時に owncloud.log に出る 2 種のエラー**（いずれも非致命的で、実行時には再現しない）:
  - `PHP: preg_match(): Allocation of JIT memory failed, PCRE JIT will be disabled` —
    `owncloud-init` が `apache2.service` の `ExecStartPre` で走り、そのユニットに
    `MemoryDenyWriteExecute=true` が付いているため PCRE JIT が実行可能メモリを取れない。
    php-fpm は別ユニットでこの制限が無いので、リクエスト処理時には発生しない。
    気になるなら `owncloud-init.conf` で `MemoryDenyWriteExecute=no` を上書きするか
    `pcre.jit=0` を CLI 側の php.ini に入れる。
  - `mysql.setup: Specific user creation failed: ... SELECT command denied to user
    'owncloud'@'localhost' for table 'user'` — `60-owncloud.sh` が先に DB ユーザを
    作っているのに ownCloud のインストーラが自前でユーザを作ろうとして `mysql.user` を
    読めずに失敗している。インストール自体は成功する。

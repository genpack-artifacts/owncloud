# PHP 7.4 と ownCloud の現状メモ

最終更新: 2026-06-25

## ownCloud Classic の PHP 事情

### なぜ PHP 7.4 のままなのか

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

PHP 8 対応が遅れたのはリソース不足というより「Classic は捨てる予定だったので投資しなかった」
が実態で、買収と人材流出でその計画が崩れた結果、今になって対応を余儀なくされた格好。

### PHP 8 対応の現状（2026年6月時点）

- ownCloud 10.x 系（最新: 10.16.3）は依然 **PHP 7.4 必須**
- ownCloud 11.0.0 は **プレアルファ**（Docker Hub のみ）、PHP 8.3 対応
- 10.x 系に PHP 8 が入る見込みはなく、11 の安定版リリース時期も不透明

## このアーティファクトでの PHP 7.4 調達方法

### 現状: Remi リポジトリの RPM を展開

`50-php74.sh` で行っている力技：

1. **Remi リポジトリ**（EL9向け）から `php74-*` の RPM を `get-rpm-download-url` で最新版取得
2. 依存ライブラリを CentOS Stream 9 / EPEL / Fedora 39 アーカイブから個別取得
3. `rpm2targz` で展開し、`patchelf` で rpath を書き換えて Gentoo 環境で動かす

`get-rpm-download-url` は `repomd.xml` → `primary.xml` を解析して**常に最新版を自動追従**する
ため、Remi が新しいバックポートをリリースすれば自動的に拾う。

### ownCloud Docker イメージが使っている PHP 7.4 の正体

ownCloud の公式 Docker イメージ（`owncloud-docker/php`）は **Freexian** の商用 PHP LTS
サービス（`php.freexian.com`）を使用している。Remi とは別物で、
ownCloud が Pro/Enterprise 契約を結んで顧客への再配布権を得ている形。
外部から自由に使えるものではないため、このアーティファクトでは Remi を使うのが妥当。

### Remi の PHP 7.4 バックポートの持続性

Remi（Remi Collet 氏）は [php-src-security](https://github.com/remicollet/php-src-security)
リポジトリで `PHP-7.4-security-backports` ブランチを管理しており、
PHP 8.x 系からの CVE 修正を cherry-pick し続けている（2026年6月時点でも現役）。

ただし「**best effort、spare time ベース、無保証**」と本人が明言しており、
いつ止まってもおかしくない。EL7 向けはすでに `-15` で更新が途絶えており、
EL8 / EL9 / EL10 向けは `-26` で並走中。このアーティファクトは EL9 を使用。

### ebuild 化の検討

Portage にはすでに PHP 7.4 の ebuild が存在せず（8.2 以降のみ）、
Remi のバックポートもパッチファイルではなくフルソースフォークであるため、
ebuild を作るにはゼロから書く必要があり、Remi のブランチを追い続ける運用コストも発生する。
ownCloud 11 の安定版リリース時期が不透明な現状では、現行の RPM 展開方式を維持する
コストパフォーマンスが相対的に高い。

## 今後の移行判断の目安

- **ownCloud 11 安定版がリリースされたら**: PHP 8.3 対応版への切り替えを検討。
  `50-php74.sh` と `50-php74.sh` 関連の `buildtime_packages`（`app-arch/rpm2targz`、
  `dev-util/patchelf`）をまとめて廃止できる。
- **Remi のバックポートが止まったら**: ownCloud 11 安定版を待てるか、
  あるいは OpenCloud（oCIS フォーク）への移行を検討する岐路になる。

#!/bin/sh
# owncloud ログインユーザー関連の配置・権限の確定。
# Upper フェーズの users 作成 & files コピーの後 (build.d) に root で実行される。
set -e

# --- sudoers.d/owncloud: occ 実行だけを NOPASSWD で許可 ---
# files/ コピーはモードを保証しないので 0440/root に確定し、visudo で検証する。
mkdir -p /etc/sudoers.d
grep -q '^@includedir /etc/sudoers.d' /etc/sudoers 2>/dev/null \
	|| printf '\n@includedir /etc/sudoers.d\n' >> /etc/sudoers
chown root:root /etc/sudoers.d/owncloud
chmod 0440 /etc/sudoers.d/owncloud
visudo -c >/dev/null

# --- /home/owncloud: 所有者と権限を確定 ---
chown -R owncloud:owncloud /home/owncloud
chmod 700 /home/owncloud
mkdir -p /home/owncloud/.ssh
chown owncloud:owncloud /home/owncloud/.ssh
chmod 700 /home/owncloud/.ssh
[ -f /home/owncloud/AGENTS.md ] && chmod 644 /home/owncloud/AGENTS.md
[ -f /home/owncloud/.bashrc ] && chmod 644 /home/owncloud/.bashrc

# owncloud ログインユーザーの .bashrc

# 対話シェルで AGENTS.md を目立たせる
if [ -n "$PS1" ] && [ -f "$HOME/AGENTS.md" ]; then
	printf '\n'
	printf '================================================================\n'
	printf '  ownCloud 運用ガイド:  ~/AGENTS.md\n'
	printf '  これは genpack イメージ: 前提として /.genpack/genpack.md を先に読むこと\n'
	printf '  occ 実行:  sudo occ <command>   (例:  sudo occ status)\n'
	printf '  全容は ~/AGENTS.md を cat してください。\n'
	printf '================================================================\n'
	printf '\n'
fi

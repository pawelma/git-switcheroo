demo_root=/tmp/switcheroo-demo
switcheroo_root=$(pwd)
rm -rf "$demo_root"
mkdir -p "$demo_root/config/git-switcheroo"

export GIT_CONFIG_GLOBAL="$demo_root/gitconfig"
export XDG_CONFIG_HOME="$demo_root/config"
export PATH="$switcheroo_root/bin:$PATH"
git config --global user.name "Demo"
git config --global user.email "demo@example.com"
git config --global alias.co checkout
echo 'commands="co"' >"$XDG_CONFIG_HOME/git-switcheroo/config"

git init -q -b main "$demo_root/shop"
cd "$demo_root/shop"
printf 'button: "Log in"\n' >login.yml
git add login.yml
git commit -qm "Initial shop"
git worktree add -q -b feature-login "$demo_root/shop-agent-login"
printf 'button: "Log in with a passkey"\n' >"$demo_root/shop-agent-login/login.yml"
git -C "$demo_root/shop-agent-login" commit -qam "Add passkey login"
PS1='\W $ '
[ "${1:-}" = with-switcheroo ] && . "$switcheroo_root/shell/git-switcheroo.sh"

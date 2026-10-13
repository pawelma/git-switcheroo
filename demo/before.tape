Output demo/before.gif
Set Shell "bash"
Set FontSize 22
Set Width 1200
Set Height 460
Set Padding 24
Set Theme "Catppuccin Mocha"
Set TypingSpeed 45ms

Hide
Type "source demo/setup.sh" Enter
Sleep 2s
Type "clear" Enter
Sleep 1s
Show

Type "# agent finished feature-login in its own worktree, let's test it" Enter
Sleep 800ms
Type "git co feature-login" Enter
Sleep 2s
Type "cat login.yml" Enter
Sleep 1.5s
Type "# ...still on main. the checkout failed and we're testing the wrong code" Enter
Sleep 3s

if status is-interactive
    set -l config_home $HOME/.config
    set -q XDG_CONFIG_HOME; and set config_home $XDG_CONFIG_HOME
    set -g __switcheroo_commands sr
    if test -r $config_home/git-switcheroo/config
        set -a __switcheroo_commands (string match -r '^commands=.*' <$config_home/git-switcheroo/config | string replace 'commands=' '' | string trim -c '"' | string split -n ' ')
    end

    function git
        if test (count $argv) -eq 0; or not contains -- $argv[1] $__switcheroo_commands; or not command -q git-switcheroo
            command git $argv
            return
        end
        set -l tmp_dir /tmp
        set -q TMPDIR; and set tmp_dir $TMPDIR
        set -l cd_file (mktemp $tmp_dir/git-switcheroo.XXXXXX); or return 1
        SWITCHEROO_CD_FILE=$cd_file command git-switcheroo $argv
        set -l rc $status
        if test -s $cd_file
            cd (cat $cd_file); or set rc 1
        end
        rm -f $cd_file
        return $rc
    end
end

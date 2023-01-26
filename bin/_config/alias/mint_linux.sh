# mint linux hacks

## display settings
function display1920() {
    model_list="173.00 1920 2048 2248 2576 1080 1083 1088 1120"

    # define new mode
    xrandr --newmode "1920x1080_60.00" ${model_list} -hsync +vsync

    # add new mode:
    xrandr --addmode VGA-1 "1920x1080_60.00"
}

alias vscode="$HOME/Application/vscodium/codium &"

function mintm() {
    echo "mint linux hacks"
    echo "--------------------"
    echo "  display1920: set 1920x1080 display resolution"
    echo "  vscode: start latest vscodium from local Application folder"
}

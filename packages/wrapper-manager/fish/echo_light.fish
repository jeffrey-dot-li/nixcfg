function echo_light
    # Arguments:
    #   $argv[1]: prefix (displayed in normal color)
    #   $argv[2]: text (displayed in light grey)
    
    if test (count $argv) -lt 2
        echo "Usage: echo_light prefix text"
        return 1
    end
    
    echo -s $argv[1] " " (set_color 999999) $argv[2] (set_color normal)
end
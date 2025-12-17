function open_gs
    set -l gs_path $argv[1]
    # Remove 'gs://' prefix if present
    set gs_path (string replace -r '^gs://' '' $gs_path)
    # Remove trailing slash if present
    set gs_path (string trim -r -c '/' $gs_path)
    
    open "https://console.cloud.google.com/storage/browser/$gs_path"
end

function open
    if string match -q 'gs://*' $argv[1]
        open_gs $argv[1]
    else if type -q xdg-open  # For Linux
        xdg-open $argv
    else if type -q /usr/bin/open  # For macOS but not really because xdg-open is included in this derivation
        /usr/bin/open $argv
    end
end
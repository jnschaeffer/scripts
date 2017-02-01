#!/bin/sh
#
# see.sh - see active network connections on the system, grouped by process

# build_map runs netstat to get active connections, removes headers from the
# output, and pipes the output through awk to group connections by connecting
# process.
#
# on success, MAP_OUT will be set with the output of awk. MAP_ERR will be set
# to the error code of the pipe (0 if none).
build_map () {
  awk_prog='
  {
    counts[$7] += 1
    map[$7,counts[$7]] = sprintf("%s: %s (%s)", $1, $5, $6)
  } END {
    for (proc in counts) {
      printf("%s\n", proc)
      for (i=1; i<=counts[proc]; i++) {
        printf("\\t%s\\n", map[proc,counts[proc]])
      }
    }
  }'

  # show TCP, UDP, PID/program, and do not limit host width
  awk_args="-tupW"

  MAP_OUT=$(netstat $awk_args 2>/dev/null | tail -n"+3" | awk "$awk_prog")
  MAP_ERR=$?
}

# draw_header calculates the width of the terminal and draws the header for
# the program at the top of the terminal.
draw_header () {
  header="Network connections"

  if [ $(id -u) -ne 0 ]; then
    header=$(printf "%s (not being run as root)" "$header")
  fi
  
  num_spaces=$(( $(tput cols) - ${#header} ))
  
  tput cup 0 0
  printf "\033[44m\033[37m%s%${num_spaces}s\033[0m" "$header" " "
}

# draw_body draws up to ($(tput lines) - 2) lines of the network connection
# map on the screen after clearing all characters below the header.
draw_body () {
  map="$1"
  num_rows=$(( $(tput lines) - 2 ))

  tput cup 1 0

  truncated=$(echo "$map" | head -n$num_rows)

  clear_body
  printf "%s\n" "$truncated"
}

# clear_all sets the terminal cursor to (0, 0) and clears all characters.
clear_all () {
  tput cup 0 0
  tput ed
}

# clear_body sets the terminal cursor to (1, 0) and clears all characters.
clear_body () {
  tput cup 1 0
  tput ed
}

# setup clears the screen and draws the header.
setup () {
  clear_all
  draw_header
}

# trap to redraw the screen on resize.
trap setup WINCH

# run setup
setup

# build the map and draw it as long as there are no errors from awk or netstat.
# refreshes every second.
while true; do
  build_map
  if [ $MAP_ERR -ne 0 ]; then
    exit $MAP_ERR
  fi
  
  draw_body "$MAP_OUT"
  sleep 1 &
  wait
done

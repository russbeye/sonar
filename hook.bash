# Sonar's bash hook. Inside tmux it hands the shell's state to the tmux status
# row, which runs outside this shell and cannot see its exit code, jobs or
# environment. Outside tmux it prints the Sonar line above the prompt itself.
#
# Starship already measures each command, so we read its STARSHIP_CMD_STATUS
# and STARSHIP_DURATION instead of timing commands a second time. That is why
# this hook has to run after starship_precmd in PROMPT_COMMAND.

_sonar_dir="${XDG_RUNTIME_DIR:-/tmp}/sonar/pane"
mkdir -p "$_sonar_dir"
_sonar_last_end=""
if [[ -n $TMUX_PANE ]]; then
  _sonar_key=${TMUX_PANE#%}
else
  _sonar_key=sh$$
  trap 'rm -f "$_sonar_dir/$_sonar_key"' EXIT
fi

_sonar_precmd() {
  local st="" ms="" n=0 j
  # STARSHIP_END_TIME only changes when a command ran. A bare Enter keeps the
  # old values, and we must not report the old failure as a new one.
  if [[ -n ${STARSHIP_END_TIME-} && $STARSHIP_END_TIME != "$_sonar_last_end" ]]; then
    _sonar_last_end=$STARSHIP_END_TIME
    st=$STARSHIP_CMD_STATUS ms=$STARSHIP_DURATION
  elif [[ -f $_sonar_dir/$_sonar_key ]]; then
    { read -r st; read -r ms; } < "$_sonar_dir/$_sonar_key"
  fi
  for j in $(jobs -p); do ((n++)); done
  printf '%s\n' "$st" "$ms" "$n" "${AWS_PROFILE-}" "${SSH_CONNECTION-}" "$PATH" \
    > "$_sonar_dir/$_sonar_key"
  if [[ -n $TMUX_PANE ]]; then
    # Redraw now so the bar does not wait for the next status-interval tick.
    tmux refresh-client -S 2>/dev/null
  else
    # A blank line, then Sonar, then the prompt. Starship's add_newline is off
    # so that the blank line sits above Sonar and not between Sonar and the prompt.
    printf '\n'
    ~/.local/bin/sonar prompt "$_sonar_key" "$PWD" "${COLUMNS:-140}"
  fi
}

PROMPT_COMMAND+=(_sonar_precmd)

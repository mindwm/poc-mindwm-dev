#!/usr/bin/env bash
#
set -euo pipefail

if [[ "${TMUX:-x}" == "x" ]]; then
  printf "Must be executed inside TMUX\n" >&2
  exit 1
elif [[ "${TMUX_PANE:-x}" == "x" ]]; then
  printf "Cannot get TMUX_PANE value\n" >&2
  exit 2
fi

socket=$(echo "${TMUX}" | cut -d',' -f1)
session=$(echo "${TMUX}" | cut -d',' -f3)
if [[ "${MINDWM_TMUX_TARGET_PANE:-x}" == "x" ]]; then
  pane="${TMUX_PANE//%/}"
else
  pane="${MINDWM_TMUX_TARGET_PANE//%/}"
fi

printf "mindwm.%s.%s.tmux.%s.%s.%s.%s\n" \
  "$(whoami)" \
  "$(hostname)" \
  "$(printf '%s' "${socket}" | base64 )" \
  "${MINDWM_SESSION_ID}" \
  "${session}" \
  "${pane}"


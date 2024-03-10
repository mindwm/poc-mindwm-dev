#!/usr/bin/env bash
set -euo pipefail

subject_prefix="$(operable-current-subject)"
export MINDWM_TMUX="${TMUX}"
export MINDWM_CLIENT_NATS_SUBJECT_WORDS_IN="${subject_prefix}.words_in"
export MINDWM_CLIENT_NATS_SUBJECT_WORDS_OUT="${subject_prefix}.words_out"

pushd ./mindwm-manager/src >/dev/null 1>&2
python3 ./main.py
popd >/dev/null 2>&1

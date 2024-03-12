#!/usr/bin/env bash
set -euo pipefail

export MINDWM_CLIENT_VECTOR_UDP_HOST="127.0.0.1"
export MINDWM_CLIENT_VECTOR_UDP_PORT="32020"
export MINDWM_BACK_NATS_HOST="127.0.0.1"
export MINDWM_BACK_NATS_PORT="4222"
export MINDWM_BACK_NATS_SUBJECT_WORDS_IN="$(operable-current-subject).words"
export MINDWM_CLIENT_NATS_SUBJECT_FEEDBACK="$(operable-current-subject).feedback"

printf "Backend NATS subject: %s" "${MINDWM_BACK_NATS_SUBJECT_WORDS_IN}\n"

pushd ./mindwm-manager/src >/dev/null 2>&1
python3 ./main.py
popd >/dev/null 2>&1

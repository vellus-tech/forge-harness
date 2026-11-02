#!/usr/bin/env bash
# git substituto para os gates do /forge:kb: registra o subcomando em $FAKE_GIT_LOG e delega ao git
# real ($REAL_GIT). O gate confere que a busca só chama `rev-parse`.
args=("$@"); sub=""
i=0; while [ $i -lt ${#args[@]} ]; do a="${args[$i]}"; case "$a" in -C|-c) i=$((i + 2)); continue ;; -*) i=$((i + 1)); continue ;; *) sub="$a"; break ;; esac; done
echo "${sub:-?}" >> "${FAKE_GIT_LOG:?}"
exec "${REAL_GIT:?}" "$@"

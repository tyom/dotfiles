#!/bin/bash

# gb and gl colour commit authors once a repo has more than a few of them, and
# both must land on the same colour for the same name.

set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

fail() { echo " ✖ $1"; exit 1; }

mkdir -p "$TMP/bin"
printf '#!/bin/bash\ncat\n' >"$TMP/bin/less"
chmod +x "$TMP/bin/less"

commit() { # repo, author, message
  echo "$3" >>"$1/file"
  git -C "$1" add file
  git -C "$1" -c user.name="$2" -c user.email="${2// /.}@example.com" \
    commit -qm "$3" --no-gpg-sign
}

run() { # repo, command, args...
  local repo=$1 cmd=$2
  shift 2
  (cd "$repo" && PATH="$TMP/bin:/usr/bin:/bin" "$ROOT/home/bin/$cmd" "$@")
}

# The colour code right before a name, empty when the name is not coloured.
# All bash, so a name holding a backslash or a bracket stays a plain string
color_of() { # output, name
  local before=${1%%"$2"*}
  before=${before##*$'\033['}
  # A plain name is not a failure, so the caller keeps its exit status
  [[ "$before" == 38\;5\;*m ]] || return 0
  printf '%s' "${before%m}"
}

# One author per colour on the trunk, plus one who commits before all of them
# and so is last in line when the colours are handed out, plus one that only
# ever exists on an orphan branch and never reaches the sample at all. The
# last two have to come out plain
crowd="$TMP/crowd"
git init -q -b main "$crowd"
# As many people as the palette has colours, so a palette too short to give
# them one each fails here rather than on a busy repo
read -ra palette < <(sed -n 's/^AUTHOR_COLORS=(\(.*\))$/\1/p' "$ROOT/home/bin/gb")
# Sized from the palette, so pin the size too: a palette cut to four colours
# would otherwise build four authors and pass
((${#palette[@]} == 24)) || fail "the palette holds ${#palette[@]}, not 24"
# A backslash is what awk reads an escape sequence out of, so gl has to carry
# this name to its colour by a route that does not. A tab is what the colours
# are written out with, so a name holding one has to survive the round trip
authors=('José Ñuñez' 'Back\bslash' $'Tab\tAuthor')
while ((${#authors[@]} < ${#palette[@]})); do
  # Zero padded so no name is a prefix of another and the grep below cannot
  # read one author colour off another author line
  printf -v name 'Dev %02d' "${#authors[@]}"
  authors+=("$name")
done
# Commits first, so every colour is spoken for by the time it asks
overflow='Early Bird'
branch=0
for author in "$overflow" "${authors[@]}"; do
  commit "$crowd" "$author" "work by $author"
  # gb lists branches, so each author needs one for their name to show up.
  # Numbered, because a name is not always a legal ref
  git -C "$crowd" branch "author-$((branch++))"
done
git -C "$crowd" switch -q --orphan stale
commit "$crowd" 'Zoe Orphan' 'stale work'
git -C "$crowd" switch -q main

gb_out=$(run "$crowd" gb)
gl_out=$(run "$crowd" gl --all)

seen=""
for author in "${authors[@]}"; do
  gb_color=$(color_of "$gb_out" "$author")
  gl_color=$(color_of "$gl_out" "$author")
  [[ -n "$gb_color" ]] || fail "gb leaves $author uncoloured"
  [[ "$gb_color" == "$gl_color" ]] ||
    fail "gb and gl disagree on $author: $gb_color vs $gl_color"
  # The colour has to close again, or it bleeds into the subject
  [[ "$gl_out" == *"$gl_color"m"$author"$'\033[37m'* ]] ||
    fail "gl leaves $author's colour open"
  [[ "$seen" != *"[$gb_color]"* ]] ||
    fail "$author shares a colour with another"
  seen="${seen}[$gb_color]"
done

# No colour left, and no place in the list at all: both stay the plain white
for author in "$overflow" 'Zoe Orphan'; do
  [[ "$gb_out" == *$'\033[37m'"$author"* ]] || fail "gb colours $author"
  [[ "$gl_out" == *$'\033[37m'"$author"* ]] || fail "gl colours $author"
done

# macOS ships bash 3.2 and these dotfiles do not install another, so gb has to
# hold to it. An associative array or a mapfile would die here. Compare one
# colour, not the whole output: the relative dates move between two runs
old_bash=$(cd "$crowd" && PATH="$TMP/bin:/usr/bin:/bin" /bin/bash "$ROOT/home/bin/gb")
[[ "$(color_of "$old_bash" "${authors[0]}")" == "$(color_of "$gb_out" "${authors[0]}")" ]] ||
  fail 'gb needs a bash newer than the one macOS ships'

# Someone gets used to a colour on a branch they live on, so a new name must
# not move it. That is what the store in .git is for: work the colours out
# afresh on every run and the newcomer walks in ahead of half of them
before=$(color_of "$gb_out" "${authors[0]}")
commit "$crowd" 'Newcomer Late' 'work by a name nobody has seen'
commit "$crowd" 'Newcomer Late' 'and more of it'
[[ "$(color_of "$(run "$crowd" gb)" "${authors[0]}")" == "$before" ]] ||
  fail 'a new author moved an existing colour'

# A colour is not held for ever by someone who has gone. Hand every one of
# them to a name this repo has never heard of, and the people who are actually
# here have to get them back
store=$crowd/.git/author-colors
for i in "${!palette[@]}"; do printf '%s\tGhost %s\n' "$i" "$i"; done >"$store"
# The newest name is first in line, so it is the one to look for
[[ -n "$(color_of "$(run "$crowd" gb)" 'Newcomer Late')" ]] ||
  fail 'a colour never came back from an author who has gone'
grep -q Ghost "$store" && fail 'the departed are still holding colours'

# Below the threshold the author stays the plain white it has always been
solo="$TMP/solo"
git init -q -b main "$solo"
commit "$solo" 'Ada Lovelace' 'solo work'

white=$'\033[37mAda Lovelace'
[[ "$(run "$solo" gb)" == *"$white"* ]] || fail 'gb colours a solo repo'
[[ "$(run "$solo" gl)" == *"$white"* ]] || fail 'gl colours a solo repo'

echo ' ✔ gb and gl give each author the same colour once a repo has a crowd'

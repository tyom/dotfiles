# shellcheck shell=bash
# Checklist menu. Entries are "name|description|on/off" (on = pre-checked).
# Toggle by number, Enter confirms, q quits. Checked names land in CHECKED.
# YES_OVERRIDE checks everything, SELECT_OVERRIDE checks a named list, and with
# no tty neither prompting nor drawing the menu is possible, so the defaults win.
function multi_select {
  local title="$1" entry i n
  shift
  local names=() descs=() states=()
  for entry in "$@"; do
    names+=("${entry%%|*}")
    entry="${entry#*|}"
    descs+=("${entry%%|*}")
    states+=("${entry#*|}")
  done
  n=${#names[@]}

  # -e /dev/tty is true even with no controlling terminal, so open it instead
  # (same check as link.sh). A container started without -t has the device node
  # but the open fails, and the menu then read that failure as a confirming
  # keypress — which is how CI installs quietly fell back to the defaults.
  local has_tty=true
  : 2>/dev/null </dev/tty || has_tty=false

  if $YES_OVERRIDE || [[ -n "$SELECT_OVERRIDE" ]] || ! $has_tty; then
    CHECKED=()
    for ((i = 0; i < n; i++)); do
      if [[ -n "$SELECT_OVERRIDE" ]]; then
        [[ ",$SELECT_OVERRIDE," == *",${names[i]},"* ]] && CHECKED+=("${names[i]}")
      elif $YES_OVERRIDE || [[ "${states[i]}" == "on" ]]; then
        CHECKED+=("${names[i]}")
      fi
    done

    # A typo would otherwise skip the thing it named without a word about it.
    for entry in ${SELECT_OVERRIDE//,/ }; do
      is_checked "$entry" || {
        print_error "Unknown option '$entry'. Available: ${names[*]}"
        exit 1
      }
    done

    print_step "$title"
    print_info "Selected: ${CHECKED[*]:-nothing}"
    return 0
  fi

  local drawn=false key box
  while true; do
    $drawn && printf "\r\e[%dA" $((n + 1))
    drawn=true
    print_step "$title"
    for ((i = 0; i < n; i++)); do
      box=' '
      [[ "${states[i]}" == "on" ]] && box='✔'
      printf '   \e[0;33m%d\e[0m [\e[0;32m%s\e[0m] \e[0;36m%-22s\e[0m %s\e[K\n' \
        $((i + 1)) "$box" "${names[i]}" "${descs[i]}"
    done
    printf " Toggle \e[0;33m1-%d\e[0m, \e[0;32mEnter\e[0m to install, \e[0;31mq\e[0m to quit \e[K" "$n"
    read -n 1 -s key </dev/tty || key=''
    case "$key" in
    '') echo; break ;;
    [qQ])
      echo
      exit 0
      ;;
    [1-9])
      i=$((key - 1))
      if ((i < n)); then
        [[ "${states[i]}" == "on" ]] && states[i]="off" || states[i]="on"
      fi
      ;;
    esac
  done

  CHECKED=()
  for ((i = 0; i < n; i++)); do
    [[ "${states[i]}" == "on" ]] && CHECKED+=("${names[i]}")
  done
}

function is_checked {
  local x
  for x in "${CHECKED[@]}"; do
    [[ "$x" == "$1" ]] && return 0
  done
  return 1
}

function print_step {
  printf "\e[0;36m ▶ \e[0m$1\n"
}

function print_question {
  printf "\e[0;33m ⁇ $1\e[0m"
}

function print_info {
  printf "\e[0;35m » $1\e[0m\n"
}

function print_skip {
  printf "\e[0;33m ○ $1\e[0m\n"
}

function print_success {
  printf "\e[0;32m ✔ $1\e[0m\n"
}

function print_error {
  printf "\e[0;31m ✖ $1 $2\e[0m\n"
}

function print_warning {
  printf "\e[0;33m ⚠ $1\e[0m\n"
}

# True when live symlink $2 lands inside directory $1. Resolved against the
# link's own directory, because installs made with GNU Stow wrote relative
# targets. Comparing to the whole path, not just the prefix: a prefix match
# would also claim links into a sibling checkout such as <repo>-old.
function normalize_absolute_path {
  local path="$1" segment normalized=
  [[ "$path" == /* ]] || return 1
  path=${path#/}

  while [ -n "$path" ]; do
    segment=${path%%/*}
    if [ "$path" = "$segment" ]; then
      path=
    else
      path=${path#*/}
    fi

    case "$segment" in
    '' | .) ;;
    ..) normalized=${normalized%/*} ;;
    *) normalized="$normalized/$segment" ;;
    esac
  done

  printf '%s\n' "${normalized:-/}"
}

function resolve_dangling_absolute_path {
  local path="$1" prefix suffix='' segment physical
  [[ "$path" == /* ]] || return 1
  prefix=${path%/}
  [ -n "$prefix" ] || prefix=/

  while [ ! -d "$prefix" ]; do
    # A non-directory component cannot lead to the missing suffix. A dangling
    # symlink is also unsafe to infer through, so leave the link unclaimed.
    if [ -e "$prefix" ] || [ -L "$prefix" ]; then
      return 1
    fi
    [ "$prefix" != / ] || return 1

    segment=${prefix##*/}
    if [ -n "$suffix" ]; then
      suffix="$segment/$suffix"
    else
      suffix=$segment
    fi
    prefix=${prefix%/*}
    [ -n "$prefix" ] || prefix=/
  done

  physical=$(cd "$prefix" && pwd -P) || return 1
  normalize_absolute_path "$physical${suffix:+/$suffix}"
}

function links_into {
  local dir raw repo target
  raw=$(readlink "$2") || return 1

  # link.sh writes absolute targets. For a dangling one, resolve its longest
  # existing directory prefix before deciding ownership. Relative links need a
  # live target because a moved checkout cannot be identified safely.
  if [ ! -e "$2" ] && [[ "$raw" == /* ]]; then
    repo=$(cd "$1" && pwd -P) || return 1
    target=$(resolve_dangling_absolute_path "$raw") || return 1
    [[ "$target" == "$repo" || "$target" == "$repo"/* ]]
    return
  fi

  dir=$( (cd "$(dirname "$2")" && cd "$(dirname "$(readlink "$2")")" && pwd -P) 2>/dev/null)
  [[ "$dir" == "$1" || "$dir" == "$1"/* ]]
}

# Download a reviewed bootstrap script and reject any bytes that differ from the
# checksum committed beside its pinned version. The caller decides how to run it.
function download_verified {
  local url="$1" expected="$2" output="$3" actual

  if ! curl -fsSL "$url" -o "$output"; then
    print_error "Download failed: $url"
    rm -f "$output"
    return 1
  fi

  if command -v shasum >/dev/null 2>&1; then
    actual=$(shasum -a 256 "$output" | awk '{print $1}')
  elif command -v sha256sum >/dev/null 2>&1; then
    actual=$(sha256sum "$output" | awk '{print $1}')
  else
    print_error 'Cannot verify download: shasum or sha256sum is required'
    rm -f "$output"
    return 1
  fi

  if [ "$actual" != "$expected" ]; then
    print_error "Checksum verification failed: $url"
    rm -f "$output"
    return 1
  fi
}

function which_os {
  declare -r OS_NAME="$(uname -s)"
  local os=""

  if [ "$OS_NAME" == "Darwin" ]; then
    os="macos"
  elif [ "$OS_NAME" == "Linux" ]; then
    if [[ -f /etc/debian_version ]]; then
      os="debian"
    elif [[ -f /etc/redhat-release ]]; then
      os="redhat"
    else
      os="linux"
    fi
  fi
  printf $os
}

exists() {
  command -v $1 >/dev/null 2>&1
}

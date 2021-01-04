#!/usr/bin/env bash

# Bash strict mode: http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -o nounset   # Using an undefined variable is fatal
set -o errexit   # A sub-process/shell returning non-zero is fatal
# set -o pipefail  # If a pipeline step fails, the pipelines RC is the RC of the failed step
# set -o xtrace    # Output a complete trace of all bash actions; uncomment for debugging

# IFS=$'\n\t'  # Only split strings on newlines & tabs, not spaces.

usage() {
  cat <<EOF

Create new project

${bld}USAGE${off}
  $(basename "${BASH_SOURCE[0]}") [options] NAME

${bld}OPTIONS${off}
  -h, --help       show this help
  -p, --project    make the project public by creating a Github repository
  -t, --todo       make the project pending, by creating it in the "$HOME/projects/_todo/" folder

${bld}ARGUMENTS${off}
  NAME   the name of the new project

${bld}EXAMPLES${off}
  ${gry}# Create a new project called "test project"${off}
  $ $(basename "${BASH_SOURCE[0]}") test project
  
  ${gry}# Create a new public project called "test project"${off}
  $ $(basename "${BASH_SOURCE[0]}") --public test project
EOF
  exit
}

setup_colors() {
  if [[ -t 2 ]] && [[ -z "${NO_COLOR-}" ]] && [[ "${TERM-}" != "dumb" ]]; then
    # Control sequences for fancy colours
    readonly red="$(tput setaf 1 2> /dev/null || true)"
    readonly grn="$(tput setaf 2 2> /dev/null || true)"
    readonly ylw="$(tput setaf 3 2> /dev/null || true)"
    readonly wht="$(tput setaf 7 2> /dev/null || true)"
    readonly gry="$(tput setaf 240 2> /dev/null || true)"
    readonly bld="$(tput bold 2> /dev/null || true)"
    readonly off="$(tput sgr0 2> /dev/null || true)"
  else
    readonly red=''
    readonly grn=''
    readonly ylw=''
    readonly wht=''
    readonly gry=''
    readonly bld=''
    readonly off=''
  fi
}

msg() {
  echo >&2 -e "${1-}"
}

die() {
  local msg=$1
  local code=${2-1} # default exit status 1
  msg "$msg"
  exit "$code"
}

slugify() {
  tr -s ' ' | tr ' A-Z' '-a-z' | tr -s '-' | tr -c '[:alnum:][:cntrl:].' '-'
}

trim() {
  # Merge all passed in arguments into $var
  local var="$*"
  # remove leading whitespace characters
  var="${var#"${var%%[![:space:]]*}"}"
  # remove trailing whitespace characters
  var="${var%"${var##*[![:space:]]}"}"   
  printf '%s' "$var"
}

setup_colors

if ! command -v git &> /dev/null
then
  die "git could not be found\n\
    ${BASH_SOURCE[0]} requires git\n\
    See: https://git-scm.com/" 127
fi
if ! command -v gh &> /dev/null
then
  die "gh could not be found\n\
    ${BASH_SOURCE[0]} requires gh - Github CLI\n\
    See: https://cli.github.com/" 127
fi


if [[ $# == 0 ]]; then
  msg "Missing parameter: Project name."
  usage
fi

function parse_params() {
  local param
  while [[ $# -gt 0 ]]; do
    param="$1"
    shift
    case $param in
      -h | --help | help)
        usage
        ;;
      -p | --public)
        public=true
        ;;
      -t | --todo)
        todo='_todo/'
        ;;
      *)
        new_project_name="${new_project_name:-} $param"
        ;;
    esac
  done
  new_project_name=$(trim $new_project_name)
  new_project_dir="$HOME/projects/${todo:-}$(echo "$new_project_name" | slugify)"
}

parse_params "$@"

# Get users full name
user=$(getent passwd $(whoami) | cut -d ':' -f 5 | cut -d ',' -f 1)

# 
# Make new project, idempotently
# 
git init "$new_project_dir"

if [ ! -f "$new_project_dir/notes.adoc" ]; then
cat << EOF > "$new_project_dir/notes.adoc"
# $new_project_name
:author: $user
EOF
fi

if [ ! -f "$new_project_dir/README.adoc" ]; then
cat << EOF > "$new_project_dir/README.adoc"
# $new_project_name
:author: $user
EOF
fi

if [ "$public" = true ]; then
  cd "$new_project_dir"
  gh repo create "$new_project_name" --confirm --public
fi

msg "Project Created: ${bld}$new_project_dir${off}"
ls -halp "$new_project_dir"

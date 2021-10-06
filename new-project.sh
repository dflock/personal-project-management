#!/usr/bin/env bash

# Bash strict mode: http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -o nounset   # Using an undefined variable is fatal
set -o errexit   # A sub-process/shell returning non-zero is fatal
# set -o pipefail  # If a pipeline step fails, the pipelines RC is the RC of the failed step
# set -o xtrace    # Output a complete trace of all bash actions; uncomment for debugging

# IFS=$'\n\t'  # Only split strings on newlines & tabs, not spaces.

function init() {
  readonly script_path="${BASH_SOURCE[0]:-$0}"
  readonly script_dir="$(dirname "$(readlink -f "$script_path")")"
  readonly script_name="$(basename "$script_path")"

  public=false
  script=false

  setup_colors
  parse_params "$@"
}

function usage() {
  cat <<EOF

Create & scaffold a new personal project

${bld}USAGE${off}
  $script_name [options] PROJECT NAME

${bld}OPTIONS${off}
  -h, --help       show this help
  -p, --public     make the project public by creating a Github repository
  -s, --script     include skeleton stuff for a bash script in the project
  -t, --todo       make the project pending, by creating it in the "$HOME/projects/_todo/" folder

${bld}ARGUMENTS${off}
  PROJECT NAME     the name of the new project. Spaces are allowed.

${bld}EXAMPLES${off}
  ${gry}# Create a new project called "test project"${off}
  $ $script_name test project
  
  ${gry}# Create a new public project called "test project"${off}
  $ $script_name --public test project
EOF
  exit
}

function setup_colors() {
  if [[ -t 2 ]] && [[ -z "${NO_COLOR-}" ]] && [[ "${TERM-}" != "dumb" ]]; then
    # Control sequences for fancy colours
    readonly gry="$(tput setaf 240 2> /dev/null || true)"
    readonly bld="$(tput bold 2> /dev/null || true)"
    readonly off="$(tput sgr0 2> /dev/null || true)"
  else
    readonly gry=''
    readonly bld=''
    readonly off=''
  fi
}

function msg() {
  echo >&2 -e "${1:-}"
}

function die() {
  local msg=$1
  local code=${2:-1} # default exit status 1
  msg "$msg"
  exit "$code"
}

function slugify() {
  tr -s ' ' | tr ' A-Z' '-a-z' | tr -s '-' | tr -c '[:alnum:][:cntrl:].' '-'
}

function trim() {
  # Merge all passed in arguments into $var
  local var="$*"
  # remove leading whitespace characters
  var="${var#"${var%%[![:space:]]*}"}"
  # remove trailing whitespace characters
  var="${var%"${var##*[![:space:]]}"}"   
  printf '%s' "$var"
}

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
      -s | --script)
        script=true
        ;;        
      *)
        new_project_name="${new_project_name:-} $param"
        ;;
    esac
  done
  new_project_name=$(trim "${new_project_name:-}")
  new_project_slug=$(echo "$new_project_name" | slugify)
  new_project_dir="$HOME/Projects/${todo:-}$new_project_slug"
}

init "$@"

# Check dependencies
if ! command -v git &> /dev/null
then
  die "git could not be found\n\
    $script_name requires git\n\
    See: https://git-scm.com/" 127
fi
if ! command -v gh &> /dev/null
then
  die "gh could not be found\n\
    $script_name requires gh - Github CLI\n\
    See: https://cli.github.com/" 127
fi


if [[ $# == 0 ]]; then
  msg "Missing parameter: PROJECT NAME."
  usage
fi

# Get users full name
user=$(getent passwd "$(whoami)" | cut -d ':' -f 5 | cut -d ',' -f 1)

# 
# Make new project, idempotently
# 
git init "$new_project_dir"

# Add notes file
if [ ! -f "$new_project_dir/notes.adoc" ]; then
cat << EOF > "$new_project_dir/notes.adoc"
# $new_project_name
:author: $user
EOF
fi

# Add template/skeleton script
if [ "$script" = true -a ! -f "$new_project_dir/$new_project_slug.sh" ]; then
  cp "$script_dir/template_script.sh" "$new_project_dir/$new_project_slug.sh"
  chmod u+x "$new_project_dir/$new_project_slug.sh"
fi

# Create README & github repo, if public
if [ "$public" = true ]; then

# Add README
if [ ! -f "$new_project_dir/README.adoc" ]; then
cat << EOF > "$new_project_dir/README.adoc"
# $new_project_name
:author: $user
EOF

# If adding template script, also add script stuff to README
if [ "$script" = true ]; then
cat << EOF >> "$new_project_dir/README.adoc"
## Requirements

You need \`foo\` installed. See: https://www.foo.org/install/

For Debian/Ubuntu, you can do:

\`\`\`shell
$ sudo apt install foo
\`\`\`

## Installation

\`\`\`shell
$ sudo cp ${new_project_slug}.sh /usr/bin/$new_project_slug
\`\`\`

## Usage

EOF
fi
fi

  cd "$new_project_dir"
  gh repo create "$new_project_slug" --confirm --public
fi

msg "Project Created: ${bld}$new_project_dir${off}"
ls -halp "$new_project_dir"

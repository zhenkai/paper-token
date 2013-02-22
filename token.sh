#!/usr/bin/env bash

GIT=git

TOKEN_FILE=".token"
SHOW=false
INIT=false

ADD_LIST=()
DELETE_LIST=()
CLAIM_LIST=()
RELEASE_LIST=()

BRANCH="ignore-this-branch-token-only"
CURRENT_BRANCH="master"

function usage {
  cat << EOF
usage:
$0 <[-h] | [-i] | [-s]
            | [-a <file [file...]>] [-d <file [file...]>] [-c <file [file...]>] [-r <file [file...]>]>
             -a --add:      add token for files
             -c --claim:    claim token for files
             -d --delete:   delete token for files
             -h --help:     help
             -i --init:     init tokens
             -r --release:  release token for files
             -s --show:     show tokens
EOF
  exit 1
}

function set_cmd {
  if [ $# -lt 1 ]
  then
    echo "Error! Missing parameter for set_cmd"
  fi

  if [ ! -z $CURRENT_CMD ]
  then
    case $CURRENT_CMD in
      "add")
        if [ ${#ADD_LIST[@]} -eq 0 ]
        then
          usage
        fi
        ;;
      "claim")
        if [ ${#CLAIM_LIST[@]} -eq 0 ]
        then
          usage
        fi
        ;;
      "delete")
        if [ ${#DELETE_LIST[@]} -eq 0 ]
        then
          usage
        fi
        ;;
      "release")
        if [ ${#RELEASE_LIST[@]} -eq 0 ]
        then
          usage
        fi
        ;;
      *)
        usage
        ;;
    esac
  fi

  CURRENT_CMD=$1
}

function check_init {
  $GIT branch | grep -q $BRANCH
}

function stash_if_need {
  $GIT status | grep -q "nothing to commit"
  if [ $? -ne 0 ]
  then
    $GIT stash
    echo "true"
  else
    echo "false"
  fi
}

while [ $# -gt 0 ]
do
  case $1 in
    -a | --add)
      set_cmd "add"
      shift
      continue
      ;;
    -c | --claim)
      set_cmd "claim"
      shift
      continue
      ;;
    -d | --delete)
      set_cmd "delete"
      shift
      continue
      ;;
    -h | --help)
      usage
      ;;
    -i | --init)
      INIT=true
      break
      ;;
    -r | --release)
      set_cmd "release"
      shift
      continue
      ;;
    -s | --show)
      SHOW=true
      break
      ;;
    --) # end of all options
      shift
      break
      ;;
    -* | --*)
      echo "Unknown option: $1"
      usage
      ;;
    *)
      if [ -z $CURRENT_CMD ]
      then
        usage
      fi
      case $CURRENT_CMD in
        "add")
          ADD_LIST+=($1)
          ;;
        "claim")
          CLAIM_LIST+=($1)
          ;;
        "delete")
          DELETE_LIST+=($1)
          ;;
        "release")
          RELEASE_LIST+=($1)
          ;;
        *)
          echo "Error: unkonwn cmd $CURRENT_CMD"
          ;;
      esac
      shift
      ;;
  esac
done

if [ $INIT ]
then
  check_init && echo "Error: already initiated!" && exit 1
  stashed=$(stash_if_needed)
  $GIT branch $BRANCH
  $GIT checkout $BRANCH
  touch $TOKEN_FILE
  $GIT add $TOKEN_FILE
  $GIT commit -m "init token"
  $GIT push origin $BRANCH
  $GIT checkout $CURRENT_BRANCH
  if [ $stashed ]
  then
    $GIT stash pop
  fi
  echo "Initialized token. Now you can add and claim tokens."
fi

echo "ADD:" ${ADD_LIST[@]}
echo "DELETE:" ${DELETE_LIST[@]}
echo "CLAIM:" ${CLAIM_LIST[@]}
echo "RELEASE:" ${RELEASE_LIST[@]}



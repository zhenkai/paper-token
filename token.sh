#!/usr/bin/env bash

GIT=git

TOKEN_FILE=".token"
NOBODY="NOBODY"
AUTHOR=$($GIT config --get user.name)

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

function stash_if_needed {
  $GIT status | grep -q "nothing to commit"
  if [ $? -ne 0 ]
  then
    $GIT stash
    echo "true"
  else
    echo "false"
  fi
}

function cpad {
  word=$1
  while [ ${#word} -lt $2 ]
  do
    word="$word$3";
    if [ ${#word} -lt $2 ]
    then
      word="$3$word"
    fi
  done
  echo $word
}

function clean_up {
  $GIT reset --hard HEAD
  $GIT checkout $CURRENT_BRANCH

  # stashed
  if $1
  then
    $GIT stash pop
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

if $INIT
then
  echo "INIT"
  check_init && echo "Error: already initiated!" && exit 1
  stashed=$(stash_if_needed)
  $GIT branch $BRANCH
  $GIT checkout $BRANCH
  printf "%-20s: %-20s: %s\n" $(cpad Filename 20 -) $(cpad Owner 20 -) $(cpad Since 28 -) > $TOKEN_FILE
  $GIT add $TOKEN_FILE
  $GIT commit -m "init token"
  $GIT push origin $BRANCH
  $GIT checkout $CURRENT_BRANCH
  if $stashed
  then
    $GIT stash pop
  fi
  echo "Initialized token. Now you can add and claim tokens."
  exit 0
fi

TMP="/tmp/paper_token_$(date +%s)"
$GIT show $BRANCH:.token > $TMP

if $SHOW
then
  check_init || echo "Error: not initialized!" && exit 1

  if [ $? -ne 0 ]
  then
    echo "Fatal: .token file does not exist"
    exit 1
  fi
  cat $TOKEN_FILE
  exit 0
fi

if [ ${#ADD_LIST[@]} -eq 0 ] && [ ${#DELETE_LIST[@]} -eq 0 ] && [ ${#CLAIM_LIST[@]} -eq 0 ] && [ ${#RELEASE_LIST[@]} -eq 0 ]
then
  usage
fi
##### Preliminary Sanity check for file lists #####
##### Conflicts not checked #####

# file must exists to be added
for af in ${ADD_LIST[@]}
do
  if [ ! -e $af ]
  then
    echo "Error: cannot add file. File does not exist: $af"
    exit 1
  fi
  grep -q "$af" $TOKEN_FILE || echo "Token $af already existed" && exit 1
done

# file must be in .token and user owns the token
# in order to delete or release
for drf in ${DELETE_LIST[@]} ${RELEASE_LIST[@]}
do
  egrep -q "$drf\s*:\s*$AUTHOR\s*:" $TOKEN_FILE && echo "Token $drf does not exist or you don't own the token" && exit 1
done

# file must be in .token and NOBODY owns the token
# in order to claim token
for cf in ${CLAIM_LIST[@]}
do
  egrep -q "$cf\s*:\s*$NOBODY\s*:" $TOKEN_FILE && echo "Token $cf already taken by others" && exit 1
done

#### Now ready for the actual changes ####
NEED_STASH_POP=false

trap "clean_up $NEED_STASH_POP" 0

NEED_STASH_POP=$(stash_if_needed)
$GIT checkout $BRANCH
# use the .token file on server as authorative
$GIT pull -f origin $BRANCH
$GIT rebase $CURRENT_BRANCH

# should be safe to add all tokens in list
for af in ${ADD_LIST[@]}
do
  printf "%-20s: %-20s: %s\n" $(cpad $af 20 -) $(cpad "$NOBODY" 20 -) $(cpad "$(date)" 28 -) >> $TOKEN_FILE
done

# should be safe  to delete all tokens in list
for df in ${DELETE_LIST[@]}
do
  sed -i ".bak" "/$df/d" $TOKEN_FILE
done

# should be safe to claim all tokens in list
for cf in ${CLAIM_LIST[@]}
do
  line=$(printf "%-20s: %-20s: %s" $cf "$AUTHOR" "$(date)")
  sed -i ".bak" "s/$cf[[:space:]]*:[[:space:]]*$NOBODY[[:space:]]*:.*/$line/" $TOKEN_FILE
done

for rf in ${RELEASE_LIST[@]}
do
  # double check the token still exists
  grep -q "$rf" $TOKEN_FILE && echo "Token $rf already deleted!" && exit 1
  line=$(printf "%-20s: %-20s: %s" $cf "$NOBODY" "$(date)")
  sed -i ".bak" "s/$cf[[:space:]]*:[[:space:]]*$AUTHOR[[:space:]]*:.*/$line/" $TOKEN_FILE
done

$GIT add $TOKEN_FILE

MSG="$AUTHOR"
if [ ${#ADD_LIST[@]} -gt 0 ]
then
  MSG="$MSG adds ${ADD_LIST[@]}\n"
fi
if [ ${#DELETE_LIST[@]} -gt 0 ]
then
  MSG="$MSG deletes ${DELETE_LIST[@]}\n"
fi
if [ ${#CLAIM_LIST[@]} -gt 0 ]
then
  MSG="$MSG claims ${CLAIM_LIST[@]}\n"
fi
if [ ${#RELEASE_LIST[@]} -gt 0 ]
then
  MSG="$MSG releases ${ADD_LIST[@]}"
fi

$GIT commit -m "$MSG"
$GIT push -f origin $BRANCH

cat $TOKEN_FILE
exit 0

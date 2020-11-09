# You can fill these, or not. (Github Prefix Example "https://github.com/$LOGIN/")
LOGIN=
CITY=
GITHUB_PREFIX=

if [ "$1" == "-h" ]; then
  echo "Usage: ./42cursus.sh [OPTION]"
  echo "Retrieves all the last repositories from the intra and organises them into directories."
  echo "Might take up to 5 minutes depending on your campus."
  echo "Optionally you can add a github account to retrieve from there aswell."
  echo 
  echo "Dependencies: jq, bash"
  echo 
  echo "Options:"
  echo "  -h            display this help text"
  echo
  exit 
fi

if [ -z $LOGIN ]; then
  echo -n "Login: "
  read LOGIN
fi

if [ -z $CITY ]; then
  echo -n "City of campus: "
  read CITY
fi

if [ -z $GITHUB_PREFIX ]; then
  echo -n "Github prefix (not mandatory): "
  read GITHUB_PREFIX
fi

CITY=${CITY^}

# GET ACCESS TOKEN
MY_AWESOME_SECRET=61685f90ae7ec137cb916dd785cf3d7252dbfd13007d21ead5ff9c150d72f4d5
MY_AWESOME_UID=4c8b6090c10edd4d18bfe036d2ddaacffd63beb223edecdb761d7ebcf0ed7edd
ACCESS_TOKEN=`curl -s -X POST --data "grant_type=client_credentials&client_id=$MY_AWESOME_UID&client_secret=$MY_AWESOME_SECRET" https://api.intra.42.fr/oauth/token | jq ".access_token"`

function echo_red() {
  echo -e -n "\e[031m";echo $@;echo -e -n "\e[m"
}

function echo_green() {
  echo -e -n "\e[032m";echo $@;echo -e -n "\e[m"
}

function echo_gold() {
  echo -e -n "\e[033m";echo $@;echo -e -n "\e[m"
}

function get_all() {
  file="srcs/${@//\//_}.json"
  tmp="srcs/tmp.json"
  mkdir -p srcs

  if [ -s $file ]; then
    echo "$file is already existing"; return
  fi

  for page in {1..99999}; do
    sleep 1 & pid=$!
    if curl -s -X GET --data "access_token=${ACCESS_TOKEN:1:(-1)}" https://api.intra.42.fr/v2/$@?page[number]=$page | jq ".[]" > $tmp; then
      if [ ! -s $tmp ]; then
        wait $pid
        rm -rf $tmp
        break
      fi
    else
      echo "FAILED TO RETRIEVE DATA ($?)"
      exit 1
    fi
    wait $pid
    cat $tmp >> $file
    echo -e -n "\rpage $page of ${@}"
  done
  echo -e "\rAll data retrieved into $file ($page pages)"
}

# Campus informations
get_all campus
campus_id=`cat srcs/campus.json | jq "select(.name==\"$CITY\") | .id"`
if [ -z $campus_id ]; then
  echo_red "Your campus ($CITY) was not found."; exit
fi

echo_green "city:  $CITY's id is $campus_id."

# Retrieve login (can take some times...)
get_all campus/${campus_id}/users
user_id=`cat srcs/campus_${campus_id}_users.json | jq "select(.login==\"$LOGIN\") | .id"`
if [ -z $campus_id ]; then
  echo_red "Your login ($LOGIN) was not found in the $CITY's campus data".; exit
fi

echo_green "login: $LOGIN's id is $user_id."

get_all users/${user_id}/projects_users
get_all users/${user_id}/scale_teams

function 42_cursus_cloner() {
  cat srcs/users_${user_id}_projects_users.json | jq ".project.name" | grep -v "Exam" | grep -v "Piscine" > my_projects.txt

  cat my_projects.txt | while read line; do
    dir=`cat srcs/users_${user_id}_projects_users.json | jq "select(.project.name==$line) | .teams | .[0] | .project_gitlab_path"`
    dir=${dir:1:(-1)}
    dir=${dir#pedago_world\/42-cursus\/}
    mkdir -p $dir

    repo=`cat srcs/users_${user_id}_projects_users.json | jq "select(.project.name==$line) | .teams | .[-1] | .repo_url"`
    echo_gold Vogsphere ${line:1:(-1)}
    git clone ${repo:1:(-1)} $dir/vogsphere-${line:1:(-1)}
    if [ ! -z $GITHUB_PREFIX ]; then
      echo_gold Github ${line:1:(-1)}
      git clone $GITHUB_PREFIX${line:1:(-1)} $dir/github-${line:1:(-1)}
    fi
  done
}
42_cursus_cloner

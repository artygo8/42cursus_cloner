# You can fill these, or not. (Github Prefix Example "https://github.com/$LOGIN/")
LOGIN=agossuin
CITY=brussels
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

RED="\e[031m%s\e[m\n"
GREEN="\e[032m%s\e[m\n"
GOLD="\e[033m%s\e[m\n"

printf $GOLD "Please go to this link:"
echo "https://api.intra.42.fr/oauth/authorize?client_id=4c8b6090c10edd4d18bfe036d2ddaacffd63beb223edecdb761d7ebcf0ed7edd&redirect_uri=http%3A%2F%2Fgoogle.com&response_type=code"
echo
printf $GOLD "Once logged in, you will be redirected to google, but in the ADRESS BAR you can find your access token."
printf $GOLD "Paste Token: "
read ACCESS_TOKEN

# get_all [path] [optional_filter] 
function get_all() {
  file="srcs/${1//\//_}.json"
  tmp="srcs/tmp.json"
  mkdir -p srcs

  if [ -s $file ]; then
    echo "$file is already existing"; return
  fi

  for page in {1..99999}; do
    sleep 1 & pid=$!
    if curl -s -X GET --data "access_token=${ACCESS_TOKEN:1:(-1)}" https://api.intra.42.fr/v2/$1?page[number]=$page$2 | jq ".[]" > $tmp; then
      if [ ! -s $tmp ]; then
        wait $pid
        rm -rf $tmp
        if [ $page == 1 ]; then
          printf $RED "The page \"$1$2\" does not contain anything"
          exit 1
        fi
        break
      fi
    else
      curl -s -X GET --data "access_token=${ACCESS_TOKEN:1:(-1)}" https://api.intra.42.fr/v2/$1?page[number]=$page > result.html
      printf $RED "FAILED TO RETRIEVE DATA (curl result in result.html)"
      exit 1
    fi

    wait $pid
    cat $tmp >> $file
    echo -e -n "\rpage $page of ${1}"

  done
  echo -e "\rAll data retrieved into $file ($page pages)"
}

# Campus informations
get_all campus
campus_id=`cat srcs/campus.json | jq "select(.name==\"$CITY\") | .id"`
if [ -z $campus_id ]; then
  printf $RED "Your campus ($CITY) was not found."; exit
fi

printf $GREEN "city:  $CITY's id is $campus_id."

# Retrieve login (can take some times...)
get_all campus/${campus_id}/users
user_id=`cat srcs/campus_${campus_id}_users.json | jq "select(.login==\"$LOGIN\") | .id"`
if [ -z $campus_id ]; then
  printf $RED "Your login ($LOGIN) was not found in the $CITY's campus data".; exit
fi

printf $GREEN "login: $LOGIN's id is $user_id."

get_all users/${user_id}/projects_users
get_all users/${user_id}/scale_teams

function 42_cursus_cloner() {
  cat srcs/users_${user_id}_projects_users.json | jq ".project.name" | grep -v "Exam" | grep -v "Piscine" > my_projects.txt

  rm -rf projects_ids.txt
  cat my_projects.txt | while read line; do
    cat srcs/users_${user_id}_projects_users.json | jq "select(.project.name==$line) | .id" >> projects_ids.txt

    dir=`cat srcs/users_${user_id}_projects_users.json | jq "select(.project.name==$line) | .teams | .[0] | .project_gitlab_path"`
    dir=${dir:1:(-1)}
    dir=${dir#pedago_world\/42-cursus\/}
    mkdir -p $dir

    repo=`cat srcs/users_${user_id}_projects_users.json | jq "select(.project.name==$line) | .teams | .[-1] | .repo_url"`
    printf $GOLD "Vogsphere ${line:1:(-1)}"
    git clone ${repo:1:(-1)} $dir/vogsphere-${line:1:(-1)}
    if [ ! -z $GITHUB_PREFIX ]; then
      printf $GOLD "Github ${line:1:(-1)}"
      git clone $GITHUB_PREFIX${line:1:(-1)} $dir/github-${line:1:(-1)}
    fi
  done
}
# 42_cursus_cloner


cursus_id=21 #42-cursus (new)
# get_all cursus/$cursus_id/projects

# &filter[kind]=pdf&range[id]=13000,20000
get_all attachments "&filter[kind]=pdf&range[id]=13000,20000"

# project_session_id=929
# get_all projects/$project_session_id

# project_id=1331
# get_all projects/$project_id/attachments
# get_all projects/$project_id/project_sessions
# get_all projects/$project_id/projects
# get_all projects/$project_id/scale_teams
# get_all projects/$project_id/tags


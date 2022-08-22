#!/bin/bash

# Init mode
mode=remote
DEPENDENCY_FILE="protodep.yaml"
DEPENDENCY_LOCAL_FILE="protodep.local.yaml"

while getopts 'm:f:' OPTION; do
  case "$OPTION" in 
    m)
      mode=$OPTARG
      ;;
    f)
      DEPENDENCY_FILE=$OPTARG
      DEPENDENCY_LOCAL_FILE=$(echo $OPTARG | sed 's/yaml/local.yaml/')
      ;;
  esac
done

# Check if yq installed
if ! command -v yq &> /dev/null
then
    echo "🙀 yq is not installed."
    echo "Installing yq"
    brew install yq
    echo "✅ yq installed"
fi

# Check if protobuf installed
if ! command -v protobuf &> /dev/null
then
    echo "🙀 protobuf is not installed."
    echo "Installing protobuf"
    brew install protobuf
    echo "✅ protobuf installed"
fi

# Check if dependency file exists
if [ ! -f $DEPENDENCY_FILE ]
then
    echo "🙀 Dependency file not found."
    echo "🙀 Exiting"
    exit 1
fi

if [ ! -f $DEPENDENCY_LOCAL_FILE ] && [ $mode == "local" ]
then
    echo "🙀 Dependency local file not found."
    echo "🙀 Exiting"
    exit 1
fi

# Loading .env
if [ -f .env ]; then
  export $(echo $(cat .env | sed 's/#.*//g'| xargs) | envsubst)
fi

proto_yaml_file=$DEPENDENCY_FILE
proto_yaml_local_file=$DEPENDENCY_LOCAL_FILE

source=$(yq .source $proto_yaml_file)
branch=$(yq .branch $proto_yaml_file)
outpb=$(yq .outpb $proto_yaml_file)
outdir=$(yq .outdir $proto_yaml_file)
token_key=$(printenv $(yq .token_key $proto_yaml_file))
remote_dependencies=$(yq .dependencies $proto_yaml_file)

if [ $mode == "local" ]
then
  local_dependencies=$(yq .dependencies $proto_yaml_local_file)
fi

command=$(yq .command $proto_yaml_file)

if [[ -z "$source" || $source == null ]] && [ $mode == "remote" ]
then
    echo "🙀 Source is not set. Please set outdir key of protodep.yaml"
    exit 2
fi

if [[ -z "$branch" || $branch == null ]] && [ $mode == "remote" ]
then
    echo "🙀 Branch is not set. Please set branch key of protodep.yaml"
    exit 2
fi

if [[ -z "$outpb" || $outpb == null ]] && [ $mode == "remote" ]
then
    echo "🙀 OutPb is not set. Please set outpb key of protodep.yaml"
    exit 2
fi

if [[ -z "$outdir" || $outdir == null ]] && [ $mode == "remote" ]
then
    echo "🙀 Out dir is not set. Please set outdir key of protodep.yaml"
    exit 2
fi

if [[ -z "$token_key" || $token_key == null ]] && [ $mode == "remote" ]
then
    echo "🙀 Token key is not set. Please set token_key key of protodep.yaml"
    exit 2
fi

if [[ -z "$remote_dependencies" || $remote_dependencies == null ]] && [ $mode == "remote" ]
then
    echo "🙀 Dependencies is not set. Please set dependencies key of protodep.yaml"
    exit 2
fi

if [[ -z "$local_dependencies"  || $local_dependencies == null ]] && [ $mode == "local" ]
then
    echo "🙀 Local Dependencies is not set. Please set dependencies key of protodep.local.yaml"
    exit 2
fi


delete_out_dir() {
  if [ $mode == "local" ];then
    return
  fi

  read -r -p "Are you sure to delete dir '$outpb' and '$outdir' ? [y|N] " response
  if [[ $response =~ (y|yes|Y) ]];then
    rm -rf $outpb/*.proto
    rm -rf $outdir/*
  else
    return
  fi
}

delete_out_dir

fetch_proto() {
  if [ $mode == "local" ];then
    return
  fi

  dependency=$1
  name=$(parse_name $dependency)

  curl -H "Authorization: token $token_key" \
          -H "Accept: application/vnd.github.v3.raw" \
          -o $outpb/$name.proto \
          -L "https://api.github.com/repos/$source/contents/$1.proto?ref=$branch"
}

parse_name() {
  echo $(echo $1 | cut -d "/" -f 2)
}

get_dependencies_list() {
  if [ $mode == "local" ];then
    echo "$(yq eval '.dependencies' $proto_yaml_local_file)"
  else
    echo "$(yq eval '.dependencies' $proto_yaml_file)"
  fi
}

while IFS= read -r value; do
  dependency=$(echo $value | sed 's/\-//g')
  name=$(parse_name $dependency)

  formatted_pb=$(echo $outpb | sed 's/\//\\\//g')
  formatted_outdir=$(echo $outdir | sed 's/\//\\\//g')

  fetch_proto $dependency

  formatted_command=$(echo "$command" | sed "s/\$outpb/$formatted_pb/g" \
    | sed "s/\$dependency/$name/g" \
    | sed "s/\$outdir/$formatted_outdir/g" \
  )

  $($formatted_command)
done < <(get_dependencies_list)

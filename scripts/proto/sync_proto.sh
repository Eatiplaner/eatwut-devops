#!/bin/bash

# Loading .env
if [ -f .env ]; then
  export $(echo $(cat .env | sed 's/#.*//g'| xargs) | envsubst)
fi

proto_yaml_file=protodep.yaml

source=$(yq .source $proto_yaml_file)
branch=$(yq .branch $proto_yaml_file)
outpb=$(yq .outpb $proto_yaml_file)
outdir=$(yq .outdir $proto_yaml_file)
token_key=$(printenv $(yq .token_key $proto_yaml_file))
dependencies=$(yq .dependencies $proto_yaml_file)

command=$(yq .command $proto_yaml_file)

rm -rf $outpb/*
rm -rf $outdir/*

fetch_proto() {
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
done < <(yq eval '.dependencies' $proto_yaml_file)

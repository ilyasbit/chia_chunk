#!/bin/bash

url=$1
suffix=$2
curl $url | jq '.results.results' >config.json

generate_rclone_config() {
  line=$1
  config=$(echo $line | jq -r '.config')
  config=$(echo $config | sed 's/newline/\\n/g')
  echo -e $config >>rclone.conf
  #replace null with demo-bucket on rclone.conf
  sed -i 's/null/demo-bucket/g' rclone.conf
}

force_create_bucket() {
  line=$1
  storj_id=$(echo $line | cut -d "[" -f 2 | cut -d "-" -f 1)
  rclone mkdir $storj_id:demo-bucket --config rclone.conf
}

export -f force_create_bucket

export -f generate_rclone_config

echo "" >rclone.conf

jq -c '.[]' config.json | parallel --bar generate_rclone_config {}

#grep "\-CRYPT]" rclone.conf | parallel -j 10 --bar force_create_bucket {}

#generate union Mount

num_remotes=$(grep -c '.*UNION:$' rclone.conf)
num_unions=$((($num_remotes + 99) / 100))
grep '.*UNION:$' rclone.conf | cut -d "=" -f2 | tr -d " " | cut -d "-" -f1 >listchunk.txt

for i in $(seq 1 $num_unions); do
  start_index=$((($i - 1) * 100))
  end_index=$(($start_index + 99))
  if [ $end_index -ge $num_remotes ]; then
    end_index=$(($num_remotes - 1))
  fi
  upstreams=""
  while read -r line; do
    remote=$line
    upstreams+="$remote: "
  done < <(sed -n "$(($start_index + 1)),$(($end_index + 1))p" listchunk.txt)

  index=$(printf "%03d\n" "$i")
  union="[UNION-${suffix}-${index}]
type = union
upstreams = $upstreams
"
  echo "$union" >>rclone.conf
done

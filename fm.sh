#!/bin/bash

export SSW=/home/isavnin/ssw
export IDL_PATH=.:\+\$SSW/stereo/dev
export SSW_INSTR="secchi lasco"

function find_fts()
{
  local data_path=$1
  local timestamp=$2
  local spacecraft=$3
  local telescope=$4

  case "$spacecraft" in
    "sta" )
      case "$telescope" in
        "cor2" ) suffix="d4c2A";;
        "hi1"  ) suffix="s4h1A";;
        "euvi" ) suffix="n4euA";;
      esac
    ;;
    "stb" )
      case "$telescope" in
        "cor2" ) suffix="d4c2B";;
        "hi1"  ) suffix="s4h1B";;
        "euvi" ) suffix="n4euB";;
      esac
    ;;
    "soho" )
      case "$telescope" in
        "c2" ) suffix="c2L";;
        "c3" ) suffix="c3L";;
      esac
    ;;
  esac

  local files=(`ls "$data_path"/*_"$suffix".fts`)
  local timestamps=(`ls "$data_path"/*_"$suffix".fts | sed 's/^.*\///g' | sed 's/_[^_]*$//g' | sed -r 's/([0-9]{4})([0-9]{2})([0-9]{2})_([0-9]{2})([0-9]{2})([0-9]{2})/\1-\2-\3 \4:\5:\6/g' | sed -r 's/$/\x0/' | xargs -n1 -0 date +%s -d`)
  local dmin=${timestamps[0]}
  local index=0
  for ((i = 0; i < ${#timestamps[*]}-1; i++)); do
    local d=`expr ${timestamps[$i]} - $timestamp`
    local d=${d#-}
    if [ $d -lt $dmin ]; then
      local dmin=$d
      local index=$i
    fi
  done
  echo ${files[$index]}
}

function parse_config_line()
{
  flag=`echo $config_line | cut -d ' ' -f 1`
  date=`echo $config_line | cut -d ' ' -f 2`
  time=`echo $config_line | cut -d ' ' -f 3`
  timestamp=`date +%s -d "$date $time"`
  stb=`echo $config_line | cut -d ' ' -f 4 | tr '[:upper:]' '[:lower:]'`
  soho=`echo $config_line | cut -d ' ' -f 5 | tr '[:upper:]' '[:lower:]'`
  sta=`echo $config_line | cut -d ' ' -f 6 | tr '[:upper:]' '[:lower:]'`
}

event_path=$1
config_path="$event_path"/config
data_path="$event_path"/data
tmp_path="$event_path"/.tmp
cmd_path="$event_path"/.cmd
idl_path="$event_path"/.idl
params_path="$data_path"/.params

idl_cmd_bg=""
cat $config_path | grep ^B > $tmp_path
while read config_line; do

  parse_config_line
  if [ "$sta" != "none" ]; then
    idl_cmd_bg="${idl_cmd_bg}, bg${sta}sta='$(find_fts $data_path $timestamp sta $sta)'"
  elif [ "$stb" != "none" ]; then
    idl_cmd_bg="${idl_cmd_bg}, bg${stb}stb='$(find_fts $data_path $timestamp stb $stb)'"
  elif [ "$soho" != "none" ]; then
    idl_cmd_bg="${idl_cmd_bg}, bg${soho}soho='$(find_fts $data_path $timestamp soho $soho)'"
  fi
done < $tmp_path
rm -rf $tmp_path

n_flag2=`cat $config_path | grep ^2 -c`

if [ $n_flag2 -gt 0 ]; then cat $config_path | grep ^2 > $tmp_path;
else cat $config_path | grep ^1 > $tmp_path; fi

while read config_line; do
  idl_cmd="fm_process, '$data_path'"
  parse_config_line
  idl_cmd="${idl_cmd}, ${sta}sta='$(find_fts $data_path $timestamp sta $sta)'"
  idl_cmd="${idl_cmd}, ${stb}stb='$(find_fts $data_path $timestamp stb $stb)'"
  idl_cmd="${idl_cmd}, euvista='$(find_fts $data_path $timestamp sta euvi)'"
  idl_cmd="${idl_cmd}, euvistb='$(find_fts $data_path $timestamp stb euvi)'"
  idl_cmd="${idl_cmd}, ${soho}soho='$(find_fts $data_path $timestamp soho $soho)'"
  idl_cmd="${idl_cmd}""${idl_cmd_bg}"
  
  if [ -f $params_path ]; then
    idl_cmd="${idl_cmd}, sparaminit=$(cat $params_path)"
    rm -rf $params_path
  fi

  echo ".run fm" > $cmd_path
  echo $idl_cmd >> $cmd_path
  echo "exit" >> $cmd_path

  tcsh -c "source $SSW/gen/setup/setup.ssw; $SSW/gen/setup/ssw_idl $cmd_path"

  rm -rf $cmd_path
done < $tmp_path
rm -rf $tmp_path

mv "$data_path"/*.png "$event_path"/images/


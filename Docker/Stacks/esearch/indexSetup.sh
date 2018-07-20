#!/bin/bash

ESHOST="esproxy-service:9200"
curl -iv -X DELETE "${ESHOST}/arranger-projects-dev"
curl -iv -X DELETE "${ESHOST}/gen3-dev-subject"
curl -iv -X DELETE "${ESHOST}/arranger-projects-dev-gen3-dev-subject"

#
# Arranger has a "projects" index that references
# types in other indexes
#
curl -iv -X PUT "${ESHOST}/arranger-projects-dev" \
-H 'Content-Type: application/json' -d'
{
    "settings" : {
        "index" : {
            "number_of_shards" : 1, 
            "number_of_replicas" : 0 
        }
    },
    "mappings" : {
      "arranger-projects-dev" : {
        "properties" : {
          "active" : {
            "type" : "boolean"
          },
          "config" : {
            "type" : "object"
          },
          "esType" : {
            "type" : "text",
            "fields" : {
              "keyword" : {
                "type" : "keyword",
                "ignore_above" : 256
              }
            }
          },
          "index" : {
            "type" : "text",
            "fields" : {
              "keyword" : {
                "type" : "keyword",
                "ignore_above" : 256
              }
            }
          },
          "name" : {
            "type" : "text",
            "fields" : {
              "keyword" : {
                "type" : "keyword",
                "ignore_above" : 256
              }
            }
          },
          "timestamp" : {
            "type" : "date"
          }
        }
      }
    }
}
'

#
# `subject` index for arranger-projects-dev project
#
curl -iv -X PUT "${ESHOST}/gen3-dev-subject" \
-H 'Content-Type: application/json' -d'
{
    "settings" : {
        "index" : {
            "number_of_shards" : 1, 
            "number_of_replicas" : 0 
        }
    },
    "mappings": {
      "subject": {
        "properties": {
          "name": { "type": "text" },
          "project": { "type": "text" },
          "study": { "type": "text" },
          "gender": { "type": "keyword" },
          "race": { "type": "keyword" },
          "ethnicity": { "type": "keyword" },
          "vital_status": { "type": "keyword" },
          "file_type": { "type": "keyword" },
          "file_format": { "type": "keyword" }
        }
      }
    }
}
'

#
# Arranger type/field data for `subject` index - ugh!
#
curl -iv -X PUT "${ESHOST}/arranger-projects-dev-gen3-dev-subject" \
-H 'Content-Type: application/json' -d'
{
    "settings" : {
        "index" : {
            "number_of_shards" : 1, 
            "number_of_replicas" : 0 
        }
    },
    "mappings": {
      "arranger-projects-dev-gen3-dev-subject": {
        "properties": {
          "field": { "type": "text" },
          "type": { "type": "text" }
        }
      }
    }
}
'

curl -X GET "${ESHOST}/_cat/health?v"

function es_dump() {
  local indexName
  indexName=$1

curl -X GET "${ESHOST}/${indexName}/_search?pretty=true" \
-H 'Content-Type: application/json' -d'
{
  "query": { "match_all": {} }
}
'

}

function es_indices() {
  curl -X GET "${ESHOST}/_cat/indices?v"
}

function es_export() {
  local destFolder
  local indexList

  destFolder="$1"
  mkdir -p "$destFolder"
  indexList="$(es_indices 2> /dev/null | grep arranger- | awk '{ print $3 }')"
  for name in $indexList; do
    echo $name
    npx elasticdump --input http://$ESHOST/$name --output ${destFolder}/${name}__data.json --type data
    npx elasticdump --input http://$ESHOST/$name --output ${destFolder}/${name}__mapping.json --type mapping
  done
}


function es_import() {
  local destFolder
  local indexList

  destFolder="$1"
  #indexList="$(es_indices 2> /dev/null | grep arranger- | awk '{ print $3 }')"
  indexList="$(ls -1 data | sed 's/__.*json$//' | sort -u)"
  for name in $indexList; do
    echo $name
    npx elasticdump --output http://$ESHOST/$name --input data/${name}__data.json --type data
    npx elasticdump --output http://$ESHOST/$name --input data/${name}__mapping.json --type mapping
  done
}

function es_mapping() {
  local indexName
  indexName=$1
  curl -X GET $ESHOST/_mapping/${indexName}?pretty=true
}


#------------------------------------

curl -X PUT "${ESHOST}/arranger-projects-dev/arranger-projects-dev/1?pretty" -H 'Content-Type: application/json' -d'
{
  "index": "gen3-dev-subject",
  "name": "subject",
  "esType": "subject"
}
'

#---------------------------

curl -X PUT "${ESHOST}/arranger-projects-dev-gen3-dev-subject/arranger-projects-dev-gen3-dev-subject/_bulk" -H 'Content-Type: application/json' --data-binary '
{ "create": { "_id": "1"}}  
{"field": "name","type": "String"}
{ "create": {"_id": "2"}}  
{"field": "project","type": "String"}
{ "create": {"_id": "3"}}  
{"field": "study","type": "String"}
{ "create": {"_id": "4"}}  
{"field": "gender","type": "keyword"}
{ "create": {"_id": "5"}}  
{"field": "race","type": "keyword"}
{ "create": {"_id": "6"}}  
{"field": "ethnicity","type": "keyword"}
{ "create": {"_id": "7"}}  
{"field": "vital_status","type": "keyword"}
{ "create": {"_id": "8"}}  
{"field": "file_type","type": "keyword"}
{ "create": {"_id": "9"}}  
{"field": "file_format","type": "keyword"}
'

#--------------------------------------

function indexRecords() {
  local startIndex
  local endIndex
  local COUNT
  local tmpName
  startIndex="${1:-0}"
  endIndex="${2:-0}"

declare -a genderList
declare -a ethnicityList
declare -a raceList
declare -a vitalList
declare -a fileTypeList
declare -a fileFormat

genderList=( male female )
ethnicityList=( 'American Indian' 'Pacific Islander' 'Black' 'Multi-racial' 'White' 'Haspanic' )
raceList=( white black hispanic asian mixed )
vitalList=( Alive Dead )
fileTypeList=( "mRNA Array" "Unaligned Reads" "Lipdomic MS" "Protionic MS" "1Gs Ribosomes")
fileFormatList=( BEM BAM BED CSV FASTQ RAW TAR TSV TXT IDAT )

COUNT=$startIndex
XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}"
tmpName="$(mktemp -p $XDG_RUNTIME_DIR es.json.XXXXXX)"
while [[ $COUNT -lt $endIndex ]]; do
  projectIndex=$(( $RANDOM % 5 ))
  studyIndex=$(( $RANDOM % 10 ))
  gender="${genderList[$(( $RANDOM % ${#genderList[@]}))]}"
  ethnicity="${ethnicityList[$(( $RANDOM % ${#ethnicityList[@]}))]}"
  race="${raceList[$(( $RANDOM % ${#raceList[@]}))]}"
  vital="${vitalList[$(( $RANDOM % ${#vitalList[@]}))]}"
  fileType="${fileTypeList[$(( $RANDOM % ${#fileTypeList[@]}))]}"
  fileFormat="${fileFormatList[$(( $RANDOM % ${#fileFormatList[@]}))]}"

  cat - > "$tmpName" <<EOM
{
  "name": "Subject-$COUNT",
  "project": "Proj-${projectIndex}",
  "study": "Study-${projectIndex}${studyIndex}",
  "gender": "${gender}",
  "ethnicity": "${ethnicity}",
  "race": "${race}",
  "vital_status": "${vital}",
  "file_type": "${fileType}",
  "file_format": "${fileFormat}"
}
EOM
  cat - $tmpName <<EOM
Loading record:
EOM
  curl -X PUT "${ESHOST}/gen3-dev-subject/subject/${COUNT}?pretty" \
       -H 'Content-Type: application/json' "-d@$tmpName"

  let COUNT+=1
done
}

#--------------------------


curl -X GET "${ESHOST}/arranger-projects-dev-gen3-dev-subject/_search" \
-H 'Content-Type: application/json' -d'
{
  "query": { "match_all": {} }
}
'

COUNT=0
while [[ $COUNT -lt 2 ]]; do
  curl -X POST "${ESHOST}/arranger-projects-dev/arranger-projects-dev/${COUNT}/_update?pretty" -H 'Content-Type: application/json' -d"
{ \"doc\": {
  \"id\": $COUNT,
  \"name\": \"A$COUNT\",
  \"count\": $COUNT
}}
"

  let COUNT+=1
done


#----------------------------------
# graphQL queries
#    Looking for fields on type, got: mapping,extended,aggsState,columnsState,matchBoxState,hits,aggregations subject
#
curl  -X POST localhost:3000/search/graphql -H 'Content-Type: application/json' -d'
{
"query":"{ subject { __typename } }"
}
'

curl  -X POST https://reuben.planx-pla.net/api/v0/flat-search/search/graphql -H 'Content-Type: application/json' -d'
{
"query":"{ subject { __typename } }"
}
'

curl  -X POST localhost:3000/search/graphql -H 'Content-Type: application/json' -d'
{
"query":"{ subject { __typename, mapping, hits {total, edges{ node{name, project, study} } }  } }"
}
'

curl  -X POST https://abby.planx-pla.net/api/v0/flat-search/search/graphql -H 'Content-Type: application/json' -d'
{
"query":"{ subject { __typename, mapping, hits {total, edges{ node{name, project, study} } }  } }"
}
'

# 'query { subject { hits{ edges{ node {name} } } }'
# result: {"data":{"subject":{"__typename":"subject","mapping":{"count":{"type":"integer"},"name":{"type":"text"}},"hits":{"total":2,"edges":[{"node":{"name":"A0","count":0}},{"node":{"name":"A1","count":1}}]}}}}

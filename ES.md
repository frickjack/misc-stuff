# TL;DR

Some elastic search queries

## Curls

```
GET bhcprodv2-2018-10/_aliases

POST bhcprodv2-2018-10/bhcprodv2/_search
{
  "from": 0,
  "size": 200,
  "_source": [ "message.log", "timestamp" ],
  "sort": [
    {"timestamp": "asc"}
  ],
  "query": {
    "bool": {
      "must": [
        { "term": {
          "logGroup": "bhcprodv2"
        }},
        {"term": {
          "message.kubernetes.container_name.keyword": "revproxy"
        }},
        { 
          "range": {
            "timestamp" : {
              "gte": "2018/10/01",
              "lte": "2018/10/02",
              "format": "yyyy/MM/dd"
            }
          }
        }
      ]
    }
  }
}

GET bhcprodv2-2018-10/_mapping

POST bhcprodv2-2018-10/bhcprodv2/_search
{
  "from": 0,
  "size": 20,
  "query": {
    "match_all": {}
  },
  "aggs": {
    "mtype": {
      "terms": { "field": "message.kubernetes.container_name.keyword" }
    }
  }
}

POST bhcprodv2-2018-10/bhcprodv2/_search
{
  "from": 0,
  "size": 20,
  "_source": [ "message.log" ],
  "query": {
    "bool": {
      "must": [
        { 
          "range": {
            "message.kubernetes.labels.date" : {
              "gte": "1538370000"
            }
          }
        }
      ]
    }
  },
  "aggs": {
    "mtype": {
      "terms": { "field": "message.kubernetes.container_name.keyword" }
    }
  }
}

```

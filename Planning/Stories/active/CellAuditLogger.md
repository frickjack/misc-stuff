# TL;DR

Develop cell audit logger for testing in basic docker-compose cell dev/test harness

## Details

A littleware cell is a system for asynchronously processing
messages for an `(project, api, session)` that runs on a single VM.
The current design assumes the following services:

* kafka topic for requests, commands, and responses
* redis caches
* object storage prefix for audit logs of kafka topics
* authz and quota and circuit-breaker service - authorizes requests, and promotes to commands
* request/response API - validates JWT session tokens, checks quota and circuit breaker status, adds to the request queue
* audit logging service - logs kafka topics to object storage
* api service - processes commands and generates responses

This story involves the following subtasks:

* document basic cell infrastructure
* develop basic docker-compose dev/test harness
* develop, test, and document the audit logger service

## References


# TL;DR

A table of contents for preparing training modules for new employees.

## Overview

If we spend one day (`8 hours`) training a new employee, and that increases the employee's productivity by 1%, then we'll realize a `0.01 * 40 hours/wk * 52 wks/year = 20 hour` return on that investment.

## Training Modules

### Welcome!

* What is our mission?
* What do we do?
* How do we do it?
* Why is it important?
* What might we do in the future that is in line with our mission?  Ex - Apple expanded from computers to phones, but its mission didn't change.

### What is your role?

* What is our org chart?
    - how many people do we have in each role?
    - what are the different positions in our career ladder?  what is the pay scale in each position?
    - what are the responsibilities in each position?
    - what do we look for in a candidate each position?

* How do we operate?
    - guilds (dev, qa, devops, bio, services)
    - project manager teams

* How will you be evaluated?
    - it is your manager's job to track your performance, provide feedback, and document a formal annual performance review
    - each year's performance review will be when we consider pay raise, bonus, promotion
    - quantitative performance measures
    - qualitative performance measures

* Who are your team's customers/clients?
    - focus on customers - the team is evaluated on its ability to deliver value to its customers
    - the customer is not stupid - if the customer has difficulty with the team's products or is not happy with the team, then the flaw is in the product or the way the team provides service to the customer, and the team needs to work to improve that situation
    - it's the manager's responsibility to communicate performance feedback to the team

* What are our hopes for you?
    - empathy for customers and coworkers
    - self actualization - to reach a position where your demands for basic things like financial security are satisfied, and you are motivated by internal desires
        * to become the best person you can be by seeking out worthy rivals and role models and striving for self improvement
        * help those around you similarly achieve their goals
        * improve the world by contribution to the organization's mission
        * take on difficult but important challenges
        * play an infinite game
            - prioritize progress towards a mission over short term wins
            - accept and learn from failures
            - respect and learn from rivals


### Management processes

- a manager is evaluated by the performance of her team and the performance of the teams she influences (Andy Grove)
- manager is responsible for her team's
    * training
    * motivation
    * processes
- 1 on 1 meetings
- performance review
- planning and project management
- team self evaluation and improvement
    * know your customers
    * metrics
    * feedback


### Our business

* How do we make money?
    - Why do customers value us and pay us?
    - What is the structure of our relationship with each client?
        * technology development and POC contracts - ex: stage, anvil, niaid
        * ongoing commons operations - ex: GDC

* Who are our customers?
    - What is the NIH?
    - NIH organization - NCI, NIAID, NHLBI, ...?
    - CVB

* Who are the other players in the market?  How do we compare?
    - BROAD
    - Seven bridges
    - ...

* How do we plan to grow and develop the business?  How are we trying to position ourselves in the market?

* Who are our customers?

### Automation for developers

* #on_call - what it's for, what it's not for
* introduction to Docker
* introduction to Kubernetes
* introduction to our infrastructure model
    - CSOC, VPN, and admin-vm
    - client account, VPC, and kubernetes
* introduction to your dev environment
* introduction to cloud-automation/
    - gen3 psql
    - aws s3
    - gcloud
    - gen3 es
    - gen3 logs 
    - gen3 roll
    - gen3 db
    - gen3 job
    - gen3 secret
* gitops
    - manifest.json
    - `cdis-manifest` PR's and cron jobs
    - gen3 job run etl, usersync, gitops-sync
    - k8s configmaps and secrets

### Gen3 authentication and authorization

* introduction to OIDC/OAuth
* access tokens and API calls
* API tokens
* commons OIDC clients and refresh tokens
    - Gen3 trusted partners
* arborist and authorization
    - resources
    - permissions
    - policies
    - roles
    - users
* subject level consent codes
* `user.yaml` and `commons-users/` gitops

### Gen3 Object Storage

* Indexd
    - versions
    - authorization
* gen3-client - data-submission, core metadata
* signed URL's
* requester pays mechanisms
* Google cloud-identity access groups and proxy groups
    - service account registration
    - user account registration
* 3rd party object storage

### Gen3 metadata

* what is clinical data?
    - programs, projects, studies, cases/subjects, visits, ... data-nodes
* what is core metadata?
* dictionary data modeling and validation
    - data submission
    - graphql for data validation
* ETL de-normalization for cohort discovery
    - etl mapping
    - guppy graphql and aggregations
* Cohort discovery
    - what is a cohort?
    - manifest exchange
* PFB

### Gen3 tools

* API design and openapi (swagger)
* Review of access tokens and authorization
* Gen3 SDK
* Gen3 workspace
    - Workspace token service 
        * OAUTH client to Gen3
        * vends access tokens based on k8s labels
    - FUSE sidecar
        * user level file system
        * signed URL's
    - hatchery and workspace containers
* mariner 
    - cwl
    - user data
* security concerns
    - container whitelist
    - networking and isolation
    - what to do with products of computation
* gen3 dashboard

### Introduction to bionformatics

* what is TCGA?
    - DNA - MRNA - protein
    - unaligned reads, aligned reads, variants
* what is a pipeline?  CWL?
* tools
    - what is a dataframe?
    - pandas
    - R
    - jupyter lab
* typical research questions
    - is there a correlation between X and Y?
    - which is more effective - X or Y?
    - is observation X for cohort A also true for cohort B?
* retrospective studies - using data collected for other purposes to answer new questions
* data governance
    - PII
    - IRB
* dbGAP
    - data collected by researchers funded by NIH
    - research studies generate data that NIH collects in dbGAP
    - in general - data in hostpital system EMR systems is not made available to the research community outside the context of a specific study
* Q: why don't we pursue a data sharing agreement with the Univserity of Chicago hostpitals similar to what the VA does?  Does the UCH system already have internal processes dedicated to analyzing its data for optimal outcomes, correlating patient diagnosis, etc.?


### Gen3 CICD

* git-flow 
    - branch types and naming convention
    - commit messages
    - rebase and squash
*  PR code review checklist
    - Travis and unit tests
    - style rules - linting, codacy
    - documentation
    - security - static analysis and dependency scan
    - ... (see other document with long PR chcklist)
* integration tests
    - `cdis-manifest` PR's
    - Jenkins environments
    - `gen3-qa`
* code promotion
    - test plans
    - QA - staging - prod
* QA process
    - test cases
    - test cycle
    - reports

### Hiring Process

* What are we looking for?
    - Strengths, not lack of weaknesses - we are trying to expand the capabilities of our team
        Each opening should specify which strengths we are looking for (ex - qa experience, UI development, ...)
    - Diversity of view - beware of byass toward candidates with similar experience and perspective to your own
    - Motivated by team success

* Process overview
    - Resume review
    - Zoom interview - technical screen

* How to review a resume'
    - Team focus - avoid candidates that change jobs every year
    - look for project experience - not particular technology.  For example - a developer with extensive backend development experience with java and mysql is great even though we use python and postgres

* How to conduct a technical screen
    - Introduce yourself
    - Introduce what we do
    - Conduct the screen (see Jesus' page)
    - Answer questions

### Project management

* what is the client's goal for the project
* what is our goal for the project?  how does it align with the overall mission of the center, and our other goals?
* understanding a client
    - what is the client's overall business/mission
    - who are the client's people that are important to the project.  what is their surrounding management structure
* meeting process
    - prepare agenda
    - document action items, etc
    - post meeting communication, documentation, record keeping
* planning, timetables, and deliverables

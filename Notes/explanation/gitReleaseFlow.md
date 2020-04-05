# TL;DR

A strategy for managing monthly releases.

## Process

### Release Management

This process is suitable for a development group with 3 to 5 teams of 5 to 10 each that wants to maintain a monthly release schedule.  For each month long sprint the product has three releases in process.

* *planning* - the release whose feature set is be planned during the sprint, for development in the next sprint
* *development* - the release under active development during the sprint that will be promoted to production at the beginning of the next sprint
* *deployment* - the release promoted to production at the beginning of the sprint

Each release has one or more release managers.  Managing a release is a three month commitment for a release manager.  During planning, the manager works with the product stake holders to identify features to include in the release.  

During development, the manager maintains the *dev* branch of the git repositories (see below).  She coordinates the deployment of the code to a test environment, and tracks the quality of the release through qa testing.

Finally, during deployment the manager promotes the code to the git master branch (see below), then deploys the code to production, and patches bugs discovered in production if the fix cannot wait for the next release.

In summary - each release progresses through a three month time boxed pipeline: planning and design, development and test, deployment and maintenance.  A release may be tracked as a Jira story that progresses through those states.

### Feature Management

Like a release - each feature has an owner that manages its progress through a pipeline that begins with specification and design, then progresses through development, test, and deployment.  A feature may be tracked as a Jira story that progresses through those states.

A simple feature may complete its entire pipeline in less than a month, and merge into the *dev* release under development.  A more sophisticated feature might progress through multiple months of design and review before progressing to development and a phased release. 

### Communicating with Stake Holders

To successfully move a product to a monthly release cycle the project managers must introduce the product's stake holders the new process.  Each month a release of new features and improvements is deployed to each client's staging environment for client testing before promotion to production.  Client requests for simple new features might go directly into development for the next release if resources are available, but otherwise must be prioritized against other work on the release "train".

### Weekly Core Product Meeting

At the end of each week the entire group meets for an hour to present progress over the past week and goals for the next week.  Each release manager presents for 5 to 10 minutes.  The deployment manager reports on which environments (clients) the new release has been deployed to, bugs that have been revealed in production, and patches applied.  The development manager reports which features have been accepted into the release branch, and the status of QA testing.  The planning manager reports on new features and technical debt that will be addressed in the next release, and who will manage each project.

Project managers for different clients or features also speak for 5 to 10 minutes at the weekly meeting, so the entire group has a view of the work in progress across teams.

Note that although the discussion above considers an organization that assigns a different manager to each release; an equally effective strategy might instead have a single manager per team for all releases.  For example, an organization with three teams (A, B, C) might simply make the lead for each team responsible for coordinating all the release activities (planning, development, and deployment) for her team's contribution to each release.  

Or different managers might specialize in each phase of the pipeline, so each release moves from a planning manager to a development manager to a deployment manager.


## Git flow branching scheme

### Release branches

Each git repository maintains two long lived branches - `master` and `dev` for tracking code in production and development respectively.  
The release manager approves all pull requests to the code in her release.  

When a release progresses from development to deployment, its code moves from the `dev` branch to into `master`.  Patches (`major.minor.1`, `major.minor.2`, ...) to the `master` branch are only for bug fixes and security patches that must be deployed to production.

A feature is developed on a branch that merges into the `dev` branch for the next release after it passes QA.


### Release PR Review

* does the new code allow for rollback, and concurrent deploy with last release (canary, rollback)?
* does the new code work with configuration for the previous release?
* does the new code include unit tests?
* is there a straight forward way to setup a dev-test cycle to work with the new code?
* is the code running in a qa environment?
* is there a test plan?
* has the test plan been executed by QA?
* where are the results of the last test cycle?
* is there an SLO? 
* has the SLO been tested?
* have the PR's dependencies been audited for security vulnerabilities?
* has the PR been analyzed for security vulnerabilities? https://www.owasp.org/index.php/Static_Code_Analysis
* does the PR test plan include test cases to verify authn and authz are enforced?
* does the PR include documentation for users (ux workflow), developers (feature design, dev-test process), operators, and testers in a `Process/Release/Semver/Feature.md` file?
* does QA sign off after executing the test plan?
* does ops sign off on the PR?
* does the release owner sign off on the PR?

# TL;DR

Gitflow branching scheme for time-boxed releases.

## Overview

### Release branches

We maintain two release branches - `master` and `dev`.  The `master` branch hosts the code currently active in production.  The `dev` branch hosts code for the next release.  

A particial `major.minor.0` release is scheduled for a particular date with a particular set of features.  Any features not ready a week before are deferred till the next minor release.  We track the features and patches associated with a particular release in markdown files under a `Process/Release/` folder.  
```
Process/Release/1.4/
    README.md
    FeatureX.md
    FeatureY.md
    PatchA.md
    ChoreK.md
```

Each release has a particular owner.  Only two `major.minor.0` releases may be in flight simultaneously - the current production release, and the next release accepting new features under development.
Once a release is merged into `master` - that release owner takes ownership of the `master` branch, and has responsibility for deploying and patching that release.  Patches (`major.minor.1`, `major.minor.2`, ...) to the `master` branch are only for bug fixes and security patches.  A new manager takes ownership of the `dev` branch, and becomes responsible for preparing the next release under development.

Feature development occurs on feature branches, and merges into the `dev` branch for the next release.  A feature branch is merged into the dev branch once it passes QA.

Similarly - patch development occurs on patch branches, and a patch merges into the `master` branch current release, which is then in turn merged back into the dev branch for the next release.

Releases may be nested, so multiple teams may independently each work on its own releases, and an overall product release might synchronize the releases of component teams.


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
* does the PR include documentation for users (ux workflow), developers (feature design, dev-test process), operators, and testers in a `Process/Release/Semver/Feature.md` file?
* does QA sign off after executing the test plan?
* does ops sign off on the PR?
* does the release owner sign off on the PR?

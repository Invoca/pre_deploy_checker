# Pre Deploy Checker [![Build Status](https://semaphoreci.com/api/v1/mikeweaver/pre_deploy_checker/branches/jquery_datatables/badge.svg)](https://semaphoreci.com/mikeweaver/pre_deploy_checker)  [![Coverage Status](https://coveralls.io/repos/github/mikeweaver/pre_deploy_checker/badge.svg)](https://coveralls.io/github/mikeweaver/pre_deploy_checker)
The pre-deploy checker (PDC) is a tool that correlates commits made to GitHub with issues in JIRA. Commits are correlated with JIRA issues by including the JIRA issue key (i.e. STORY-1234) in the commit message. It identifies:
* Commits that do not have corresponding JIRA issues
* JIRA issues that are in the Ready to Deploy state, but have no commits
* For JIRA issues that do have commits it identifies issues that:
    * Do not have post deploy checks, migration checks
    * Are not in the Ready to Deploy state
The PDC sets the status of the branch to Failed if any of the above checks fail. Users can approve the errant JIRA issues or commits via the UI which will then change the status of the branch to Passed.

The tool also allows the user to copy the list of JIRA issues to the clipboard for use in pre-deploy announcements.

## How it works
The PDC can be triggered several ways:
### GitHub Push
* You push a change to GitHub
* GitHub sends a notification about the change to the PDC
* The PDC:
    * Sets the PDC status of the push in GitHub to Pending
    * Gets the list of commits in the push and extracts the JIRA issue numbers from them
    * Requests the details of the JIRA issues from JIRA
    * Examines the commits and JIRA issues for errors
    * Sets the status of the push in GitHub to Passed or Failed, depending on the results of the examination

### JIRA Push
* You change the status of an issue in JIRA
* JIRA sends a notification about the change to the PDC
* The PDC examines the change to determine if it is related to a push it knows about
* If the change is related, it fetches fresh data from GitHub and JIRA and rexamines the data as described in the GitHub Push section above

### Manual Refresh
* You click the Refresh JIRA and Git data button on the PDC UI
* It fetches fresh data from GitHub and JIRA and rexamines the data as described in the GitHub Push section above

## Settings File
* cache_directory: Location to clone git repositories to. Recommended that you set this to your system temporary folder. Defaults to './data/git'.
* web_server_url: The publicly available URL of the web application. i.e. 'http://www.myserver.com'. Used in unsubscribe and suppression links sent by the application.
* project_keys: The keys of the JIRA projects that should be checked.
* valid_statuses: A list of JIRA statuses that indicate a JIRA issue should be considered ready for deployment.
* valid_post_deploy_check_statuses: A list of JIRA post deploy check statuses that indicate the post deploy checks are ready for deployment.
* ignore_commits_with_messages: A list of commit messages that should be excluded from the PDCs output. You may use regular expressions.
* ignore_branches: A list of branch names that should NOT be checked. You may use regular expressions. Defaults to empty list.
* only_branches: A list of branch names that SHOULD be checked. You may use regular expressions. Defaults to empty list.

## JIRA Configuration
* Navigate to https://YOURJIRASERVERNAME/plugins/servlet/webhooks
* Create a webhook that is triggered for issue create, update and delete.
* Point the webhook at http://localhost:3000/api/v1/callbacks/jira/hook

## GitHub Configuration
* Navigate to https://github.com/YOUR_ORG/YOUR_REPO/settings/hooks/
* Create a webhook that is triggered for "Just the push event"
* Point the webhook at http://YOURSERVERNAME/api/v1/callbacks/github/push

## Development Environment Setup
* Install bundler
* Install rbenv
* Install git (>= 2.6.2)
* Install docker (optional)
* Configure git authentication to access the repo(s) you want the pre-deploy checker to operate upon
* Run `bundle install`
* Run `VALIDATE_SETTINGS=false bundle exec rake db:setup RAILS_ENV=development`
* Get OAuth credentials for your JIRA instance. There are some instructions here: https://github.com/nburwell/jira-glue
* Create a data/config/settings.development.yml file (See Settings File section below.)
* Configure secrets, via environment variables of the following names:
    * GITHUB_USER_NAME: GitHub credentials. Recommend creating a personal access token that has "repo:status" scope.
    * GITHUB_PASSWORD
    * JIRA_SITE: Full URL for JIRA instance
    * JIRA_CONSUMER_KEY: JIRA OAuth credential
    * JIRA_ACCESS_KEY: JIRA OAuth credential
    * JIRA_ACCESS_TOKEN: JIRA OAuth credential
    * JIRA_PRIVATE_KEY_FILE: Path to pem file for JIRA OAuth

## Running Locally
* ### Manually
	* The PDC consists of Ruby on Rails web application and a delayed job processor. You must run two processes to operate the application:

			bundle exec rails server
			bundle exec rake jobs:work

* ### With Foreman
	* Foreman is installed during the `bundle install` phase. Just run:

			foreman start

* [Simulate a push from Github](#simulating-pushes-from-github)
* Navigate to http://localhost:3000/jira/status/push/<id from simulated push>/edit

## Running with Docker
The PDC is designed to be run in docker. To do so:
* Create a docker-secrets.env file that contains the same secrets as you are using in your local ENV plus:
    * GITHUB_PRIVATE_KEY
    * JIRA_PRIVATE_KEY
These are the contents of private key files with the linebreaks replaced by \n. This is necessary so the keys can be loaded into the containers using environment variables. Sorry.
* Run docker-compose build
* Run docker-compose up
* Navigate to http://localhost:3000

## Simulating pushes from GitHub
* Use an HTTP client like curl, to POST a GitHub push hook body to http://localhost:3000/api/v1/callbacks/github/push
* You can find an GitHub hook body in the webhook management page of GitHub UI: https://github.com/YOUR_ORG/YOUR_REPO/settings/hooks/
** Click Edit
** Scroll down to Recent Deliveries
** Expand a request
** Copy the payload
* You can also find an example hook body in the spec/fixtures/github_push_payload.json file in this repo

## Simulating issue updates from JIRA
* Use an HTTP client like curl, to POST a GitHub push hook body to http://localhost:3000/api/v1/callbacks/jira/hook
* You can also find an example hook body in the spec/fixtures/jira_hook_payload.json file in this repo
* Otherwise, you will need to setup the PDC to receive hooks from JIRA and check the log, or use a service like requestb.in to receive hooks from JIRA.

## Editing the Settings
1. Open pdc-secrets.yaml in LastPass
2. Copy the value of settings-file-content and Base64 decode it
3. Edit what you want
4. Base64 encode the edited settings
5. Save the LastPass pdc-secrets.yaml secret with the new value
6. Run `kubectl --namespace=deploy-tools edit secrets gcd-secrets` and edit the secrets there too (deploy-tools is the name of the K8 cluster running the PDC; this may change)
7. Delete the pod so that it will restart with the new settings

## Known Issues
* There is a load order problem that may cause the application to complain about required settings missing when running rake tasks. Prepend you command with VALIDATE_SETTINGS=false to disable validation in those cases.
* The PDC expects numeous custom JIRA fields to exist. The use of these fields, and their JIRA field IDs, should be configurable, but they are not.
* The PDC docker containers are running unicorn with a web server (nginx). The causes problems with clients that hold connections open, like load balancers. We need to add an nginx container.

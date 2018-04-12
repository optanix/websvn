#!groovy

/**
 * Jenkins pipeline build file.
 *
 * @version $Id$
 * @copyright 2018, Optanix, Inc.  All Rights Reserved
 */

@Library('common-build-lib@master') _

def config = [:]
config.debianComponentPrefix = 'OPTPL'
config.debug = false
config.dockerRegistry = env.DOCKER_REGISTRY_ENDPOINT ?: 'https://artifactory.awsdev.optanix.com:8443'
config.builderContainer = 'aio-ubuntu-16.04:latest'

nodeWrap {
  def slackChannel = ''
  def debianConfig = [
    repository: env.DEBIAN_REPOSITORY,
    distribution: 'xenial',
    archType: 'all',
    component: 'OPTPL.' + (String)env.BRANCH_NAME.replace('-', '~').replace('_', '.').replace('/', '.'),
    targetPath: 'OPTPL/xenial/' + (String)env.BRANCH_NAME.replace('_', '-').replace('/', '-'),
    branchName: (String)env.BRANCH_NAME.replace('_', '-').replace('/', '-')
  ]

  def jobCustomData = [:]

  def isPullRequest = (env.CHANGE_ID != null)
  def isMasterRelease = (env.BRANCH_NAME == "master" || env.BRANCH_NAME == 'develop' || env.BRANCH_NAME ==~ /^release\/.*/)

  def git = stageCheckout {}

  echo "git repository name: ${git.repoName}"
  echo "Current Tag: ${git.version}"
  echo "Current Version: ${git.shortVersion}"
  echo "Commit: ${git.commit}"
  echo "Author: ${git.author} <${git.email}>"
  echo "Slack channel is: ${slackChannel}"
  echo "Target Debian repository is: ${debianConfig.repository}"
  echo "Debian distribution is: ${debianConfig.distribution}"
  echo "Debian architecture type is: ${debianConfig.archType}"
  echo "Debian Component is: ${debianConfig.component}"

  catchError {
    timeout(time:15, unit:'MINUTES') {
      if (!isPullRequest) {
        stageBuildPublishPackages {
          debian = debianConfig
          dockerRegistry = config.dockerRegistry
          container = config.builderContainer
        }
      }
      currentBuild.result = 'SUCCESS'
    }

    jobCustomData.jobView = "Build-Packages"
    jobCustomData.jobRepoName = "\"${git.repoName}\""
    jobCustomData.build_result = "\"${currentBuild.result}\""
    stageInfluxDbPublish {
      data = jobCustomData
    }
  }
  stageCleanup {}
  stageNotifications {
    commit = git.commit
    author = git.author
    email = git.email
    channel = slackChannel
  }
}

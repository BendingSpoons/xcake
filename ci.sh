#!/usr/bin/env bash
retval=""
package="xcake-fork"

is_non_release_commit() {
  echo "[CHECK] Checking if release commit..";
  message=`git log --pretty=oneline | head -1`;
  for word in $message
  do
    if [[ "$word" == "#release" ]] 
    then
      return 1;
    fi
  done
  return 0;
}

get_gemfile(){
    retval=`ls -1 $package-*.gem`;
}

get_version(){
    retval=`cat lib/xcake/version.rb | grep VERSION | cut -d "'" -f2`;
}

checks() {
    echo "[CHECK] Pre-release checks";

    if is_non_release_commit
    then
      echo "[CHECK] Not a release commit";
      exit 0;
    fi

    if [[ ${TRAVIS_BRANCH} != 'master' ]]
    then
      echo "[CHECK] Cannot release from a branch that is not master!";
      exit 0;
    fi
}

build() {
    echo "[BUILD] Building gem"

    gem build xcake-fork.gemspec;
}

deploy_artifactory() {
    echo "[DEPLOY] Artifactory"
    get_gemfile;
    gemfile=$retval;

    get_version;
    version=$retval;

    jfrog rt upload --url=$ARTIFACTORY_RUBY_URL --access-token=$ARTIFACTORY_CI_TOKEN $gemfile gems-local/gems/$package-$version.gem
}

deploy() {
    echo "[DEPLOY] Starting deploy"

    deploy_artifactory
}

release(){
    echo "[RELEASE] Creating release on Github"

    get_version;
    version=$retval;
    body=$(git log -n 1 --pretty=format:'%b' | tr "\n" "^" | sed "s/\^/\\\\n/g")

    # Create release on github!
    API_JSON=$(printf '{"target_commitish": "%s", "tag_name": "%s", "name": "%s", "body": "%s", "draft": false, "prerelease": false}' "${TRAVIS_COMMIT}" ${version} ${version} "${body}")
    curl --data "$API_JSON" https://api.github.com/repos/BendingSpoons/xcake/releases?access_token=${GITHUB_TOKEN}
}

main(){
    checks

    build

    deploy

    release
}

main

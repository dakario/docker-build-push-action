#!/bin/sh
set -e

function main() {
  echo "" # see https://github.com/actions/toolkit/issues/168

  sanitize "${INPUT_NAME}" "name"
  sanitize "${INPUT_USERNAME}" "username"
  sanitize "${INPUT_PASSWORD}" "password"
  sanitize "${INPUT_REGISTRY}" "registry"

  translateDockerTag

  FULLNAME="${REGISTRY}/${INPUT_NAME}:${TAG}"

  echo ${INPUT_PASSWORD} | docker login -u ${INPUT_USERNAME} --password-stdin ${INPUT_REGISTRY}

  BUILDPARAMS=""

  if uses "${INPUT_BUILDARGS}"; then
    addBuildArgs
  fi

  buildImage

  pushImage

  echo ::set-output name=tag::"${TAG}"

  docker logout
}

function buildImage(){
  docker build -t "${FULLNAME}" .
  docker images
}

function pushImage(){
  docker push "${FULLNAME}"
}

function sanitize() {
  if [ -z "${1}" ]; then
    >&2 echo "Unable to find the ${2}. Did you set with.${2}?"
    exit 1
  fi
}

function isPartOfTheName() {
  [ $(echo "${INPUT_NAME}" | sed -e "s/${1}//g") != "${INPUT_NAME}" ]
}

function translateDockerTag() {
  local BRANCH=$(echo ${GITHUB_REF} | sed -e "s/refs\/heads\///g" | sed -e "s/\//-/g")
  if hasCustomTag; then
    TAG=$(echo ${INPUT_NAME} | cut -d':' -f2)
    INPUT_NAME=$(echo ${INPUT_NAME} | cut -d':' -f1)
  elif isOnMaster; then
    TAG="latest"
  elif isGitTag && usesBoolean "${INPUT_TAG_NAMES}"; then
    TAG=$(echo ${GITHUB_REF} | sed -e "s/refs\/tags\///g")
  elif isGitTag; then
    TAG="latest"
  elif isPullRequest; then
    TAG="${GITHUB_SHA}"
  else
    TAG="${BRANCH}"
  fi;
}

function hasCustomTag() {
  [ $(echo "${INPUT_NAME}" | sed -e "s/://g") != "${INPUT_NAME}" ]
}

function isOnMaster() {
  [ "${BRANCH}" = "master" ]
}

function isGitTag() {
  [ $(echo "${GITHUB_REF}" | sed -e "s/refs\/tags\///g") != "${GITHUB_REF}" ]
}

function isPullRequest() {
  [ $(echo "${GITHUB_REF}" | sed -e "s/refs\/pull\///g") != "${GITHUB_REF}" ]
}

function addBuildArgs() {
  for arg in $(echo "${INPUT_BUILDARGS}" | tr ',' '\n'); do
    BUILDPARAMS="$BUILDPARAMS --build-arg ${arg}"
    echo "::add-mask::${arg}"
  done
}

function uses() {
  [ ! -z "${1}" ]
}

function usesBoolean() {
  [ ! -z "${1}" ] && [ "${1}" = "true" ]
}

main
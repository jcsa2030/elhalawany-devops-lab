#!/bin/bash
set -euo pipefail

GITOPS_REPO_DIR="${GITOPS_REPO_DIR:-$HOME/elhalawany-devops-gitops}"
APP_IMAGE="${APP_IMAGE:-ghcr.io/jcsa2030/elhalawany-devops-lab}"
IMAGE_TAG="${IMAGE_TAG:-security}"
ENVIRONMENT="${ENVIRONMENT:-dev}"

echo "Updating GitOps image tag..."
echo "GitOps repo : $GITOPS_REPO_DIR"
echo "Image       : $APP_IMAGE"
echo "Tag         : $IMAGE_TAG"
echo "Environment : $ENVIRONMENT"

cd "$GITOPS_REPO_DIR"

git pull origin main

cd "overlays/$ENVIRONMENT"

kustomize edit set image "$APP_IMAGE=$APP_IMAGE:$IMAGE_TAG"

cd "$GITOPS_REPO_DIR"

kubectl kustomize "overlays/$ENVIRONMENT" | grep "image:"

git status

if git diff --quiet; then
  echo "No GitOps image change detected."
  exit 0
fi

git add "overlays/$ENVIRONMENT/kustomization.yaml"
git commit -m "Promote $APP_IMAGE:$IMAGE_TAG to $ENVIRONMENT"
git push origin main

echo "GitOps image update completed."

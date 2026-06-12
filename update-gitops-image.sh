#!/bin/bash
set -euo pipefail

GITOPS_REPO_DIR="${GITOPS_REPO_DIR:-$HOME/elhalawany-devops-gitops}"
APP_IMAGE="${APP_IMAGE:-ghcr.io/jcsa2030/elhalawany-devops-lab}"
IMAGE_TAG="${IMAGE_TAG:-security}"
ENVIRONMENT="${ENVIRONMENT:-dev}"

echo "Updating GitOps image tag..."
echo "GitOps repo  : $GITOPS_REPO_DIR"
echo "Image        : $APP_IMAGE"
echo "Tag          : $IMAGE_TAG"
echo "Environment  : $ENVIRONMENT"

cd "$GITOPS_REPO_DIR"

git pull origin main

KUSTOMIZATION_FILE="overlays/$ENVIRONMENT/kustomization.yaml"

if [ ! -f "$KUSTOMIZATION_FILE" ]; then
  echo "ERROR: $KUSTOMIZATION_FILE not found"
  exit 1
fi

python3 - <<PY
from pathlib import Path

file = Path("$KUSTOMIZATION_FILE")
text = file.read_text()

app_image = "$APP_IMAGE"
image_tag = "$IMAGE_TAG"

lines = text.splitlines()
out = []
inside_images = False
changed = False

for line in lines:
    stripped = line.strip()

    if stripped == "images:":
        inside_images = True
        out.append(line)
        continue

    if inside_images and stripped.startswith("newTag:"):
        indent = line[:len(line) - len(line.lstrip())]
        out.append(f"{indent}newTag: {image_tag}")
        changed = True
        inside_images = False
        continue

    out.append(line)

if not changed:
    out.append("")
    out.append("images:")
    out.append(f"  - name: {app_image}")
    out.append(f"    newTag: {image_tag}")

file.write_text("\\n".join(out) + "\\n")
print(f"Updated {file} to tag {image_tag}")
PY

kubectl kustomize "overlays/$ENVIRONMENT" | grep "image:"

git status

if git diff --quiet; then
  echo "No GitOps image change detected."
  exit 0
fi

git add "$KUSTOMIZATION_FILE"
git commit -m "Promote $APP_IMAGE:$IMAGE_TAG to $ENVIRONMENT"
git push origin main

echo "GitOps image update completed."

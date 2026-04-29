#!/usr/bin/env bash
# One-shot deploy to Cloud Run (requires gcloud auth + PROJECT_ID set)
set -euo pipefail

PROJECT_ID="${GOOGLE_CLOUD_PROJECT:-$(gcloud config get-value project)}"
REGION="us-central1"
SERVICE="capware-speedtest"
IMAGE="gcr.io/$PROJECT_ID/$SERVICE"

echo "Building image for project: $PROJECT_ID"
gcloud builds submit \
  --tag "$IMAGE" \
  --project "$PROJECT_ID" \
  .

echo "Deploying to Cloud Run..."
gcloud run deploy "$SERVICE" \
  --image "$IMAGE" \
  --region "$REGION" \
  --platform managed \
  --allow-unauthenticated \
  --min-instances 0 \
  --max-instances 10 \
  --memory 256Mi \
  --cpu 1 \
  --project "$PROJECT_ID"

echo "Service URL:"
gcloud run services describe "$SERVICE" \
  --region "$REGION" \
  --project "$PROJECT_ID" \
  --format "value(status.url)"

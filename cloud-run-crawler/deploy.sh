#!/bin/bash

# ZenRadar Cloud Run Crawler Deployment Script

set -e

# Configuration
PROJECT_ID="zenradar-acb85"  # Replace with your Firebase project ID
REGION="europe-west3"         # Same region as your Firestore
SERVICE_NAME="zenradar-crawler"
IMAGE_NAME="gcr.io/$PROJECT_ID/$SERVICE_NAME"

echo "🚀 Deploying ZenRadar Cloud Run Crawler..."
echo "Project: $PROJECT_ID"
echo "Region: $REGION"
echo "Service: $SERVICE_NAME"

# Build the Docker image
echo "📦 Building Docker image..."
docker build -t $IMAGE_NAME .

# Push to Google Container Registry
echo "🔼 Pushing to Container Registry..."
docker push $IMAGE_NAME

# Deploy to Cloud Run
echo "☁️ Deploying to Cloud Run..."
gcloud run deploy $SERVICE_NAME \
  --image=$IMAGE_NAME \
  --region=$REGION \
  --platform=managed \
  --memory=2Gi \
  --cpu=2 \
  --timeout=900 \
  --max-instances=10 \
  --min-instances=0 \
  --port=8080 \
  --set-env-vars="NODE_ENV=production,LOG_LEVEL=info" \
  --project=$PROJECT_ID

# Get the service URL
SERVICE_URL=$(gcloud run services describe $SERVICE_NAME --region=$REGION --format="value(status.url)" --project=$PROJECT_ID)

echo "✅ Deployment completed!"
echo "🌐 Service URL: $SERVICE_URL"
echo ""
echo "📝 Next steps:"
echo "1. Update your Cloud Function with the service URL:"
echo "   CLOUD_RUN_CRAWLER_URL=$SERVICE_URL"
echo ""
echo "2. Set up IAM permissions for Cloud Functions to invoke this service:"
echo "   gcloud run services add-iam-policy-binding $SERVICE_NAME \\"
echo "     --member='serviceAccount:zenradar@appspot.gserviceaccount.com' \\"
echo "     --role='roles/run.invoker' \\"
echo "     --region=$REGION"
echo ""
echo "3. Deploy your Cloud Functions:"
echo "   cd ../functions && firebase deploy --only functions"

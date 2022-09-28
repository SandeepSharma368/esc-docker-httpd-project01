#!/usr/bin/env sh
IMAGE_TAG="$1/canoe-sync-manager-job:$2"
TASK_FAMILY="$3"
ECS_CLUSTER="$4"
ECS_SERVICE="$5"
TASK_DEFINITION="$(cat taskDefinition.json)"
VPC_STRING="$14"
LB_STRING="$15"
echo "IMAGE_TAG: $IMAGE_TAG \n TASK_FAMILY: $TASK_FAMILY \n ECS_CLUSTER: $ECS_CLUSTER \n ECS_SERVICE: $ECS_SERVICE \n VPC_STRING: $VPC_STRING \n LB_STRING: $LB_STRING \n AWSLOGS_GROUP: $16"
INTEGRATION_ID="$18"

NEW_TASK_DEFINITION=$(echo "$TASK_DEFINITION" | jq --arg IMAGE "$IMAGE_TAG" --arg OAUTH_CLIENT_ID "$7" --arg OAUTH_CLIENT_SECRET "$8" --arg MOCK_CLIENT_USERNAME "$9" --arg MOCK_CLIENT_PASSWORD "$10" --arg SYNC_MANAGER_BASE_URL "$11" --arg CANOE_BASE_URL "$12" --arg USE_ADDEPAR_SANDBOX "$13" --arg AWSLOGS_GROUP "$16" --arg RATE_LIMIT_CLIENT_ID "$17" --arg INTEGRATION_ID "$INTEGRATION_ID" '.taskDefinition | 
                          .containerDefinitions[0].image = $IMAGE |.containerDefinitions[0].environment[0].value = $OAUTH_CLIENT_ID | .containerDefinitions[0].environment[1].value = $OAUTH_CLIENT_SECRET |
                          .containerDefinitions[0].environment[2].value = $SYNC_MANAGER_BASE_URL | .containerDefinitions[0].environment[3].value = $CANOE_BASE_URL | .containerDefinitions[0].environment[4].value = $MOCK_CLIENT_USERNAME | 
                          .containerDefinitions[0].environment[5].value = $MOCK_CLIENT_PASSWORD | .containerDefinitions[0].environment[6].value = $USE_ADDEPAR_SANDBOX | .containerDefinitions[0].environment[7].value = $RATE_LIMIT_CLIENT_ID | .containerDefinitions[0].environment[11].value = $INTEGRATION_ID | .containerDefinitions[0].logConfiguration.options["awslogs-group"] = $AWSLOGS_GROUP')
echo "New Task Definition:"
echo "$NEW_TASK_DEFINITION"
echo "Register Task Revision..."
NEW_TASK_INFO=$(aws ecs register-task-definition --family "$TASK_FAMILY" --region="$AWS_DEFAULT_REGION" --cli-input-json "$NEW_TASK_DEFINITION")
echo "New task info: $NEW_TASK_INFO"
echo "New Revision Task Info..."
NEW_REVISION=$(echo "$NEW_TASK_INFO" | jq '.taskDefinition.revision')

STATUS=$(aws ecs describe-services --cluster "$ECS_CLUSTER" --services "$ECS_SERVICE" | jq '.services | length')
echo "New task definition revision: $NEW_REVISION"

if [ $STATUS -eq 0 ]
  then
    echo "$ECS_SERVICE service in $ECS_CLUSTER not found.. Creating $ECS_SERVICE in $ECS_CLUSTER"
    aws ecs create-service --cluster "$ECS_CLUSTER" --service-name "$ECS_SERVICE" --task-definition "$TASK_FAMILY:$NEW_REVISION" --desired-count 1 --launch-type FARGATE --network-configuration "$VPC_STRING"
  else
    echo "$ECS_SERVICE service in $ECS_CLUSTER found.. Updating current Task Definition with new Image"

    echo "Update Cluster Service..."
    aws ecs update-service --cluster "$ECS_CLUSTER" --service "$ECS_SERVICE" --task-definition "$TASK_FAMILY:$NEW_REVISION" --network-configuration "$VPC_STRING" --load-balancers "[]"
fi

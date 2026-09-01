#!/bin/bash
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCORE=0
TOTAL=100

echo -e "${BLUE}======================================================${NC}"
echo -e "${BLUE}  SIDE QUEST 01: LOGISTICS PIPELINE VERIFICATION     ${NC}"
echo -e "${BLUE}======================================================${NC}"

# Check 1: data-logger & Storage (25 pts)
echo -n "Checking Objective 1 (data-logger & PV/PVC Binding)... "
PVC_STATUS=$(kubectl get pvc logistics-data-pvc -n incident-logistics -o jsonpath='{.status.phase}' 2>/dev/null || echo "NotFound")
LOGGER_STATUS=$(kubectl get pod data-logger -n incident-logistics -o jsonpath='{.status.phase}' 2>/dev/null || echo "NotFound")
LOGGER_READY=$(kubectl get pod data-logger -n incident-logistics -o jsonpath='{.status.containerStatuses[0].ready}' 2>/dev/null || echo "false")

if [ "$PVC_STATUS" == "Bound" ] && [ "$LOGGER_STATUS" == "Running" ] && [ "$LOGGER_READY" == "true" ]; then
    echo -e "${GREEN}[PASS] (+25 pts)${NC}"
    SCORE=$((SCORE + 25))
else
    echo -e "${RED}[FAIL] (0/25 pts)${NC}"
    echo "  - PVC Status: $PVC_STATUS (Expected: Bound)"
    echo "  - Pod Status: $LOGGER_STATUS (Expected: Running, Ready=true)"
fi

# Check 2: order-dispatcher Deployment, Scheduling, Secrets & Probes (35 pts)
echo -n "Checking Objective 2 (order-dispatcher Scheduling, Secrets & Probes)... "
DISPATCHER_DESIRED=$(kubectl get deployment order-dispatcher -n incident-logistics -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")
DISPATCHER_READY=$(kubectl get deployment order-dispatcher -n incident-logistics -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
[ -z "$DISPATCHER_READY" ] && DISPATCHER_READY=0
DISPATCHER_NODES=$(kubectl get pods -n incident-logistics -l app=order-dispatcher -o jsonpath='{.items[*].spec.nodeName}' 2>/dev/null || echo "")

SUB_SCORE_2=0
if [ "$DISPATCHER_READY" -ge 2 ] 2>/dev/null; then
    SUB_SCORE_2=$((SUB_SCORE_2 + 20))
fi

# Check node affinity / scheduling on cka-worker2
ALL_ON_WORKER2=true
if [ -z "$DISPATCHER_NODES" ]; then
    ALL_ON_WORKER2=false
else
    for node in $DISPATCHER_NODES; do
        if [ "$node" != "cka-worker2" ]; then
            ALL_ON_WORKER2=false
        fi
    done
fi

if [ "$ALL_ON_WORKER2" = true ]; then
    SUB_SCORE_2=$((SUB_SCORE_2 + 15))
fi

if [ $SUB_SCORE_2 -eq 35 ]; then
    echo -e "${GREEN}[PASS] (+35 pts)${NC}"
    SCORE=$((SCORE + 35))
else
    echo -e "${RED}[PARTIAL/FAIL] ($SUB_SCORE_2/35 pts)${NC}"
    echo "  - Ready Replicas: $DISPATCHER_READY / $DISPATCHER_DESIRED"
    echo "  - Scheduled Nodes: $DISPATCHER_NODES (Expected on: cka-worker2)"
fi

# Check 3: dispatcher-svc Service Discovery & Endpoints (15 pts)
echo -n "Checking Objective 3 (dispatcher-svc Endpoints & Routing)... "
EP_COUNT=$(kubectl get endpoints dispatcher-svc -n incident-logistics -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null | wc -w)
[ -z "$EP_COUNT" ] && EP_COUNT=0

if [ "$EP_COUNT" -ge 2 ]; then
    echo -e "${GREEN}[PASS] (+15 pts)${NC}"
    SCORE=$((SCORE + 15))
else
    echo -e "${RED}[FAIL] (0/15 pts)${NC}"
    echo "  - Registered Endpoints: $EP_COUNT (Expected: >= 2)"
fi

# Check 4: metrics-collector RBAC & Pod Status (25 pts)
echo -n "Checking Objective 4 (metrics-collector RBAC Authorization)... "
COLLECTOR_STATUS=$(kubectl get pod metrics-collector -n incident-logistics -o jsonpath='{.status.phase}' 2>/dev/null || echo "NotFound")
COLLECTOR_READY=$(kubectl get pod metrics-collector -n incident-logistics -o jsonpath='{.status.containerStatuses[0].ready}' 2>/dev/null || echo "false")
CAN_I=$(kubectl auth can-i list pods --namespace=incident-logistics --as=system:serviceaccount:incident-logistics:collector-sa 2>/dev/null | tr -d '[:space:]' || echo "no")

if [ "$COLLECTOR_STATUS" == "Running" ] && [ "$COLLECTOR_READY" == "true" ] && [ "$CAN_I" == "yes" ]; then
    echo -e "${GREEN}[PASS] (+25 pts)${NC}"
    SCORE=$((SCORE + 25))
else
    echo -e "${RED}[FAIL] (0/25 pts)${NC}"
    echo "  - Collector Pod: $COLLECTOR_STATUS (Ready: $COLLECTOR_READY)"
    echo "  - RBAC can-i list pods: $CAN_I (Expected: yes)"
fi

echo -e "${BLUE}======================================================${NC}"
if [ $SCORE -eq 100 ]; then
    echo -e "${GREEN}TOTAL SCORE: $SCORE / $TOTAL - EXCELLENT WORK! ALL SYSTEMS GREEN!${NC}"
else
    echo -e "${YELLOW}TOTAL SCORE: $SCORE / $TOTAL - SOME OBJECTIVES REMAIN UNRESOLVED.${NC}"
fi
echo -e "${BLUE}======================================================${NC}"
exit 0

#!/bin/bash

# Example Usage Script for GPTComputer Task Management System
# This script demonstrates how to interact with the task management API

# Configuration
SERVER_URL="https://gptcomputer-810360555756.us-central1.run.app"
AUTH_TOKEN="your-auth-secret-here"  # Replace with your actual auth secret

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper function to print colored output
print_step() {
    echo -e "${BLUE}=== $1 ===${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# Check if computer ID is provided
if [ -z "$1" ]; then
    print_error "Usage: $0 <computer-id>"
    print_warning "First run the task_manager.lua on your ComputerCraft computer to get the computer ID"
    exit 1
fi

COMPUTER_ID="$1"

print_step "GPTComputer Task Management Demo"
echo "Server: $SERVER_URL"
echo "Computer ID: $COMPUTER_ID"
echo ""

# Test 1: Check computer status
print_step "Checking Computer Status"
response=$(curl -s -w "\n%{http_code}" \
    -H "Authorization: Bearer $AUTH_TOKEN" \
    "$SERVER_URL/computer/$COMPUTER_ID/status")

http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')

if [ "$http_code" = "200" ]; then
    print_success "Computer is registered and active"
    echo "$body" | jq '.'
else
    print_error "Failed to get computer status (HTTP $http_code)"
    echo "$body"
    exit 1
fi

echo ""

# Test 2: Queue a simple file_out task
print_step "Queuing file_out Task"
task_response=$(curl -s -w "\n%{http_code}" \
    -X POST \
    -H "Authorization: Bearer $AUTH_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
        "program": "file_out",
        "parameters": ["test_output.txt", "Hello from the task management system!"],
        "expectedDuration": 30,
        "priority": 1
    }' \
    "$SERVER_URL/computer/$COMPUTER_ID/queue")

http_code=$(echo "$task_response" | tail -n1)
body=$(echo "$task_response" | sed '$d')

if [ "$http_code" = "200" ]; then
    print_success "Task queued successfully"
    echo "$body" | jq '.'
    TASK_ID=$(echo "$body" | jq -r '.taskId')
else
    print_error "Failed to queue task (HTTP $http_code)"
    echo "$body"
    exit 1
fi

echo ""

# Test 3: Queue another task with different content
print_step "Queuing Another file_out Task"
task2_response=$(curl -s -w "\n%{http_code}" \
    -X POST \
    -H "Authorization: Bearer $AUTH_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
        "program": "file_out",
        "parameters": ["status_report.txt", "Task management system is working correctly!"],
        "expectedDuration": 20,
        "priority": 0
    }' \
    "$SERVER_URL/computer/$COMPUTER_ID/queue")

http_code=$(echo "$task2_response" | tail -n1)
body=$(echo "$task2_response" | sed '$d')

if [ "$http_code" = "200" ]; then
    print_success "Second task queued successfully"
    echo "$body" | jq '.'
else
    print_error "Failed to queue second task (HTTP $http_code)"
    echo "$body"
fi

echo ""

# Test 4: Check updated computer status
print_step "Checking Updated Computer Status"
status_response=$(curl -s \
    -H "Authorization: Bearer $AUTH_TOKEN" \
    "$SERVER_URL/computer/$COMPUTER_ID/status")

echo "$status_response" | jq '.'

queue_length=$(echo "$status_response" | jq '.queueLength')
active_tasks=$(echo "$status_response" | jq '.activeTasks | length')

print_success "Queue length: $queue_length"
print_success "Active tasks: $active_tasks"

echo ""

# Test 5: Monitor task execution
print_step "Monitoring Task Execution"
print_warning "The ComputerCraft computer should now be executing the queued tasks"
print_warning "Check the computer's console output to see the task execution"
print_warning "You can run this script again to see the updated status"

echo ""
print_step "Manual Commands"
echo "Check computer status:"
echo "curl -H 'Authorization: Bearer $AUTH_TOKEN' $SERVER_URL/computer/$COMPUTER_ID/status | jq '.'"
echo ""
echo "Queue a custom task:"
echo "curl -X POST -H 'Authorization: Bearer $AUTH_TOKEN' -H 'Content-Type: application/json' \\"
echo "  -d '{\"program\":\"your_program\",\"parameters\":[\"arg1\",\"arg2\"]}' \\"
echo "  $SERVER_URL/computer/$COMPUTER_ID/queue"

echo ""
print_step "Demo Complete"
print_success "Task management system demonstration finished!"
print_warning "Make sure your ComputerCraft computer is running task_manager.lua to process the queued tasks" 
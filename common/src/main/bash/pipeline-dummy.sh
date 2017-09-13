#!/bin/bash

function deleteService() {
    echo "$*"
}

function deployService() {
    echo "$*" 
}

function outputFolder() {
    echo "target/"
}

function testResultsAntPattern() {
    echo "**/test-results/*.xml"
}

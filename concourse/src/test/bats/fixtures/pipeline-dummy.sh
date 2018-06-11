# ---- BUILD PHASE ----
function build() {
	echo "$*"
}

function apiCompatibilityCheck() {
	echo "$*"
}

# ---- TEST PHASE ----

function testDeploy() {
	echo "$*"
}

function testRollbackDeploy() {
	echo "$*"
}

function prepareForSmokeTests() {
	echo "$*"
}

function runSmokeTests() {
	echo "$*"
}

# ---- STAGE PHASE ----

function stageDeploy() {
	echo "$*"
}

function prepareForE2eTests() {
	echo "$*"
}

function runE2eTests() {
	echo "$*"
}

# ---- PRODUCTION PHASE ----

function prodDeploy() {
	echo "$*"
}

function rollbackToPreviousVersion() {
	echo "$*"
}

function completeSwitchOver() {
	echo "$*"
}

# ---- COMMON ----

function projectType() {
	echo "$*"
}

function outputFolder() {
	echo "$*"
}

function testResultsAntPattern() {
	echo "$*"
}

package io.springframework.cloud.ci

import javaposse.jobdsl.dsl.DslFactory

/**
 * @author Marcin Grzejszczak
 */
class VaultSpringCloudDeployBuildMaker extends AbstractHashicorpDeployBuildMaker {

	VaultSpringCloudDeployBuildMaker(DslFactory dsl) {
		super(dsl, 'spring-cloud-incubator', 'spring-cloud-vault-config')
	}

	@Override
	protected String preStep() {
		return preVaultShell()
	}

	@Override
	protected String postStep() {
		return postVaultShell()
	}
}

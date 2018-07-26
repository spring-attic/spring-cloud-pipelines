package org.springframework.cloud.pipelines.common

import groovy.transform.CompileStatic
import groovy.transform.Immutable

import org.springframework.cloud.projectcrawler.Repository

/**
 * Git repo (either https or ssh) together with the proper project
 * and branch names
 *
 * @author Marcin Grzejszczak
 * @since 1.0.0
 */
@CompileStatic
@Immutable
class Coordinates {
	String gitRepoName
	String fullGitRepo
	String branchName

	static Coordinates fromRepo(Repository repository, PipelineDefaults defaults) {
		String repo = defaults.gitUseSshKey() ? repository.ssh_url : repository.clone_url
		String gitRepoName = repo.split('/').last() - '.git'
		String fullGitRepo = ""
		String branchName = "master"
		int customNameIndex = repo.indexOf('$')
		int customBranchIndex = repo.indexOf('#')
		if (customNameIndex == -1 && customBranchIndex == -1) {
			// url
			fullGitRepo = repo
			branchName = "master"
		} else if (customNameIndex > -1 && (customNameIndex < customBranchIndex || customBranchIndex == -1)) {
			fullGitRepo = repo.substring(0, customNameIndex)
			if (customNameIndex < customBranchIndex) {
				// url$newName#someBranch
				gitRepoName = repo.substring(customNameIndex + 1, customBranchIndex)
				branchName = repo.substring(customBranchIndex + 1)
			} else if (customBranchIndex == -1) {
				// url$newName
				gitRepoName = repo.substring(customNameIndex + 1)
			}
		} else if (customBranchIndex > -1) {
			fullGitRepo = repo.substring(0, customBranchIndex)
			if (customBranchIndex < customNameIndex) {
				// url#someBranch$newName
				gitRepoName = repo.substring(customNameIndex + 1)
				branchName = repo.substring(customBranchIndex + 1, customNameIndex)
			} else if (customNameIndex == -1) {
				// url#someBranch
				gitRepoName = repo.substring(repo.lastIndexOf("/") + 1, customBranchIndex)
				branchName = repo.substring(customBranchIndex + 1)
			}
		}
		return new Coordinates(gitRepoName, fullGitRepo, branchName)
	}
}

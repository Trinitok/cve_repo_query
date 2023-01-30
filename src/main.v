module main

import github_api


fn main() {
	file_query := 'CVE-2017-0143'
	
	searched_cve_repos := github_api.search_for_repos_related_to_cve(file_query)!

	println('here are all the cve repos that have a language, in order of star count: ${searched_cve_repos}')
}
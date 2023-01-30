module github_api

import net.http
import json
import encoding.base64
import time

struct REPO {
	name string
	path string
	url string
	html_url string
	content string
	stargazers_count int
	language string
}

struct REPO_LIST {
	total_count int
	items []REPO
}

struct GITHUB_RESPONSE {
	x_ratelimit_limit int
	x_ratelimit_remaining int
	message string
	body REPO_LIST | REPO
}


//  Will search for all the repos in GitHub that are related to a CVE.
//  Will use the public GitHub API and trickest/cve repo as the starting point and filter the markdown on it
//  It will then query each of the repos listed in trickest/cve and return them in a sorted list by the number of stars
pub fn search_for_repos_related_to_cve(cve_query string)! []REPO {
	results := query_file_in_cve_repo(cve_query)!

	mut site_result := ''
	if results.total_count > 0 {
		for result in results.items {
			site_result = adhoc_query(result.url)!
		}
	}

	mut split_site_result := site_result.split('- https://github.com/')
	
	// filter out the junk from the rest of the markdown that is unrelated to the linked github repos
	split_site_result.delete(0)

	// trim each result and query to get the repo for a repo list
	mut all_repos := []REPO{}
	for i, result in split_site_result {
		if i == 6 {
			break
		}

		trimmed_repo_str := result.trim_space()

		repo_retval := get_repo(trimmed_repo_str) or {
			println(err)
			continue
		}

		// println('searching for repo ${trimmed_repo_str} returned ${repo_retval}')

		if repo_retval.name != '' {
			all_repos << repo_retval
		}
	}

	//  filter out ones that do not have a defined language as they may be a readme only
	mut repos_with_language := all_repos.filter(fn (x REPO) bool {
		return x.language.len > 0
	})
	//  order everything based on stars
	repos_with_language.sort(a.stargazers_count > b.stargazers_count)

	return repos_with_language
}

//  Will perform whatever http.get you so desire and then try to transform the result into the REPO
//  struct and then take the returned contents that are base64 encoded and turn them
//  into human readable content
pub fn adhoc_query(query_str string)! string {
	repo_resp := http.get(query_str) or {
		println('Failed to perform http get on ${query_str}')
		panic(err)
	}
	
	check_if_github_api_requests_remaining(repo_resp)!

	converted := json.decode(REPO, repo_resp.body) or {
		println('failed to parse repo list json')
		panic(err)
	}
	split_newlines_content := converted.content.split('\n')

	mut converted_strings := ''

	for line in split_newlines_content {
		b64_decoded_str := base64.decode_str(line)
		converted_strings = converted_strings + b64_decoded_str
	}
	return converted_strings
}

//  Will allow for other query material in the trickest/cve repo
pub fn general_query_in_cve_repo(query_str string)! REPO_LIST {
	repo_resp := http.get('https://api.github.com/search/code?q=${query_str}+repo:trickest/cve')!
	
	check_if_github_api_requests_remaining(repo_resp)!
	
	converted := json.decode(REPO_LIST, repo_resp.body) or {
		println('failed to parse repo list json')
		panic(err)
	}

	return converted
}

//  Will search for a repo using the public github api.
//  will only be able to find public repos
//  repo_name will need the creator and repo name (Ex: Trinitok/vnmap)
pub fn search_for_repo(repo_name string)! REPO_LIST {
	repo_resp := http.get('https://api.github.com/search/code?q=repo:${repo_name}')!

	check_if_github_api_requests_remaining(repo_resp)!

	converted := json.decode(REPO_LIST, repo_resp.body) or {
		println('failed to parse repo list json for ${repo_resp.body}')
		panic(err)
	}

	return converted
}

// Will check for the custom github headers X-RateLimit-Remaining and X-RateLimit-Reset
//  If X-RateLimit-Remaining is 0 then it will calculate how long until X-RateLimit-Reset
//  is in minutes which will allow you to make github api requests again
// 
//  If X-RateLimit-Remaining is 0 it will panic.  Else this returns nothing
fn check_if_github_api_requests_remaining(resp http.Response)! {
	exact_header_query := http.HeaderQueryConfig {
		exact: false
	}

	custom_ratelimit_remaining_allowed_request_count_header := resp.header.get_custom('X-RateLimit-Remaining', exact_header_query) or {
		println('getting custom github X-RateLimit-Remaining header did not work :(')
		panic(err)
	}

	if custom_ratelimit_remaining_allowed_request_count_header.i64() == 0 {
		custom_ratelimit_remaining_time_for_reset_header := resp.header.get_custom('X-RateLimit-Reset', exact_header_query) or {
			println('getting custom github X-RateLimit-Reset header did not work :(')
			panic(err)
		}

		remaining_time := time.Duration(custom_ratelimit_remaining_time_for_reset_header.i64())
		remaining_time_minutes := remaining_time.seconds()
		panic('There are no github api requests remaining.  Please wait ${remaining_time_minutes.str()} minutes')
	}
}

//  Will get the repo
//  parameter repo_name: should be structured as owner/name_of_repo
pub fn get_repo(repo_name string)! REPO {
	repo_resp := http.get('https://api.github.com/repos/${repo_name}')!

	check_if_github_api_requests_remaining(repo_resp)!

	repo_converted := json.decode(REPO, repo_resp.body) or {
		println('failed to parse repo list json for ${repo_resp.body}')
		panic(err)
	}

	return repo_converted
}

//  Will explicitly query the trickest/cve repo for the desired string
pub fn query_file_in_cve_repo(filename_query string)! REPO_LIST {
	repo_resp := http.get('https://api.github.com/search/code?q=filename:${filename_query}+repo:trickest/cve+language:MD')!

	check_if_github_api_requests_remaining(repo_resp)!

	converted := json.decode(REPO_LIST, repo_resp.body) or {
		println('failed to parse repo list json')
		panic(err)
	}

	return converted
}
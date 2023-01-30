# CVE GitHub Query
If you have a particular CVE you want to lookup, this will search github for repos that will contain the CVE and return them.  They will be ordered based on stars

# Technical
Will use the following repositories to help make guesses and filtering
1. https://github.com/trickest/cve

There is also a local copy of that repo downloaded.

## Anonymous searching
This does prompt for any kind of password.  The downside to this is that GitHub will limit how many searches you can perform after an hour.

# TODO
1. Fix the timing response when being rate limited by GitHub API.  It is woefully inaccurate and confusing
1. Try to incorporate more GitHub API requests using authenticated means
1. Try to incorporate more CVE recommendation repos other than trickest
1. Incorporate some kind of pagination when performing requests and filtering results